import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/notification_service.dart';

class TestNotificationScreen extends StatelessWidget {
  const TestNotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final NotificationService notificationService = NotificationService();
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Test Thông báo')),
        body: const Center(child: Text('Vui lòng đăng nhập')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Thông báo'),
        backgroundColor: const Color(0xFF3E8F8B),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Tạo thông báo test',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Study notification
          _buildTestButton(
            context,
            title: 'Thông báo học tập',
            subtitle: 'Tạo thông báo nhắc nhở học',
            icon: Icons.school,
            color: const Color(0xFF3E8F8B),
            onPressed: () async {
              await notificationService.createStudyReminder(user.uid, 15);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã tạo thông báo học tập')),
                );
              }
            },
          ),
          const SizedBox(height: 16),

          // Achievement notification
          _buildTestButton(
            context,
            title: 'Thông báo thành tích',
            subtitle: 'Tạo thông báo chuỗi ngày học',
            icon: Icons.emoji_events,
            color: Colors.amber,
            onPressed: () async {
              await notificationService.createAchievementNotification(user.uid, 7);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã tạo thông báo thành tích')),
                );
              }
            },
          ),
          const SizedBox(height: 16),

          // System notification
          _buildTestButton(
            context,
            title: 'Thông báo hệ thống',
            subtitle: 'Tạo thông báo cập nhật',
            icon: Icons.update,
            color: Colors.blue,
            onPressed: () async {
              await notificationService.createNotification(
                userId: user.uid,
                title: 'Cập nhật hệ thống',
                message: 'Phiên bản mới 2.4.1 đã sẵn sàng với nhiều cải tiến về hiệu năng SRS.',
                type: 'system',
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã tạo thông báo hệ thống')),
                );
              }
            },
          ),
          const SizedBox(height: 16),

          // Community notification
          _buildTestButton(
            context,
            title: 'Thông báo cộng đồng',
            subtitle: 'Tạo thông báo từ cộng đồng',
            icon: Icons.people,
            color: const Color(0xFF3E8F8B),
            onPressed: () async {
              await notificationService.createNotification(
                userId: user.uid,
                title: 'Thư viện mới',
                message: 'Chúng tôi vừa thêm bộ thẻ "Business Communication" vào thư viện.',
                type: 'community',
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã tạo thông báo cộng đồng')),
                );
              }
            },
          ),
          const SizedBox(height: 32),

          // Create multiple notifications
          ElevatedButton.icon(
            onPressed: () async {
              await notificationService.createStudyReminder(user.uid, 10);
              await Future.delayed(const Duration(milliseconds: 100));
              await notificationService.createAchievementNotification(user.uid, 5);
              await Future.delayed(const Duration(milliseconds: 100));
              await notificationService.createNotification(
                userId: user.uid,
                title: 'Cập nhật hệ thống',
                message: 'Nhiều tính năng mới đã được thêm vào.',
                type: 'system',
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã tạo 3 thông báo')),
                );
              }
            },
            icon: const Icon(Icons.add_alert),
            label: const Text('Tạo nhiều thông báo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3E8F8B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),

          // Get unread count
          ElevatedButton.icon(
            onPressed: () async {
              int count = await notificationService.getUnreadCount();
              if (context.mounted) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Số thông báo chưa đọc'),
                    content: Text('Bạn có $count thông báo chưa đọc'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            },
            icon: const Icon(Icons.notifications_active),
            label: const Text('Kiểm tra số thông báo chưa đọc'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
          ),
          child: const Text('Tạo'),
        ),
      ),
    );
  }
}
