import '../models/question_type.dart';
import '../models/word_progress.dart';

/// خدمة جدولة المراجعة اعتماداً على "مستوى الإتقان" (masteryLevel 0-5)
/// — أبسط من SM-2 وأكثر قابلية للتفسير للمستخدم، وتتتبّع أيضاً نوع
/// السؤال الذي أُجيب عليه لتغذية المراجعة الذكية حسب نقاط الضعف.
///
/// جدولة المراجعة:
///   mastery 0 → بعد 10 دقائق
///   mastery 1 → بعد يوم
///   mastery 2 → بعد 3 أيام
///   mastery 3 → بعد 7 أيام
///   mastery 4 → بعد 14 يوماً
///   mastery 5 → بعد 30 يوماً
class MasteryService {
  static const int maxMastery = 5;

  static const Map<int, Duration> _scheduleByMastery = {
    0: Duration(minutes: 10),
    1: Duration(days: 1),
    2: Duration(days: 3),
    3: Duration(days: 7),
    4: Duration(days: 14),
    5: Duration(days: 30),
  };

  /// يطبّق نتيجة إجابة على سجل تقدّم ويرجع السجل المُحدَّث (جاهز للحفظ).
  static WordProgress applyAnswer(
    WordProgress current, {
    required QuestionType type,
    required bool correct,
  }) {
    var mastery = current.masteryLevel;
    final wrongByType = Map<QuestionType, int>.from(current.wrongByType);
    final correctByType = Map<QuestionType, int>.from(current.correctByType);

    if (correct) {
      // إجابة صحيحة: ارفع مستوى الإتقان تدريجياً وأجّل المراجعة.
      mastery = (mastery + 1).clamp(0, maxMastery);
      correctByType[type] = (correctByType[type] ?? 0) + 1;
    } else {
      // إجابة خاطئة: أنقص مستوى الإتقان (لا تُصفّره بالكامل) وسجّل نوع الخطأ.
      mastery = (mastery - 1).clamp(0, maxMastery);
      wrongByType[type] = (wrongByType[type] ?? 0) + 1;
    }

    final now = DateTime.now();
    // إجابة خاطئة → مراجعة قريبة جداً بغضّ النظر عن المستوى الجديد،
    // لضمان تثبيت الكلمة قبل التباعد مجدداً.
    final nextReview = correct
        ? now.add(_scheduleByMastery[mastery]!)
        : now.add(const Duration(minutes: 10));

    return current.copyWith(
      correctCount: current.correctCount + (correct ? 1 : 0),
      wrongCount: current.wrongCount + (correct ? 0 : 1),
      lastReviewedAt: now,
      nextReviewAt: nextReview,
      masteryLevel: mastery,
      wrongByType: wrongByType,
      correctByType: correctByType,
    );
  }
}
