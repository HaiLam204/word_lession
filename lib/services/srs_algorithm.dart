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

  // Multipliers based on SRS intensity
  static double _getIntensityMultiplier(String intensity, String rating) {
    if (intensity == 'Dễ') {
      // Longer intervals, easier to master
      if (rating == 'hard') return 1.5;
      if (rating == 'easy') return 1.5;
      return 1.3;
    } else if (intensity == 'Khó') {
      // Shorter intervals, more reviews
      if (rating == 'hard') return 0.9;
      if (rating == 'easy') return 0.9;
      return 1.0;
    }
    // Cân bằng - default
    return 1.0;
  }

  static SrsResult calculate(Flashcard card, String rating, {String intensity = 'Cân bằng'}) {
    int now = DateTime.now().millisecondsSinceEpoch;
    
    int nextInterval = 0;
    int nextDueDate = now;
    double nextEaseFactor = card.easeFactor;
    double intensityMultiplier = _getIntensityMultiplier(intensity, rating);
    
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
        nextInterval = (card.interval * 1.2 * intensityMultiplier).round();
        nextDueDate = now + (nextInterval * oneDayMillis);
      }
      nextEaseFactor = (card.easeFactor - 0.15).clamp(1.3, 2.5);
    } 
    else if (rating == 'easy') {
      if (card.interval == 0) {
        nextInterval = (4 * intensityMultiplier).round();
        nextDueDate = now + (nextInterval * oneDayMillis);
      } else {
        nextInterval = (card.interval * card.easeFactor * 1.3 * intensityMultiplier).round();
        nextDueDate = now + (nextInterval * oneDayMillis);
      }
      nextEaseFactor = (card.easeFactor + 0.15).clamp(1.3, 2.5);
    }

    return SrsResult(nextInterval, nextEaseFactor, nextDueDate);
  }
}
