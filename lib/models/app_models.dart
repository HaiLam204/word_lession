class AppUser {
  final String id;
  final String displayName;
  final String email;
  final int streak;
  final int dailyGoal;

  AppUser({
    required this.id,
    required this.displayName,
    required this.email,
    this.streak = 0,
    this.dailyGoal = 20,
  });

  factory AppUser.fromMap(Map<dynamic, dynamic> data) {
    return AppUser(
      id: data['id'] ?? '',
      displayName: data['displayName'] ?? 'User',
      email: data['email'] ?? '',
      streak: data['streak'] ?? 0,
      dailyGoal: data['dailyGoal'] ?? 20,
    );
  }
}

class Deck {
  final String id;
  final String name;
  final int cardCount;

  Deck({required this.id, required this.name, required this.cardCount});

  factory Deck.fromMap(String id, Map<dynamic, dynamic> data) {
    return Deck(
      id: id,
      name: data['name'] ?? 'Untitled Deck',
      cardCount: data['cardCount'] ?? 0,
    );
  }
}

class Flashcard {
  final String id;
  final String front;
  final String back;
  final String example;
  final int dueDate;
  final int interval;
  final double easeFactor;
  final String status;

  Flashcard({
    required this.id,
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
      'dueDate': dueDate,
      'interval': interval,
      'easeFactor': easeFactor,
      'status': status,
    };
  }
}