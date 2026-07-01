/// خدمة تحليل الكلمات - الكشف عن الجمع والأفعال المتصرفة وإيجاد الجذر
class LemmatizationService {
  /// نتيجة تحليل الكلمة
  static LemmaResult analyze(String inputWord) {
    final word = inputWord.trim().toLowerCase();

    // 1. تحقق من الجمع الشاذ أولاً
    final irregularSingular = _irregularPlurals[word];
    if (irregularSingular != null) {
      return LemmaResult(
        inputWord: word,
        rootWord: irregularSingular,
        formType: WordFormType.pluralIrregular,
        isModified: true,
      );
    }

    // 2. تحقق من الأفعال الشاذة
    final irregularVerb = _irregularVerbs[word];
    if (irregularVerb != null) {
      return LemmaResult(
        inputWord: word,
        rootWord: irregularVerb,
        formType: WordFormType.verbIrregular,
        isModified: true,
      );
    }

    // 3. قواعد الجمع القياسية
    final pluralResult = _detectPlural(word);
    if (pluralResult != null) return pluralResult;

    // 4. قواعد الأفعال المتصرفة
    final verbResult = _detectVerbForm(word);
    if (verbResult != null) return verbResult;

    // 5. الكلمة في شكلها الأصلي
    return LemmaResult(
      inputWord: word,
      rootWord: word,
      formType: WordFormType.base,
      isModified: false,
    );
  }

  /// الكشف عن الجمع القياسي
  static LemmaResult? _detectPlural(String word) {
    // ies → y (مثل: cities → city, babies → baby)
    if (word.endsWith('ies') && word.length > 4) {
      final root = '${word.substring(0, word.length - 3)}y';
      if (_isLikelyWord(root)) {
        return LemmaResult(
          inputWord: word,
          rootWord: root,
          formType: WordFormType.pluralIes,
          isModified: true,
        );
      }
    }

    // ves → f أو fe (مثل: wolves → wolf, knives → knife)
    if (word.endsWith('ves') && word.length > 4) {
      final rootF = '${word.substring(0, word.length - 3)}f';
      final rootFe = '${word.substring(0, word.length - 3)}fe';
      return LemmaResult(
        inputWord: word,
        rootWord: rootF,
        altRoot: rootFe,
        formType: WordFormType.pluralVes,
        isModified: true,
      );
    }

    // ses / xes / zes / ches / shes → remove es (مثل: boxes → box)
    if ((word.endsWith('ses') ||
            word.endsWith('xes') ||
            word.endsWith('zes') ||
            word.endsWith('ches') ||
            word.endsWith('shes')) &&
        word.length > 4) {
      final root = word.substring(0, word.length - 2);
      return LemmaResult(
        inputWord: word,
        rootWord: root,
        formType: WordFormType.pluralEs,
        isModified: true,
      );
    }

    // s → remove s (مثل: dogs → dog, cats → cat)
    // نتحقق أن الكلمة تنتهي بـ s وليست فعلاً مضارعاً
    if (word.endsWith('s') &&
        !word.endsWith('ss') &&
        !word.endsWith('us') &&
        !word.endsWith('is') &&
        !word.endsWith('as') &&
        word.length > 3) {
      final root = word.substring(0, word.length - 1);
      // تحقق بسيط: إذا الجذر يبدو كلمة منطقية
      if (root.length >= 2) {
        return LemmaResult(
          inputWord: word,
          rootWord: root,
          formType: WordFormType.pluralS,
          isModified: true,
        );
      }
    }

    return null;
  }

