import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/word.dart';
import '../models/quiz_pack.dart';

/// خدمة الذكاء الاصطناعي (Claude) لتوليد حزمة اختبار لكل كلمة.
///
/// تُستدعى مرة واحدة عند إضافة الكلمة (أو عند الطلب لاحقاً)، وتُخزَّن نتيجتها
/// محلياً فتعمل الاختبارات بعدها بدون إنترنت (offline-first).
///
/// ⚠️ ملاحظة أمان: المفتاح يُمرَّر وقت البناء عبر:
///   flutter run --dart-define=CLAUDE_API_KEY=sk-ant-...
/// هذا مناسب للتطوير والاستخدام الشخصي فقط. تطبيقات الموبايل قابلة لفكّ
/// التجميع، لذا **للنشر العام** يجب استبدال هذا باستدعاء خادم وسيط (proxy)
/// يحمل المفتاح من جهة الخادم بدل تضمينه في التطبيق.
class ClaudeService {
  static const String _apiKey = String.fromEnvironment('CLAUDE_API_KEY');
  static const String _endpoint = 'https://api.anthropic.com/v1/messages';
  static const String _model = 'claude-opus-4-8';

  /// هل الميزة مفعّلة؟ (وُجد مفتاح).
  static bool get isEnabled => _apiKey.isNotEmpty;

  /// مخطّط JSON للمخرجات المنظّمة (يضمن ردّاً قابلاً للتحليل).
  static const Map<String, dynamic> _schema = {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'distractorTranslations': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'distractorDefinitions': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'distractorWords': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'clozeSentence': {'type': 'string'},
      'clozeTranslationAr': {'type': 'string'},
      'hintAr': {'type': 'string'},
    },
    'required': [
      'distractorTranslations',
      'distractorDefinitions',
      'distractorWords',
      'clozeSentence',
      'clozeTranslationAr',
      'hintAr',
    ],
  };

  /// توليد حزمة اختبار لكلمة. يرجع `null` عند غياب المفتاح أو أي فشل
  /// (فيعمل المحرّك بـ fallback محلي).
  static Future<QuizPack?> generateQuizPack(Word word) async {
    if (!isEnabled) return null;

    try {
      final prompt = _buildPrompt(word);
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'x-api-key': _apiKey,
              'anthropic-version': '2023-06-01',
              'content-type': 'application/json',
            },
            body: json.encode({
              'model': _model,
              'max_tokens': 1500,
              'output_config': {
                'format': {
                  'type': 'json_schema',
                  'schema': _schema,
                },
              },
              'messages': [
                {'role': 'user', 'content': prompt},
              ],
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        print('ClaudeService HTTP ${response.statusCode}: ${response.body}');
        return null;
      }

      final data = json.decode(utf8.decode(response.bodyBytes));

      // رفض من مُصنِّفات الأمان (نادر لكلمات المفردات) → لا محتوى.
      if (data['stop_reason'] == 'refusal') return null;

      final content = data['content'];
      if (content is! List) return null;

      // أول كتلة نصية تحوي JSON المنظّم.
      String? jsonText;
      for (final block in content) {
        if (block is Map && block['type'] == 'text') {
          jsonText = block['text'] as String?;
          break;
        }
      }
      if (jsonText == null || jsonText.trim().isEmpty) return null;

      final parsed = json.decode(_stripFences(jsonText));
      if (parsed is Map<String, dynamic>) {
        return QuizPack.fromJson(parsed);
      }
      return null;
    } catch (e) {
      print('ClaudeService Error: $e');
      return null;
    }
  }

  static String _buildPrompt(Word word) {
    final pos = word.partOfSpeech ?? 'unknown';
    final definition = word.definition ?? '';
    return '''
You generate quiz material for an Arabic speaker learning English vocabulary.

Target word: "${word.word}"
Part of speech: $pos
Correct Arabic meaning: "${word.translation}"
English definition: "$definition"

Produce challenging but fair quiz material as JSON with these fields:
- distractorTranslations: 3 Arabic translations that are PLAUSIBLE but WRONG for this word (close in topic/meaning so they are tricky — not random unrelated words).
- distractorDefinitions: 3 English definitions that are plausible but WRONG for this word.
- distractorWords: 3 real English words similar in spelling or meaning to "${word.word}" but with a different meaning (good confusable distractors).
- clozeSentence: one natural English sentence that uses the exact word "${word.word}" (so it can be blanked out for a fill-in-the-blank question).
- clozeTranslationAr: the Arabic translation of that sentence.
- hintAr: a short Arabic hint about the word's meaning WITHOUT revealing the translation directly.

Return only the JSON object.''';
  }

  /// إزالة أسوار ```json إن وُجدت (احتياط).
  static String _stripFences(String text) {
    var t = text.trim();
    if (t.startsWith('```')) {
      t = t.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
      if (t.endsWith('```')) {
        t = t.substring(0, t.length - 3);
      }
    }
    return t.trim();
  }
}
