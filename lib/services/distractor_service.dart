import 'dart:math';

import '../models/word.dart';
import 'dictionary_service.dart';
import 'lemmatization_service.dart';

/// خدمة اختيار البدائل الخاطئة (distractors) للأسئلة، بقواعد تمنع الأسئلة
/// الضعيفة أو المضلِّلة بشكل غير عادل:
/// - لا تكرار، ولا تطابق مع الإجابة الصحيحة.
/// - تفضيل نفس partOfSpeech حين أمكن.
/// - استبعاد كلمات من نفس عائلة الكلمة (تصريفات) من بدائل أسئلة المعنى.
class DistractorService {
  static final Random _rng = Random();

  // ==================== بدائل الترجمة (لسؤال wordToArabic) ====================

  static List<String> translationDistractors({
    required Word target,
    required List<Word> allWords,
    int count = 3,
  }) {
    final targetTrans = target.translation.trim();
    if (targetTrans.isEmpty) return const [];

    final candidates = allWords.where((w) =>
        w.id != target.id &&
        w.translation.trim().isNotEmpty &&
        w.translation.trim() != targetTrans &&
        !isSameWordFamily(target.word, w.word, null));

    // المرحلة الأولى: نفس نوع الكلمة (partOfSpeech) أولاً.
    final samePos = candidates.where((w) =>
        target.partOfSpeech != null &&
        w.partOfSpeech != null &&
        w.partOfSpeech!.toLowerCase() == target.partOfSpeech!.toLowerCase());

    final pool = uniqueClean(
      samePos.map((w) => w.translation).toList(),
      exclude: targetTrans,
    )..shuffle(_rng);

    var chosen = pool.take(count).toList();

    if (chosen.length < count) {
      // المرحلة الثانية: أكمل من بقية الكلمات دون تمييز partOfSpeech.
      final rest = uniqueClean(
        candidates.map((w) => w.translation).toList(),
        exclude: targetTrans,
      );
      chosen = fillWithFallback(
        chosen: chosen,
        needed: count,
        broaderPool: rest,
        exclude: targetTrans,
      );
    }
    return chosen;
  }

  // ==================== بدائل الكلمة الإنجليزية (لسؤال arabicToWord وغيره) ====================

  static List<String> wordDistractors({
    required Word target,
    required List<Word> allWords,
    DictionaryResult? dictionary,
    int count = 3,
  }) {
    final targetWord = target.word.trim();
    if (targetWord.isEmpty) return const [];

    final candidates = allWords.where((w) =>
        w.id != target.id &&
        w.word.trim().isNotEmpty &&
        w.word.trim().toLowerCase() != targetWord.toLowerCase() &&
        !isSameWordFamily(targetWord, w.word, dictionary)).toList();

    // رتّب حسب القرب: طول مشابه أولاً، ثم مسافة Levenshtein تصاعدياً
    // (كلمات قريبة الشكل لكن مختلفة المعنى — بدائل مربكة وعادلة).
    candidates.sort((a, b) {
      final lenDiffA = (a.word.length - targetWord.length).abs();
      final lenDiffB = (b.word.length - targetWord.length).abs();
      if (lenDiffA != lenDiffB) return lenDiffA.compareTo(lenDiffB);
      final distA = levenshtein(targetWord, a.word);
      final distB = levenshtein(targetWord, b.word);
      return distA.compareTo(distB);
    });

    final samePos = candidates.where((w) =>
        target.partOfSpeech != null &&
        w.partOfSpeech != null &&
        w.partOfSpeech!.toLowerCase() == target.partOfSpeech!.toLowerCase());

    var chosen = uniqueClean(
      samePos.map((w) => w.word).toList(),
      exclude: targetWord,
    ).take(count).toList();

    if (chosen.length < count) {
      final rest = uniqueClean(
        candidates.map((w) => w.word).toList(),
        exclude: targetWord,
      );
      chosen = fillWithFallback(
        chosen: chosen,
        needed: count,
        broaderPool: rest,
        exclude: targetWord,
      );
    }
    return chosen;
  }

  // ==================== بدائل التعريف (لسؤال wordToDefinition) ====================

