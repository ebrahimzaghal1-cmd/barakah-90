import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// يرفع الصور والفيديوهات المختارة من الجوال إلى خادم بركة الإعلامي.
class MediaUploadService {
  static const _endpoint =
      'https://barakah-90-production-384c.up.railway.app/upload';

  Future<String> upload(File file, {required bool isVideo}) async {
    Object? lastError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final request = http.MultipartRequest('POST', Uri.parse(_endpoint));
        request.files.add(await http.MultipartFile.fromPath(
          'image',
          file.path,
          contentType: _contentType(file.path, isVideo: isVideo),
        ));
        final streamed = await request.send().timeout(
              const Duration(seconds: 90),
            );
        final response = await http.Response.fromStream(streamed).timeout(
          const Duration(seconds: 30),
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('الخادم أعاد الرمز ${response.statusCode}');
        }
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw Exception('استجابة خادم الوسائط غير صالحة');
        }
        final url = decoded['url']?.toString().trim() ?? '';
        final uri = Uri.tryParse(url);
        if (url.isEmpty || uri == null || !uri.hasScheme) {
          throw Exception('لم يُرجع الخادم رابطاً صالحاً');
        }
        return url;
      } catch (error) {
        lastError = error;
        if (attempt < 3) {
          await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    }
    throw Exception('تعذر رفع الملف بعد 3 محاولات: $lastError');
  }

  MediaType _contentType(String path, {required bool isVideo}) {
    final extension = path.split('.').last.toLowerCase();
    if (isVideo) {
      return MediaType(
          'video',
          switch (extension) {
            'mov' => 'quicktime',
            'm4v' => 'x-m4v',
            _ => 'mp4',
          });
    }
    return MediaType(
        'image',
        switch (extension) {
          'png' => 'png',
          'webp' => 'webp',
          'heic' || 'heif' => 'heic',
          _ => 'jpeg',
        });
  }
}
