/// حالة التعلّم لكلمة واحدة وفق خوارزمية التكرار المتباعد (SM-2).
///
/// تُخزَّن في جدول `word_progress` منفصلاً عن بيانات الكلمة نفسها.
class WordProgress {
  final int wordId;
  final int interval; // عدد الأيام حتى المراجعة القادمة
  final int repetition; // عدد الإجابات الصحيحة المتتالية
  final double easeFactor; // معامل السهولة (يبدأ 2.5)
  final DateTime? nextReviewDate;
  final DateTime? lastReviewDate;
  final int totalAttempts;
  final int correctAttempts;

  const WordProgress({
    required this.wordId,
    this.interval = 0,
    this.repetition = 0,
    this.easeFactor = 2.5,
    this.nextReviewDate,
    this.lastReviewDate,
    this.totalAttempts = 0,
    this.correctAttempts = 0,
  });

  /// حالة ابتدائية لكلمة لم تُراجَع بعد (مستحقّة فوراً).
  factory WordProgress.initial(int wordId) => WordProgress(wordId: wordId);

  /// نسبة الإتقان (0.0 - 1.0). تُستخدم لوضع "الكلمات الصعبة".
  double get accuracy =>
      totalAttempts == 0 ? 0.0 : correctAttempts / totalAttempts;

  /// هل الكلمة مستحقّة للمراجعة الآن؟ (لا سجل سابق = مستحقّة).
  bool get isDue {
    if (nextReviewDate == null) return true;
    return !nextReviewDate!.isAfter(DateTime.now());
  }

  Map<String, dynamic> toMap() {
    return {
      'wordId': wordId,
      'interval': interval,
      'repetition': repetition,
      'easeFactor': easeFactor,
      'nextReviewDate': nextReviewDate?.toIso8601String(),
      'lastReviewDate': lastReviewDate?.toIso8601String(),
      'totalAttempts': totalAttempts,
      'correctAttempts': correctAttempts,
    };
  }

  factory WordProgress.fromMap(Map<String, dynamic> map) {
    DateTime? parse(dynamic v) =>
        (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;
    return WordProgress(
      wordId: map['wordId'] as int,
      interval: (map['interval'] as int?) ?? 0,
      repetition: (map['repetition'] as int?) ?? 0,
      easeFactor: (map['easeFactor'] as num?)?.toDouble() ?? 2.5,
      nextReviewDate: parse(map['nextReviewDate']),
      lastReviewDate: parse(map['lastReviewDate']),
      totalAttempts: (map['totalAttempts'] as int?) ?? 0,
      correctAttempts: (map['correctAttempts'] as int?) ?? 0,
    );
  }

  WordProgress copyWith({
    int? interval,
    int? repetition,
    double? easeFactor,
    DateTime? nextReviewDate,
    DateTime? lastReviewDate,
    int? totalAttempts,
    int? correctAttempts,
  }) {
    return WordProgress(
      wordId: wordId,
      interval: interval ?? this.interval,
      repetition: repetition ?? this.repetition,
      easeFactor: easeFactor ?? this.easeFactor,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      lastReviewDate: lastReviewDate ?? this.lastReviewDate,
      totalAttempts: totalAttempts ?? this.totalAttempts,
      correctAttempts: correctAttempts ?? this.correctAttempts,
    );
  }
}
