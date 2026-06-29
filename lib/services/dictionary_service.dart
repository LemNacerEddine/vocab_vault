import 'dart:convert';
import 'package:http/http.dart' as http;

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
  final String word;
  final String? phonetic;
  final String? audioUrl;
  final List<WordMeaning> meanings;
  final List<String> allSynonyms; // جميع المرادفات مجمعة
  final List<String> allAntonyms; // جميع الأضداد مجمعة

  DictionaryResult({
    required this.word,
    this.phonetic,
    this.audioUrl,
    required this.meanings,
    required this.allSynonyms,
    required this.allAntonyms,
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

  /// جميع الأمثلة
  List<String> get allExamples {
    final examples = <String>[];
    for (final meaning in meanings) {
      for (final def in meaning.definitions) {
        if (def.example != null && def.example!.isNotEmpty) {
          examples.add(def.example!);
        }
      }
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

  /// البحث عن كلمة في القاموس
  static Future<DictionaryResult?> lookupWord(String word) async {
    try {
      final cleanWord = word.trim().toLowerCase();
      final url = Uri.parse('$_baseUrl/$cleanWord');
      final response = await http.get(url).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return _parseResponse(data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        return null;
      }
    } catch (e) {
      print('DictionaryService Error: $e');
      return null;
    }
  }

  /// تحليل استجابة API الكاملة
  static DictionaryResult _parseResponse(List<dynamic> data) {
    final entry = data[0] as Map<String, dynamic>;

    // استخراج الكلمة
    final word = entry['word'] as String;

    // استخراج النطق الصوتي
    String? phonetic;
    String? audioUrl;

    if (entry.containsKey('phonetics') && entry['phonetics'] is List) {
      final phonetics = entry['phonetics'] as List;
      for (final p in phonetics) {
        if (p is Map<String, dynamic>) {
          if (phonetic == null &&
              p['text'] != null &&
              p['text'].toString().isNotEmpty) {
            phonetic = p['text'] as String;
          }
          if (audioUrl == null &&
              p['audio'] != null &&
              p['audio'].toString().isNotEmpty) {
            audioUrl = p['audio'] as String;
          }
        }
      }
    }

    if (phonetic == null &&
        entry.containsKey('phonetic') &&
        entry['phonetic'] != null) {
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

          // استخراج التعريفات
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
              }
            }
          }

          // استخراج المرادفات على مستوى المعنى
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

          // استخراج الأضداد على مستوى المعنى
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
