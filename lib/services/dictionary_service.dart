import 'dart:convert';
import 'package:http/http.dart' as http;

/// نتيجة البحث في القاموس
class DictionaryResult {
  final String word;
  final String? definition;
  final String? example;
  final String? phonetic;
  final String? audioUrl;
  final String? partOfSpeech;

  DictionaryResult({
    required this.word,
    this.definition,
    this.example,
    this.phonetic,
    this.audioUrl,
    this.partOfSpeech,
  });
}

/// خدمة القاموس - تستخدم Free Dictionary API
class DictionaryService {
  static const String _baseUrl =
      'https://api.dictionaryapi.dev/api/v2/entries/english';

  /// البحث عن كلمة في القاموس
  /// يُرجع DictionaryResult إذا وُجدت الكلمة، أو null إذا لم تُوجد
  static Future<DictionaryResult?> lookupWord(String word) async {
    try {
      final url = Uri.parse('$_baseUrl/${word.trim().toLowerCase()}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return _parseResponse(data);
      } else if (response.statusCode == 404) {
        // الكلمة غير موجودة في القاموس
        return null;
      } else {
        // خطأ في الخادم
        return null;
      }
    } catch (e) {
      // خطأ في الاتصال (لا يوجد إنترنت مثلاً)
      return null;
    }
  }

  /// تحليل استجابة API واستخراج البيانات المطلوبة
  static DictionaryResult _parseResponse(List<dynamic> data) {
    final entry = data[0] as Map<String, dynamic>;

    // استخراج الكلمة
    final word = entry['word'] as String;

    // استخراج النطق الصوتي (phonetic)
    String? phonetic;
    String? audioUrl;

    if (entry.containsKey('phonetics') && entry['phonetics'] is List) {
      final phonetics = entry['phonetics'] as List;
      for (final p in phonetics) {
        if (p is Map<String, dynamic>) {
          // أخذ أول phonetic text متوفر
          if (phonetic == null && p['text'] != null && p['text'].toString().isNotEmpty) {
            phonetic = p['text'] as String;
          }
          // أخذ أول audio URL متوفر
          if (audioUrl == null && p['audio'] != null && p['audio'].toString().isNotEmpty) {
            audioUrl = p['audio'] as String;
          }
        }
      }
    }

    // إذا لم نجد phonetic من القائمة، نأخذه من الحقل المباشر
    if (phonetic == null && entry.containsKey('phonetic') && entry['phonetic'] != null) {
      phonetic = entry['phonetic'] as String;
    }

    // استخراج المعنى والمثال ونوع الكلمة
    String? definition;
    String? example;
    String? partOfSpeech;

    if (entry.containsKey('meanings') && entry['meanings'] is List) {
      final meanings = entry['meanings'] as List;
      if (meanings.isNotEmpty) {
        final firstMeaning = meanings[0] as Map<String, dynamic>;

        // نوع الكلمة
        partOfSpeech = firstMeaning['partOfSpeech'] as String?;

        // التعريف والمثال
        if (firstMeaning.containsKey('definitions') &&
            firstMeaning['definitions'] is List) {
          final definitions = firstMeaning['definitions'] as List;
          if (definitions.isNotEmpty) {
            final firstDef = definitions[0] as Map<String, dynamic>;
            definition = firstDef['definition'] as String?;
            example = firstDef['example'] as String?;
          }

          // إذا لم يكن هناك مثال في التعريف الأول، نبحث في البقية
          if (example == null) {
            for (final def in definitions) {
              if (def is Map<String, dynamic> &&
                  def['example'] != null &&
                  def['example'].toString().isNotEmpty) {
                example = def['example'] as String;
                break;
              }
            }
          }
        }
      }
    }

    return DictionaryResult(
      word: word,
      definition: definition,
      example: example,
      phonetic: phonetic,
      audioUrl: audioUrl,
      partOfSpeech: partOfSpeech,
    );
  }
}
