import 'dart:convert';
import 'package:http/http.dart' as http;
import 'lemmatization_service.dart';

/// تعريف واحد للكلمة
class WordDefinition {
  final String definition;
  final String? example;

  WordDefinition({required this.definition, this.example});
}

/// معنى واحد (يحتوي على نوع الكلمة + عدة تعريفات)
class WordMeaning {
  final String partOfSpeech;
  final List<WordDefinition> definitions;
  final List<String> synonyms;
  final List<String> antonyms;

  WordMeaning({
    required this.partOfSpeech,
    required this.definitions,
    required this.synonyms,
    required this.antonyms,
  });
}

/// نتيجة البحث الكاملة في القاموس
class DictionaryResult {
  final String word;           // الكلمة كما أدخلها المستخدم
  final String? rootWord;      // الكلمة الجذر (المفرد/المصدر) إن وجدت
  final bool isModifiedForm;   // هل الكلمة جمع أو متصرفة؟
  final String? formTypeLabel; // وصف نوع التصريف (صيغة الجمع، فعل ماضٍ...)
  final String? phonetic;
  final String? audioUrl;
  final List<WordMeaning> meanings;
  final List<String> allSynonyms;
  final List<String> allAntonyms;
  // أمثلة الكلمة المُدخلة (الجمع مثلاً)
  final List<String> inputFormExamples;

  DictionaryResult({
    required this.word,
    this.rootWord,
    this.isModifiedForm = false,
    this.formTypeLabel,
    this.phonetic,
    this.audioUrl,
    required this.meanings,
    required this.allSynonyms,
    required this.allAntonyms,
    this.inputFormExamples = const [],
  });

  /// أول تعريف متوفر
  String? get firstDefinition {
    for (final meaning in meanings) {
      if (meaning.definitions.isNotEmpty) {
        return meaning.definitions[0].definition;
      }
    }
    return null;
  }

  /// أول مثال متوفر
  String? get firstExample {
    for (final meaning in meanings) {
      for (final def in meaning.definitions) {
        if (def.example != null && def.example!.isNotEmpty) {
          return def.example;
        }
      }
    }
    return null;
  }

  /// أول نوع كلمة متوفر
  String? get firstPartOfSpeech {
    if (meanings.isNotEmpty) return meanings[0].partOfSpeech;
    return null;
  }

  /// جميع الأمثلة (من الجذر + من الصيغة المُدخلة)
  List<String> get allExamples {
    final examples = <String>[];
    // أمثلة من الجذر
    for (final meaning in meanings) {
      for (final def in meaning.definitions) {
        if (def.example != null && def.example!.isNotEmpty) {
          examples.add(def.example!);
        }
      }
    }
    // أمثلة من الصيغة المُدخلة (الجمع مثلاً)
    for (final ex in inputFormExamples) {
      if (!examples.contains(ex)) examples.add(ex);
    }
    return examples;
  }

  /// جميع التعريفات كنص واحد
  String get allDefinitionsText {
    final defs = <String>[];
    for (final meaning in meanings) {
      for (final def in meaning.definitions) {
        defs.add(def.definition);
      }
    }
    return defs.join('\n');
  }
}

// =============================================================
// خدمة القاموس - تستخدم Free Dictionary API
// URL: https://api.dictionaryapi.dev/api/v2/entries/en/<word>
// =============================================================
class DictionaryService {
  static const String _baseUrl =
      'https://api.dictionaryapi.dev/api/v2/entries/en';

