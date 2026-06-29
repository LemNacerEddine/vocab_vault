import 'dart:convert';
import 'package:http/http.dart' as http;

/// نتيجة صورة من Unsplash
class UnsplashImage {
  final String id;
  final String smallUrl; // صورة صغيرة للعرض
  final String regularUrl; // صورة بحجم متوسط
  final String description;
  final String photographerName;

  UnsplashImage({
    required this.id,
    required this.smallUrl,
    required this.regularUrl,
    required this.description,
    required this.photographerName,
  });
}

/// خدمة Unsplash - لجلب صور توضيحية للكلمات
class UnsplashService {
  static const String _baseUrl = 'https://api.unsplash.com/search/photos';
  static const String _accessKey =
      'LhLJZjndZu8lzJu937h2V4T4R3V19knwFiLWoBxmipM';

  /// البحث عن صور مرتبطة بالكلمة
  /// يُرجع قائمة من الصور (حتى 3 صور)
  static Future<List<UnsplashImage>> searchImages(String query,
      {int perPage = 3}) async {
    try {
      final url = Uri.parse(
          '$_baseUrl?query=${Uri.encodeComponent(query)}&per_page=$perPage&client_id=$_accessKey');

      final response = await http.get(url).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _parseResponse(data);
      } else {
        print('Unsplash API Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Unsplash Service Error: $e');
      return [];
    }
  }

  /// تحليل استجابة API واستخراج الصور
  static List<UnsplashImage> _parseResponse(Map<String, dynamic> data) {
    final results = data['results'] as List<dynamic>? ?? [];
    final images = <UnsplashImage>[];

    for (final result in results) {
      if (result is Map<String, dynamic>) {
        final urls = result['urls'] as Map<String, dynamic>?;
        final user = result['user'] as Map<String, dynamic>?;

        if (urls != null) {
          images.add(UnsplashImage(
            id: result['id'] as String? ?? '',
            smallUrl: urls['small'] as String? ?? '',
            regularUrl: urls['regular'] as String? ?? '',
            description: result['alt_description'] as String? ??
                result['description'] as String? ??
                '',
            photographerName: user?['name'] as String? ?? 'Unknown',
          ));
        }
      }
    }

    return images;
  }
}
