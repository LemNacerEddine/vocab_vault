import '../models/word.dart';
import 'lemmatization_service.dart';

/// بيانات عائلة كلمة (تصريفاتها المعروفة).
///
/// كل الحقول اختيارية عن قصد: نملأ فقط ما نملك دليلاً مؤكداً عليه
/// (تصريف شاذ معروف، أو كلمة أخرى محفوظها المستخدم فعلياً من نفس العائلة)
/// — لا نخترع تصريفات غير مضمونة.
class WordFamilyData {
  final String base;
  final String? past;
  final String? pastParticiple;
  final String? ingForm;
  final String? thirdPerson;

  const WordFamilyData({
    required this.base,
    this.past,
    this.pastParticiple,
    this.ingForm,
    this.thirdPerson,
  });

  bool get hasAnyForm =>
      past != null || pastParticiple != null || ingForm != null || thirdPerson != null;
}

/// يبني بيانات عائلة الكلمة اعتماداً فقط على مصدرين موثوقين:
/// 1. قاموس الأفعال الشاذة الثابت في [LemmatizationService] (علاقة مؤكدة).
/// 2. كلمات أخرى حفظها المستخدم فعلياً وتنتمي لنفس الجذر (بيانات حقيقية،
///    لا توليد). مثال: لو حفظ المستخدم "go" و"went" و"going" كلمات منفصلة.
class WordFamilyService {
  static WordFamilyData? build(Word target, List<Word> allWords) {
    final selfLemma = LemmatizationService.analyze(target.word);
    final base = selfLemma.rootWord; // يساوي الكلمة نفسها إن لم تكن متصرّفة.

    String? past;
    String? pastParticiple;
    String? ingForm;
    String? thirdPerson;

    void classify(String word, WordFormType type) {
      switch (type) {
        case WordFormType.verbIrregular:
        case WordFormType.verbEd:
          past ??= word;
          break;
        case WordFormType.verbIng:
          ingForm ??= word;
          break;
        default:
          break;
      }
    }

    // من التصريف الشاذ الثابت (علاقة مضمونة من قاموس، وليست توليداً).
    final irregularPast = LemmatizationService.irregularPastOf(base);
    if (irregularPast != null) past = irregularPast;

    // إن كانت الكلمة المستهدفة نفسها صيغة متصرّفة معروفة، صنّفها.
    if (selfLemma.isModified) {
      classify(target.word.trim().toLowerCase(), selfLemma.formType);
    }

    // امسح بقية الكلمات المحفوظة فعلياً وابحث عن أفراد نفس العائلة.
    for (final w in allWords) {
      if (w.id == target.id) continue;
      final lemma = LemmatizationService.analyze(w.word);
      if (lemma.rootWord != base) continue;
      if (lemma.isModified) {
        classify(w.word.trim().toLowerCase(), lemma.formType);
      }
    }

    final data = WordFamilyData(
      base: base,
      past: past,
      pastParticiple: pastParticiple,
      ingForm: ingForm,
      thirdPerson: thirdPerson,
    );
    return data.hasAnyForm ? data : null;
  }
}
