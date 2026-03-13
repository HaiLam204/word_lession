import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class DeckService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Share deck to community with description and tags
  Future<void> shareDeck(String deckId, {String? description, List<String>? tags}) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Get deck info
      DataSnapshot deckSnapshot = await _dbRef.child('decks/$deckId').get();
      if (!deckSnapshot.exists) throw Exception('Deck không tồn tại');

      Map deckData = deckSnapshot.value as Map;
      
      // Get all cards in this deck
      DataSnapshot cardsSnapshot = await _dbRef
          .child('cards')
          .orderByChild('deckId')
          .equalTo(deckId)
          .get();
      
      List<Map<String, dynamic>> cardsList = [];
      if (cardsSnapshot.exists) {
        Map cardsData = cardsSnapshot.value as Map;
        cardsData.forEach((key, value) {
          cardsList.add({
            'front': value['front'],
            'back': value['back'],
            'example': value['example'] ?? '',
          });
        });
      }
      
      // Update deck to public with cards data
      Map<String, dynamic> updateData = {
        'isPublic': true,
        'sharedAt': DateTime.now().millisecondsSinceEpoch,
        'sharedCards': cardsList,
        'rating': 0.0,
        'ratingCount': 0,
        'likes': 0,
        'saves': 0,
      };
      
      if (description != null && description.isNotEmpty) {
        updateData['description'] = description;
      }
      
      if (tags != null && tags.isNotEmpty) {
        updateData['tags'] = tags;
      }
      
      await _dbRef.child('decks/$deckId').update(updateData);

      print('✅ Đã chia sẻ deck thành công');
    } catch (e) {
      print('❌ Lỗi chia sẻ deck: $e');
      rethrow;
    }
  }

  // Unshare deck from community
  Future<void> unshareDeck(String deckId) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _dbRef.child('decks/$deckId').update({
        'isPublic': false,
      });
      print('✅ Đã hủy chia sẻ deck');
    } catch (e) {
      print('❌ Lỗi hủy chia sẻ: $e');
      rethrow;
    }
  }

  // Copy deck from community to user's library
  Future<void> copyDeckToLibrary(String sourceDeckId) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Vui lòng đăng nhập');

    try {
      // Get source deck
      DataSnapshot deckSnapshot = await _dbRef.child('decks/$sourceDeckId').get();
      if (!deckSnapshot.exists) throw Exception('Deck không tồn tại');

      Map sourceDeck = deckSnapshot.value as Map;

      // Get shared cards from deck
      List<dynamic> sharedCards = sourceDeck['sharedCards'] ?? [];
      
      // FALLBACK: Nếu deck cũ chưa có sharedCards, thử đọc từ cards table
      if (sharedCards.isEmpty) {
        print('⚠️ Deck chưa có sharedCards, đang thử đọc từ cards table...');
        try {
          DataSnapshot cardsSnapshot = await _dbRef
              .child('cards')
              .orderByChild('deckId')
              .equalTo(sourceDeckId)
              .get();
          
          if (cardsSnapshot.exists) {
            Map cardsData = cardsSnapshot.value as Map;
            sharedCards = cardsData.values.map((card) => {
              'front': card['front'] ?? '',
              'back': card['back'] ?? '',
              'example': card['example'] ?? '',
            }).toList();
            print('✅ Đã lấy được ${sharedCards.length} cards từ cards table');
          }
        } catch (e) {
          print('❌ Không thể đọc cards: $e');
        }
      }
      
      if (sharedCards.isEmpty) {
        throw Exception('Deck này chưa có thẻ nào hoặc chủ sở hữu chưa cập nhật deck');
      }

      // Create new deck for current user
      DatabaseReference newDeckRef = _dbRef.child('decks').push();
      String newDeckId = newDeckRef.key!;

      await newDeckRef.set({
        'id': newDeckId,
        'ownerId': user.uid,
        'name': sourceDeck['name'],
        'description': sourceDeck['description'] ?? '',
        'cardCount': sharedCards.length,
        'isPublic': false,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'copiedFrom': sourceDeckId,
      });

      // Copy all cards from sharedCards
      int now = DateTime.now().millisecondsSinceEpoch;
      
      for (var cardData in sharedCards) {
        await _dbRef.child('cards').push().set({
          'ownerId': user.uid,
          'deckId': newDeckId,
          'front': cardData['front'] ?? '',
          'back': cardData['back'] ?? '',
          'example': cardData['example'] ?? '',
          'dueDate': now,
          'interval': 0,
          'easeFactor': 2.5,
          'status': 'new',
        });
      }

      print('✅ Đã sao chép deck thành công');
    } catch (e) {
      print('❌ Lỗi sao chép deck: $e');
      rethrow;
    }
  }

  // Get public decks for community
  Stream<List<Map<String, dynamic>>> getPublicDecks() {
    return _dbRef
        .child('decks')
        .onValue
        .map((event) {
      List<Map<String, dynamic>> decks = [];
      if (event.snapshot.value != null) {
        Map data = event.snapshot.value as Map;
        data.forEach((key, value) {
          Map<String, dynamic> deck = Map<String, dynamic>.from(value);
          // Filter only public decks
          if (deck['isPublic'] == true) {
            deck['id'] = key;
            decks.add(deck);
          }
        });
      }
      // Sort by sharedAt descending (newest first)
      decks.sort((a, b) {
        int aTime = a['sharedAt'] ?? 0;
        int bTime = b['sharedAt'] ?? 0;
        return bTime.compareTo(aTime);
      });
      return decks;
    });
  }

  // Get deck owner info
  Future<Map<String, dynamic>?> getDeckOwnerInfo(String ownerId) async {
    try {
      DataSnapshot snapshot = await _dbRef.child('users/$ownerId').get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
    } catch (e) {
      print('Lỗi lấy thông tin owner: $e');
    }
    return null;
  }

  // Like a deck
  Future<void> likeDeck(String deckId) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Check if user already liked
      DataSnapshot likeSnapshot = await _dbRef
          .child('deckLikes/$deckId/${user.uid}')
          .get();

      if (likeSnapshot.exists) {
        // Unlike
        await _dbRef.child('deckLikes/$deckId/${user.uid}').remove();
        
        // Decrement likes count
        DataSnapshot deckSnapshot = await _dbRef.child('decks/$deckId').get();
        if (deckSnapshot.exists) {
          Map deckData = deckSnapshot.value as Map;
          int currentLikes = deckData['likes'] ?? 0;
          
          // Only update if user is owner or use transaction
          try {
            await _dbRef.child('decks/$deckId/likes').set(currentLikes > 0 ? currentLikes - 1 : 0);
          } catch (e) {
            print('Không thể cập nhật likes count (không phải owner)');
          }
        }
      } else {
        // Like
        await _dbRef.child('deckLikes/$deckId/${user.uid}').set(true);
        
        // Increment likes count
        DataSnapshot deckSnapshot = await _dbRef.child('decks/$deckId').get();
        if (deckSnapshot.exists) {
          Map deckData = deckSnapshot.value as Map;
          int currentLikes = deckData['likes'] ?? 0;
          
          // Only update if user is owner or use transaction
          try {
            await _dbRef.child('decks/$deckId/likes').set(currentLikes + 1);
          } catch (e) {
            print('Không thể cập nhật likes count (không phải owner)');
          }
        }
      }
    } catch (e) {
      print('Lỗi like deck: $e');
      rethrow;
    }
  }

  // Check if user liked a deck
  Future<bool> hasLikedDeck(String deckId) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      DataSnapshot snapshot = await _dbRef
          .child('deckLikes/$deckId/${user.uid}')
          .get();
      return snapshot.exists;
    } catch (e) {
      return false;
    }
  }

  // Save a deck to favorites
  Future<void> saveDeck(String deckId) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Check if user already saved
      DataSnapshot saveSnapshot = await _dbRef
          .child('deckSaves/$deckId/${user.uid}')
          .get();

      if (saveSnapshot.exists) {
        // Unsave
        await _dbRef.child('deckSaves/$deckId/${user.uid}').remove();
        
        // Decrement saves count
        DataSnapshot deckSnapshot = await _dbRef.child('decks/$deckId').get();
        if (deckSnapshot.exists) {
          Map deckData = deckSnapshot.value as Map;
          int currentSaves = deckData['saves'] ?? 0;
          
          try {
            await _dbRef.child('decks/$deckId/saves').set(currentSaves > 0 ? currentSaves - 1 : 0);
          } catch (e) {
            print('Không thể cập nhật saves count (không phải owner)');
          }
        }
      } else {
        // Save
        await _dbRef.child('deckSaves/$deckId/${user.uid}').set(true);
        
        // Increment saves count
        DataSnapshot deckSnapshot = await _dbRef.child('decks/$deckId').get();
        if (deckSnapshot.exists) {
          Map deckData = deckSnapshot.value as Map;
          int currentSaves = deckData['saves'] ?? 0;
          
          try {
            await _dbRef.child('decks/$deckId/saves').set(currentSaves + 1);
          } catch (e) {
            print('Không thể cập nhật saves count (không phải owner)');
          }
        }
      }
    } catch (e) {
      print('Lỗi save deck: $e');
      rethrow;
    }
  }

  // Check if user saved a deck
  Future<bool> hasSavedDeck(String deckId) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      DataSnapshot snapshot = await _dbRef
          .child('deckSaves/$deckId/${user.uid}')
          .get();
      return snapshot.exists;
    } catch (e) {
      return false;
    }
  }

  // Rate a deck
  Future<void> rateDeck(String deckId, double rating) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Check if user already rated
      DataSnapshot ratingSnapshot = await _dbRef
          .child('deckRatings/$deckId/${user.uid}')
          .get();

      DataSnapshot deckSnapshot = await _dbRef.child('decks/$deckId').get();
      if (!deckSnapshot.exists) return;

      Map deckData = deckSnapshot.value as Map;
      double currentRating = (deckData['rating'] ?? 0.0).toDouble();
      int currentRatingCount = deckData['ratingCount'] ?? 0;

      if (ratingSnapshot.exists) {
        // Update existing rating
        double oldRating = (ratingSnapshot.value as num).toDouble();
        double totalRating = currentRating * currentRatingCount;
        totalRating = totalRating - oldRating + rating;
        double newRating = totalRating / currentRatingCount;

        await _dbRef.child('deckRatings/$deckId/${user.uid}').set(rating);
        await _dbRef.child('decks/$deckId').update({
          'rating': newRating,
        });
      } else {
        // New rating
        double totalRating = currentRating * currentRatingCount + rating;
        int newRatingCount = currentRatingCount + 1;
        double newRating = totalRating / newRatingCount;

        await _dbRef.child('deckRatings/$deckId/${user.uid}').set(rating);
        await _dbRef.child('decks/$deckId').update({
          'rating': newRating,
          'ratingCount': newRatingCount,
        });
      }
    } catch (e) {
      print('Lỗi rate deck: $e');
      rethrow;
    }
  }

  // Get user's rating for a deck
  Future<double?> getUserRating(String deckId) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      DataSnapshot snapshot = await _dbRef
          .child('deckRatings/$deckId/${user.uid}')
          .get();
      if (snapshot.exists) {
        return (snapshot.value as num).toDouble();
      }
    } catch (e) {
      return null;
    }
    return null;
  }
}
