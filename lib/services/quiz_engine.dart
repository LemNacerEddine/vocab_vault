import 'dart:math';

import '../models/word.dart';
import '../models/quiz_pack.dart';
import '../models/quiz_question.dart';

/// يبني جلسة اختبار من الكلمات المستحقّة للمراجعة.
///
/// لكل كلمة يختار نوع سؤال عشوائياً من الأنواع المتاحة لها. البدائل الخاطئة
/// تأتي من حزمة Claude إن وُجدت (بدائل ذكية)، وإلا من كلمات المستخدم الأخرى
/// (fallback محلي) — فالمحرّك يعمل بالكامل بدون إنترنت وبدون AI.
class QuizEngine {
  static final Random _rng = Random();

  static const int _desiredDistractors = 3;

  /// بناء جلسة أسئلة.
  ///
  /// [dueWords] الكلمات المستحقّة (مصدر الأسئلة).
  /// [allWords] كل الكلمات (مصدر البدائل المحلية والصور).
  /// [maxQuestions] الحد الأقصى لعدد الأسئلة في الجلسة.
  static List<QuizQuestion> buildSession(
    List<Word> dueWords,
    List<Word> allWords, {
    int maxQuestions = 15,
  }) {
    final questions = <QuizQuestion>[];
    for (final word in dueWords) {
      if (questions.length >= maxQuestions) break;
      final q = buildQuestionForWord(word, allWords);
      if (q != null) questions.add(q);
    }
    return questions;
  }

  /// بناء سؤال واحد لكلمة، باختيار نوع عشوائي من الأنواع المتاحة لها.
  static QuizQuestion? buildQuestionForWord(Word word, List<Word> allWords) {
    final others = allWords.where((w) => w.id != word.id).toList();
    final pack = word.quizPack;

    // جميع البُناة المتاحة (كل واحد يرجع null إن نقصت بيانات نوعه).
    final builders = <QuizQuestion? Function()>[
      () => _chooseMeaning(word, others, pack),
      () => _chooseWord(word, others, pack),
      () => _fillBlank(word, others, pack),
      () => _matchDefinition(word, others, pack),
      () => _chooseImage(word, others),
      () => _listenChoose(word, others, pack),
    ];

    final candidates = <QuizQuestion>[];
    for (final build in builders) {
      final q = build();
      if (q != null) candidates.add(q);
    }
    if (candidates.isEmpty) return null;
    return candidates[_rng.nextInt(candidates.length)];
  }

  // ==================== بُناة الأنواع ====================

  /// 1) اختيار المعنى العربي الصحيح (EN→AR).
  static QuizQuestion? _chooseMeaning(
    Word word,
    List<Word> others,
    QuizPack? pack,
  ) {
    final correct = word.translation.trim();
    if (correct.isEmpty) return null;
    final distractors = _pickTexts(
      correct: correct,
      packList: pack?.distractorTranslations ?? const [],
      pool: others.map((w) => w.translation).toList(),
    );
    if (distractors.isEmpty) return null;
    return QuizQuestion(
      type: QuizType.chooseMeaning,
      word: word,
      promptAr: 'ما معنى كلمة «${word.word}»؟',
      options: _buildTextOptions(correct, distractors),
    );
  }

  /// 2) اختيار الكلمة الإنجليزية الصحيحة (AR→EN).
  static QuizQuestion? _chooseWord(
    Word word,
    List<Word> others,
    QuizPack? pack,
  ) {
    final correct = word.word.trim();
    if (correct.isEmpty || word.translation.trim().isEmpty) return null;
    final distractors = _pickTexts(
      correct: correct,
      packList: pack?.distractorWords ?? const [],
      pool: others.map((w) => w.word).toList(),
      caseInsensitive: true,
    );
    if (distractors.isEmpty) return null;
    return QuizQuestion(
      type: QuizType.chooseWord,
      word: word,
      promptAr: 'أي كلمة تعني «${word.translation}»؟',
      options: _buildTextOptions(correct, distractors),
    );
  }

  /// 3) ملء الفراغ في جملة.
  static QuizQuestion? _fillBlank(
    Word word,
    List<Word> others,
    QuizPack? pack,
  ) {
    final target = word.word.trim();
    if (target.isEmpty) return null;

    // اختيار جملة تحتوي الكلمة: من حزمة Claude أولاً، ثم من الأمثلة المحفوظة.
    String? sentence = pack?.clozeSentence;
    if (sentence == null || !_containsWord(sentence, target)) {
      sentence = word.allExamplesMerged.firstWhere(
        (s) => _containsWord(s, target),
        orElse: () => '',
      );
    }
    if (sentence.isEmpty || !_containsWord(sentence, target)) return null;

    final blanked = _blankOut(sentence, target);
    final distractors = _pickTexts(
      correct: target,
      packList: pack?.distractorWords ?? const [],
      pool: others.map((w) => w.word).toList(),
      caseInsensitive: true,
    );
    if (distractors.isEmpty) return null;

    return QuizQuestion(
      type: QuizType.fillBlank,
      word: word,
      promptAr: 'أكمل الفراغ بالكلمة الصحيحة:',
      promptDetail: blanked,
      options: _buildTextOptions(target, distractors),
    );
  }

