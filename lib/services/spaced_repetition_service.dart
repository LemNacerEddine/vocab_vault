import '../models/word_progress.dart';

/// خوارزمية التكرار المتباعد SM-2.
///
/// تحسب الموعد الأمثل للمراجعة القادمة: الكلمات الصعبة تعود قريباً،
/// والسهلة تتباعد تدريجياً. هذا هو "التناوب" الذي يرسّخ الحفظ.
class SpacedRepetitionService {
  static const double minEaseFactor = 1.3;

  /// الحساب الأساسي (دالة نقية قابلة للاختبار).
  ///
  /// [quality] تقييم من 0 إلى 5 (0 = خطأ تام، 5 = إجابة مثالية).
  /// تعيد القيم الجديدة لـ easeFactor / interval / repetition / nextReviewDate.
  static Map<String, dynamic> calculateNext({
    required int quality,
    required double easeFactor,
    required int interval,
    required int repetition,
  }) {
    final q = quality.clamp(0, 5);

    double newEF = easeFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
    if (newEF < minEaseFactor) newEF = minEaseFactor;

    int newInterval;
    int newRepetition;

    if (q < 3) {
      // إجابة خاطئة: إعادة من البداية.
      newRepetition = 0;
      newInterval = 1;
    } else {
      newRepetition = repetition + 1;
      if (newRepetition == 1) {
        newInterval = 1;
      } else if (newRepetition == 2) {
        newInterval = 3;
      } else {
        newInterval = (interval * newEF).round();
      }
    }
    if (newInterval < 1) newInterval = 1;

    final nextReviewDate = DateTime.now().add(Duration(days: newInterval));

    return {
      'easeFactor': newEF,
      'interval': newInterval,
      'repetition': newRepetition,
      'nextReviewDate': nextReviewDate,
    };
  }

  /// تحويل نتيجة إجابة (صح/خطأ + السرعة) إلى تقييم quality من 0-5.
  ///
  /// - خطأ            → 2
  /// - صحيحة بطيئة    → 4
  /// - صحيحة سريعة    → 5
  static int qualityFromAnswer({
    required bool correct,
    Duration? timeTaken,
    Duration fastThreshold = const Duration(seconds: 6),
  }) {
    if (!correct) return 2;
    if (timeTaken != null && timeTaken > fastThreshold) return 4;
    return 5;
  }

  /// تطبيق إجابة على سجل تقدّم وإرجاع السجل المُحدّث (جاهز للحفظ).
  static WordProgress applyAnswer(
    WordProgress current, {
    required bool correct,
    Duration? timeTaken,
  }) {
    final quality = qualityFromAnswer(correct: correct, timeTaken: timeTaken);
    final next = calculateNext(
      quality: quality,
      easeFactor: current.easeFactor,
      interval: current.interval,
      repetition: current.repetition,
    );

    return current.copyWith(
      easeFactor: next['easeFactor'] as double,
      interval: next['interval'] as int,
      repetition: next['repetition'] as int,
      nextReviewDate: next['nextReviewDate'] as DateTime,
      lastReviewDate: DateTime.now(),
      totalAttempts: current.totalAttempts + 1,
      correctAttempts: current.correctAttempts + (correct ? 1 : 0),
    );
  }
}
