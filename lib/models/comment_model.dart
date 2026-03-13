class DeckComment {
  final String id;
  final String deckId;
  final String userId;
  final String userName;
  final String content;
  final int timestamp;
  final int likes;
  final double? rating; // Optional rating with comment

  DeckComment({
    required this.id,
    required this.deckId,
    required this.userId,
    required this.userName,
    required this.content,
    required this.timestamp,
    this.likes = 0,
    this.rating,
  });

  factory DeckComment.fromMap(String id, Map<dynamic, dynamic> data) {
    return DeckComment(
      id: id,
      deckId: data['deckId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      content: data['content'] ?? '',
      timestamp: data['timestamp'] ?? 0,
      likes: data['likes'] ?? 0,
      rating: data['rating'] != null ? (data['rating'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deckId': deckId,
      'userId': userId,
      'userName': userName,
      'content': content,
      'timestamp': timestamp,
      'likes': likes,
      if (rating != null) 'rating': rating,
    };
  }
}
