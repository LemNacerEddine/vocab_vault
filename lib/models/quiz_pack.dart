import 'dart:convert';

import 'quiz_question.dart';

/// حزمة اختبار محلية لكلمة واحدة — تُبنى بالكامل بدون أي ذكاء اصطناعي عبر
/// [LocalQuestionGeneratorService]، وتُحفظ كنص JSON في عمود `quizContent`
/// بجدول `words`، فتعمل الاختبارات بعدها بدون إنترنت.
///
/// [questions] هو المصدر الرئيسي الحالي (أسئلة جاهزة العرض).
/// الحقول الأخرى (distractorTranslations...) قديمة، أُبقيت فقط للتوافق مع
/// أي بيانات محفوظة من نسخة سابقة، ولم تعد تُستخدم في التوليد الحالي.
class QuizPack {
  // الحقول التالية قديمة (لم تعد تُستخدم في التوليد الحالي) — أُبقيت فقط
  // كي لا ينكسر تحليل JSON محفوظ من نسخة سابقة من التطبيق.
  final List<String> distractorTranslations;
  final List<String> distractorDefinitions;
  final List<String> distractorWords;
  final String? clozeSentence;
  final String? clozeTranslationAr;
  final String? hintAr;

  /// الأسئلة المحلية الجاهزة — المصدر الرئيسي لمحتوى الاختبار.
  final List<QuizQuestion> questions;

  const QuizPack({
    this.distractorTranslations = const [],
    this.distractorDefinitions = const [],
    this.distractorWords = const [],
    this.clozeSentence,
    this.clozeTranslationAr,
    this.hintAr,
    this.questions = const [],
  });

  /// تحويل قائمة ديناميكية من JSON إلى قائمة نصوص منظّفة.
  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static String? _nonEmpty(dynamic value) {
    final s = value?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  factory QuizPack.fromJson(Map<String, dynamic> json) {
    final questionsList = <QuizQuestion>[];
    final rawQuestions = json['questions'];
    if (rawQuestions is List) {
      for (final q in rawQuestions) {
        if (q is Map<String, dynamic>) {
          questionsList.add(QuizQuestion.fromJson(q));
        } else if (q is Map) {
          questionsList.add(QuizQuestion.fromJson(Map<String, dynamic>.from(q)));
        }
      }
    }
    return QuizPack(
      distractorTranslations: _stringList(json['distractorTranslations']),
      distractorDefinitions: _stringList(json['distractorDefinitions']),
      distractorWords: _stringList(json['distractorWords']),
      clozeSentence: _nonEmpty(json['clozeSentence']),
      clozeTranslationAr: _nonEmpty(json['clozeTranslationAr']),
      hintAr: _nonEmpty(json['hintAr']),
      questions: questionsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'distractorTranslations': distractorTranslations,
      'distractorDefinitions': distractorDefinitions,
      'distractorWords': distractorWords,
      'clozeSentence': clozeSentence,
      'clozeTranslationAr': clozeTranslationAr,
      'hintAr': hintAr,
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }

  String encode() => json.encode(toJson());

  /// فكّ نص JSON إلى حزمة. يرجع `null` عند الفشل أو النص الفارغ.
  static QuizPack? tryDecode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        return QuizPack.fromJson(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
