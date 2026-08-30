import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

/// يرفع الصور والفيديوهات المختارة من الجوال إلى خادم بركة الإعلامي.
class MediaUploadService {
  static const _endpoint = 'https://upload.imagekit.io/api/v1/files/upload';
  static const _authenticationEndpoint =
      'https://barakah-secure-api.ebrahimzaghal1.workers.dev/v1/media/upload-auth';

  Future<Map<String, String>> _authentication() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('سجّل الدخول أولاً لرفع الصورة');
    }
    final idToken = await user.getIdToken();
    if (idToken == null || idToken.trim().isEmpty) {
      throw Exception('انتهت جلسة الدخول. ادخل مجدداً');
    }
    final response = await http
        .post(
          Uri.parse(_authenticationEndpoint),
          headers: {
            'authorization': 'Bearer $idToken',
            'content-type': 'application/json',
          },
          body: '{}',
        )
        .timeout(const Duration(seconds: 25));
    final raw = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = raw is Map ? raw['message']?.toString().trim() : null;
      throw Exception(
        message == null || message.isEmpty
            ? 'تعذر الحصول على تصريح رفع الصورة'
            : message,
      );
    }
    if (raw is! Map) {
      throw Exception('استجابة تصريح رفع الصورة غير صالحة');
    }
    final data = Map<String, dynamic>.from(raw);
    final authentication = <String, String>{
      'token': data['token']?.toString() ?? '',
      'expire': data['expire']?.toString() ?? '',
      'signature': data['signature']?.toString() ?? '',
      'publicKey': data['publicKey']?.toString() ?? '',
    };
    if (authentication.values.any((value) => value.trim().isEmpty)) {
      throw Exception('تصريح رفع الصورة غير مكتمل');
    }
    return authentication;
  }

  Future<String> upload(XFile file, {required bool isVideo}) async {
    Object? lastError;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('الملف المختار فارغ');
    }
    final fileName = file.name.trim().isNotEmpty
        ? file.name.trim()
        : file.path.split('/').last;

    // الصور والفيديوهات تستخدم خادم ImageKit نفسه في الويب والآيفون.
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final authentication = await _authentication();
        final request = http.MultipartRequest('POST', Uri.parse(_endpoint));
        request.fields.addAll({
          ...authentication,
          'fileName': fileName,
        });
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
          contentType: _contentType(fileName, isVideo: isVideo),
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
