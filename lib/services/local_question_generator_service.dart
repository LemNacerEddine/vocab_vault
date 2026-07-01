import 'dart:math';

import '../models/question_type.dart';
import '../models/quiz_question.dart';
import '../models/word.dart';
import '../utils/pos_category.dart';
import 'dictionary_service.dart';
import 'distractor_service.dart';
import 'quiz_validation_service.dart';
import 'word_family_service.dart';

/// يولّد أسئلة اختبار محلية بالكامل — بدون أي استدعاء لذكاء اصطناعي —
/// اعتماداً فقط على البيانات المضمونة الموجودة فعلاً للكلمة: الترجمة،
/// الصورة، الصوت، التعريف، المثال، المرادفات، الأضداد، والجذر/التصريف.
///
/// المبدأ: لا نولّد كل أنواع الأسئلة دائماً — فقط الأنواع التي تتوفر
/// بياناتها الحقيقية لهذه الكلمة تحديداً. أي سؤال لا يجتاز
/// [QuizValidationService.isValidQuestion] يُستبعد قبل إرجاعه.
class LocalQuestionGeneratorService {
  static final Random _rng = Random();
  static int _idCounter = 0;

  /// يولّد قائمة أسئلة متنوعة لكلمة واحدة (سؤال واحد كحد أقصى لكل نوع
  /// متاح). اختيار/توزيع الأنواع عبر جلسة كاملة مهمة [ReviewSessionBuilder].
  static List<QuizQuestion> generateQuestionsForWord({
    required Word word,
    required DictionaryResult? dictionary,
    required List<Word> allWords,
    required List<DictionaryResult> cachedDictionaries,
  }) {
    final builders = <QuizQuestion? Function()>[
      () => _imageToWord(word, dictionary, allWords),
      () => _audioToWord(word, dictionary, allWords),
      () => _wordToArabic(word, allWords),
      () => _arabicToWord(word, allWords),
      () => _definitionToWord(word, dictionary, allWords),
      () => _wordToDefinition(word, dictionary, allWords, cachedDictionaries),
      () => _clozeQuestion(word, allWords),
      () => _synonymQuestion(word, allWords),
      () => _antonymQuestion(word, allWords),
      () => _wordFamilyQuestion(word, allWords),
    ];

    final result = <QuizQuestion>[];
    for (final build in builders) {
      final q = build();
      if (q != null && QuizValidationService.isValidQuestion(q)) {
        result.add(q);
      }
    }
    return result;
  }

  // ==================== 1) صورة → كلمة ====================

  /// هل الكلمة مناسبة لسؤال صورة؟ الأسماء أفضل، الأفعال والصفات ممكنة
  /// إن وُجدت صورة، والكلمات المجرّدة لا تُعطى أولوية.
  static bool isGoodForImageQuestion(Word word, DictionaryResult? dictionary) {
    final hasImage = word.imageUrlsList.isNotEmpty ||
        (word.imageUrl != null && word.imageUrl!.trim().isNotEmpty);
    if (!hasImage) return false;

    final category = PosCategoryUtil.ofWord(word);
    switch (category) {
      case PosCategory.noun:
      case PosCategory.verb:
      case PosCategory.adjective:
        return true;
      case PosCategory.other:
        // كلمات مجرّدة (although, because...) — لا أولوية إلا إن كانت
        // الصورة موجودة فعلاً ووصفها يطابق الكلمة (لا نملك تحقّقاً دلالياً
        // موثوقاً هنا، لذا نتجنّبها للسلامة).
        return false;
    }
  }

  static QuizQuestion? _imageToWord(
    Word word,
    DictionaryResult? dictionary,
    List<Word> allWords,
  ) {
    if (!isGoodForImageQuestion(word, dictionary)) return null;
    final image = word.imageUrlsList.isNotEmpty ? word.imageUrlsList.first : word.imageUrl;
    if (image == null || image.trim().isEmpty) return null;

    final distractors = DistractorService.wordDistractors(
      target: word,
      allWords: allWords,
      dictionary: dictionary,
    );
    if (distractors.length < 3) return null;

    return QuizQuestion(
      id: _nextId(word, QuestionType.imageToWord),
      type: QuestionType.imageToWord,
      wordId: _wordId(word),
      prompt: 'What is this?',
      correctAnswer: word.word,
      options: _shuffledOptions(word.word, distractors),
      imageUrl: image,
      explanation: word.translation,
      difficulty: 2,
    );
  }

  // ==================== 2) صوت → كلمة ====================

