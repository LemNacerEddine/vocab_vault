import 'dart:convert';

import 'question_type.dart';

/// حالة تعلّم كلمة واحدة وفق نظام "مستوى الإتقان" (masteryLevel 0-5)
/// بدلاً من خوارزمية SM-2 التقليدية — أبسط، وأكثر قابلية للتفسير للمستخدم،
/// ويتتبّع أيضاً نوع الأسئلة التي يخطئ/يصيب فيها المستخدم لكل كلمة
/// (wrongByType / correctByType) لدعم المراجعة الذكية حسب نقاط الضعف.
class WordProgress {
  final String wordId;
  final int correctCount;
  final int wrongCount;
  final DateTime? lastReviewedAt;
  final DateTime? nextReviewAt;
  final int masteryLevel; // 0 إلى 5
  final Map<QuestionType, int> wrongByType;
  final Map<QuestionType, int> correctByType;

  const WordProgress({
    required this.wordId,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.lastReviewedAt,
    this.nextReviewAt,
    this.masteryLevel = 0,
    this.wrongByType = const {},
    this.correctByType = const {},
  });

  /// حالة ابتدائية لكلمة لم تُراجَع بعد (مستحقّة فوراً).
  factory WordProgress.initial(String wordId) => WordProgress(wordId: wordId);

  /// نسبة الإتقان الكلية (0.0 - 1.0).
  double get accuracy {
    final total = correctCount + wrongCount;
    return total == 0 ? 0.0 : correctCount / total;
  }

  /// هل الكلمة مستحقّة للمراجعة الآن؟ (لا سجل سابق = مستحقّة فوراً).
  bool get isDue {
    if (nextReviewAt == null) return true;
    return !nextReviewAt!.isAfter(DateTime.now());
  }

  /// أكثر نوع سؤال يخطئ فيه المستخدم بهذه الكلمة تحديداً، أو null إن لا بيانات.
  QuestionType? get weakestType {
    if (wrongByType.isEmpty) return null;
    QuestionType? best;
    var bestCount = 0;
    wrongByType.forEach((type, count) {
      if (count > bestCount) {
        best = type;
        bestCount = count;
      }
    });
    return bestCount > 0 ? best : null;
  }

  static Map<QuestionType, int> _decodeTypeMap(String? raw) {
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final result = <QuestionType, int>{};
      decoded.forEach((key, value) {
        for (final t in QuestionType.values) {
          if (t.name == key) {
            result[t] = (value as num).toInt();
            break;
          }
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  static String _encodeTypeMap(Map<QuestionType, int> map) {
    final asStringMap = map.map((key, value) => MapEntry(key.name, value));
    return json.encode(asStringMap);
  }

  /// wordId يُحوَّل رقماً عند الحفظ (يطابق عمود words.id عدداً صحيحاً).
  Map<String, dynamic> toMap() {
    return {
      'wordId': int.tryParse(wordId) ?? wordId,
      'correctCount': correctCount,
      'wrongCount': wrongCount,
      'lastReviewedAt': lastReviewedAt?.toIso8601String(),
      'nextReviewAt': nextReviewAt?.toIso8601String(),
      'masteryLevel': masteryLevel,
      'wrongByType': _encodeTypeMap(wrongByType),
      'correctByType': _encodeTypeMap(correctByType),
    };
  }

  factory WordProgress.fromMap(Map<String, dynamic> map) {
    DateTime? parse(dynamic v) =>
        (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;
    return WordProgress(
      wordId: map['wordId'].toString(),
      correctCount: (map['correctCount'] as int?) ?? 0,
      wrongCount: (map['wrongCount'] as int?) ?? 0,
      lastReviewedAt: parse(map['lastReviewedAt']),
      nextReviewAt: parse(map['nextReviewAt']),
      masteryLevel: (map['masteryLevel'] as int?) ?? 0,
      wrongByType: _decodeTypeMap(map['wrongByType'] as String?),
      correctByType: _decodeTypeMap(map['correctByType'] as String?),
    );
  }

  WordProgress copyWith({
    int? correctCount,
    int? wrongCount,
    DateTime? lastReviewedAt,
    DateTime? nextReviewAt,
    int? masteryLevel,
    Map<QuestionType, int>? wrongByType,
    Map<QuestionType, int>? correctByType,
  }) {
    return WordProgress(
      wordId: wordId,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      masteryLevel: masteryLevel ?? this.masteryLevel,
      wrongByType: wrongByType ?? this.wrongByType,
      correctByType: correctByType ?? this.correctByType,
    );
  }
}