  /// 4) مطابقة التعريف الإنجليزي الصحيح.
  static QuizQuestion? _matchDefinition(
    Word word,
    List<Word> others,
    QuizPack? pack,
  ) {
    final correct =
        (word.definition ?? word.definitionsList.firstOrNull ?? '').trim();
    if (correct.isEmpty) return null;
    final pool = <String>[];
    for (final w in others) {
      final d = w.definition ?? w.definitionsList.firstOrNull;
      if (d != null && d.trim().isNotEmpty) pool.add(d);
    }
    final distractors = _pickTexts(
      correct: correct,
      packList: pack?.distractorDefinitions ?? const [],
      pool: pool,
    );
    if (distractors.isEmpty) return null;
    return QuizQuestion(
      type: QuizType.matchDefinition,
      word: word,
      promptAr: 'أي تعريف يطابق كلمة «${word.word}»؟',
      options: _buildTextOptions(correct, distractors),
    );
  }

  /// 5) اختيار الصورة المناسبة.
  static QuizQuestion? _chooseImage(Word word, List<Word> others) {
    final correctImage = word.imageUrlsList.firstOrNull ?? word.imageUrl;
    if (correctImage == null || correctImage.trim().isEmpty) return null;

    // صور من كلمات أخرى كبدائل.
    final otherImages = <String>[];
    final shuffledOthers = [...others]..shuffle(_rng);
    for (final w in shuffledOthers) {
      final img = w.imageUrlsList.firstOrNull ?? w.imageUrl;
      if (img != null && img.trim().isNotEmpty && img != correctImage) {
        otherImages.add(img);
      }
      if (otherImages.length >= _desiredDistractors) break;
    }
    if (otherImages.isEmpty) return null;

    final options = <QuizOption>[
      QuizOption(imageUrl: correctImage, isCorrect: true),
      ...otherImages.map((u) => QuizOption(imageUrl: u, isCorrect: false)),
    ]..shuffle(_rng);

    return QuizQuestion(
      type: QuizType.chooseImage,
      word: word,
      promptAr: 'اختر الصورة التي تعبّر عن «${word.word}»',
      options: options,
      optionsAreImages: true,
    );
  }

  /// 6) الاستماع للنطق واختيار المعنى.
  static QuizQuestion? _listenChoose(
    Word word,
    List<Word> others,
    QuizPack? pack,
  ) {
    final audio = word.audioUrl?.trim();
    if (audio == null || audio.isEmpty) return null;
    final correct = word.translation.trim();
    if (correct.isEmpty) return null;
    final distractors = _pickTexts(
      correct: correct,
      packList: pack?.distractorTranslations ?? const [],
      pool: others.map((w) => w.translation).toList(),
    );
    if (distractors.isEmpty) return null;
    return QuizQuestion(
      type: QuizType.listenChoose,
      word: word,
      promptAr: 'استمع للنطق ثم اختر المعنى الصحيح',
      audioUrl: audio,
      options: _buildTextOptions(correct, distractors),
    );
  }

  // ==================== أدوات مساعدة ====================

  /// اختيار بدائل نصية: من حزمة Claude أولاً ثم من المجموعة المحلية،
  /// مع ضمان التمايز وعدم مطابقة الإجابة الصحيحة.
  static List<String> _pickTexts({
    required String correct,
    required List<String> packList,
    required List<String> pool,
    bool caseInsensitive = false,
    int count = _desiredDistractors,
  }) {
    String norm(String s) =>
        caseInsensitive ? s.trim().toLowerCase() : s.trim();

    final chosen = <String>[];
    final seen = <String>{norm(correct)};

    void addFrom(List<String> source, {bool shuffle = false}) {
      final items = shuffle ? ([...source]..shuffle(_rng)) : source;
      for (final raw in items) {
        if (chosen.length >= count) break;
        final value = raw.trim();
        if (value.isEmpty) continue;
        if (seen.add(norm(value))) chosen.add(value);
      }
    }

    addFrom(packList); // بدائل Claude الذكية أولاً (بترتيبها)
    addFrom(pool, shuffle: true); // ثم بدائل محلية عشوائية
    return chosen;
  }

  /// بناء قائمة خيارات نصية مخلوطة من إجابة صحيحة + بدائل.
  static List<QuizOption> _buildTextOptions(
    String correct,
    List<String> distractors,
  ) {
    final options = <QuizOption>[
      QuizOption(text: correct, isCorrect: true),
      ...distractors.map((d) => QuizOption(text: d, isCorrect: false)),
    ]..shuffle(_rng);
    return options;
  }

  /// هل تحتوي الجملة على الكلمة ككلمة مستقلة (غير حسّاس لحالة الأحرف)؟
  static bool _containsWord(String sentence, String word) {
    final pattern = RegExp(
      r'\b' + RegExp.escape(word) + r'\b',
      caseSensitive: false,
    );
    return pattern.hasMatch(sentence);
  }

  /// استبدال الكلمة في الجملة بفراغ.
  static String _blankOut(String sentence, String word) {
    final pattern = RegExp(
      r'\b' + RegExp.escape(word) + r'\b',
      caseSensitive: false,
    );
    return sentence.replaceAll(pattern, '______');
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