  static QuizQuestion? _audioToWord(
    Word word,
    DictionaryResult? dictionary,
    List<Word> allWords,
  ) {
    final audio = word.audioUrl?.trim();
    if (audio == null || audio.isEmpty) return null;

    final distractors = DistractorService.wordDistractors(
      target: word,
      allWords: allWords,
      dictionary: dictionary,
    );
    if (distractors.length < 3) return null;

    return QuizQuestion(
      id: _nextId(word, QuestionType.audioToWord),
      type: QuestionType.audioToWord,
      wordId: _wordId(word),
      prompt: 'Listen and choose the word',
      correctAnswer: word.word,
      options: _shuffledOptions(word.word, distractors),
      audioUrl: audio,
      explanation: word.translation,
      difficulty: 3,
    );
  }

  // ==================== 3) كلمة → ترجمة عربية ====================

  static QuizQuestion? _wordToArabic(Word word, List<Word> allWords) {
    final correct = word.translation.trim();
    if (correct.isEmpty) return null;

    final distractors = DistractorService.translationDistractors(
      target: word,
      allWords: allWords,
    );
    if (distractors.length < 3) return null;

    return QuizQuestion(
      id: _nextId(word, QuestionType.wordToArabic),
      type: QuestionType.wordToArabic,
      wordId: _wordId(word),
      prompt: word.word,
      correctAnswer: correct,
      options: _shuffledOptions(correct, distractors),
      explanation: '"${word.word}" تعني "$correct"',
      difficulty: 1,
    );
  }

  // ==================== 4) ترجمة عربية → كلمة ====================

  static QuizQuestion? _arabicToWord(Word word, List<Word> allWords) {
    final correct = word.word.trim();
    if (correct.isEmpty || word.translation.trim().isEmpty) return null;

    final distractors = DistractorService.wordDistractors(
      target: word,
      allWords: allWords,
    );
    if (distractors.length < 3) return null;

    return QuizQuestion(
      id: _nextId(word, QuestionType.arabicToWord),
      type: QuestionType.arabicToWord,
      wordId: _wordId(word),
      prompt: word.translation,
      correctAnswer: correct,
      options: _shuffledOptions(correct, distractors),
      explanation: '"${word.translation}" تعني "$correct"',
      difficulty: 2,
    );
  }

  // ==================== 5) تعريف إنجليزي → كلمة ====================

  static QuizQuestion? _definitionToWord(
    Word word,
    DictionaryResult? dictionary,
    List<Word> allWords,
  ) {
    final def = pickBestDefinition(dictionary, fallback: word);
    if (def == null) return null;

    final distractors = DistractorService.wordDistractors(
      target: word,
      allWords: allWords,
      dictionary: dictionary,
    );
    if (distractors.length < 3) return null;

    return QuizQuestion(
      id: _nextId(word, QuestionType.definitionToWord),
      type: QuestionType.definitionToWord,
      wordId: _wordId(word),
      prompt: def,
      correctAnswer: word.word,
      options: _shuffledOptions(word.word, distractors),
      explanation: word.translation,
      difficulty: 3,
    );
  }

  // ==================== 6) كلمة → تعريف إنجليزي ====================

  static QuizQuestion? _wordToDefinition(
    Word word,
    DictionaryResult? dictionary,
    List<Word> allWords,
    List<DictionaryResult> cachedDictionaries,
  ) {
    final def = pickBestDefinition(dictionary, fallback: word);
    if (def == null) return null;

    final distractors = DistractorService.definitionDistractors(
      target: word,
      dictionary: dictionary,
      allWords: allWords,
      cachedDictionaries: cachedDictionaries,
    );
    if (distractors.length < 3) return null;

    return QuizQuestion(
      id: _nextId(word, QuestionType.wordToDefinition),
      type: QuestionType.wordToDefinition,
      wordId: _wordId(word),
      prompt: word.word,
      correctAnswer: def,
      options: _shuffledOptions(def, distractors),
      explanation: word.translation,
      difficulty: 3,
    );
  }

  /// أفضل تعريف متاح: طوله مناسب (≥20 حرفاً)، لا ينتهي بـ ':'، ولا يحتوي
  /// الكلمة نفسها بشكل واضح. يفضّل تعريف مصحوب بمثال، ثم يجرّب `fallback`
  /// (كلمة محفوظة محلياً) إن غاب القاموس الحيّ (عند المراجعة بدون إنترنت).
  static String? pickBestDefinition(DictionaryResult? dictionary, {Word? fallback}) {
    bool isQuality(String d, String targetWord) {
      final t = d.trim();
      if (t.length < 20) return false;
      if (t.endsWith(':')) return false;
      final containsTarget = RegExp(
        r'\b' + RegExp.escape(targetWord) + r'\b',
        caseSensitive: false,
      ).hasMatch(t);
      return !containsTarget;
    }

    if (dictionary != null) {
      // الأولوية: تعريف مصحوب بمثال (أوضح للمتعلّم).
      for (final meaning in dictionary.meanings) {
        for (final def in meaning.definitions) {
          if (def.example != null && isQuality(def.definition, dictionary.word)) {
            return def.definition.trim();
          }
        }
      }
      for (final meaning in dictionary.meanings) {
        for (final def in meaning.definitions) {
          if (isQuality(def.definition, dictionary.word)) {
            return def.definition.trim();
          }
        }
      }
    }

    if (fallback != null) {
      for (final d in fallback.definitionsList) {
        if (isQuality(d, fallback.word)) return d.trim();
      }
    }
    return null;
  }

