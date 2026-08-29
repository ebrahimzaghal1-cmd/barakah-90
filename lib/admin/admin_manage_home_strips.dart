import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/media_upload_service.dart';
import '../theme/app_theme.dart';
import '../widgets/barakah_media_image.dart';

class AdminManageHomeStrips extends StatefulWidget {
  const AdminManageHomeStrips({
    super.key,
    this.surface = 'restaurants',
  });

  final String surface;

  @override
  State<AdminManageHomeStrips> createState() => _AdminManageHomeStripsState();
}

class _AdminManageHomeStripsState extends State<AdminManageHomeStrips> {
  final _firestore = FirebaseFirestore.instance;
  final _imagePicker = ImagePicker();
  bool _rebuildingSales = false;

  CollectionReference<Map<String, dynamic>> get _strips =>
      _firestore.collection('home_category_strips');

  bool get _isMarket => widget.surface == 'market';

  @override
  void initState() {
    super.initState();
    if (_isMarket) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _rebuildSalesCounts(showMessage: false);
      });
    }
  }

  Future<void> _rebuildSalesCounts({bool showMessage = true}) async {
    if (_rebuildingSales) return;
    setState(() => _rebuildingSales = true);
    try {
      final orders = await _firestore.collection('orders').get();
      final counts = <String, int>{};
      for (final order in orders.docs) {
        final data = order.data();
        if (data['status']?.toString() != 'delivered') continue;
        final items = (data['items'] as List?) ?? const [];
        for (final rawItem in items.whereType<Map>()) {
          final item = Map<String, dynamic>.from(rawItem);
          final productId = item['productId']?.toString().trim() ?? '';
          if (productId.isEmpty) continue;
          final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
          counts.update(
            productId,
            (value) => value + quantity,
            ifAbsent: () => quantity,
          );
        }
      }

      final products = await _firestore.collection('items').get();
      var batch = _firestore.batch();
      var operations = 0;
      for (final product in products.docs) {
        final data = product.data();
        if (data['type']?.toString().toLowerCase() != 'market' ||
            data['kind']?.toString() != 'product') {
          continue;
        }
        batch.set(
          product.reference,
          {
            'salesCount': counts[product.id] ?? 0,
            'salesUpdatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        operations++;
        if (operations == 400) {
          await batch.commit();
          batch = _firestore.batch();
          operations = 0;
        }
      }
      if (operations > 0) await batch.commit();
      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث ترتيب الأكثر مبيعاً.')),
        );
      }
    } catch (_) {
      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحديث إحصائيات المبيعات.')),
        );
      }
    } finally {
      if (mounted) setState(() => _rebuildingSales = false);
    }
  }

  Future<void> _seedDefault() async {
    await _strips.add({
      'title': _isMarket ? 'سوق بركة' : 'شو مخبيلك بركة اليوم🤔',
      'surface': widget.surface,
      'order': 0,
      'enabled': true,
      'useQuickActions': !_isMarket,
      'stripType': 'categories',
      'showAllCategories': _isMarket,
      'categoryIds': <String>[],
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> _editCustomItem(
    BuildContext context, {
    Map<String, dynamic>? current,
  }) async {
    final title = TextEditingController(text: current?['title']?.toString());
    final description =
        TextEditingController(text: current?['description']?.toString());
    final destinationUrl =
        TextEditingController(text: current?['destinationUrl']?.toString());
    var actionType = current?['actionType']?.toString() ?? 'details';
    var image = current?['image']?.toString() ?? '';
    XFile? imageFile;
    Uint8List? imageBytes;
    var uploading = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (itemDialogContext) => StatefulBuilder(
        builder: (context, setItemState) => AlertDialog(
          title: Text(current == null ? 'إضافة بطاقة مخصصة' : 'تعديل البطاقة'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'اسم البطاقة',
                      hintText: 'مثال: قريباً من بركة',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    decoration: const InputDecoration(
                      labelText: 'وصف قصير (اختياري)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: destinationUrl,
                    keyboardType: TextInputType.url,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'رابط الوجهة (اختياري)',
                      hintText: 'https://example.com',
                      helperText:
                          'تبقى البطاقة قابلة للفتح داخل التطبيق حتى دون رابط.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: actionType,
                    decoration: const InputDecoration(
                      labelText: 'وظيفة الاختصار عند الضغط',
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'details', child: Text('صفحة التفاصيل')),
                      DropdownMenuItem(
                          value: 'play', child: Text('العب واربح')),
                      DropdownMenuItem(
                          value: 'deliveryOffers', child: Text('عروض التوصيل')),
                      DropdownMenuItem(
                          value: 'discounts', child: Text('خصومات بركة')),
                      DropdownMenuItem(
                          value: 'nearby', child: Text('أماكن قريبة')),
                      DropdownMenuItem(
                          value: 'market', child: Text('فتح الماركت')),
                      DropdownMenuItem(
                          value: 'external', child: Text('فتح رابط خارجي')),
                    ],
                    onChanged: uploading
                        ? null
                        : (value) => setItemState(
                              () => actionType = value ?? 'details',
                            ),
                  ),
                  const SizedBox(height: 14),
                  if (imageBytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.memory(
                        imageBytes!,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  else if (image.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: BarakahMediaImage(
                        path: image,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: uploading
                        ? null
                        : () async {
                            final picked = await _imagePicker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 80,
                              maxWidth: 1400,
                              maxHeight: 1400,
                            );
                            if (picked != null) {
                              final bytes = await picked.readAsBytes();
                              if (!itemDialogContext.mounted) return;
                              setItemState(() {
                                imageFile = picked;
                                imageBytes = bytes;
                              });
                            }
                          },
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                      image.isEmpty && imageFile == null
                          ? 'اختيار صورة'
                          : 'تغيير الصورة',
                    ),
                  ),
                  if (uploading) ...[
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 6),
                    const Text('جارٍ رفع الصورة...'),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  uploading ? null : () => Navigator.pop(itemDialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              onPressed: uploading
                  ? null
                  : () async {
                      if (title.text.trim().isEmpty ||
                          (image.isEmpty && imageFile == null)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('أدخل الاسم واختر صورة.'),
                          ),
                        );
                        return;
                      }
                      setItemState(() => uploading = true);
                      try {
                        if (imageFile != null) {
                          image = await MediaUploadService().upload(
                            imageFile!,
                            isVideo: false,
                          );
                        }
                        if (itemDialogContext.mounted) {
                          Navigator.pop(itemDialogContext, {
                            'title': title.text.trim(),
                            'description': description.text.trim(),
                            'image': image,
                            'destinationUrl': destinationUrl.text.trim(),
                            'actionType': actionType,
                          });
                        }
                      } catch (_) {
                        setItemState(() => uploading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تعذر رفع الصورة.')),
                          );
                        }
                      }
                    },
              icon: const Icon(Icons.save_rounded),
              label: const Text('حفظ البطاقة'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    description.dispose();
    destinationUrl.dispose();
    return result;
  }

  Future<void> _showEditor(
      {DocumentSnapshot<Map<String, dynamic>>? doc}) async {
    final current = doc?.data() ?? const <String, dynamic>{};
    final title = TextEditingController(
      text: current['title']?.toString() ?? '',
    );
    final order = TextEditingController(
      text: ((current['order'] as num?)?.toInt() ?? 0).toString(),
    );
    final surface = doc == null
        ? widget.surface
        : current['surface']?.toString() == 'market'
            ? 'market'
            : 'restaurants';
    var enabled = current['enabled'] != false;
    var useQuickActions = current['useQuickActions'] == true;
    var stripType = current['stripType']?.toString() ??
        ((current['title']?.toString() ?? '').contains('مبيع')
            ? 'bestSelling'
            : 'categories');
    if (surface == 'restaurants' && useQuickActions) {
      stripType = 'custom';
    }
    var showAllCategories = current['showAllCategories'] == true ||
        current['title']?.toString().trim() == 'سوق بركة';
    var saving = false;
    final selectedIds = ((current['categoryIds'] as List?) ?? const [])
        .map((value) => value.toString())
        .toSet();
    final customItems = ((current['customItems'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final quickItems = ((current['quickItems'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    if (useQuickActions && quickItems.isEmpty) {
      quickItems.addAll([
        {
          'title': 'العب واربح',
          'image': 'assets/images/play_with_barakah_selected.png',
          'actionType': 'play',
        },
        {
          'title': 'عروض التوصيل',
          'image': 'assets/images/home_icons/delivery.png',
          'actionType': 'deliveryOffers',
        },
        {
          'title': 'خصومات بركة',
          'image': 'assets/images/home_icons/barakah_discounts.png',
          'actionType': 'discounts',
        },
        {
          'title': 'أماكن قريبة منك',
          'image': 'assets/images/home_icons/nearby.png',
          'actionType': 'nearby',
        },
      ]);
    }

    final restaurantCategories =
        await _firestore.collection('restaurant_categories').get();
    final marketCategories =
        await _firestore.collection('market_categories').get();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final categories = surface == 'market'
              ? marketCategories.docs
              : restaurantCategories.docs;

          Future<void> save() async {
            if (title.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('أدخل اسم الشريط.')),
              );
              return;
            }
            final usesEditableCards =
                surface == 'restaurants' && stripType == 'custom';
            if (!usesEditableCards &&
                stripType == 'categories' &&
                !showAllCategories &&
                selectedIds.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'اختر تصنيفاً واحداً على الأقل، أو فعّل «عرض كل التصنيفات».',
                  ),
                ),
              );
              return;
            }
            if (stripType == 'custom' && customItems.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('أضف بطاقة مخصصة واحدة على الأقل.'),
                ),
              );
              return;
            }
            if (usesEditableCards && quickItems.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('أضف اختصاراً واحداً على الأقل.'),
                ),
              );
              return;
            }
            setDialogState(() => saving = true);
            final data = <String, dynamic>{
              'title': title.text.trim(),
              'surface': surface,
              'order': int.tryParse(order.text.trim()) ?? 0,
              'enabled': enabled,
              'useQuickActions': usesEditableCards,
              'stripType': stripType,
              'showAllCategories': showAllCategories,
              'categoryIds': selectedIds.toList(),
              'customItems': customItems,
              'quickItems': quickItems,
              'updatedAt': FieldValue.serverTimestamp(),
            };
            try {
              if (doc == null) {
                await _strips.add(data);
              } else {
                await _strips.doc(doc.id).set(data, SetOptions(merge: true));
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تعذر حفظ الشريط.')),
                );
              }
              setDialogState(() => saving = false);
            }
          }

          return AlertDialog(
            title: Text(doc == null ? 'إضافة شريط' : 'تعديل الشريط'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: title,
                      decoration: InputDecoration(
                        labelText: 'عنوان الشريط',
                        hintText: _isMarket
                            ? 'مثال: عروض الماركت اليومية'
                            : 'مثال: شو مخبيلك بركة اليوم',
                      ),
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration:
                          const InputDecoration(labelText: 'مكان الظهور'),
                      child: Text(
                        surface == 'market' ? 'الماركت' : 'المطاعم',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: order,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'الترتيب',
                        hintText: '0 يظهر أولاً',
                      ),
                    ),
                    SwitchListTile.adaptive(
                      value: enabled,
                      onChanged: saving
                          ? null
                          : (value) => setDialogState(() => enabled = value),
                      title: const Text('إظهار الشريط'),
                    ),
                    if (surface == 'market') ...[
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: stripType,
                        decoration: const InputDecoration(
                          labelText: 'نوع محتوى الشريط',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'categories',
                            child: Text('تصنيفات الماركت'),
                          ),
                          DropdownMenuItem(
                            value: 'bestSelling',
                            child: Text('المنتجات الأكثر مبيعاً'),
                          ),
                          DropdownMenuItem(
                            value: 'custom',
                            child: Text('محتوى مخصص حر'),
                          ),
                        ],
                        onChanged: saving
                            ? null
                            : (value) => setDialogState(
                                  () => stripType = value ?? 'categories',
                                ),
                      ),
                    ],
                    if (surface == 'restaurants') ...[
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: stripType == 'custom' ? 'custom' : 'categories',
                        decoration: const InputDecoration(
                          labelText: 'نوع محتوى الشريط',
                          helperText:
                              'كل شريط يمكن أن يعرض تصنيفات أو بطاقات تضيفها وتعدلها بحرية.',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'categories',
                            child: Text('تصنيفات المطاعم'),
                          ),
                          DropdownMenuItem(
                            value: 'custom',
                            child: Text('بطاقات حرة قابلة للإضافة والتعديل'),
                          ),
                        ],
                        onChanged: saving
                            ? null
                            : (value) => setDialogState(() {
                                  stripType = value ?? 'categories';
                                  useQuickActions = stripType == 'custom';
                                }),
                      ),
                    ],
                    if (surface == 'restaurants' && stripType == 'custom') ...[
                      const Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          'بطاقات الشريط وصورها',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (var itemIndex = 0;
                          itemIndex < quickItems.length;
                          itemIndex++)
                        Card(
                          child: ListTile(
                            leading: _EditableStripImage(
                              path:
                                  quickItems[itemIndex]['image']?.toString() ??
                                      '',
                            ),
                            title: Text(
                              quickItems[itemIndex]['title']?.toString() ??
                                  'اختصار',
                            ),
                            subtitle: Text(
                              quickItems[itemIndex]['actionType']?.toString() ??
                                  'details',
                            ),
                            trailing: Wrap(
                              children: [
                                IconButton(
                                  tooltip: 'تعديل الاسم والصورة والوظيفة',
                                  onPressed: saving
                                      ? null
                                      : () async {
                                          final updated = await _editCustomItem(
                                            context,
                                            current: quickItems[itemIndex],
                                          );
                                          if (updated != null) {
                                            setDialogState(() =>
                                                quickItems[itemIndex] =
                                                    updated);
                                          }
                                        },
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'حذف',
                                  onPressed: saving
                                      ? null
                                      : () => setDialogState(
                                            () =>
                                                quickItems.removeAt(itemIndex),
                                          ),
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                final added = await _editCustomItem(context);
                                if (added != null) {
                                  setDialogState(() => quickItems.add(added));
                                }
                              },
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        label: const Text('إضافة بطاقة جديدة'),
                      ),
                    ],
                    if (stripType == 'categories') ...[
                      SwitchListTile.adaptive(
                        value: showAllCategories,
                        onChanged: saving
                            ? null
                            : (value) => setDialogState(
                                  () => showAllCategories = value,
                                ),
                        title: const Text('عرض كل التصنيفات'),
                        subtitle: const Text(
                          'فعّله فقط للشريط العام، مثل سوق بركة.',
                        ),
                      ),
                      const Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          'اختر التصنيفات داخل الشريط',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (categories.isEmpty)
                        const Text('لا توجد تصنيفات مضافة حالياً.')
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 7,
                          children: categories.map((category) {
                            final data = category.data();
                            final categoryTitle =
                                data['title']?.toString() ?? 'تصنيف';
                            return FilterChip(
                              label: Text(categoryTitle),
                              selected: selectedIds.contains(category.id),
                              selectedColor:
                                  AppTheme.coolYellow.withOpacity(.35),
                              onSelected: saving
                                  ? null
                                  : (selected) => setDialogState(() {
                                        if (selected) {
                                          selectedIds.add(category.id);
                                        } else {
                                          selectedIds.remove(category.id);
                                        }
                                      }),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 6),
                      const Text(
                        'لن يظهر الشريط حتى تختار تصنيفاً، إلا إذا فعّلت عرض الكل.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                    if (surface == 'market' && stripType == 'custom') ...[
                      const SizedBox(height: 12),
                      const Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          'بطاقات الشريط المخصص',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (var itemIndex = 0;
                          itemIndex < customItems.length;
                          itemIndex++)
                        Card(
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: _EditableStripImage(
                                path: customItems[itemIndex]['image']
                                        ?.toString() ??
                                    '',
                              ),
                            ),
                            title: Text(
                              customItems[itemIndex]['title']?.toString() ??
                                  'بطاقة',
                            ),
                            trailing: Wrap(
                              children: [
                                IconButton(
                                  tooltip: 'تعديل',
                                  onPressed: saving
                                      ? null
                                      : () async {
                                          final updated = await _editCustomItem(
                                            context,
                                            current: customItems[itemIndex],
                                          );
                                          if (updated != null) {
                                            setDialogState(() =>
                                                customItems[itemIndex] =
                                                    updated);
                                          }
                                        },
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'حذف',
                                  onPressed: saving
                                      ? null
                                      : () => setDialogState(
                                            () =>
                                                customItems.removeAt(itemIndex),
                                          ),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                final added = await _editCustomItem(context);
                                if (added != null) {
                                  setDialogState(() => customItems.add(added));
                                }
                              },
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text('إضافة بطاقة مخصصة'),
                      ),
                      const Text(
                        'يمكن إضافة أي محتوى هنا، حتى لو لم يكن تصنيفاً موجوداً.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                onPressed: saving ? null : save,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
    title.dispose();
    order.dispose();
  }

  Future<void> _delete(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الشريط؟'),
        content: Text('سيتم حذف «${doc.data()?['title'] ?? ''}».'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _strips.doc(doc.id).delete();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF2F2F2),
        appBar: AppBar(
          title: Text(_isMarket ? 'أشرطة الماركت' : 'أشرطة المطاعم'),
          centerTitle: true,
          actions: [
            if (_isMarket)
              IconButton(
                tooltip: 'تحديث الأكثر مبيعاً',
                onPressed: _rebuildingSales ? null : _rebuildSalesCounts,
                icon: _rebuildingSales
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showEditor,
          icon: const Icon(Icons.add_rounded),
          label: const Text('إضافة شريط'),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _strips.snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs
                .where((doc) => doc.data()['surface'] == widget.surface)
                .toList()
              ..sort((a, b) {
                return ((a.data()['order'] as num?)?.toInt() ?? 0).compareTo(
                  (b.data()['order'] as num?)?.toInt() ?? 0,
                );
              });
            if (docs.isEmpty) {
              return Center(
                child: FilledButton.icon(
                  onPressed: _seedDefault,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: Text(
                    _isMarket
                        ? 'إنشاء شريط الماركت الافتراضي'
                        : 'إنشاء شريط المطاعم الافتراضي',
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final market = data['surface'] == 'market';
                return Card(
                  color: Colors.white,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.coolYellow.withOpacity(.28),
                      child: Icon(
                        market ? Icons.storefront_rounded : Icons.restaurant,
                        color: AppTheme.navy,
                      ),
                    ),
                    title: Text(
                      data['title']?.toString() ?? 'شريط',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      '${market ? 'الماركت' : 'المطاعم'} • ترتيب ${data['order'] ?? 0}'
                      '${data['stripType'] == 'bestSelling' ? ' • الأكثر مبيعاً' : ''}'
                      '${data['enabled'] == false ? ' • مخفي' : ''}',
                    ),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          onPressed: () => _showEditor(doc: doc),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: () => _delete(doc),
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
}

class _EditableStripImage extends StatelessWidget {
  const _EditableStripImage({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    const fallback = SizedBox(
      width: 48,
      height: 48,
      child: Icon(Icons.image_not_supported_outlined),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BarakahMediaImage(
        path: path,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        fallback: fallback,
      ),
    );
  }
}
