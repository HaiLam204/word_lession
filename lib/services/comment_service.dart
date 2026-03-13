import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/comment_model.dart';

class CommentService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Add comment to a deck
  Future<void> addComment(String deckId, String content, {double? rating}) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Vui lòng đăng nhập');

    try {
      // Get user name
      DataSnapshot userSnapshot = await _dbRef.child('users/${user.uid}').get();
      String userName = 'Anonymous';
      if (userSnapshot.exists) {
        Map userData = userSnapshot.value as Map;
        userName = userData['displayName'] ?? 'Anonymous';
      }

      // Create comment
      DatabaseReference commentRef = _dbRef.child('deckComments/$deckId').push();
      
      await commentRef.set({
        'deckId': deckId,
        'userId': user.uid,
        'userName': userName,
        'content': content,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'likes': 0,
        if (rating != null) 'rating': rating,
      });

      // If rating is provided, update deck rating
      if (rating != null) {
        await _updateDeckRating(deckId, user.uid, rating);
      }

      print('✅ Đã thêm bình luận');
    } catch (e) {
      print('❌ Lỗi thêm bình luận: $e');
      rethrow;
    }
  }

  // Update deck rating
  Future<void> _updateDeckRating(String deckId, String userId, double rating) async {
    try {
      // Check if user already rated
      DataSnapshot ratingSnapshot = await _dbRef
          .child('deckRatings/$deckId/$userId')
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

        await _dbRef.child('deckRatings/$deckId/$userId').set(rating);
        await _dbRef.child('decks/$deckId/rating').set(newRating);
      } else {
        // New rating
        double totalRating = currentRating * currentRatingCount + rating;
        int newRatingCount = currentRatingCount + 1;
        double newRating = totalRating / newRatingCount;

        await _dbRef.child('deckRatings/$deckId/$userId').set(rating);
        await _dbRef.child('decks/$deckId/rating').set(newRating);
        await _dbRef.child('decks/$deckId/ratingCount').set(newRatingCount);
      }
    } catch (e) {
      print('Lỗi cập nhật rating: $e');
    }
  }

  // Get comments for a deck
  Stream<List<DeckComment>> getComments(String deckId) {
    return _dbRef
        .child('deckComments/$deckId')
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      List<DeckComment> comments = [];
      if (event.snapshot.value != null) {
        Map data = event.snapshot.value as Map;
        data.forEach((key, value) {
          comments.add(DeckComment.fromMap(key, value));
        });
      }
      // Sort by timestamp descending (newest first)
      comments.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return comments;
    });
  }

  // Like a comment
  Future<void> likeComment(String deckId, String commentId) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Check if user already liked
      DataSnapshot likeSnapshot = await _dbRef
          .child('commentLikes/$commentId/${user.uid}')
          .get();

      DataSnapshot commentSnapshot = await _dbRef
          .child('deckComments/$deckId/$commentId')
          .get();
      
      if (!commentSnapshot.exists) return;

      Map commentData = commentSnapshot.value as Map;
      int currentLikes = commentData['likes'] ?? 0;

      if (likeSnapshot.exists) {
        // Unlike
        await _dbRef.child('commentLikes/$commentId/${user.uid}').remove();
        await _dbRef.child('deckComments/$deckId/$commentId/likes')
            .set(currentLikes > 0 ? currentLikes - 1 : 0);
      } else {
        // Like
        await _dbRef.child('commentLikes/$commentId/${user.uid}').set(true);
        await _dbRef.child('deckComments/$deckId/$commentId/likes')
            .set(currentLikes + 1);
      }
    } catch (e) {
      print('Lỗi like comment: $e');
      rethrow;
    }
  }

  // Check if user liked a comment
  Future<bool> hasLikedComment(String commentId) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      DataSnapshot snapshot = await _dbRef
          .child('commentLikes/$commentId/${user.uid}')
          .get();
      return snapshot.exists;
    } catch (e) {
      return false;
    }
  }

  // Delete comment (only owner can delete)
  Future<void> deleteComment(String deckId, String commentId) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      DataSnapshot commentSnapshot = await _dbRef
          .child('deckComments/$deckId/$commentId')
          .get();
      
      if (!commentSnapshot.exists) return;

      Map commentData = commentSnapshot.value as Map;
      String commentUserId = commentData['userId'] ?? '';

      // Only owner can delete
      if (commentUserId != user.uid) {
        throw Exception('Bạn không có quyền xóa bình luận này');
      }

      await _dbRef.child('deckComments/$deckId/$commentId').remove();
      
      // Remove all likes for this comment
      await _dbRef.child('commentLikes/$commentId').remove();

      print('✅ Đã xóa bình luận');
    } catch (e) {
      print('❌ Lỗi xóa bình luận: $e');
      rethrow;
    }
  }

  // Get comment count for a deck
  Future<int> getCommentCount(String deckId) async {
    try {
      DataSnapshot snapshot = await _dbRef.child('deckComments/$deckId').get();
      if (snapshot.exists) {
        Map data = snapshot.value as Map;
        return data.length;
      }
    } catch (e) {
      print('Lỗi lấy số lượng comment: $e');
    }
    return 0;
  }
}
