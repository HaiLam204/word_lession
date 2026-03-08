import '../models/app_models.dart';

class SrsResult {
  final int nextInterval;  
  final double nextEaseFactor; 
  final int nextDueDate;   

  SrsResult(this.nextInterval, this.nextEaseFactor, this.nextDueDate);
}

class SrsAlgorithm {
  static const int tenMinutesMillis = 10 * 60 * 1000;  
  static const int oneDayMillis = 24 * 60 * 60 * 1000; 

  static SrsResult calculate(Flashcard card, String rating) {
    int now = DateTime.now().millisecondsSinceEpoch;
    
    int nextInterval = 0;
    int nextDueDate = now;
    double nextEaseFactor = card.easeFactor;
    
    if (rating == 'again') {
      nextInterval = 0; 
      nextDueDate = now + tenMinutesMillis;
      nextEaseFactor = (card.easeFactor - 0.2).clamp(1.3, 2.5);
    } 
    else if (rating == 'hard') {
      if (card.interval == 0) {
        nextInterval = 1;
        nextDueDate = now + oneDayMillis;
      } else {
        nextInterval = (card.interval * 1.2).round();
        nextDueDate = now + (nextInterval * oneDayMillis);
      }
      nextEaseFactor = (card.easeFactor - 0.15).clamp(1.3, 2.5);
    } 
    else if (rating == 'easy') {
      if (card.interval == 0) {
        nextInterval = 4;
        nextDueDate = now + (4 * oneDayMillis);
      } else {
        nextInterval = (card.interval * card.easeFactor * 1.3).round();
        nextDueDate = now + (nextInterval * oneDayMillis);
      }
      nextEaseFactor = (card.easeFactor + 0.15).clamp(1.3, 2.5);
    }

    return SrsResult(nextInterval, nextEaseFactor, nextDueDate);
  }
}