  /// البحث الذكي عن كلمة:
  /// 1. يحاول البحث بالكلمة كما هي
  /// 2. إذا فشل، يكتشف الجذر (مفرد/مصدر) ويبحث عنه
  /// 3. يدمج أمثلة الصيغتين معاً
  static Future<DictionaryResult?> lookupWord(String word) async {
    final cleanWord = word.trim().toLowerCase();

    // أولاً: حاول البحث بالكلمة كما هي
    final directResult = await _fetchWord(cleanWord);

    if (directResult != null) {
      // الكلمة وُجدت مباشرة - تحقق إذا كانت جمعاً أو متصرفة
      final lemma = LemmatizationService.analyze(cleanWord);
      if (lemma.isModified && lemma.rootWord != cleanWord) {
        // الكلمة موجودة لكنها جمع أو متصرفة - نضيف معلومات الجذر
        final rootResult = await _fetchWord(lemma.rootWord);
        if (rootResult != null) {
          return _mergeResults(
            inputWord: cleanWord,
            inputResult: directResult,
            rootResult: rootResult,
            lemma: lemma,
          );
        }
        // إذا لم يوجد الجذر، أعد النتيجة المباشرة مع تمييز الصيغة
        return DictionaryResult(
          word: cleanWord,
          rootWord: lemma.rootWord,
          isModifiedForm: true,
          formTypeLabel: lemma.formTypeDescription,
          phonetic: directResult.phonetic,
          audioUrl: directResult.audioUrl,
          meanings: directResult.meanings,
          allSynonyms: directResult.allSynonyms,
          allAntonyms: directResult.allAntonyms,
        );
      }
      return directResult;
    }

    // ثانياً: الكلمة لم توجد - حاول إيجاد الجذر
    final lemma = LemmatizationService.analyze(cleanWord);
    if (lemma.isModified) {
      // جرب الجذر الأول
      final rootResult = await _fetchWord(lemma.rootWord);
      if (rootResult != null) {
        return DictionaryResult(
          word: cleanWord,
          rootWord: lemma.rootWord,
          isModifiedForm: true,
          formTypeLabel: lemma.formTypeDescription,
          phonetic: rootResult.phonetic,
          audioUrl: rootResult.audioUrl,
          meanings: rootResult.meanings,
          allSynonyms: rootResult.allSynonyms,
          allAntonyms: rootResult.allAntonyms,
        );
      }

      // جرب الجذر البديل إن وجد
      if (lemma.altRoot != null) {
        final altResult = await _fetchWord(lemma.altRoot!);
        if (altResult != null) {
          return DictionaryResult(
            word: cleanWord,
            rootWord: lemma.altRoot,
            isModifiedForm: true,
            formTypeLabel: lemma.formTypeDescription,
            phonetic: altResult.phonetic,
            audioUrl: altResult.audioUrl,
            meanings: altResult.meanings,
            allSynonyms: altResult.allSynonyms,
            allAntonyms: altResult.allAntonyms,
          );
        }
      }
    }

    return null;
  }

  /// دمج نتائج الكلمة المُدخلة مع نتائج الجذر
  static DictionaryResult _mergeResults({
    required String inputWord,
    required DictionaryResult inputResult,
    required DictionaryResult rootResult,
    required LemmaResult lemma,
  }) {
    // أمثلة من الكلمة المُدخلة (الجمع مثلاً)
    final inputExamples = inputResult.allExamples;

    // دمج المرادفات والأضداد
    final mergedSynonyms = <String>{
      ...rootResult.allSynonyms,
      ...inputResult.allSynonyms,
    }.toList();
    final mergedAntonyms = <String>{
      ...rootResult.allAntonyms,
      ...inputResult.allAntonyms,
    }.toList();

    return DictionaryResult(
      word: inputWord,
      rootWord: lemma.rootWord,
      isModifiedForm: true,
      formTypeLabel: lemma.formTypeDescription,
      // الصوت والنطق من الجذر (أوضح وأكثر توفراً)
      phonetic: rootResult.phonetic ?? inputResult.phonetic,
      audioUrl: rootResult.audioUrl ?? inputResult.audioUrl,
      // المعاني من الجذر (أشمل)
      meanings: rootResult.meanings,
      allSynonyms: mergedSynonyms,
      allAntonyms: mergedAntonyms,
      // أمثلة الصيغة المُدخلة تُضاف كأمثلة إضافية
      inputFormExamples: inputExamples,
    );
  }

