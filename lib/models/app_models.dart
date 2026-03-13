class AppUser {
  final String id;
  final String displayName;
  final String email;
  final int streak;
  final int dailyGoal;
  final int xp;
  final int totalDecks;

  AppUser({
    required this.id,
    required this.displayName,
    required this.email,
    this.streak = 0,
    this.dailyGoal = 20,
    this.xp = 0,
    this.totalDecks = 0,
  });

  factory AppUser.fromMap(Map<dynamic, dynamic> data) {
    return AppUser(
      id: data['id'] ?? '',
      displayName: data['displayName'] ?? 'User',
      email: data['email'] ?? '',
      streak: data['streak'] ?? 0,
      dailyGoal: data['dailyGoal'] ?? 20,
      xp: data['xp'] ?? 0,
      totalDecks: data['totalDecks'] ?? 0,
    );
  }
}

class Deck {
  final String id;
  final String name;
  final int cardCount;
  final bool isPublic;
  final String? copiedFrom;
  final String? description;
  final List<String>? tags;
  final double rating;
  final int ratingCount;
  final int likes;
  final int saves;

  Deck({
    required this.id,
    required this.name,
    required this.cardCount,
    this.isPublic = false,
    this.copiedFrom,
    this.description,
    this.tags,
    this.rating = 0.0,
    this.ratingCount = 0,
    this.likes = 0,
    this.saves = 0,
  });

  factory Deck.fromMap(String id, Map<dynamic, dynamic> data) {
    List<String> tagsList = [];
    if (data['tags'] != null) {
      if (data['tags'] is List) {
        tagsList = List<String>.from(data['tags']);
      }
    }
    
    return Deck(
      id: id,
      name: data['name'] ?? 'Untitled Deck',
      cardCount: data['cardCount'] ?? 0,
      isPublic: data['isPublic'] ?? false,
      copiedFrom: data['copiedFrom'],
      description: data['description'],
      tags: tagsList.isEmpty ? null : tagsList,
      rating: (data['rating'] ?? 0.0).toDouble(),
      ratingCount: data['ratingCount'] ?? 0,
      likes: data['likes'] ?? 0,
      saves: data['saves'] ?? 0,
    );
  }
}

class Flashcard {
  final String id;
  final String deckId; // THÊM DÒNG NÀY
  final String front;
  final String back;
  final String example;
  final int dueDate;
  final int interval;
  final double easeFactor;
  final String status;

  Flashcard({
    required this.id,
    required this.deckId, 
    required this.front,
    required this.back,
    this.example = '',
    required this.dueDate,
    this.interval = 0,
    this.easeFactor = 2.5,
    this.status = 'new',
  });

  factory Flashcard.fromMap(String id, Map<dynamic, dynamic> data) {
    return Flashcard(
      id: id,
      deckId: data['deckId'] ?? '',
      front: data['front'] ?? '',
      back: data['back'] ?? '',
      example: data['example'] ?? '',
      dueDate: data['dueDate'] ?? 0,
      interval: (data['interval'] ?? 0).toInt(),
      easeFactor: (data['easeFactor'] ?? 2.5).toDouble(),
      status: data['status'] ?? 'new',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deckId': deckId, 
      'dueDate': dueDate,
      'interval': interval,
      'easeFactor': easeFactor,
      'status': status,
    };
  }
}