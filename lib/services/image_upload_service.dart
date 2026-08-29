import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Uploads images selected on the device to the Barakah media service.
class ImageUploadService {
  ImageUploadService({http.Client? client}) : _client = client ?? http.Client();

  static const _endpoint =
      'https://barakah-90-production-384c.up.railway.app/upload';
  final http.Client _client;

  Future<String> upload(File image) async {
    final request = http.MultipartRequest('POST', Uri.parse(_endpoint));
    request.files.add(await http.MultipartFile.fromPath(
      'image',
      image.path,
      contentType: MediaType('image', _extension(image.path)),
    ));

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ImageUploadException(
          'تعذر رفع الصورة. رمز الخادم: ${response.statusCode}');
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw ImageUploadException('استجابة خادم الصور غير صالحة.');
    }
    final url = body['url']?.toString();
    if (url == null || url.isEmpty || !Uri.tryParse(url)!.hasScheme) {
      throw ImageUploadException('لم يُرجع خادم الصور رابطًا صالحًا.');
    }
    return url;
  }

  String _extension(String path) {
    final extension = path.split('.').last.toLowerCase();
    return switch (extension) {
      'png' => 'png',
      'webp' => 'webp',
      'heic' => 'heic',
      _ => 'jpeg',
    };
  }
}

class ImageUploadException implements Exception {
  const ImageUploadException(this.message);
  final String message;

  @override
  String toString() => message;
}
