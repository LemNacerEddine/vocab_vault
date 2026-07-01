import 'question_type.dart';

/// سؤال اختبار جاهز للعرض. تبنيه [LocalQuestionGeneratorService] محلياً
/// بالكامل دون أي استدعاء لذكاء اصطناعي.
///
/// القواعد:
/// - options تحتوي دائماً 4 اختيارات في أسئلة الاختيار من متعدد، أو تكون
///   فارغة في أسئلة الكتابة الحرة (غير مُستخدمة حالياً لكن الحقل يدعمها).
/// - لا يوجد تكرار في الاختيارات، والجواب الصحيح موجود مرة واحدة فقط.
/// - difficulty من 1 إلى 5.
class QuizQuestion {
  final String id;
  final QuestionType type;

  /// معرّف الكلمة المستهدفة (Word.id كنص) — يُستخدم للربط بجدول التقدّم.
  final String wordId;

  /// نص السؤال (قد يكون بالعربية أو الإنجليزية حسب النوع).
  final String prompt;

  final String correctAnswer;

  /// 4 اختيارات (تشمل الإجابة الصحيحة) مخلوطة عشوائياً، أو فارغة لأسئلة الكتابة.
  final List<String> options;

  /// رابط صورة توضيحية شبكي (لنوع imageToWord).
  final String? imageUrl;

  /// مسار صورة محلية مخزَّنة على الجهاز (بديل offline لـ imageUrl مستقبلاً).
  final String? localImagePath;

  /// رابط ملف الصوت (لنوع audioToWord).
  final String? audioUrl;

  /// شرح قصير يُعرض بعد الإجابة (تعريف/ترجمة/سبب).
  final String? explanation;

  /// تلميح يُعرض مع السؤال (اختياري، دون كشف الإجابة).
  final String? hint;

  /// مستوى الصعوبة من 1 إلى 5.
  final int difficulty;

  const QuizQuestion({
    required this.id,
    required this.type,
    required this.wordId,
    required this.prompt,
    required this.correctAnswer,
    this.options = const [],
    this.imageUrl,
    this.localImagePath,
    this.audioUrl,
    this.explanation,
    this.hint,
    this.difficulty = 1,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'wordId': wordId,
      'prompt': prompt,
      'correctAnswer': correctAnswer,
      'options': options,
      'imageUrl': imageUrl,
      'localImagePath': localImagePath,
      'audioUrl': audioUrl,
      'explanation': explanation,
      'hint': hint,
      'difficulty': difficulty,
    };
  }

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    QuestionType parseType(dynamic raw) {
      for (final t in QuestionType.values) {
        if (t.name == raw) return t;
      }
      return QuestionType.wordToArabic;
    }

    return QuizQuestion(
      id: json['id'] as String? ?? '',
      type: parseType(json['type']),
      wordId: json['wordId']?.toString() ?? '',
      prompt: json['prompt'] as String? ?? '',
      correctAnswer: json['correctAnswer'] as String? ?? '',
      options: (json['options'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      imageUrl: json['imageUrl'] as String?,
      localImagePath: json['localImagePath'] as String?,
      audioUrl: json['audioUrl'] as String?,
      explanation: json['explanation'] as String?,
      hint: json['hint'] as String?,
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 1,
    );
  }
}
