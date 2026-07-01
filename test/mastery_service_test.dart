import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_vault/models/question_type.dart';
import 'package:vocab_vault/models/word_progress.dart';
import 'package:vocab_vault/services/mastery_service.dart';

void main() {
  group('MasteryService.applyAnswer', () {
    test('الإجابة الصحيحة ترفع مستوى الإتقان وتؤجّل المراجعة تدريجياً', () {
      var progress = WordProgress.initial('1');
      expect(progress.masteryLevel, 0);

      // المراجعة الأولى (صحيحة): mastery 0 → 1، الموعد القادم بعد يوم تقريباً.
      progress = MasteryService.applyAnswer(progress, type: QuestionType.wordToArabic, correct: true);
      expect(progress.masteryLevel, 1);
      expect(progress.correctCount, 1);
      expect(progress.nextReviewAt, isNotNull);
      final diff1 = progress.nextReviewAt!.difference(DateTime.now());
      expect(diff1.inHours, greaterThan(20)); // قريب من يوم واحد

      // الثانية (صحيحة): mastery 1 → 2، الموعد بعد 3 أيام تقريباً.
      progress = MasteryService.applyAnswer(progress, type: QuestionType.wordToArabic, correct: true);
      expect(progress.masteryLevel, 2);
      final diff2 = progress.nextReviewAt!.difference(DateTime.now());
      expect(diff2.inDays, greaterThanOrEqualTo(2));
    });

    test('الإجابة الخاطئة تُنقص مستوى الإتقان وتجعل المراجعة قريبة جداً', () {
      var progress = WordProgress.initial('1');
      for (var i = 0; i < 4; i++) {
        progress = MasteryService.applyAnswer(progress, type: QuestionType.wordToArabic, correct: true);
      }
      expect(progress.masteryLevel, 4);

      progress = MasteryService.applyAnswer(progress, type: QuestionType.audioToWord, correct: false);
      expect(progress.masteryLevel, 3); // ينقص بدل التصفير الكامل
      expect(progress.wrongCount, 1);
      expect(progress.wrongByType[QuestionType.audioToWord], 1);

      final diff = progress.nextReviewAt!.difference(DateTime.now());
      expect(diff.inMinutes, lessThanOrEqualTo(11)); // مراجعة قريبة جداً (~10 دقائق)
    });

    test('مستوى الإتقان لا يتجاوز 5 ولا ينزل تحت 0', () {
      var progress = WordProgress.initial('1');
      for (var i = 0; i < 10; i++) {
        progress = MasteryService.applyAnswer(progress, type: QuestionType.synonym, correct: true);
      }
      expect(progress.masteryLevel, MasteryService.maxMastery);

      for (var i = 0; i < 10; i++) {
        progress = MasteryService.applyAnswer(progress, type: QuestionType.synonym, correct: false);
      }
      expect(progress.masteryLevel, 0);
    });

    test('weakestType يرجع نوع السؤال الأكثر خطأً', () {
      var progress = WordProgress.initial('1');
      progress = MasteryService.applyAnswer(progress, type: QuestionType.audioToWord, correct: false);
      progress = MasteryService.applyAnswer(progress, type: QuestionType.audioToWord, correct: false);
      progress = MasteryService.applyAnswer(progress, type: QuestionType.synonym, correct: false);

      expect(progress.weakestType, QuestionType.audioToWord);
    });
  });
}