  /// الكشف عن الأفعال المتصرفة
  static LemmaResult? _detectVerbForm(String word) {
    // ing → remove ing (مثل: running → run, playing → play)
    if (word.endsWith('ing') && word.length > 5) {
      // إذا كان الحرف قبل ing مضاعفاً (running → run)
      final withoutIng = word.substring(0, word.length - 3);
      if (withoutIng.length >= 2 &&
          withoutIng[withoutIng.length - 1] ==
              withoutIng[withoutIng.length - 2]) {
        final root = withoutIng.substring(0, withoutIng.length - 1);
        return LemmaResult(
          inputWord: word,
          rootWord: root,
          formType: WordFormType.verbIng,
          isModified: true,
        );
      }
      // إذا ينتهي بـ e محذوف (making → make)
      final withE = '${withoutIng}e';
      return LemmaResult(
        inputWord: word,
        rootWord: withoutIng,
        altRoot: withE,
        formType: WordFormType.verbIng,
        isModified: true,
      );
    }

    // ed → remove ed (مثل: played → play, walked → walk)
    if (word.endsWith('ed') && word.length > 4) {
      final withoutEd = word.substring(0, word.length - 2);
      // حرف مضاعف (stopped → stop)
      if (withoutEd.length >= 2 &&
          withoutEd[withoutEd.length - 1] ==
              withoutEd[withoutEd.length - 2]) {
        final root = withoutEd.substring(0, withoutEd.length - 1);
        return LemmaResult(
          inputWord: word,
          rootWord: root,
          formType: WordFormType.verbEd,
          isModified: true,
        );
      }
      // ied → y (مثل: tried → try)
      if (word.endsWith('ied') && word.length > 4) {
        final root = '${word.substring(0, word.length - 3)}y';
        return LemmaResult(
          inputWord: word,
          rootWord: root,
          formType: WordFormType.verbEd,
          isModified: true,
        );
      }
      return LemmaResult(
        inputWord: word,
        rootWord: withoutEd,
        altRoot: '${withoutEd}e',
        formType: WordFormType.verbEd,
        isModified: true,
      );
    }

    // er / est (صفات مقارنة: bigger → big, fastest → fast)
    if (word.endsWith('er') && word.length > 4) {
      final root = word.substring(0, word.length - 2);
      if (root.length >= 2 &&
          root[root.length - 1] == root[root.length - 2]) {
        return LemmaResult(
          inputWord: word,
          rootWord: root.substring(0, root.length - 1),
          formType: WordFormType.adjectiveComparative,
          isModified: true,
        );
      }
    }

    return null;
  }

  /// تحقق بسيط إذا الكلمة تبدو منطقية
  static bool _isLikelyWord(String word) {
    return word.length >= 2 && RegExp(r'^[a-z]+$').hasMatch(word);
  }

  // =============================================
  // قاموس الجموع الشاذة
  // =============================================
  static const Map<String, String> _irregularPlurals = {
    'men': 'man',
    'women': 'woman',
    'children': 'child',
    'teeth': 'tooth',
    'feet': 'foot',
    'mice': 'mouse',
    'geese': 'goose',
    'oxen': 'ox',
    'people': 'person',
    'leaves': 'leaf',
    'lives': 'life',
    'wives': 'wife',
    'knives': 'knife',
    'halves': 'half',
    'scarves': 'scarf',
    'shelves': 'shelf',
    'wolves': 'wolf',
    'loaves': 'loaf',
    'thieves': 'thief',
    'criteria': 'criterion',
    'phenomena': 'phenomenon',
    'data': 'datum',
    'media': 'medium',
    'alumni': 'alumnus',
    'cacti': 'cactus',
    'fungi': 'fungus',
    'nuclei': 'nucleus',
    'syllabi': 'syllabus',
    'analyses': 'analysis',
    'bases': 'basis',
    'crises': 'crisis',
    'diagnoses': 'diagnosis',
    'hypotheses': 'hypothesis',
    'oases': 'oasis',
    'parentheses': 'parenthesis',
    'syntheses': 'synthesis',
    'theses': 'thesis',
    'appendices': 'appendix',
    'indices': 'index',
    'matrices': 'matrix',
    'vertices': 'vertex',
    'axes': 'axis',
  };

