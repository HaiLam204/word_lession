class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String type; // 'study', 'achievement', 'system', 'community'
  final int timestamp;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });

  factory NotificationItem.fromMap(String id, Map<dynamic, dynamic> data) {
    return NotificationItem(
      id: id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? 'system',
      timestamp: data['timestamp'] ?? 0,
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'type': type,
      'timestamp': timestamp,
      'isRead': isRead,
    };
  }
}
