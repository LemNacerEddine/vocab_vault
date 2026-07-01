import 'dart:math';

import '../models/question_type.dart';
import '../models/quiz_question.dart';
import '../models/word.dart';
import '../models/word_progress.dart';
import 'dictionary_service.dart';
import 'local_question_generator_service.dart';
import 'quiz_validation_service.dart';

/// يبني جلسة مراجعة ذكية من قائمة كلمات + سجلات تقدّمها.
///
/// قواعد الاختيار:
/// - أولوية للكلمات المستحقّة الآن (nextReviewAt <= now)، ثم الأكثر خطأً.
/// - لكل كلمة، يُفضَّل نوع السؤال الذي يخطئ فيه المستخدم بها تحديداً.
/// - لا يتكرر نفس نوع السؤال لنفس الكلمة أكثر من مرة في نفس الجلسة.
/// - أسئلة الترجمة (wordToArabic + arabicToWord) لا تتجاوز 30% من الجلسة،
///   حتى لا يتحول الاختبار إلى "كلمة → ترجمة" فقط.
///
/// ملاحظة: لكلمة جديدة تماماً (بلا سجل تقدّم)، لا يوجد "نوع ضعيف" محدَّد،
/// فيقع الاختيار عشوائياً بين الأنواع المتاحة — وهذا يحقق تلقائياً توزيعاً
/// متنوعاً (صورة/صوت/تعريف/ترجمة/مرادف...) دون الحاجة لمنطق نسب منفصل.
class ReviewSessionBuilder {
  static final Random _rng = Random();

  static bool _isTranslationType(QuestionType t) =>
      t == QuestionType.wordToArabic || t == QuestionType.arabicToWord;

  static List<QuizQuestion> buildSession({
    required List<Word> words,
    required Map<String, WordProgress> progress,
    Map<String, DictionaryResult> dictionaries = const {},
    int maxQuestions = 20,
  }) {
    if (words.isEmpty) return const [];

    // 1) رتّب الكلمات: المستحقّة أولاً، ثم الأكثر خطأً، ثم الأقدم موعد مراجعة.
    final sortedWords = [...words];
    sortedWords.sort((a, b) {
      final pa = progress[a.id.toString()];
      final pb = progress[b.id.toString()];
      final dueA = pa?.isDue ?? true;
      final dueB = pb?.isDue ?? true;
      if (dueA != dueB) return dueA ? -1 : 1;

      final wrongA = pa?.wrongCount ?? 0;
      final wrongB = pb?.wrongCount ?? 0;
      if (wrongA != wrongB) return wrongB.compareTo(wrongA);

      final nextA = pa?.nextReviewAt;
      final nextB = pb?.nextReviewAt;
      if (nextA == null && nextB == null) return 0;
      if (nextA == null) return -1;
      if (nextB == null) return 1;
      return nextA.compareTo(nextB);
    });

    final selected = <QuizQuestion>[];
    final usedTypesPerWord = <String, Set<QuestionType>>{};
    final translationCap = (maxQuestions * 0.3).ceil();
    var translationCount = 0;

    var pass = 0;
    while (selected.length < maxQuestions && pass < 3) {
      var addedThisPass = false;

      for (final word in sortedWords) {
        if (selected.length >= maxQuestions) break;

        final wordId = word.id.toString();
        final wp = progress[wordId];
        final candidates = _candidatesFor(word, words, dictionaries[wordId]);
        if (candidates.isEmpty) continue;

        final used = usedTypesPerWord.putIfAbsent(wordId, () => <QuestionType>{});
        var remaining = candidates.where((q) => !used.contains(q.type)).toList();
        if (remaining.isEmpty) continue;

        // احترام سقف أسئلة الترجمة: استبعدها من الاحتمالات إن بلغنا السقف
        // (إلا إن لم يبقَ نوع آخر متاح لهذه الكلمة).
        if (translationCount >= translationCap) {
          final nonTranslation = remaining.where((q) => !_isTranslationType(q.type)).toList();
          if (nonTranslation.isNotEmpty) remaining = nonTranslation;
        }

        QuizQuestion? pick;
        // في الجولة الأولى، فضّل نوع السؤال الذي يخطئ فيه المستخدم بهذه الكلمة.
        final weakest = wp?.weakestType;
        if (pass == 0 && weakest != null) {
          final weakMatches = remaining.where((q) => q.type == weakest).toList();
          if (weakMatches.isNotEmpty) pick = weakMatches.first;
        }
        if (pick == null) {
          remaining.shuffle(_rng);
          pick = remaining.first;
        }

        selected.add(pick);
        used.add(pick.type);
        if (_isTranslationType(pick.type)) translationCount++;
        addedThisPass = true;
      }

      if (!addedThisPass) break; // لا مزيد من الأسئلة الممكنة لأي كلمة
      pass++;
    }

    return selected;
  }

  /// أسئلة مرشّحة صالحة لكلمة معيّنة: من الحزمة المحفوظة إن وُجدت،
  /// وإلا تُولَّد فوراً محلياً (لا يزال بدون إنترنت أو ذكاء اصطناعي).
  static List<QuizQuestion> _candidatesFor(
    Word word,
    List<Word> allWords,
    DictionaryResult? dictionary,
  ) {
    final stored = word.quizPack?.questions ?? const [];
    final validStored = stored.where(QuizValidationService.isValidQuestion).toList();
    if (validStored.isNotEmpty) return validStored;

    final generated = LocalQuestionGeneratorService.generateQuestionsForWord(
      word: word,
      dictionary: dictionary,
      allWords: allWords,
      cachedDictionaries: const [],
    );
    return generated.where(QuizValidationService.isValidQuestion).toList();
  }
}
