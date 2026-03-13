import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/notification_model.dart';

class NotificationService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Get notifications for current user
  Stream<List<NotificationItem>> getNotifications() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    return _dbRef
        .child('notifications/${user.uid}')
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      List<NotificationItem> notifications = [];
      if (event.snapshot.value != null) {
        Map data = event.snapshot.value as Map;
        data.forEach((key, value) {
          notifications.add(NotificationItem.fromMap(key, value));
        });
      }
      // Sort by timestamp descending (newest first)
      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return notifications;
    });
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _dbRef.child('notifications/${user.uid}/$notificationId').update({
      'isRead': true,
    });
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DataSnapshot snapshot = await _dbRef.child('notifications/${user.uid}').get();
    if (snapshot.exists) {
      Map data = snapshot.value as Map;
      Map<String, dynamic> updates = {};
      data.forEach((key, value) {
        updates['$key/isRead'] = true;
      });
      await _dbRef.child('notifications/${user.uid}').update(updates);
    }
  }

  // Create a notification
  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
  }) async {
    DatabaseReference newNotifRef = _dbRef.child('notifications/$userId').push();
    await newNotifRef.set({
      'title': title,
      'message': message,
      'type': type,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'isRead': false,
    });
  }

  // Get unread count
  Future<int> getUnreadCount() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    DataSnapshot snapshot = await _dbRef.child('notifications/${user.uid}').get();
    if (!snapshot.exists) return 0;

    int count = 0;
    Map data = snapshot.value as Map;
    data.forEach((key, value) {
      if (value['isRead'] == false) count++;
    });
    return count;
  }

  // Create study reminder notification
  Future<void> createStudyReminder(String userId, int dueCount) async {
    await createNotification(
      userId: userId,
      title: 'Đến giờ ôn tập rồi!',
      message: 'Bạn có $dueCount thẻ đang chờ ôn tập hôm nay.',
      type: 'study',
    );
  }

  // Create achievement notification
  Future<void> createAchievementNotification(String userId, int streak) async {
    await createNotification(
      userId: userId,
      title: 'Chúc mừng!',
      message: 'Bạn đã đạt chuỗi $streak ngày học liên tục. Hãy giữ vững phong độ nhé!',
      type: 'achievement',
    );
  }
}
