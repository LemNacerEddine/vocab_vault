import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_vault/models/question_type.dart';
import 'package:vocab_vault/models/word.dart';
import 'package:vocab_vault/services/distractor_service.dart';
import 'package:vocab_vault/services/local_question_generator_service.dart';
import 'package:vocab_vault/services/quiz_validation_service.dart';

/// كلمات اختبار ثابتة (بدون إنترنت) تحاكي بيانات محفوظة فعلياً بعد الإضافة،
/// لاختبار مولّد الأسئلة المحلي على أمثلة واقعية: go, went, apple,
/// beautiful, stop, run.
List<Word> _fixtureWords() {
  return [
    Word(
      id: 1,
      word: 'go',
      translation: 'يذهب',
      definition: 'to move from one place to another',
      allDefinitions: 'to move from one place to another',
      example: 'I go to school every day.',
      allExamples: 'I go to school every day.',
      audioUrl: 'https://example.com/go.mp3',
      partOfSpeech: 'verb',
      allPartsOfSpeech: 'verb',
      synonyms: 'travel,move',
      antonyms: 'stay,remain',
      imageUrl: 'https://example.com/go.jpg',
      allImageUrls: 'https://example.com/go.jpg',
    ),
    Word(
      id: 2,
      word: 'went',
      translation: 'ذهب',
      definition: 'moved from one place to another in the past',
      allDefinitions: 'moved from one place to another in the past',
      example: 'I went to school yesterday.',
      allExamples: 'I went to school yesterday.',
      partOfSpeech: 'verb',
      allPartsOfSpeech: 'verb',
      rootWord: 'go',
      formTypeLabel: 'فعل ماضٍ شاذ',
      inputFormExamples: 'I went to school yesterday.',
    ),
    Word(
      id: 3,
      word: 'apple',
      translation: 'تفاحة',
      definition: 'a round fruit with red or green skin and a whitish inside',
      allDefinitions: 'a round fruit with red or green skin and a whitish inside',
      example: 'She ate a red apple.',
      allExamples: 'She ate a red apple.',
      audioUrl: 'https://example.com/apple.mp3',
      partOfSpeech: 'noun',
      allPartsOfSpeech: 'noun',
      imageUrl: 'https://example.com/apple.jpg',
      allImageUrls: 'https://example.com/apple.jpg',
    ),
    Word(
      id: 4,
      word: 'beautiful',
      translation: 'جميل',
      definition: 'pleasing to look at or listen to; attractive',
      allDefinitions: 'pleasing to look at or listen to; attractive',
      example: 'The sunset was beautiful tonight.',
      allExamples: 'The sunset was beautiful tonight.',
      partOfSpeech: 'adjective',
      allPartsOfSpeech: 'adjective',
      synonyms: 'pretty,lovely',
      antonyms: 'ugly',
      imageUrl: 'https://example.com/beautiful.jpg',
      allImageUrls: 'https://example.com/beautiful.jpg',
    ),
    Word(
      id: 5,
      word: 'stop',
      translation: 'يتوقف',
      definition: 'to no longer continue moving or operating',
      allDefinitions: 'to no longer continue moving or operating',
      example: 'Please stop the car right now.',
      allExamples: 'Please stop the car right now.',
      audioUrl: 'https://example.com/stop.mp3',
      partOfSpeech: 'verb',
      allPartsOfSpeech: 'verb',
      synonyms: 'halt,cease',
      antonyms: 'continue',
    ),
    Word(
      id: 6,
      word: 'run',
      translation: 'يجري',
      definition: 'to move quickly using your legs faster than walking',
      allDefinitions: 'to move quickly using your legs faster than walking',
      example: 'He can run very fast in the park.',
      allExamples: 'He can run very fast in the park.',
      audioUrl: 'https://example.com/run.mp3',
      partOfSpeech: 'verb',
      allPartsOfSpeech: 'verb',
      synonyms: 'sprint,dash',
      antonyms: 'walk',
      imageUrl: 'https://example.com/run.jpg',
      allImageUrls: 'https://example.com/run.jpg',
    ),
  ];
}