  // =============================================
  // قاموس الأفعال الشاذة
  // =============================================
  static const Map<String, String> _irregularVerbs = {
    // ماضي الأفعال الشاذة
    'went': 'go',
    'came': 'come',
    'saw': 'see',
    'did': 'do',
    'had': 'have',
    'was': 'be',
    'were': 'be',
    'been': 'be',
    'got': 'get',
    'made': 'make',
    'said': 'say',
    'took': 'take',
    'knew': 'know',
    'thought': 'think',
    'told': 'tell',
    'found': 'find',
    'gave': 'give',
    'felt': 'feel',
    'became': 'become',
    'left': 'leave',
    'kept': 'keep',
    'began': 'begin',
    'shown': 'show',
    'heard': 'hear',
    'ran': 'run',
    'brought': 'bring',
    'held': 'hold',
    'wrote': 'write',
    'stood': 'stand',
    'lost': 'lose',
    'paid': 'pay',
    'met': 'meet',
    'sat': 'sit',
    'spoke': 'speak',
    'sent': 'send',
    'built': 'build',
    'read': 'read',
    'spent': 'spend',
    'grew': 'grow',
    'broke': 'break',
    'cut': 'cut',
    'put': 'put',
    'set': 'set',
    'hit': 'hit',
    'let': 'let',
    'won': 'win',
    'bought': 'buy',
    'caught': 'catch',
    'taught': 'teach',
    'fought': 'fight',
    'sought': 'seek',
    'thought': 'think',
    'chose': 'choose',
    'drove': 'drive',
    'fell': 'fall',
    'flew': 'fly',
    'forgot': 'forget',
    'froze': 'freeze',
    'hid': 'hide',
    'rode': 'ride',
    'rose': 'rise',
    'sang': 'sing',
    'sank': 'sink',
    'slept': 'sleep',
    'slid': 'slide',
    'stole': 'steal',
    'stuck': 'stick',
    'swam': 'swim',
    'swore': 'swear',
    'threw': 'throw',
    'understood': 'understand',
    'woke': 'wake',
    'wore': 'wear',
    'wept': 'weep',
  };
}

// =============================================
// نوع تصريف الكلمة
// =============================================
enum WordFormType {
  base, // الكلمة في شكلها الأصلي
  pluralS, // جمع بإضافة s (dogs)
  pluralEs, // جمع بإضافة es (boxes)
  pluralIes, // جمع بتحويل y→ies (cities)
  pluralVes, // جمع بتحويل f→ves (wolves)
  pluralIrregular, // جمع شاذ (men, children)
  verbIng, // فعل مضارع مستمر (running)
  verbEd, // فعل ماضي (played)
  verbIrregular, // فعل ماضٍ شاذ (went)
  adjectiveComparative, // صفة مقارنة (bigger)
}

// =============================================
// نتيجة تحليل الكلمة
// =============================================
class LemmaResult {
  final String inputWord; // الكلمة كما أدخلها المستخدم
  final String rootWord; // الكلمة الجذر (المفرد أو المصدر)
  final String? altRoot; // جذر بديل محتمل
  final WordFormType formType; // نوع التصريف
  final bool isModified; // هل تم تعديل الكلمة؟

  LemmaResult({
    required this.inputWord,
    required this.rootWord,
    this.altRoot,
    required this.formType,
    required this.isModified,
  });

  /// وصف نوع التصريف بالعربية
  String get formTypeDescription {
    switch (formType) {
      case WordFormType.base:
        return '';
      case WordFormType.pluralS:
      case WordFormType.pluralEs:
      case WordFormType.pluralIes:
      case WordFormType.pluralVes:
      case WordFormType.pluralIrregular:
        return 'صيغة الجمع';
      case WordFormType.verbIng:
        return 'فعل مضارع مستمر';
      case WordFormType.verbEd:
        return 'فعل ماضٍ';
      case WordFormType.verbIrregular:
        return 'فعل ماضٍ شاذ';
      case WordFormType.adjectiveComparative:
        return 'صفة مقارنة';
    }
  }

  /// هل الكلمة جمع؟
  bool get isPlural =>
      formType == WordFormType.pluralS ||
      formType == WordFormType.pluralEs ||
      formType == WordFormType.pluralIes ||
      formType == WordFormType.pluralVes ||
      formType == WordFormType.pluralIrregular;

  /// هل الكلمة فعل متصرف؟
  bool get isVerbForm =>
      formType == WordFormType.verbIng ||
      formType == WordFormType.verbEd ||
      formType == WordFormType.verbIrregular;
}
