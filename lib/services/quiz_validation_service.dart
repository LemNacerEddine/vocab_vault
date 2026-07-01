import '../models/question_type.dart';
import '../models/quiz_question.dart';
import 'distractor_service.dart';

/// نظام تقييم جودة السؤال — يُستدعى قبل إضافة أي سؤال للجلسة، لتجنّب
/// الأسئلة الضعيفة أو غير العادلة (تكرار خيارات، خيار فارغ، سؤال صورة
/// بلا صورة...).
class QuizValidationService {
  static bool isValidQuestion(QuizQuestion q) {
    if (q.prompt.trim().isEmpty) return false;
    if (q.correctAnswer.trim().isEmpty) return false;
    if (q.difficulty < 1 || q.difficulty > 5) return false;

    if (q.options.isNotEmpty) {
      if (q.options.length != 4) return false;
      if (q.options.any((o) => o.trim().isEmpty)) return false;

      final normalized = q.options.map((o) => o.trim().toLowerCase()).toList();
      if (normalized.toSet().length != normalized.length) return false; // لا تكرار

      final correctNorm = q.correctAnswer.trim().toLowerCase();
      final correctCount = normalized.where((o) => o == correctNorm).length;
      if (correctCount != 1) return false; // الجواب الصحيح مرة واحدة فقط

      // لا تُستعمل تصريفات نفس الكلمة كخيارات خاطئة إلا في أسئلة wordFamily
      // (حيث تصريفات العائلة هي بالضبط موضوع السؤال).
      if (q.type != QuestionType.wordFamily) {
        for (final o in q.options) {
          final oNorm = o.trim().toLowerCase();
          if (oNorm == correctNorm) continue;
          if (DistractorService.isSameWordFamily(q.correctAnswer, o, null)) {
            return false;
          }
        }
      }
    }

    switch (q.type) {
      case QuestionType.imageToWord:
        final hasImage = (q.imageUrl != null && q.imageUrl!.trim().isNotEmpty) ||
            (q.localImagePath != null && q.localImagePath!.trim().isNotEmpty);
        if (!hasImage) return false;
        break;
      case QuestionType.audioToWord:
        if (q.audioUrl == null || q.audioUrl!.trim().isEmpty) return false;
        break;
      case QuestionType.clozeSentence:
        if (!q.prompt.contains('___')) return false;
        break;
      default:
        break;
    }

    return true;
  }
}
