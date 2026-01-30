import '../models/app_models.dart';

class SrsResult {
  final int nextInterval;   
  final double nextEaseFactor; 
  final int nextDueDate;    

  SrsResult(this.nextInterval, this.nextEaseFactor, this.nextDueDate);
}

class SrsAlgorithm {
  static const double minEaseFactor = 1.3; 
  static const int oneDayMillis = 24 * 60 * 60 * 1000;

  static SrsResult calculate(Flashcard card, String rating) {
    int currentInterval = card.interval;
    double currentEf = card.easeFactor;
    int now = DateTime.now().millisecondsSinceEpoch;

    int nextInterval = 0;
    double nextEf = currentEf;

    if (rating == 'again') {
      nextInterval = 0; 
      nextEf = (currentEf - 0.2).clamp(minEaseFactor, 5.0); 
    } 
    else if (rating == 'hard') {
      if (currentInterval == 0) {
        nextInterval = 1; 
      } else {
        nextInterval = (currentInterval * 1.2).toInt();
      }
      nextEf = (currentEf - 0.15).clamp(minEaseFactor, 5.0);
    } 
    else if (rating == 'easy') {
      if (currentInterval == 0) {
        nextInterval = 1; 
      } else if (currentInterval == 1) {
        nextInterval = 6; 
      } else {
        nextInterval = (currentInterval * currentEf).round();
      }
      nextEf = currentEf + 0.15; 
    }

    int nextDueDate;
    if (nextInterval == 0) {
      nextDueDate = now + (10 * 60 * 1000);
    } else {
      nextDueDate = now + (nextInterval * oneDayMillis);
    }

    return SrsResult(nextInterval, nextEf, nextDueDate);
  }
}