import 'package:firebase_database/firebase_database.dart';

class StreakService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Update streak when user completes a study session
  Future<void> updateStreak(String userId) async {
    try {
      DataSnapshot snapshot = await _dbRef.child('users/$userId').get();
      if (!snapshot.exists) return;

      Map userData = snapshot.value as Map;
      int currentStreak = userData['streak'] ?? 0;
      int lastStudyDate = userData['lastStudyDate'] ?? 0;
      
      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);
      DateTime lastStudy = DateTime.fromMillisecondsSinceEpoch(lastStudyDate);
      DateTime lastStudyDay = DateTime(lastStudy.year, lastStudy.month, lastStudy.day);
      
      int daysDifference = today.difference(lastStudyDay).inDays;
      
      int newStreak = currentStreak;
      
      if (daysDifference == 0) {
        // Same day - no change to streak
        print('📅 Học cùng ngày - Streak không đổi: $currentStreak');
        return;
      } else if (daysDifference == 1) {
        // Next day - increment streak
        newStreak = currentStreak + 1;
        print('🔥 Học ngày tiếp theo - Streak tăng: $currentStreak → $newStreak');
      } else {
        // Missed days - reset streak to 1
        newStreak = 1;
        print('💔 Bỏ lỡ ${daysDifference} ngày - Streak reset về 1');
      }
      
      // Update streak and last study date
      await _dbRef.child('users/$userId').update({
        'streak': newStreak,
        'lastStudyDate': now.millisecondsSinceEpoch,
      });
      
      print('✅ Đã cập nhật streak: $newStreak');
      
      // Create achievement notification for milestones
      if (newStreak > 0 && newStreak % 7 == 0) {
        await _createStreakAchievement(userId, newStreak);
      }
    } catch (e) {
      print('❌ Lỗi cập nhật streak: $e');
    }
  }

  // Create achievement notification for streak milestones
  Future<void> _createStreakAchievement(String userId, int streak) async {
    try {
      await _dbRef.child('notifications/$userId').push().set({
        'title': 'Chúc mừng! 🎉',
        'message': 'Bạn đã đạt chuỗi $streak ngày học liên tục. Hãy giữ vững phong độ nhé!',
        'type': 'achievement',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isRead': false,
      });
      print('🏆 Đã tạo thông báo thành tích streak: $streak ngày');
    } catch (e) {
      print('❌ Lỗi tạo thông báo streak: $e');
    }
  }

  // Get current streak
  Future<int> getCurrentStreak(String userId) async {
    try {
      DataSnapshot snapshot = await _dbRef.child('users/$userId/streak').get();
      if (snapshot.exists) {
        return (snapshot.value as num).toInt();
      }
    } catch (e) {
      print('Lỗi lấy streak: $e');
    }
    return 0;
  }

  // Check if user studied today
  Future<bool> hasStudiedToday(String userId) async {
    try {
      DataSnapshot snapshot = await _dbRef.child('users/$userId/lastStudyDate').get();
      if (snapshot.exists) {
        int lastStudyDate = (snapshot.value as num).toInt();
        DateTime lastStudy = DateTime.fromMillisecondsSinceEpoch(lastStudyDate);
        DateTime today = DateTime.now();
        
        return lastStudy.year == today.year &&
               lastStudy.month == today.month &&
               lastStudy.day == today.day;
      }
    } catch (e) {
      print('Lỗi kiểm tra study today: $e');
    }
    return false;
  }

  // Reset streak (for testing)
  Future<void> resetStreak(String userId) async {
    try {
      await _dbRef.child('users/$userId').update({
        'streak': 0,
        'lastStudyDate': 0,
      });
      print('✅ Đã reset streak về 0');
    } catch (e) {
      print('❌ Lỗi reset streak: $e');
    }
  }
}