void main() {
  final words = _fixtureWords();

  group('LocalQuestionGeneratorService — go', () {
    final go = words.firstWhere((w) => w.word == 'go');
    final questions = LocalQuestionGeneratorService.generateQuestionsForWord(
      word: go,
      dictionary: null,
      allWords: words,
      cachedDictionaries: const [],
    );

    test('كل سؤال مُولَّد يجتاز فحص الجودة', () {
      for (final q in questions) {
        expect(QuizValidationService.isValidQuestion(q), isTrue, reason: '${q.type} فشل التحقق');
      }
    });

    test('تُولَّد أنواع متعدّدة وليس الترجمة فقط', () {
      final types = questions.map((q) => q.type).toSet();
      expect(types.length, greaterThan(3));
      expect(types.contains(QuestionType.wordToArabic), isTrue);
      // النوع الوحيد الذي لا يجب أن يقتصر عليه التوليد.
      expect(types.length, greaterThan(1));
    });

    test('سؤال الصوت يحمل audioUrl صحيحاً', () {
      final audioQ = questions.where((q) => q.type == QuestionType.audioToWord);
      expect(audioQ, isNotEmpty);
      expect(audioQ.first.audioUrl, 'https://example.com/go.mp3');
    });

    test('سؤال المرادف يستبعد مرادفات "go" الأخرى من الخيارات الخاطئة', () {
      final synQ = questions.where((q) => q.type == QuestionType.synonym);
      if (synQ.isNotEmpty) {
        final opts = synQ.first.options.map((o) => o.toLowerCase()).toList();
        final wrongOnly = opts.where((o) => o != synQ.first.correctAnswer.toLowerCase());
        expect(wrongOnly.contains('travel'), isFalse);
        expect(wrongOnly.contains('move'), isFalse);
      }
    });
  });

  group('LocalQuestionGeneratorService — went (عائلة الكلمة)', () {
    final went = words.firstWhere((w) => w.word == 'went');
    final questions = LocalQuestionGeneratorService.generateQuestionsForWord(
      word: went,
      dictionary: null,
      allWords: words,
      cachedDictionaries: const [],
    );

    test('يُولَّد سؤال wordFamily يسأل عن الشكل الأساسي (go)', () {
      final familyQ = questions.where((q) => q.type == QuestionType.wordFamily);
      expect(familyQ, isNotEmpty);
      expect(familyQ.first.correctAnswer, 'go');
    });
  });

  group('LocalQuestionGeneratorService — apple / beautiful / stop / run', () {
    for (final wordText in ['apple', 'beautiful', 'stop', 'run']) {
      test('$wordText: كل الأسئلة المُولَّدة صالحة', () {
        final target = words.firstWhere((w) => w.word == wordText);
        final questions = LocalQuestionGeneratorService.generateQuestionsForWord(
          word: target,
          dictionary: null,
          allWords: words,
          cachedDictionaries: const [],
        );
        expect(questions, isNotEmpty);
        for (final q in questions) {
          expect(QuizValidationService.isValidQuestion(q), isTrue, reason: '${q.type} فشل التحقق');
        }
      });
    }

    test('apple (اسم ملموس) يحصل على سؤال صورة', () {
      final apple = words.firstWhere((w) => w.word == 'apple');
      final questions = LocalQuestionGeneratorService.generateQuestionsForWord(
        word: apple,
        dictionary: null,
        allWords: words,
        cachedDictionaries: const [],
      );
      expect(questions.any((q) => q.type == QuestionType.imageToWord), isTrue);
    });
  });

  group('DistractorService.isSameWordFamily', () {
    test('go و went من نفس العائلة', () {
      expect(DistractorService.isSameWordFamily('go', 'went', null), isTrue);
    });
    test('go و run ليستا من نفس العائلة', () {
      expect(DistractorService.isSameWordFamily('go', 'run', null), isFalse);
    });
  });

  group('DistractorService.levenshtein', () {
    test('مسافة صفر بين كلمتين متطابقتين', () {
      expect(DistractorService.levenshtein('run', 'run'), 0);
    });
    test('مسافة صحيحة بين كلمتين مختلفتين', () {
      expect(DistractorService.levenshtein('run', 'ran'), 1);
    });
  });
}
