import 'word.dart';

/// أنواع الأسئلة الستة.
enum QuizType {
  chooseMeaning, // اختيار المعنى العربي الصحيح للكلمة (EN→AR)
  chooseWord, // اختيار الكلمة الإنجليزية الصحيحة للمعنى (AR→EN)
  fillBlank, // ملء الفراغ في جملة
  matchDefinition, // مطابقة التعريف الإنجليزي الصحيح
  chooseImage, // اختيار الصورة المناسبة للكلمة
  listenChoose, // الاستماع للنطق واختيار المعنى
}

/// خيار واحد ضمن سؤال (نصّي أو صورة).
class QuizOption {
  final String? text; // نص الخيار (للأنواع النصية)
  final String? imageUrl; // رابط الصورة (للنوع الصوري)
  final bool isCorrect;

  const QuizOption({this.text, this.imageUrl, required this.isCorrect});
}

/// سؤال اختبار جاهز للعرض. يبنيه [QuizEngine] محلياً بالكامل.
class QuizQuestion {
  final QuizType type;

  /// الكلمة المستهدفة (تُستخدم للتصحيح، الصوت، وتحديث SM-2).
  final Word word;

  /// نص السؤال بالعربية.
  final String promptAr;

  /// تفصيل إضافي يُعرض تحت السؤال (جملة ملء الفراغ، الكلمة الإنجليزية...).
  final String? promptDetail;

  /// رابط الصوت (للنوع listenChoose).
  final String? audioUrl;

  /// الخيارات (مخلوطة عشوائياً مسبقاً).
  final List<QuizOption> options;

  /// هل الخيارات صور بدل نصوص؟
  final bool optionsAreImages;

  const QuizQuestion({
    required this.type,
    required this.word,
    required this.promptAr,
    this.promptDetail,
    this.audioUrl,
    required this.options,
    this.optionsAreImages = false,
  });
}