  // ==================== 7) جملة ناقصة (cloze) ====================

  static QuizQuestion? _clozeQuestion(Word word, List<Word> allWords) {
    final examples = word.allExamplesMerged;
    if (examples.isEmpty) return null;

    // جرّب الصيغة المحفوظة نفسها أولاً، ثم الجذر إن وُجد.
    var matchedForm = word.word.trim();
    var blanked = buildClozeSentence(word: matchedForm, examples: examples);
    if (blanked == null && word.rootWord != null && word.rootWord!.trim().isNotEmpty) {
      matchedForm = word.rootWord!.trim();
      blanked = buildClozeSentence(word: matchedForm, examples: examples);
    }
    if (blanked == null) return null; // لا مثال حقيقي يحتوي الكلمة → لا سؤال

    final distractors = DistractorService.wordDistractors(
      target: word,
      allWords: allWords,
    );
    if (distractors.length < 3) return null;

    return QuizQuestion(
      id: _nextId(word, QuestionType.clozeSentence),
      type: QuestionType.clozeSentence,
      wordId: _wordId(word),
      prompt: blanked,
      correctAnswer: matchedForm,
      options: _shuffledOptions(matchedForm, distractors),
      hint: 'اختر الكلمة التي تكمل الجملة بشكل صحيح.',
      explanation: word.translation,
      difficulty: 4,
    );
  }

  /// يبني جملة ناقصة من مثال حقيقي محفوظ فقط (لا يخترع جملة جديدة).
  /// يرجع null إن لم يحتوِ أي مثال على الكلمة.
  static String? buildClozeSentence({
    required String word,
    required List<String> examples,
  }) {
    final w = word.trim();
    if (w.isEmpty) return null;
    for (final ex in examples) {
      if (_containsWholeWord(ex, w)) {
        return _blankOut(ex, w);
      }
    }
    return null;
  }

  static bool _containsWholeWord(String sentence, String word) {
    final pattern = RegExp(
      r'\b' + RegExp.escape(word.trim()) + r'\b',
      caseSensitive: false,
    );
    return pattern.hasMatch(sentence);
  }

  static String _blankOut(String sentence, String word) {
    final pattern = RegExp(
      r'\b' + RegExp.escape(word.trim()) + r'\b',
      caseSensitive: false,
    );
    return sentence.replaceAll(pattern, '___');
  }

  // ==================== 8) مرادف ====================

  static QuizQuestion? _synonymQuestion(Word word, List<Word> allWords) {
    final synonyms = word.synonymsList;
    if (synonyms.isEmpty) return null;

    // فضّل مرادفاً قصيراً بكلمة واحدة (أوضح من عبارة متعددة الكلمات).
    final singleWordSynonyms = synonyms.where((s) => !s.trim().contains(' ')).toList();
    final chosen = (singleWordSynonyms.isNotEmpty ? singleWordSynonyms : synonyms).first.trim();
    if (chosen.isEmpty) return null;

    // استبعد كل مرادفات الكلمة الأخرى من البدائل (حتى لا يظهر أكثر من جواب صحيح).
    final excluded = <String>{word.word.trim().toLowerCase(), ...synonyms.map((s) => s.trim().toLowerCase())};
    final pool = allWords.where((w) =>
        w.id != word.id &&
        w.word.trim().isNotEmpty &&
        !excluded.contains(w.word.trim().toLowerCase()) &&
        !DistractorService.isSameWordFamily(word.word, w.word, null));

    final distractors = DistractorService.uniqueClean(pool.map((w) => w.word).toList())
        .take(3)
        .toList();
    if (distractors.length < 3) return null;

    return QuizQuestion(
      id: _nextId(word, QuestionType.synonym),
      type: QuestionType.synonym,
      wordId: _wordId(word),
      prompt: 'Choose the closest synonym of "${word.word}"',
      correctAnswer: chosen,
      options: _shuffledOptions(chosen, distractors),
      explanation: '"$chosen" مرادف لكلمة "${word.word}"',
      difficulty: 3,
    );
  }

