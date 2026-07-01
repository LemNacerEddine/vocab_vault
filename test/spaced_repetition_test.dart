import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_vault/services/spaced_repetition_service.dart';

void main() {
  group('SpacedRepetitionService.calculateNext', () {
    // يطابق المثال في README (الجزء 5.3): تقييمات 5,5,4,5.
    test('يتبع تسلسل SM-2 القياسي', () {
      // المراجعة الأولى (quality=5) من الحالة الابتدائية.
      var r = SpacedRepetitionService.calculateNext(
        quality: 5,
        easeFactor: 2.5,
        interval: 0,
        repetition: 0,
      );
      expect((r['easeFactor'] as double), closeTo(2.6, 0.001));
      expect(r['interval'], 1);
      expect(r['repetition'], 1);

      // الثانية (quality=5).
      r = SpacedRepetitionService.calculateNext(
        quality: 5,
        easeFactor: r['easeFactor'] as double,
        interval: r['interval'] as int,
        repetition: r['repetition'] as int,
      );
      expect((r['easeFactor'] as double), closeTo(2.7, 0.001));
      expect(r['interval'], 3);
      expect(r['repetition'], 2);

      // الثالثة (quality=4).
      r = SpacedRepetitionService.calculateNext(
        quality: 4,
        easeFactor: r['easeFactor'] as double,
        interval: r['interval'] as int,
        repetition: r['repetition'] as int,
      );
      expect((r['easeFactor'] as double), closeTo(2.7, 0.001));
      expect(r['interval'], 8);
      expect(r['repetition'], 3);

      // الرابعة (quality=5).
      r = SpacedRepetitionService.calculateNext(
        quality: 5,
        easeFactor: r['easeFactor'] as double,
        interval: r['interval'] as int,
        repetition: r['repetition'] as int,
      );
      expect((r['easeFactor'] as double), closeTo(2.8, 0.001));
      expect(r['interval'], 22);
      expect(r['repetition'], 4);
    });

    test('الإجابة الخاطئة تعيد التكرار من البداية', () {
      final r = SpacedRepetitionService.calculateNext(
        quality: 2,
        easeFactor: 2.8,
        interval: 22,
        repetition: 4,
      );
      expect(r['repetition'], 0);
      expect(r['interval'], 1);
      // معامل السهولة لا ينزل تحت الحد الأدنى.
      expect((r['easeFactor'] as double), greaterThanOrEqualTo(1.3));
    });

    test('معامل السهولة لا ينزل تحت 1.3', () {
      var ef = 1.3;
      for (var i = 0; i < 10; i++) {
        final r = SpacedRepetitionService.calculateNext(
          quality: 0,
          easeFactor: ef,
          interval: 1,
          repetition: 0,
        );
        ef = r['easeFactor'] as double;
        expect(ef, greaterThanOrEqualTo(1.3));
      }
    });

    test('qualityFromAnswer يصنّف الإجابات', () {
      expect(
        SpacedRepetitionService.qualityFromAnswer(correct: false),
        2,
      );
      expect(
        SpacedRepetitionService.qualityFromAnswer(
          correct: true,
          timeTaken: const Duration(seconds: 2),
        ),
        5,
      );
      expect(
        SpacedRepetitionService.qualityFromAnswer(
          correct: true,
          timeTaken: const Duration(seconds: 20),
        ),
        4,
      );
    });
  });
}
