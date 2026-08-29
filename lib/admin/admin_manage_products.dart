import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
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

  Future<String> uploadImage(XFile image) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://barakah-90-production-384c.up.railway.app/upload'),
    );

    if (kIsWeb) {
      final bytes = await image.readAsBytes();

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: image.name,
          contentType: MediaType('image', 'jpeg'),
        ),
      );
    } else {
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          image.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );
    }

    final response = await request.send();

    if (response.statusCode != 200) {
      throw Exception(
        'Image upload failed: ${response.statusCode}',
      );
    }

    final body = await response.stream.bytesToString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final imageUrl = json['url']?.toString();

    if (imageUrl == null || imageUrl.isEmpty) {
      throw Exception('Image upload returned no URL');
    }

    return imageUrl;
  }

  Future<void> _showProductDialog({DocumentSnapshot? doc}) async {
    final product = doc?.data() as Map<String, dynamic>? ?? {};
    final businessesSnapshot = await _firestore.collection('items').get();
    final businesses = businessesSnapshot.docs
        .where((item) =>
            item.data()['kind']?.toString() != 'product' &&
            (widget.ownerUid == null ||
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
    String? businessId =
        product['businessId']?.toString() ?? widget.initialBusinessId;
    XFile? selectedImage;
    Uint8List? selectedImageBytes;
    var isSaving = false;

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
                  'kind': 'product',
                  'businessId': businessId,
                  'businessTitle': businessData['title']?.toString() ?? '',
                  'category': businessData['category']?.toString() ?? '',
                  'type': businessData['type']?.toString() ?? '',
                  'price': num.tryParse(priceController.text.trim()) ?? 0,
                  'stock': stock,
                  'soldOut': stock <= 0,
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
                      'price': num.tryParse(priceController.text.trim()) ?? 0,
                      'stock': stock,
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
                      'price': num.tryParse(priceController.text.trim()) ?? 0,
                      'stock': stock,
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
                            preview,
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
                        labelText: 'الكمية المتوفرة',
                        hintText: 'مثال: 10',
                      ),
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
                      (widget.ownerUid == null ||
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
                          '${businessTitle.toString()} • $price ₪',
                          style: const TextStyle(color: Colors.black54),
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
