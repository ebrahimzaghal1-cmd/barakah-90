import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/media_upload_service.dart';
import '../theme/app_theme.dart';

/// لوحة بسيطة لإدارة إعلانات الصفحة الرئيسية من الجوال مباشرة.
class AdminManageAds extends StatelessWidget {
  const AdminManageAds({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('إدارة الإعلانات'), centerTitle: true),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openEditor(context),
          backgroundColor: AppTheme.deepYellow,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('إضافة إعلان'),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('ads').snapshots(),
          builder: (context, snapshot) {
            final ads = snapshot.data?.docs ?? [];
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (ads.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                      'لا توجد إعلانات بعد.\nأضف صورة أو فيديو تسويقياً من زر الإضافة.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: ads.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final ad = ads[index];
                final data = ad.data();
                final image = data['image']?.toString() ?? '';
                final isActive = data['isActive'] != false;
                return Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(.06), blurRadius: 12)
                    ],
                  ),
                  child: Row(children: [
                    SizedBox(
                      width: 112,
                      height: 108,
                      child: image.isEmpty
                          ? const ColoredBox(
                              color: AppTheme.ink,
                              child: Icon(Icons.campaign_rounded,
                                  color: AppTheme.coolYellow, size: 42))
                          : Image.network(image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const ColoredBox(
                                  color: AppTheme.ink,
                                  child: Icon(Icons.broken_image_outlined,
                                      color: Colors.white))),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  data['title']?.toString() ??
                                      'إعلان بدون عنوان',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              Text(
                                  _placementLabel(
                                      data['placement']?.toString()),
                                  style:
                                      const TextStyle(color: Colors.black54)),
                              const SizedBox(height: 5),
                              Row(children: [
                                Icon(
                                    isActive
                                        ? Icons.check_circle
                                        : Icons.pause_circle,
                                    size: 18,
                                    color: isActive
                                        ? Colors.green
                                        : Colors.orange),
                                const SizedBox(width: 4),
                                Text(isActive ? 'ظاهر الآن' : 'موقوف',
                                    style: TextStyle(
                                        color: isActive
                                            ? Colors.green
                                            : Colors.orange,
                                        fontWeight: FontWeight.w800)),
                                if ((data['video']?.toString() ?? '')
                                    .isNotEmpty) ...[
                                  const SizedBox(width: 10),
                                  const Icon(Icons.play_circle_fill_rounded,
                                      size: 18, color: AppTheme.deepYellow),
                                ],
                              ]),
                            ]),
                      ),
                    ),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        tooltip: 'تعديل',
                        onPressed: () => _openEditor(context, doc: ad),
                        icon:
                            const Icon(Icons.edit_rounded, color: Colors.blue),
                      ),
                      IconButton(
                        tooltip: 'حذف',
                        onPressed: () => _confirmDelete(context, ad),
                        icon: const Icon(Icons.delete_rounded,
                            color: Colors.redAccent),
                      ),
                    ]),
                  ]),
                );
              },
            );
          },
        ),
      );

  static String _placementLabel(String? placement) => switch (placement) {
        'restaurant' => 'الصفحة الرئيسية فقط',
        'market_top' => 'الماركت - إعلان رئيسي أعلى الصفحة',
        'market_gallery' => 'الماركت - إعلان معرض صور',
        'market_between_1' => 'الماركت - ممول بين القسم 1 و2',
        'market_between_2' => 'الماركت - ممول بين القسم 2 و3',
        'market_between_3' => 'الماركت - ممول بين القسم 3 و4',
        'market_between_4' => 'الماركت - ممول بين القسم 4 و5',
        'market_between_5' => 'الماركت - ممول بين القسم 5 و6',
        'market_between_6' => 'الماركت - ممول بين القسم 6 و7',
        'market_between_7' => 'الماركت - ممول بين القسم 7 و8',
        'restaurants_top' => 'المطاعم - إعلان رئيسي أعلى الصفحة',
        'restaurants_gallery' => 'المطاعم - إعلان معرض صور',
        'restaurants_between_1' => 'المطاعم - ممول بين القسم 1 و2',
        'restaurants_between_2' => 'المطاعم - ممول بين القسم 2 و3',
        'restaurants_between_3' => 'المطاعم - ممول بين القسم 3 و4',
        'restaurants_between_4' => 'المطاعم - ممول بين القسم 4 و5',
        'restaurants_between_5' => 'المطاعم - ممول بين القسم 5 و6',
        'restaurants_between_6' => 'المطاعم - ممول بين القسم 6 و7',
        'restaurants_between_7' => 'المطاعم - ممول بين القسم 7 و8',
        _ => 'كل الصفحات',
      };

  static Future<void> _confirmDelete(BuildContext context,
      QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الإعلان؟'),
        content:
            const Text('سيختفي الإعلان من التطبيق، ولا يحذف الملف المرفوع.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed == true) await doc.reference.delete();
  }

  static Future<void> _openEditor(BuildContext context,
      {QueryDocumentSnapshot<Map<String, dynamic>>? doc}) async {
    if (doc == null) {
      final existing = await FirebaseFirestore.instance.collection('ads').get();
      if (!context.mounted) return;
      if (existing.docs.length >= 50) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('يمكن إدارة حتى 50 إعلاناً. احذف إعلاناً قديماً أولاً.')));
        return;
      }
    }
    if (!context.mounted) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _AdEditor(existing: doc),
        ));
  }
}

