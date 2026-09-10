import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../services/media_upload_service.dart';
import '../theme/app_theme.dart';

class AdminManageProducts extends StatefulWidget {
  const AdminManageProducts({
    super.key,
    this.initialBusinessId,
    this.initialBusinessTitle,
    this.ownerUid,
  });

  final String? initialBusinessId;
  final String? initialBusinessTitle;
  final String? ownerUid;

  @override
  State<AdminManageProducts> createState() => _AdminManageProductsState();
}

class _AdminManageProductsState extends State<AdminManageProducts> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();

  Future<String> uploadImage(XFile image) =>
      MediaUploadService().upload(image, isVideo: false);

  Future<void> _showProductDialog({DocumentSnapshot? doc}) async {
    final product = doc?.data() as Map<String, dynamic>? ?? {};
    final businessesSnapshot = await _firestore.collection('items').get();
    final businesses = businessesSnapshot.docs
        .where((item) =>
            item.data()['kind']?.toString() != 'product' &&
            (widget.initialBusinessId != null
                ? item.id == widget.initialBusinessId
                : widget.ownerUid == null ||
                    item.data()['ownerId']?.toString() == widget.ownerUid))
        .toList();
    final titleController = TextEditingController(text: product['title'] ?? '');
    final descriptionController =
        TextEditingController(text: product['description'] ?? '');
    final priceController =
        TextEditingController(text: '${product['price'] ?? ''}');
    final stockController = TextEditingController(
      text: '${product['stock'] ?? (doc == null ? 1 : '')}',
    );
    var imageUrl = product['image']?.toString() ?? '';
    var imageShape = product['imageShape']?.toString() ?? 'rounded';
    var soldOut = product['soldOut'] == true;
    String? businessId =
        product['businessId']?.toString() ?? widget.initialBusinessId;
    XFile? selectedImage;
    Uint8List? selectedImageBytes;
    var isSaving = false;

    final optionGroups = <Map<String, dynamic>>[];
    final rawOptionGroups = product['optionGroups'];

    if (rawOptionGroups is List) {
      for (var groupIndex = 0;
          groupIndex < rawOptionGroups.length;
          groupIndex++) {
        final rawGroup = rawOptionGroups[groupIndex];
        if (rawGroup is! Map) continue;

        final group = Map<String, dynamic>.from(rawGroup);
        final rawOptions = group['options'];

        final options = <Map<String, dynamic>>[];

        if (rawOptions is List) {
          for (var optionIndex = 0;
              optionIndex < rawOptions.length;
              optionIndex++) {
            final rawOption = rawOptions[optionIndex];
            if (rawOption is! Map) continue;

            final option = Map<String, dynamic>.from(rawOption);

            options.add({
              'id': option['id']?.toString().trim().isNotEmpty == true
                  ? option['id'].toString()
                  : 'option_${groupIndex}_$optionIndex',
              'name': option['name']?.toString() ?? '',
              'priceDelta': '${option['priceDelta'] ?? 0}',
            });
          }
        }

        optionGroups.add({
          'id': group['id']?.toString().trim().isNotEmpty == true
              ? group['id'].toString()
              : 'group_$groupIndex',
          'name': group['name']?.toString() ?? '',
          'required': group['required'] == true,
          'selectionType': group['selectionType']?.toString() == 'multiple'
              ? 'multiple'
              : 'single',
          'options': options,
        });
      }
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> chooseImage() async {
              try {
                final pickedImage = await _imagePicker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                  // توحيد الحجم يقلل الصور الضخمة ويحافظ على شكل البطاقات.
                  maxWidth: 1600,
                  maxHeight: 1600,
                );
                if (pickedImage == null) return;

                final bytes = await pickedImage.readAsBytes();

                setDialogState(() {
                  selectedImage = pickedImage;
                  selectedImageBytes = bytes;
                });
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تعذر اختيار الصورة.')),
                  );
                }
              }
            }

            Future<void> saveProduct() async {
              print('===== PRODUCT SAVE START =====');
              print(
                  'currentUserUid: ${FirebaseAuth.instance.currentUser?.uid}');
              print('ownerUid: ${widget.ownerUid}');
              print('initialBusinessId: ${widget.initialBusinessId}');
              print('selectedBusinessId: $businessId');

              final title = titleController.text.trim();
              final stock = int.tryParse(stockController.text.trim());
              if (title.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى إدخال اسم المنتج.')),
                );
                return;
              }
              if (stock == null || stock < 0 || stock > 999999) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('أدخلي كمية صحيحة من 0 إلى 999999.'),
                  ),
                );
                return;
              }

              final normalizedOptionGroups = <Map<String, dynamic>>[];

              for (var groupIndex = 0;
                  groupIndex < optionGroups.length;
                  groupIndex++) {
                final group = optionGroups[groupIndex];

                final groupName = group['name']?.toString().trim() ?? '';
                final rawOptions = group['options'];

                if (groupName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('أدخلي اسم مجموعة الخيارات، مثل: النوع.'),
                    ),
                  );
                  return;
                }

                if (rawOptions is! List || rawOptions.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'أضيفي خيارًا واحدًا على الأقل داخل مجموعة "$groupName".',
                      ),
                    ),
                  );
                  return;
                }

                final normalizedOptions = <Map<String, dynamic>>[];

                for (var optionIndex = 0;
                    optionIndex < rawOptions.length;
                    optionIndex++) {
                  final rawOption = rawOptions[optionIndex];

                  if (rawOption is! Map) continue;

                  final option = Map<String, dynamic>.from(rawOption);
                  final optionName = option['name']?.toString().trim() ?? '';

                  final priceDelta = num.tryParse(
                    option['priceDelta']?.toString().trim() ?? '',
                  );

                  if (optionName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'أدخلي اسم كل خيار داخل مجموعة "$groupName".',
                        ),
                      ),
                    );
                    return;
                  }

                  if (priceDelta == null ||
                      priceDelta < 0 ||
                      priceDelta > 1000000) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'فرق السعر للخيار "$optionName" غير صالح.',
                        ),
                      ),
                    );
                    return;
                  }

                  normalizedOptions.add({
                    'id': option['id']?.toString().trim().isNotEmpty == true
                        ? option['id'].toString()
                        : 'option_${DateTime.now().microsecondsSinceEpoch}_$optionIndex',
                    'name': optionName,
                    'priceDelta': priceDelta,
                  });
                }

                normalizedOptionGroups.add({
                  'id': group['id']?.toString().trim().isNotEmpty == true
                      ? group['id'].toString()
                      : 'group_${DateTime.now().microsecondsSinceEpoch}_$groupIndex',
                  'name': groupName,
                  'required': group['required'] == true,
                  'selectionType':
                      group['selectionType']?.toString() == 'multiple'
                          ? 'multiple'
                          : 'single',
                  'options': normalizedOptions,
                });
              }

              if (businessId == null || businessId!.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('اختاري المحل الذي يتبع له المنتج.')),
                );
                return;
              }
              final business =
                  businesses.where((item) => item.id == businessId);
              if (business.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('المحل المختار غير موجود.')),
                );
                return;
              }
              final businessData = business.first.data();

              setDialogState(() => isSaving = true);
              try {
                if (selectedImage != null) {
                  imageUrl = await uploadImage(selectedImage!);
                }

                final data = {
                  'title': title,
                  'description': descriptionController.text.trim(),
                  'image': imageUrl,
                  'imageShape': imageShape,
                  'kind': 'product',
                  'businessId': businessId,
                  'businessTitle': businessData['title']?.toString() ?? '',
                  'category': businessData['category']?.toString() ?? '',
                  'type': businessData['type']?.toString() ?? '',
                  'price': num.tryParse(priceController.text.trim()) ?? 0,
                  'stock': stock,
                  'soldOut': soldOut,
                  'optionGroups': normalizedOptionGroups,
                  if (widget.ownerUid != null) 'ownerId': widget.ownerUid,
                };

                if (doc == null && widget.ownerUid != null) {
                  final currentUser = FirebaseAuth.instance.currentUser;

                  if (currentUser == null) {
                    throw StateError('سجّل الدخول أولًا.');
                  }

                  final idToken = await currentUser.getIdToken();

                  final response = await http.post(
                    Uri.parse(
                      'https://barakah-secure-api.ebrahimzaghal1.workers.dev/v1/merchant/products',
                    ),
                    headers: {
                      'content-type': 'application/json',
                      'authorization': 'Bearer $idToken',
                    },
                    body: jsonEncode({
                      'businessId': businessId,
                      'title': title,
                      'description': descriptionController.text.trim(),
                      'image': imageUrl,
                      'imageShape': imageShape,
                      'price': num.tryParse(priceController.text.trim()) ?? 0,
                      'stock': stock,
                      'soldOut': soldOut,
                      'optionGroups': normalizedOptionGroups,
                    }),
                  );

                  final responseBody = response.body.isNotEmpty
                      ? jsonDecode(response.body)
                      : <String, dynamic>{};

                  if (response.statusCode < 200 || response.statusCode >= 300) {
                    final message = responseBody is Map
                        ? responseBody['message']?.toString()
                        : null;

                    throw StateError(
                      message ?? 'تعذر حفظ المنتج.',
                    );
                  }
                } else if (doc == null) {
                  await _firestore.collection('items').add(data);
                } else if (widget.ownerUid != null) {
                  final currentUser = FirebaseAuth.instance.currentUser;

                  if (currentUser == null) {
                    throw StateError('سجّل الدخول أولًا.');
                  }

                  final idToken = await currentUser.getIdToken();

                  final response = await http.post(
                    Uri.parse(
                      'https://barakah-secure-api.ebrahimzaghal1.workers.dev/v1/merchant/products/${Uri.encodeComponent(doc.id)}/update',
                    ),
                    headers: {
                      'content-type': 'application/json',
                      'authorization': 'Bearer $idToken',
                    },
                    body: jsonEncode({
                      'title': title,
                      'description': descriptionController.text.trim(),
                      'image': imageUrl,
                      'imageShape': imageShape,
                      'price': num.tryParse(priceController.text.trim()) ?? 0,
                      'stock': stock,
                      'soldOut': soldOut,
                      'optionGroups': normalizedOptionGroups,
                    }),
                  );

                  final responseBody = response.body.isNotEmpty
                      ? jsonDecode(response.body)
                      : <String, dynamic>{};

                  if (response.statusCode < 200 || response.statusCode >= 300) {
                    final message = responseBody is Map
                        ? responseBody['message']?.toString()
                        : null;

                    throw StateError(
                      message ?? 'تعذر تعديل المنتج.',
                    );
                  }
                } else {
                  await _firestore.collection('items').doc(doc.id).update(data);
                }

                if (context.mounted) {
                  Navigator.of(dialogContext).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        doc == null
                            ? 'تمت إضافة المنتج بنجاح ✅'
                            : 'تم تعديل المنتج بنجاح ✅',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (error, stackTrace) {
                debugPrint('===== PRODUCT SAVE ERROR =====');
                debugPrint(error.toString());
                debugPrint(stackTrace.toString());

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تعذر حفظ المنتج: $error',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                if (context.mounted) setDialogState(() => isSaving = false);
              }
            }

            final preview = selectedImageBytes != null
                ? Image.memory(
                    selectedImageBytes!,
                    fit: BoxFit.cover,
                  )
                : imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_not_supported_outlined,
                          size: 42,
                        ),
                      )
                    : const Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 42,
                      );
            final previewRadius = imageShape == 'circle' ? 999.0 : 12.0;

            return AlertDialog(
              title: Text(doc == null ? 'إضافة منتج' : 'تعديل المنتج'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: isSaving ? null : chooseImage,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(previewRadius),
                                child: preview,
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                color: Colors.black54,
                                child: Text(
                                  imageUrl.isEmpty && selectedImage == null
                                      ? 'اختيار صورة'
                                      : 'تغيير الصورة',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: imageShape,
                      decoration:
                          const InputDecoration(labelText: 'شكل الصورة'),
                      items: const [
                        DropdownMenuItem(
                            value: 'rounded',
                            child: Text('مستطيل بحواف مستديرة')),
                        DropdownMenuItem(value: 'square', child: Text('مربع')),
                        DropdownMenuItem(value: 'circle', child: Text('دائري')),
                        DropdownMenuItem(value: 'blur', child: Text('بلوري')),
                      ],
                      onChanged: isSaving
                          ? null
                          : (value) {
                              if (value != null) {
                                setDialogState(() => imageShape = value);
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration:
                          const InputDecoration(labelText: 'اسم المنتج'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'الوصف'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: businesses.any((item) => item.id == businessId)
                          ? businessId
                          : null,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'المحل / المطعم التابع له المنتج',
                        helperText: widget.ownerUid != null &&
                                widget.initialBusinessId != null
                            ? 'هذا المنتج مربوط بمتجرك تلقائيًا'
                            : null,
                      ),
                      items: businesses
                          .map((business) => DropdownMenuItem(
                                value: business.id,
                                child: Text(
                                  business.data()['title']?.toString() ??
                                      'بدون اسم',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: isSaving ||
                              (widget.ownerUid != null &&
                                  widget.initialBusinessId != null)
                          ? null
                          : (value) => setDialogState(() => businessId = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'السعر (₪)'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'الكمية التقديرية',
                        hintText: 'مثال: 10',
                        helperText: 'الكمية للمعلومة ولا تغلق الصنف تلقائيًا',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'خيارات المنتج',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: isSaving
                              ? null
                              : () {
                                  setDialogState(() {
                                    optionGroups.add({
                                      'id':
                                          'group_${DateTime.now().microsecondsSinceEpoch}',
                                      'name': '',
                                      'required': true,
                                      'selectionType': 'single',
                                      'options': <Map<String, dynamic>>[
                                        {
                                          'id':
                                              'option_${DateTime.now().microsecondsSinceEpoch}',
                                          'name': '',
                                          'priceDelta': '0',
                                        },
                                      ],
                                    });
                                  });
                                },
                          icon: const Icon(Icons.add),
                          label: const Text('إضافة مجموعة'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'مثال: النوع ← ساندويش / وجبة مع بطاطا وكولا',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...optionGroups.asMap().entries.map((groupEntry) {
                      final groupIndex = groupEntry.key;
                      final group = groupEntry.value;
                      final options =
                          group['options'] as List<Map<String, dynamic>>;

                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.coolYellow.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.coolYellow.withOpacity(0.55),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue:
                                        group['name']?.toString() ?? '',
                                    enabled: !isSaving,
                                    decoration: const InputDecoration(
                                      labelText: 'اسم المجموعة',
                                      hintText: 'مثال: النوع',
                                    ),
                                    onChanged: (value) {
                                      group['name'] = value;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  tooltip: 'حذف المجموعة',
                                  onPressed: isSaving
                                      ? null
                                      : () {
                                          setDialogState(() {
                                            optionGroups.removeAt(groupIndex);
                                          });
                                        },
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              value: group['required'] == true,
                              title: const Text(
                                'اختيار مطلوب',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                group['required'] == true
                                    ? 'لا يمكن إضافة المنتج قبل اختيار أحد الخيارات'
                                    : 'يمكن للعميل المتابعة بدون اختيار',
                              ),
                              onChanged: isSaving
                                  ? null
                                  : (value) {
                                      setDialogState(() {
                                        group['required'] = value;
                                      });
                                    },
                            ),
                            DropdownButtonFormField<String>(
                              value: group['selectionType']?.toString() ==
                                      'multiple'
                                  ? 'multiple'
                                  : 'single',
                              decoration: const InputDecoration(
                                labelText: 'طريقة اختيار العميل',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'single',
                                  child: Text('اختيار واحد فقط'),
                                ),
                                DropdownMenuItem(
                                  value: 'multiple',
                                  child: Text('يمكن اختيار عدة خيارات'),
                                ),
                              ],
                              onChanged: isSaving
                                  ? null
                                  : (value) {
                                      if (value == null) return;
                                      setDialogState(() {
                                        group['selectionType'] = value;
                                      });
                                    },
                            ),
                            const SizedBox(height: 10),
                            const Divider(),
                            ...options.asMap().entries.map((optionEntry) {
                              final optionIndex = optionEntry.key;
                              final option = optionEntry.value;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextFormField(
                                        initialValue:
                                            option['name']?.toString() ?? '',
                                        enabled: !isSaving,
                                        decoration: const InputDecoration(
                                          labelText: 'اسم الاختيار',
                                          hintText: 'مثال: ساندويش',
                                        ),
                                        onChanged: (value) {
                                          option['name'] = value;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        initialValue:
                                            option['priceDelta']?.toString() ??
                                                '0',
                                        enabled: !isSaving,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(
                                          decimal: true,
                                        ),
                                        decoration: const InputDecoration(
                                          labelText: 'زيادة السعر ₪',
                                          hintText: '0',
                                        ),
                                        onChanged: (value) {
                                          option['priceDelta'] = value;
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'حذف الخيار',
                                      onPressed: isSaving
                                          ? null
                                          : () {
                                              setDialogState(() {
                                                options.removeAt(optionIndex);
                                              });
                                            },
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: isSaving
                                    ? null
                                    : () {
                                        setDialogState(() {
                                          options.add({
                                            'id':
                                                'option_${DateTime.now().microsecondsSinceEpoch}',
                                            'name': '',
                                            'priceDelta': '0',
                                          });
                                        });
                                      },
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('إضافة اختيار'),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: soldOut,
                      title: const Text(
                        'نفد المخزون',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        soldOut
                            ? 'الصنف مغلق ولا يمكن شراؤه'
                            : 'الصنف مفتوح للشراء',
                      ),
                      activeThumbColor: Colors.red,
                      onChanged: isSaving
                          ? null
                          : (value) => setDialogState(() => soldOut = value),
                    ),
                    const SizedBox(height: 8),
                    const Text('السعر خاص بالمنتج فقط؛ تقييم النجوم للمحل.',
                        style: TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : saveProduct,
                  child: isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    stockController.dispose();
  }

  Future<void> _deleteProduct(String id) async {
    if (widget.ownerUid == null) {
      await _firestore.collection('items').doc(id).delete();
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw StateError('سجّل الدخول أولًا.');
    }

    final idToken = await currentUser.getIdToken();

    final response = await http.post(
      Uri.parse(
        'https://barakah-secure-api.ebrahimzaghal1.workers.dev/v1/merchant/products/${Uri.encodeComponent(id)}/delete',
      ),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $idToken',
      },
      body: '{}',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final responseBody = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : <String, dynamic>{};

      final message =
          responseBody is Map ? responseBody['message']?.toString() : null;

      throw StateError(
        message ?? 'تعذر حذف المنتج.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialBusinessTitle == null
            ? 'إدارة منتجات المحلات'
            : 'أصناف ${widget.initialBusinessTitle}'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          if (widget.ownerUid != null && widget.initialBusinessId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.coolYellow,
                    foregroundColor: AppTheme.ink,
                  ),
                  onPressed: () => _showProductDialog(),
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text(
                    'إضافة منتج جديد',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('items').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'لا توجد عناصر قابلة للتعديل حالياً',
                      style: TextStyle(fontSize: 18),
                    ),
                  );
                }

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['kind'] == 'product' &&
                      (widget.initialBusinessId != null ||
                          widget.ownerUid == null ||
                          data['ownerId']?.toString() == widget.ownerUid) &&
                      (widget.initialBusinessId == null ||
                          data['businessId']?.toString() ==
                              widget.initialBusinessId);
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                        widget.initialBusinessTitle == null
                            ? 'لا توجد منتجات بعد. أضيفي منتجاً واربطِيه بمحل.'
                            : 'لا توجد أصناف في هذا المحل بعد. اضغطي زر + لإضافة أول صنف.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final title = data['title'] ?? '';
                    final image = data['image'] ?? '';
                    final businessTitle = data['businessTitle'] ?? '';
                    final price = data['price'] ?? 0;
                    final soldOut = data['soldOut'] == true;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppTheme.coolYellow.withOpacity(0.25),
                          backgroundImage: image.toString().isNotEmpty
                              ? NetworkImage(image.toString())
                              : null,
                          child: image.toString().isEmpty
                              ? const Icon(Icons.fastfood,
                                  color: AppTheme.deepYellow)
                              : null,
                        ),
                        title: Text(
                          title.toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${businessTitle.toString()} • $price ₪ • '
                          '${soldOut ? 'نفد المخزون' : 'مفتوح للشراء'}',
                          style: TextStyle(
                            color: soldOut ? Colors.red : Colors.green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _showProductDialog(doc: doc),
                              icon: const Icon(Icons.edit, color: Colors.blue),
                            ),
                            IconButton(
                              onPressed: () => _deleteProduct(doc.id),
                              icon: const Icon(Icons.delete, color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
