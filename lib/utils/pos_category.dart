import '../models/word.dart';

/// مجموعات تصنيف الكلمات حسب نوعها النحوي.
enum PosCategory {
  noun('أسماء'),
  verb('أفعال'),
  adjective('صفات'),
  other('أخرى');

  final String labelAr;
  const PosCategory(this.labelAr);
}

/// أدوات تصنيف الكلمة إلى مجموعة (أسماء/أفعال/صفات/أخرى)
/// اعتماداً على حقل partOfSpeech الخام القادم من القاموس.
class PosCategoryUtil {
  /// تحويل نص نوع الكلمة الخام إلى مجموعة.
  static PosCategory fromRaw(String? raw) {
    if (raw == null) return PosCategory.other;
    final p = raw.toLowerCase().trim();
    if (p.contains('noun') || p.contains('pronoun')) return PosCategory.noun;
    if (p.contains('verb')) return PosCategory.verb;
    if (p.contains('adjective') || p.contains('adverb')) {
      return PosCategory.adjective;
    }
    return PosCategory.other;
  }

  /// تصنيف كلمة (يفحص partOfSpeech ثم allPartsOfSpeech).
  static PosCategory ofWord(Word word) {
    final primary = fromRaw(word.partOfSpeech);
    if (primary != PosCategory.other) return primary;
    // إن لم يُحدَّد النوع الأساسي، جرّب أول نوع في القائمة الكاملة.
    final all = word.allPartsOfSpeech;
    if (all != null && all.isNotEmpty) {
      for (final part in all.split(',')) {
        final cat = fromRaw(part);
        if (cat != PosCategory.other) return cat;
      }
    }
    return PosCategory.other;
  }

  /// تصفية قائمة كلمات حسب المجموعة.
  static List<Word> filter(List<Word> words, PosCategory category) {
    return words.where((w) => ofWord(w) == category).toList();
  }
}