class _AdEditor extends StatefulWidget {
  const _AdEditor({this.existing});
  final QueryDocumentSnapshot<Map<String, dynamic>>? existing;

  @override
  State<_AdEditor> createState() => _AdEditorState();
}

class _AdEditorState extends State<_AdEditor> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _subtitle = TextEditingController();
  final _picker = ImagePicker();
  XFile? _imageFile;
  Uint8List? _imageBytes;
  final List<XFile> _galleryFiles = [];
  final List<Uint8List> _galleryBytes = [];
  XFile? _videoFile;
  String _placement = 'restaurant';
  String _displaySize = 'large';
  String _adFormat = 'banner';
  bool _active = true;
  bool _saving = false;
  String _uploadProgress = '';

  Map<String, dynamic> get _existing => widget.existing?.data() ?? {};

  @override
  void initState() {
    super.initState();
    _title.text = _existing['title']?.toString() ?? '';
    _subtitle.text = _existing['subtitle']?.toString() ?? '';
    _placement = _existing['placement']?.toString() ?? 'restaurant';
    _displaySize = _existing['displaySize']?.toString() ?? 'large';
    _adFormat = _existing['adFormat']?.toString() ??
        (_existingGallery.isNotEmpty ? 'gallery' : 'banner');
    _active = _existing['isActive'] != false;
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 78,
      maxWidth: 1800,
      maxHeight: 1800,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) {
      setState(() {
        _imageFile = file;
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _pickGallery() async {
    final files = await _picker.pickMultiImage(
      imageQuality: 76,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (files.isEmpty || !mounted) return;
    final available = 5 - _existingGallery.length;
    final selectedFiles = files.take(available.clamp(0, 5)).toList();
    final selectedBytes = await Future.wait(
      selectedFiles.map((file) => file.readAsBytes()),
    );
    if (!mounted) return;
    setState(() {
      _galleryFiles
        ..clear()
        ..addAll(selectedFiles);
      _galleryBytes
        ..clear()
        ..addAll(selectedBytes);
    });
    if (files.length > available && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('يمكن إضافة خمس صور مصغرة كحد أقصى لكل إعلان.')));
    }
  }

  List<String> get _existingGallery =>
      (_existing['gallery'] as List?)
          ?.map((item) => item.toString())
          .where((url) => url.isNotEmpty)
          .take(5)
          .toList() ??
      const [];

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 30),
    );
    if (file != null && mounted) setState(() => _videoFile = file);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final hasExistingMedia =
        (_existing['image']?.toString() ?? '').isNotEmpty ||
            (_existing['video']?.toString() ?? '').isNotEmpty ||
            _existingGallery.isNotEmpty;
    if (!hasExistingMedia &&
        _imageFile == null &&
        _videoFile == null &&
        _galleryFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('اختاري صورة واحدة على الأقل أو فيديو للإعلان.'),
      ));
      return;
    }
    if (_adFormat == 'gallery') {
      final galleryImageCount =
          (_existing['image']?.toString().isNotEmpty == true ? 1 : 0) +
              _existingGallery.length +
              (_imageFile == null ? 0 : 1) +
              _galleryFiles.length;
      if (galleryImageCount < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'إعلان معرض الصور يحتاج صورة رئيسية وصورة مصغرة واحدة على الأقل.',
            ),
          ),
        );
        return;
      }
    }
    setState(() {
      _saving = true;
      _uploadProgress = 'نجهّز الإعلان...';
    });
    try {
      var image = _existing['image']?.toString() ?? '';
      var video = _existing['video']?.toString() ?? '';
      final gallery = [..._existingGallery];
      if (_imageFile != null) {
        if (mounted) {
          setState(() => _uploadProgress = 'نرفع الصورة الرئيسية...');
        }
        image = await MediaUploadService().upload(_imageFile!, isVideo: false);
      }
      for (var index = 0; index < _galleryFiles.length; index++) {
        if (gallery.length >= 5) break;
        if (mounted) {
          setState(() => _uploadProgress =
              'نرفع الصورة ${index + 1} من ${_galleryFiles.length}...');
        }
        gallery.add(await MediaUploadService()
            .upload(_galleryFiles[index], isVideo: false));
      }
      if (image.isEmpty && gallery.isNotEmpty) image = gallery.first;
      if (_videoFile != null) {
        if (mounted) setState(() => _uploadProgress = 'نرفع الفيديو...');
        video = await MediaUploadService().upload(_videoFile!, isVideo: true);
      }
      if (mounted) setState(() => _uploadProgress = 'نحفظ الإعلان...');
      final data = <String, dynamic>{
        'title': _title.text.trim(),
        'subtitle': _subtitle.text.trim(),
        'placement': _placement,
        'displaySize': _displaySize,
        'adFormat': _adFormat,
        'isActive': _active,
        'image': image,
        'gallery': gallery,
        'showInFeed': _adFormat == 'gallery',
        'video': video,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (widget.existing == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('ads').add(data);
      } else {
        await widget.existing!.reference.update(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        final message = error.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تعذر حفظ الإعلان: $message'),
          duration: const Duration(seconds: 6),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingImage = _existing['image']?.toString() ?? '';
    final existingVideo = _existing['video']?.toString() ?? '';
    return Scaffold(
      appBar: AppBar(
          title:
              Text(widget.existing == null ? 'إضافة إعلان' : 'تعديل الإعلان')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            const Text(
                'أضيفي الإعلان من هنا بدون تعديل الكود: صورة، فيديو حتى 30 ثانية، صور مصغرة، ومكان ظهور مستقل داخل الماركت.',
                style: TextStyle(color: Colors.black54, height: 1.5)),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _adFormat,
              decoration: const InputDecoration(labelText: 'شكل الإعلان'),
              items: const [
                DropdownMenuItem(
                  value: 'banner',
                  child: Text('إعلان عادي / متحرك'),
                ),
                DropdownMenuItem(
                  value: 'gallery',
                  child: Text('معرض صور — صورة كبيرة وصور مصغرة'),
                ),
              ],
              onChanged: (value) => setState(() {
                _adFormat = value ?? 'banner';
                if (_adFormat == 'gallery' &&
                    _placement != 'market_gallery' &&
                    _placement != 'restaurants_gallery') {
                  _placement = 'market_gallery';
                }
              }),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'عنوان الإعلان'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'اكتب عنوان الإعلان'
                  : null,
            ),
            const SizedBox(height: 14),
            TextField(
                controller: _subtitle,
                decoration:
                    const InputDecoration(labelText: 'وصف قصير (اختياري)')),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _placement,
              decoration: const InputDecoration(labelText: 'مكان ظهور الإعلان'),
              items: const [
                DropdownMenuItem(
                    value: 'restaurant', child: Text('الصفحة الرئيسية فقط')),
                DropdownMenuItem(
                    value: 'market_top',
                    child: Text('الماركت - إعلان رئيسي كبير أعلى الصفحة')),
                DropdownMenuItem(
                    value: 'market_gallery',
                    child: Text('الماركت - معرض صور كبير')),
                DropdownMenuItem(
                    value: 'market_between_1',
                    child: Text('الماركت - ممول بين القسم 1 و2')),
                DropdownMenuItem(
                    value: 'market_between_2',
                    child: Text('الماركت - ممول بين القسم 2 و3')),
                DropdownMenuItem(
                    value: 'market_between_3',
                    child: Text('الماركت - ممول بين القسم 3 و4')),
                DropdownMenuItem(
                    value: 'market_between_4',
                    child: Text('الماركت - ممول بين القسم 4 و5')),
                DropdownMenuItem(
                    value: 'market_between_5',
                    child: Text('الماركت - ممول بين القسم 5 و6')),
                DropdownMenuItem(
                    value: 'market_between_6',
                    child: Text('الماركت - ممول بين القسم 6 و7')),
                DropdownMenuItem(
                    value: 'market_between_7',
                    child: Text('الماركت - ممول بين القسم 7 و8')),
                DropdownMenuItem(
                    value: 'restaurants_top',
                    child: Text('المطاعم - إعلان رئيسي كبير أعلى الصفحة')),
                DropdownMenuItem(
                    value: 'restaurants_gallery',
                    child: Text('المطاعم - معرض صور كبير')),
                DropdownMenuItem(
                    value: 'restaurants_between_1',
                    child: Text('المطاعم - ممول بين القسم 1 و2')),
                DropdownMenuItem(
                    value: 'restaurants_between_2',
                    child: Text('المطاعم - ممول بين القسم 2 و3')),
                DropdownMenuItem(
                    value: 'restaurants_between_3',
                    child: Text('المطاعم - ممول بين القسم 3 و4')),
                DropdownMenuItem(
                    value: 'restaurants_between_4',
                    child: Text('المطاعم - ممول بين القسم 4 و5')),
                DropdownMenuItem(
                    value: 'restaurants_between_5',
                    child: Text('المطاعم - ممول بين القسم 5 و6')),
                DropdownMenuItem(
                    value: 'restaurants_between_6',
                    child: Text('المطاعم - ممول بين القسم 6 و7')),
                DropdownMenuItem(
                    value: 'restaurants_between_7',
                    child: Text('المطاعم - ممول بين القسم 7 و8')),
              ],
              onChanged: (value) =>
                  setState(() => _placement = value ?? 'restaurant'),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _displaySize,
              decoration: const InputDecoration(labelText: 'حجم الإعلان'),
              items: const [
                DropdownMenuItem(value: 'large', child: Text('كبير')),
                DropdownMenuItem(value: 'medium', child: Text('متوسط')),
                DropdownMenuItem(value: 'small', child: Text('مصغر')),
              ],
              onChanged: (value) =>
                  setState(() => _displaySize = value ?? 'large'),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('إظهار الإعلان الآن'),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
            ),
            const Divider(height: 32),
            if (_imageBytes != null)
              ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.memory(_imageBytes!,
                      height: 170, fit: BoxFit.cover))
            else if (existingImage.isNotEmpty)
              ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(existingImage,
                      height: 170, fit: BoxFit.cover)),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickImage,
              icon: const Icon(Icons.image_outlined),
              label: Text(_imageFile == null && existingImage.isEmpty
                  ? 'اختيار صورة الإعلان'
                  : 'تغيير صورة الإعلان'),
            ),
            const SizedBox(height: 12),
            if (_existingGallery.isNotEmpty || _galleryFiles.isNotEmpty)
              SizedBox(
                height: 82,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._existingGallery.map((url) => Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(url,
                                width: 82, height: 82, fit: BoxFit.cover),
                          ),
                        )),
                    ..._galleryBytes.map((bytes) => Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(bytes,
                                width: 82, height: 82, fit: BoxFit.cover),
                          ),
                        )),
                  ],
                ),
              ),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickGallery,
              icon: const Icon(Icons.collections_outlined),
              label: const Text('اختيار الصور المصغرة للإعلان (حتى 5 صور)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickVideo,
              icon: const Icon(Icons.video_library_outlined),
              label: Text(_videoFile != null || existingVideo.isNotEmpty
                  ? 'تغيير الفيديو التسويقي (حتى 30 ثانية)'
                  : 'اختيار فيديو تسويقي (اختياري، حتى 30 ثانية)'),
            ),
            if (_videoFile != null || existingVideo.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 6),
                  Text('تم اختيار فيديو للإعلان')
                ]),
              ),
            const SizedBox(height: 28),
            if (_saving && _uploadProgress.isNotEmpty) ...[
              Text(
                _uploadProgress,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
            ],
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54)),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded),
              label: Text(_saving ? 'جارٍ الرفع والحفظ...' : 'حفظ الإعلان'),
            ),
          ]),
        ),
      ),
    );
  }
}
