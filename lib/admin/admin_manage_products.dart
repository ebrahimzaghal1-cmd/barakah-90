import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AdminManageProducts extends StatefulWidget {
  const AdminManageProducts({super.key});

  @override
  State<AdminManageProducts> createState() => _AdminManageProductsState();
}

class _AdminManageProductsState extends State<AdminManageProducts> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _showProductDialog({DocumentSnapshot? doc}) async {
    final product = doc?.data() as Map<String, dynamic>? ?? {};
    final titleController = TextEditingController(text: product['title'] ?? '');
    final descriptionController =
        TextEditingController(text: product['description'] ?? '');
    final categoryController =
        TextEditingController(text: product['category'] ?? '');
    final typeController = TextEditingController(text: product['type'] ?? '');
    var imageUrl = product['image']?.toString() ?? '';
    File? selectedImage;
    var isSaving = false;

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

                setDialogState(() => selectedImage = File(pickedImage.path));
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تعذر اختيار الصورة.')),
                  );
                }
              }
            }

            Future<void> saveProduct() async {
              final title = titleController.text.trim();
              if (title.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى إدخال اسم المنتج.')),
                );
                return;
              }

              setDialogState(() => isSaving = true);
              try {
                if (selectedImage != null) {
                  final imagePath = selectedImage!.path;
                  final extension = imagePath.contains('.')
                      ? imagePath.split('.').last
                      : 'jpg';
                  final fileName =
                      '${DateTime.now().millisecondsSinceEpoch}.$extension';
                  final storageRef = FirebaseStorage.instance
                      .ref()
                      .child('items')
                      .child(fileName);

                  await storageRef.putFile(selectedImage!);
                  imageUrl = await storageRef.getDownloadURL();
                }

                final data = {
                  'title': title,
                  'description': descriptionController.text.trim(),
                  'image': imageUrl,
                  'category': categoryController.text.trim(),
                  'type': typeController.text.trim(),
                };

                if (doc == null) {
                  await _firestore.collection('items').add(data);
                } else {
                  await _firestore.collection('items').doc(doc.id).update(data);
                }

                if (context.mounted) Navigator.of(dialogContext).pop();
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('تعذر حفظ المنتج. حاول مرة أخرى.')),
                  );
                }
              } finally {
                if (context.mounted) setDialogState(() => isSaving = false);
              }
            }

            final preview = selectedImage != null
                ? Image.file(selectedImage!, fit: BoxFit.cover)
                : imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_not_supported_outlined,
                          size: 42,
                        ),
                      )
                    : const Icon(Icons.add_photo_alternate_outlined, size: 42);

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
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(labelText: 'التصنيف'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: typeController,
                      decoration: const InputDecoration(labelText: 'النوع'),
                    ),
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
    categoryController.dispose();
    typeController.dispose();
  }

  Future<void> _deleteProduct(String id) async {
    await _firestore.collection('items').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المنتجات'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('items').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'لا يوجد منتجات حالياً',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'] ?? '';
              final image = data['image'] ?? '';
              final category = data['category'] ?? '';
              final type = data['type'] ?? '';

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
                    backgroundColor: Colors.pink.withOpacity(0.12),
                    backgroundImage: image.toString().isNotEmpty
                        ? NetworkImage(image.toString())
                        : null,
                    child: image.toString().isEmpty
                        ? const Icon(Icons.fastfood, color: Colors.pink)
                        : null,
                  ),
                  title: Text(
                    title.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${category.toString()} • ${type.toString()}',
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
    );
  }
}