  // ==================== 9) ضد ====================

  static QuizQuestion? _antonymQuestion(Word word, List<Word> allWords) {
    final antonyms = word.antonymsList;
    if (antonyms.isEmpty) return null;

    final chosen = antonyms.first.trim();
    if (chosen.isEmpty) return null;

    final excluded = <String>{word.word.trim().toLowerCase(), ...antonyms.map((s) => s.trim().toLowerCase())};
    final pool = allWords.where((w) =>
        w.id != word.id &&
        w.word.trim().isNotEmpty &&
        !excluded.contains(w.word.trim().toLowerCase()) &&
        !DistractorService.isSameWordFamily(word.word, w.word, null));

    final distractors = DistractorService.uniqueClean(pool.map((w) => w.word).toList())
        .take(3)
        .toList();
    if (distractors.length < 3) return null;

    return QuizQuestion(
      id: _nextId(word, QuestionType.antonym),
      type: QuestionType.antonym,
      wordId: _wordId(word),
      prompt: 'Choose the opposite of "${word.word}"',
      correctAnswer: chosen,
      options: _shuffledOptions(chosen, distractors),
      explanation: '"$chosen" هو عكس "${word.word}"',
      difficulty: 3,
    );
  }

  // ==================== 10) عائلة الكلمة ====================

  static QuizQuestion? _wordFamilyQuestion(Word word, List<Word> allWords) {
    // الحالة الأضمن: الكلمة نفسها متصرّفة ولها جذر معروف مسبقاً (محفوظ من
    // القاموس وقت الإضافة) — أسأل عن الشكل الأساسي.
    if (word.rootWord != null && word.rootWord!.trim().isNotEmpty) {
      final root = word.rootWord!.trim();
      final distractors = DistractorService.wordDistractors(target: word, allWords: allWords)
          .where((d) => d.trim().toLowerCase() != root.toLowerCase())
          .take(3)
          .toList();
      if (distractors.length < 3) return null;

      return QuizQuestion(
        id: _nextId(word, QuestionType.wordFamily),
        type: QuestionType.wordFamily,
        wordId: _wordId(word),
        prompt: 'What is the base form of "${word.word}"?',
        correctAnswer: root,
        options: _shuffledOptions(root, distractors),
        explanation: '"${word.word}" ${word.formTypeLabel ?? 'صيغة متصرّفة'} من "$root"',
        difficulty: 3,
      );
    }

    // الحالة الثانية: الكلمة أساسية ولها تصريف معروف (ماضٍ أو مضارع مستمر).
    final family = WordFamilyService.build(word, allWords);
    if (family == null) return null;

    if (family.past != null) {
      final distractors = DistractorService.wordDistractors(target: word, allWords: allWords)
          .where((d) => d.trim().toLowerCase() != family.past!.toLowerCase())
          .take(3)
          .toList();
      if (distractors.length < 3) return null;
      return QuizQuestion(
        id: _nextId(word, QuestionType.wordFamily),
        type: QuestionType.wordFamily,
        wordId: _wordId(word),
        prompt: 'What is the past tense of "${word.word}"?',
        correctAnswer: family.past!,
        options: _shuffledOptions(family.past!, distractors),
        explanation: '"${family.past}" هي صيغة الماضي من "${word.word}"',
        difficulty: 3,
      );
    }

    if (family.ingForm != null) {
      final distractors = DistractorService.wordDistractors(target: word, allWords: allWords)
          .where((d) => d.trim().toLowerCase() != family.ingForm!.toLowerCase())
          .take(3)
          .toList();
      if (distractors.length < 3) return null;
      return QuizQuestion(
        id: _nextId(word, QuestionType.wordFamily),
        type: QuestionType.wordFamily,
        wordId: _wordId(word),
        prompt: 'What is the -ing form of "${word.word}"?',
        correctAnswer: family.ingForm!,
        options: _shuffledOptions(family.ingForm!, distractors),
        explanation: '"${family.ingForm}" هي صيغة المضارع المستمر من "${word.word}"',
        difficulty: 3,
      );
    }

    return null;
  }

  // ==================== أدوات مشتركة ====================

  static List<String> _shuffledOptions(String correct, List<String> distractors) {
    final options = [correct, ...distractors.take(3)]..shuffle(_rng);
    return options;
  }

  static String _wordId(Word word) => (word.id ?? 0).toString();

  static String _nextId(Word word, QuestionType type) {
    _idCounter++;
    return '${_wordId(word)}_${type.name}_$_idCounter';
  }
}
