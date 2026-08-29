import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/media_upload_service.dart';
import '../theme/app_theme.dart';
import '../widgets/barakah_media_image.dart';

class AdminManageCategories extends StatefulWidget {
  const AdminManageCategories({
    super.key,
    this.collectionName = 'categories',
    this.title = 'إدارة التصنيفات',
    this.seedItems = const [],
  });

  final String collectionName;
  final String title;
  final List<Map<String, String>> seedItems;

  @override
  State<AdminManageCategories> createState() => _AdminManageCategoriesState();
}

class _AdminManageCategoriesState extends State<AdminManageCategories> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(widget.collectionName);

  Future<void> _seedItems() async {
    final batch = _firestore.batch();
    for (final item in widget.seedItems) {
      batch.set(_collection.doc(), item);
    }
    await batch.commit();
  }

  Future<void> _showCategoryDialog({DocumentSnapshot? doc}) async {
    final category = doc?.data() as Map<String, dynamic>? ?? {};
    final titleController =
        TextEditingController(text: category['title'] ?? '');
    final descriptionController =
        TextEditingController(text: category['desc'] ?? '');
    final typeController = TextEditingController(text: category['type'] ?? '');
    var imageUrl = category['image']?.toString() ?? '';
    XFile? selectedImage;
    Uint8List? selectedImageBytes;
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
                if (pickedImage != null) {
                  final bytes = await pickedImage.readAsBytes();
                  setDialogState(() {
                    selectedImage = pickedImage;
                    selectedImageBytes = bytes;
                  });
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تعذر اختيار الصورة.')),
                  );
                }
              }
            }

            Future<void> saveCategory() async {
              final title = titleController.text.trim();
              if (title.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى إدخال اسم التصنيف.')),
                );
                return;
              }

              setDialogState(() => isSaving = true);
              try {
                if (selectedImage != null) {
                  imageUrl = await MediaUploadService().upload(
                    selectedImage!,
                    isVideo: false,
                  );
                }

                final data = {
                  'title': title,
                  'image': imageUrl,
                  'desc': descriptionController.text.trim(),
                  'type': typeController.text.trim(),
                };
                if (doc == null) {
                  await _collection.add(data);
                } else {
                  await _collection.doc(doc.id).update(data);
                }

                if (context.mounted) Navigator.of(dialogContext).pop();
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('تعذر حفظ التصنيف. حاول مرة أخرى.')),
                  );
                }
              } finally {
                if (context.mounted) setDialogState(() => isSaving = false);
              }
            }

            final preview = selectedImageBytes != null
                ? Image.memory(selectedImageBytes!, fit: BoxFit.cover)
                : imageUrl.isNotEmpty
                    ? BarakahMediaImage(
                        path: imageUrl,
                        fit: BoxFit.cover,
                        fallback: const Icon(
                          Icons.image_not_supported_outlined,
                          size: 42,
                        ),
                      )
                    : const Icon(Icons.add_photo_alternate_outlined, size: 42);

            return AlertDialog(
              title: Text(doc == null ? 'إضافة تصنيف' : 'تعديل التصنيف'),
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
                          const InputDecoration(labelText: 'اسم التصنيف'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'وصف قصير'),
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
                  onPressed: isSaving ? null : saveCategory,
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
  }

  Future<void> _deleteCategory(String id) async {
    await _collection.doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _collection.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            if (widget.seedItems.isEmpty) {
              return const Center(
                child: Text('لا يوجد تصنيفات حالياً',
                    style: TextStyle(fontSize: 18)),
              );
            }
            return Center(
              child: ElevatedButton.icon(
                onPressed: _seedItems,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('تهيئة أقسام الماركت الحالية'),
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
              final title = (doc.data() as Map<String, dynamic>)['title'] ?? '';
              final image = (doc.data() as Map<String, dynamic>)['image'] ?? '';
              final type = (doc.data() as Map<String, dynamic>)['type'] ?? '';

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
                    backgroundColor: AppTheme.coolYellow.withOpacity(0.25),
                    backgroundImage: image.toString().isNotEmpty
                        ? barakahImageProvider(image.toString())
                        : null,
                    child: image.toString().isEmpty
                        ? const Icon(Icons.category, color: AppTheme.deepYellow)
                        : null,
                  ),
                  title: Text(
                    title.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    type.toString(),
                    style: const TextStyle(color: Colors.black54),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _showCategoryDialog(doc: doc),
                        icon: const Icon(Icons.edit, color: Colors.blue),
                      ),
                      IconButton(
                        onPressed: () => _deleteCategory(doc.id),
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