  /// جلب كلمة من API
  static Future<DictionaryResult?> _fetchWord(String word) async {
    try {
      final url = Uri.parse('$_baseUrl/$word');
      final response = await http.get(url).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return _parseResponse(data, word);
      }
      return null;
    } catch (e) {
      print('DictionaryService Error for "$word": $e');
      return null;
    }
  }

  /// تحليل استجابة API الكاملة
  static DictionaryResult _parseResponse(List<dynamic> data, String inputWord) {
    final entry = data[0] as Map<String, dynamic>;

    final word = entry['word'] as String? ?? inputWord;

    // استخراج النطق الصوتي
    String? phonetic;
    String? audioUrl;

    if (entry.containsKey('phonetics') && entry['phonetics'] is List) {
      final phonetics = entry['phonetics'] as List;

      // أولاً: البحث عن عنصر يحتوي على audio
      for (final p in phonetics) {
        if (p is Map<String, dynamic>) {
          if (p['audio'] != null && p['audio'].toString().isNotEmpty) {
            audioUrl = p['audio'] as String;
            if (p['text'] != null && p['text'].toString().isNotEmpty) {
              phonetic = p['text'] as String;
            }
            break;
          }
        }
      }

      // ثانياً: إذا لم نجد phonetic text، نبحث في كل العناصر
      if (phonetic == null) {
        for (final p in phonetics) {
          if (p is Map<String, dynamic>) {
            if (p['text'] != null && p['text'].toString().isNotEmpty) {
              phonetic = p['text'] as String;
              break;
            }
          }
        }
      }
    }

    // التحقق من حقل phonetic الرئيسي
    if (phonetic == null &&
        entry.containsKey('phonetic') &&
        entry['phonetic'] != null &&
        entry['phonetic'].toString().isNotEmpty) {
      phonetic = entry['phonetic'] as String;
    }

    // استخراج جميع المعاني
    final meanings = <WordMeaning>[];
    final allSynonyms = <String>{};
    final allAntonyms = <String>{};

    if (entry.containsKey('meanings') && entry['meanings'] is List) {
      final meaningsData = entry['meanings'] as List;

      for (final meaningData in meaningsData) {
        if (meaningData is Map<String, dynamic>) {
          final partOfSpeech =
              meaningData['partOfSpeech'] as String? ?? 'unknown';

          final definitions = <WordDefinition>[];
          if (meaningData.containsKey('definitions') &&
              meaningData['definitions'] is List) {
            final defsData = meaningData['definitions'] as List;
            for (final defData in defsData) {
              if (defData is Map<String, dynamic>) {
                definitions.add(WordDefinition(
                  definition: defData['definition'] as String? ?? '',
                  example: defData['example'] as String?,
                ));

                // استخراج مرادفات وأضداد على مستوى التعريف
                if (defData['synonyms'] is List) {
                  for (final s in defData['synonyms'] as List) {
                    if (s is String && s.isNotEmpty) allSynonyms.add(s);
                  }
                }
                if (defData['antonyms'] is List) {
                  for (final a in defData['antonyms'] as List) {
                    if (a is String && a.isNotEmpty) allAntonyms.add(a);
                  }
                }
              }
            }
          }

          // مرادفات وأضداد على مستوى المعنى
          final synonyms = <String>[];
          if (meaningData.containsKey('synonyms') &&
              meaningData['synonyms'] is List) {
            for (final s in meaningData['synonyms'] as List) {
              if (s is String && s.isNotEmpty) {
                synonyms.add(s);
                allSynonyms.add(s);
              }
            }
          }

          final antonyms = <String>[];
          if (meaningData.containsKey('antonyms') &&
              meaningData['antonyms'] is List) {
            for (final a in meaningData['antonyms'] as List) {
              if (a is String && a.isNotEmpty) {
                antonyms.add(a);
                allAntonyms.add(a);
              }
            }
          }

          meanings.add(WordMeaning(
            partOfSpeech: partOfSpeech,
            definitions: definitions,
            synonyms: synonyms,
            antonyms: antonyms,
          ));
        }
      }
    }

    return DictionaryResult(
      word: word,
      phonetic: phonetic,
      audioUrl: audioUrl,
      meanings: meanings,
      allSynonyms: allSynonyms.toList(),
      allAntonyms: allAntonyms.toList(),
    );
  }
}