  static List<String> definitionDistractors({
    required Word target,
    required DictionaryResult? dictionary,
    required List<Word> allWords,
    required List<DictionaryResult> cachedDictionaries,
    int count = 3,
  }) {
    final targetWord = target.word.trim();
    if (targetWord.isEmpty) return const [];

    // كلمات يُستبعد أخذ تعريفاتها لأنها مرادفات للهدف (قد تكون مقبولة أيضاً).
    final excludedOwners = <String>{
      targetWord.toLowerCase(),
      ...target.synonymsList.map((s) => s.trim().toLowerCase()),
    };

    bool isGoodDefinition(String def, String ownerWord) {
      final d = def.trim();
      if (d.length < 20) return false;
      if (d.endsWith(':')) return false;
      if (excludedOwners.contains(ownerWord.trim().toLowerCase())) return false;
      final containsTarget = RegExp(
        r'\b' + RegExp.escape(targetWord) + r'\b',
        caseSensitive: false,
      ).hasMatch(d);
      return !containsTarget;
    }

    final pool = <String>[];

    // المرحلة الأولى: تعريفات من كلمات أخرى بنفس partOfSpeech.
    final samePos = allWords.where((w) =>
        w.id != target.id &&
        target.partOfSpeech != null &&
        w.partOfSpeech != null &&
        w.partOfSpeech!.toLowerCase() == target.partOfSpeech!.toLowerCase());
    for (final w in samePos) {
      for (final d in w.definitionsList) {
        if (isGoodDefinition(d, w.word)) pool.add(d);
      }
    }

    // المرحلة الثانية: بقية الكلمات المحفوظة.
    if (pool.length < count) {
      for (final w in allWords) {
        if (w.id == target.id) continue;
        for (final d in w.definitionsList) {
          if (isGoodDefinition(d, w.word)) pool.add(d);
        }
      }
    }

    // المرحلة الثالثة: تعريفات إضافية من قواميس مخزّنة مؤقتاً إن وُجدت.
    if (pool.length < count) {
      for (final dict in cachedDictionaries) {
        for (final meaning in dict.meanings) {
          for (final def in meaning.definitions) {
            if (isGoodDefinition(def.definition, dict.word)) {
              pool.add(def.definition);
            }
          }
        }
      }
    }

    return uniqueClean(pool).take(count).toList();
  }

  // ==================== أدوات مساعدة عامة ====================

  /// مسافة Levenshtein بين نصّين (عدد التحويلات الأدنى)، غير حسّاسة لحالة الأحرف.
  static int levenshtein(String a, String b) {
    final s = a.trim().toLowerCase();
    final t = b.trim().toLowerCase();
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    var prev = List<int>.generate(t.length + 1, (i) => i);
    for (var i = 1; i <= s.length; i++) {
      final current = List<int>.filled(t.length + 1, 0);
      current[0] = i;
      for (var j = 1; j <= t.length; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        current[j] = [
          current[j - 1] + 1, // إدراج
          prev[j] + 1, // حذف
          prev[j - 1] + cost, // استبدال
        ].reduce(min);
      }
      prev = current;
    }
    return prev[t.length];
  }

  /// هل الكلمتان من نفس العائلة (نفس الجذر بعد التحليل الصرفي)؟
  /// يُستخدم لمنع استعمال تصريفات نفس الكلمة كبدائل خاطئة في أسئلة المعنى.
  static bool isSameWordFamily(String a, String b, DictionaryResult? dictionary) {
    final wa = a.trim().toLowerCase();
    final wb = b.trim().toLowerCase();
    if (wa.isEmpty || wb.isEmpty) return false;
    if (wa == wb) return true;

    final rootA = LemmatizationService.analyze(wa).rootWord;
    final rootB = LemmatizationService.analyze(wb).rootWord;
    if (rootA == rootB) return true;
    if (rootA == wb || rootB == wa) return true;

    // احتياط إضافي عبر بيانات القاموس الحيّة إن توفرت وقت الإضافة.
    final dictRoot = dictionary?.rootWord?.toLowerCase();
    if (dictionary != null && dictRoot != null) {
      final dictWord = dictionary.word.toLowerCase();
      if ((dictWord == wa && dictRoot == wb) || (dictWord == wb && dictRoot == wa)) {
        return true;
      }
    }
    return false;
  }

  /// تنظيف قائمة نصوص: إزالة الفراغات الزائدة، الفراغات الكاملة، التكرارات
  /// (غير حسّاسة لحالة الأحرف)، واستبعاد نص معيّن إن طُلب.
  static List<String> uniqueClean(List<String> items, {String? exclude}) {
    final seen = <String>{};
    final result = <String>[];
    final excludeNorm = exclude?.trim().toLowerCase();
    for (final raw in items) {
      final v = raw.trim();
      if (v.isEmpty) continue;
      final norm = v.toLowerCase();
      if (excludeNorm != null && norm == excludeNorm) continue;
      if (!seen.add(norm)) continue;
      result.add(v);
    }
    return result;
  }

  /// إكمال قائمة مختارة حتى العدد المطلوب من مجموعة أوسع (fallback)،
  /// مع تمييزها ضمنياً كـ"بدائل مؤقتة أقل دقة" (تُستدعى فقط عند عدم كفاية
  /// البدائل الدقيقة الأولى).
  static List<String> fillWithFallback({
    required List<String> chosen,
    required int needed,
    required List<String> broaderPool,
    String? exclude,
  }) {
    if (chosen.length >= needed) return chosen.take(needed).toList();
    final result = [...chosen];
    final seen = result.map((e) => e.toLowerCase()).toSet();
    final excludeNorm = exclude?.trim().toLowerCase();
    final shuffled = [...broaderPool]..shuffle(_rng);
    for (final raw in shuffled) {
      if (result.length >= needed) break;
      final v = raw.trim();
      if (v.isEmpty) continue;
      final norm = v.toLowerCase();
      if (excludeNorm != null && norm == excludeNorm) continue;
      if (!seen.add(norm)) continue;
      result.add(v);
    }
    return result;
  }
}
