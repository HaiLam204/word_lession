import 'package:firebase_database/firebase_database.dart';
import '../models/app_models.dart';

class LeaderboardService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Get top users by XP
  Future<List<Map<String, dynamic>>> getTopUsersByXP({int limit = 50}) async {
    try {
      print('🔍 Đang query users by XP...');
      DataSnapshot snapshot = await _dbRef
          .child('users')
          .orderByChild('xp')
          .limitToLast(limit)
          .get();

      print('📊 Query result exists: ${snapshot.exists}');
      
      List<Map<String, dynamic>> users = [];
      if (snapshot.exists) {
        Map data = snapshot.value as Map;
        print('📊 Total users found: ${data.length}');
        
        data.forEach((key, value) {
          Map<String, dynamic> user = Map<String, dynamic>.from(value);
          user['id'] = key;
          int xp = user['xp'] ?? 0;
          print('👤 User: ${user['displayName']} - XP: $xp');
          users.add(user);
        });
      } else {
        print('⚠️ No users found in query');
      }

      // Sort descending by XP
      users.sort((a, b) => (b['xp'] ?? 0).compareTo(a['xp'] ?? 0));
      print('✅ Sorted ${users.length} users by XP');
      return users;
    } catch (e) {
      print('❌ Lỗi lấy leaderboard XP: $e');
      return [];
    }
  }

  // Get top users by total decks created
  Future<List<Map<String, dynamic>>> getTopUsersByDecks({int limit = 50}) async {
    try {
      DataSnapshot snapshot = await _dbRef
          .child('users')
          .orderByChild('totalDecks')
          .limitToLast(limit)
          .get();

      List<Map<String, dynamic>> users = [];
      if (snapshot.exists) {
        Map data = snapshot.value as Map;
        data.forEach((key, value) {
          Map<String, dynamic> user = Map<String, dynamic>.from(value);
          user['id'] = key;
          users.add(user);
        });
      }

      // Sort descending by totalDecks
      users.sort((a, b) => (b['totalDecks'] ?? 0).compareTo(a['totalDecks'] ?? 0));
      return users;
    } catch (e) {
      print('Lỗi lấy leaderboard Decks: $e');
      return [];
    }
  }

  // Get top users by streak
  Future<List<Map<String, dynamic>>> getTopUsersByStreak({int limit = 50}) async {
    try {
      DataSnapshot snapshot = await _dbRef
          .child('users')
          .orderByChild('streak')
          .limitToLast(limit)
          .get();

      List<Map<String, dynamic>> users = [];
      if (snapshot.exists) {
        Map data = snapshot.value as Map;
        data.forEach((key, value) {
          Map<String, dynamic> user = Map<String, dynamic>.from(value);
          user['id'] = key;
          users.add(user);
        });
      }

      // Sort descending by streak
      users.sort((a, b) => (b['streak'] ?? 0).compareTo(a['streak'] ?? 0));
      return users;
    } catch (e) {
      print('Lỗi lấy leaderboard Streak: $e');
      return [];
    }
  }

  // Update user XP (call this after completing a study session)
  Future<void> addXP(String userId, int xpToAdd) async {
    try {
      DataSnapshot snapshot = await _dbRef.child('users/$userId/xp').get();
      int currentXP = 0;
      if (snapshot.exists) {
        currentXP = (snapshot.value as num).toInt();
      }
      await _dbRef.child('users/$userId/xp').set(currentXP + xpToAdd);
    } catch (e) {
      print('Lỗi cập nhật XP: $e');
    }
  }

  // Subtract XP (never go below 0)
  Future<void> subtractXP(String userId, int xpToSubtract) async {
    try {
      DataSnapshot snapshot = await _dbRef.child('users/$userId/xp').get();
      int currentXP = 0;
      if (snapshot.exists) {
        currentXP = (snapshot.value as num).toInt();
      }
      int newXP = (currentXP - xpToSubtract).clamp(0, 999999);
      await _dbRef.child('users/$userId/xp').set(newXP);
    } catch (e) {
      print('Lỗi trừ XP: $e');
    }
  }

  // Update total decks count (call this when user creates a deck)
  Future<void> incrementDeckCount(String userId) async {
    try {
      DataSnapshot snapshot = await _dbRef.child('users/$userId/totalDecks').get();
      int currentCount = 0;
      if (snapshot.exists) {
        currentCount = (snapshot.value as num).toInt();
      }
      await _dbRef.child('users/$userId/totalDecks').set(currentCount + 1);
    } catch (e) {
      print('Lỗi cập nhật deck count: $e');
    }
  }

  // Decrement total decks count (call this when user deletes a deck)
  Future<void> decrementDeckCount(String userId) async {
    try {
      DataSnapshot snapshot = await _dbRef.child('users/$userId/totalDecks').get();
      int currentCount = 0;
      if (snapshot.exists) {
        currentCount = (snapshot.value as num).toInt();
      }
      if (currentCount > 0) {
        await _dbRef.child('users/$userId/totalDecks').set(currentCount - 1);
      }
    } catch (e) {
      print('Lỗi cập nhật deck count: $e');
    }
  }

  // Get user rank in a specific leaderboard
  Future<int> getUserRank(String userId, String type) async {
    try {
      List<Map<String, dynamic>> leaderboard;
      
      switch (type) {
        case 'xp':
          leaderboard = await getTopUsersByXP(limit: 1000);
          break;
        case 'decks':
          leaderboard = await getTopUsersByDecks(limit: 1000);
          break;
        case 'streak':
          leaderboard = await getTopUsersByStreak(limit: 1000);
          break;
        default:
          return -1;
      }

      for (int i = 0; i < leaderboard.length; i++) {
        if (leaderboard[i]['id'] == userId) {
          return i + 1; // Rank starts from 1
        }
      }
      
      return -1; // Not found
    } catch (e) {
      print('Lỗi lấy rank: $e');
      return -1;
    }
  }
}
