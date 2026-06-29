import 'dart:convert';
import 'package:http/http.dart' as http;

/// خدمة الترجمة التلقائية - تستخدم Google Translate (مجاني)
class TranslationService {
  /// ترجمة نص من الإنجليزية إلى العربية
  static Future<String?> translateToArabic(String text) async {
    try {
      final url = Uri.parse(
        'https://translate.googleapis.com/translate_a/single'
        '?client=gtx'
        '&sl=en'
        '&tl=ar'
        '&dt=t'
        '&q=${Uri.encodeComponent(text)}',
      );

      final response = await http.get(url).timeout(
            const Duration(seconds: 8),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty && data[0] is List) {
          final translations = data[0] as List;
          final buffer = StringBuffer();
          for (final t in translations) {
            if (t is List && t.isNotEmpty && t[0] is String) {
              buffer.write(t[0]);
            }
          }
          final result = buffer.toString().trim();
          return result.isNotEmpty ? result : null;
        }
      }
      return null;
    } catch (e) {
      print('TranslationService Error: $e');
      return null;
    }
  }
}
