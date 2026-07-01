import 'dart:convert';

/// حزمة اختبار مُولّدة بالذكاء الاصطناعي (Claude) لكلمة واحدة.
///
/// تُنتَج مرة واحدة عند إضافة الكلمة (أو عند الطلب لاحقاً) وتُحفظ كنص JSON
/// في عمود `quizContent` بجدول `words`، فتعمل الاختبارات بعدها بدون إنترنت.
///
/// كل الحقول اختيارية: لو غابت حزمة كاملة أو بعض حقولها، يستخدم `QuizEngine`
/// بدائل محلية من كلمات المستخدم الأخرى فلا ينكسر شيء.
class QuizPack {
  /// ترجمات عربية قريبة لكن خاطئة (لسؤال اختيار المعنى EN→AR).
  final List<String> distractorTranslations;

  /// تعريفات إنجليزية مضلِّلة (لسؤال مطابقة التعريف).
  final List<String> distractorDefinitions;

  /// كلمات إنجليزية مشابهة شكلاً/معنى (لسؤال الاختيار العكسي AR→EN).
  final List<String> distractorWords;

  /// جملة إنجليزية طبيعية تحتوي الكلمة (لسؤال ملء الفراغ).
  final String? clozeSentence;

  /// ترجمة عربية لجملة ملء الفراغ (سياق مساعد).
  final String? clozeTranslationAr;

  /// تلميح عربي لا يكشف الترجمة مباشرة.
  final String? hintAr;

  const QuizPack({
    this.distractorTranslations = const [],
    this.distractorDefinitions = const [],
    this.distractorWords = const [],
    this.clozeSentence,
    this.clozeTranslationAr,
    this.hintAr,
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
    return QuizPack(
      distractorTranslations: _stringList(json['distractorTranslations']),
      distractorDefinitions: _stringList(json['distractorDefinitions']),
      distractorWords: _stringList(json['distractorWords']),
      clozeSentence: _nonEmpty(json['clozeSentence']),
      clozeTranslationAr: _nonEmpty(json['clozeTranslationAr']),
      hintAr: _nonEmpty(json['hintAr']),
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
