import 'dart:io';

import 'package:image_picker/image_picker.dart';

import 'media_upload_service.dart';

/// Uploads images selected on the device to the Barakah media service.
class ImageUploadService {
  ImageUploadService();

  Future<String> upload(File image) async {
    try {
      return await MediaUploadService().upload(
        XFile(image.path),
        isVideo: false,
      );
    } catch (error) {
      throw ImageUploadException('تعذر رفع الصورة: $error');
    }
  }
}

class ImageUploadException implements Exception {
  const ImageUploadException(this.message);
  final String message;

  @override
  String toString() => message;
}
