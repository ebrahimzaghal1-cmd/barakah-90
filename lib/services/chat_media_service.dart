import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'chat_video_controller.dart';
import 'media_upload_service.dart';

bool isTrustedChatMediaUrl(String value) {
  final uri = Uri.tryParse(value);
  return value.length <= 2048 &&
      uri != null &&
      uri.scheme == 'https' &&
      uri.host == 'ik.imagekit.io' &&
      uri.userInfo.isEmpty &&
      !uri.hasPort &&
      !uri.hasQuery &&
      !uri.hasFragment &&
      uri.path.length > 1;
}

/// Optional fields stay absent for old text-only clients and messages.
Map<String, String> chatMediaFields({
  String? imageUrl,
  String? videoUrl,
  String? mediaType,
}) {
  final image = imageUrl?.trim() ?? '';
  final video = videoUrl?.trim() ?? '';
  final type = mediaType?.trim() ?? '';
  if (image.isEmpty && video.isEmpty) {
    if (type.isNotEmpty) throw StateError('اختر صورة أو فيديو أولاً.');
    return {};
  }
  if (image.isNotEmpty && video.isNotEmpty) {
    throw StateError('يمكن إرفاق صورة واحدة أو فيديو واحد في الرسالة.');
  }
  final expected = image.isNotEmpty ? 'image' : 'video';
  if (type.isNotEmpty && type != expected) {
    throw StateError('نوع المرفق لا يطابق الملف.');
  }
  if (!isTrustedChatMediaUrl(image.isNotEmpty ? image : video)) {
    throw StateError('رابط المرفق غير صالح. أعد رفع الملف من بركة.');
  }
  return {
    if (image.isNotEmpty) 'imageUrl': image,
    if (video.isNotEmpty) 'videoUrl': video,
    'mediaType': expected,
  };
}

Map<String, String> chatMessageFields(
  String text, {
  String? imageUrl,
  String? videoUrl,
  String? mediaType,
}) {
  final message = text.trim();
  final media = chatMediaFields(
    imageUrl: imageUrl,
    videoUrl: videoUrl,
    mediaType: mediaType,
  );
  if (message.isEmpty && media.isEmpty) {
    throw StateError('اكتب رسالة أو اختر صورة أو فيديو.');
  }
  if (message.length > 4000) {
    throw StateError('يجب ألا تتجاوز الرسالة 4000 حرف.');
  }
  return {'text': message, ...media};
}

typedef ChatMediaUploader = Future<String> Function(XFile file,
    {required bool isVideo});
typedef ChatVideoDuration = Future<Duration> Function(XFile file);

/// Keeps the uploaded URL after a failed message send, so retrying does not
/// upload the same attachment a second time.
class ChatMediaDraft extends ChangeNotifier {
  ChatMediaDraft({
    ImagePicker? picker,
    ChatMediaUploader? uploader,
    ChatVideoDuration? videoDuration,
  })  : _picker = picker ?? ImagePicker(),
        _uploader = uploader ?? MediaUploadService().upload,
        _videoDuration = videoDuration ?? _readVideoDuration;

  static const maxImageBytes = 10 * 1024 * 1024;
  static const maxVideoBytes = 50 * 1024 * 1024;
  static const maxVideoDuration = Duration(seconds: 30);
  final ImagePicker _picker;
  final ChatMediaUploader _uploader;
  final ChatVideoDuration _videoDuration;
  XFile? _file;
  Uint8List? _imageBytes;
  bool _isVideo = false;
  bool _busy = false;
  bool _disposed = false;
  Map<String, String>? _uploaded;

  XFile? get file => _file;
  Uint8List? get imageBytes => _imageBytes;
  bool get isVideo => _isVideo;
  bool get hasAttachment => _file != null;
  bool get isBusy => _busy;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> pick({required bool isVideo}) async {
    if (_busy || _disposed) return;
    _busy = true;
    _notify();
    try {
      final file = isVideo
          ? await _picker.pickVideo(
              source: ImageSource.gallery, maxDuration: maxVideoDuration)
          : await _picker.pickImage(source: ImageSource.gallery);
      if (file != null && !_disposed) {
        await _select(file, isVideo: isVideo);
      }
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> selectFile(XFile file, {required bool isVideo}) async {
    if (_busy || _disposed) return;
    _busy = true;
    _notify();
    try {
      await _select(file, isVideo: isVideo);
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> _select(XFile file, {required bool isVideo}) async {
    final extension = file.name.split('.').last.toLowerCase();
    final allowed = isVideo
        ? const {'mp4', 'mov', 'm4v'}
        : const {'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'};
    if (!allowed.contains(extension)) {
      throw StateError(isVideo
          ? 'اختر فيديو بصيغة MP4 أو MOV أو M4V.'
          : 'اختر صورة بصيغة JPG أو PNG أو WebP أو HEIC.');
    }
    final size = await file.length();
    if (size <= 0) throw StateError('الملف المختار فارغ.');
    if (size > (isVideo ? maxVideoBytes : maxImageBytes)) {
      throw StateError(isVideo
          ? 'حجم الفيديو يجب ألا يتجاوز 50 ميغابايت.'
          : 'حجم الصورة يجب ألا يتجاوز 10 ميغابايت.');
    }
    if (isVideo) {
      final duration = await _videoDuration(file);
      if (duration <= Duration.zero || duration > maxVideoDuration) {
        throw StateError('اختر فيديو مدته 30 ثانية أو أقل.');
      }
    }
    final bytes = isVideo ? null : await file.readAsBytes();
    if (_disposed) return;
    _file = file;
    _isVideo = isVideo;
    _imageBytes = bytes;
    _uploaded = null;
  }

  Future<Map<String, String>> upload() async {
    if (_disposed) throw StateError('أُغلقت المحادثة.');
    if (_busy) throw StateError('انتظر حتى يجهز المرفق.');
    final file = _file;
    if (file == null) return {};
    if (_uploaded != null) return Map.of(_uploaded!);
    _busy = true;
    _notify();
    try {
      final url = await _uploader(file, isVideo: _isVideo);
      final fields = chatMediaFields(
        imageUrl: _isVideo ? null : url,
        videoUrl: _isVideo ? url : null,
      );
      if (!_disposed) _uploaded = fields;
      return Map.of(fields);
    } finally {
      _busy = false;
      _notify();
    }
  }

  void clear() {
    if (_busy || _disposed) return;
    _file = null;
    _imageBytes = null;
    _uploaded = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _file = null;
    _imageBytes = null;
    super.dispose();
  }

  static Future<Duration> _readVideoDuration(XFile file) async {
    final controller = localChatVideoController(file.path);
    try {
      await controller.initialize().timeout(const Duration(seconds: 20));
      return controller.value.duration;
    } catch (_) {
      throw StateError('تعذر قراءة الفيديو. اختر ملفاً آخر بصيغة مدعومة.');
    } finally {
      await controller.dispose();
    }
  }
}
