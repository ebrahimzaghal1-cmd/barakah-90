import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminManageCategories extends StatefulWidget {
  const AdminManageCategories({super.key});

  @override
  State<AdminManageCategories> createState() => _AdminManageCategoriesState();
}

class _AdminManageCategoriesState extends State<AdminManageCategories> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _showCategoryDialog({DocumentSnapshot? doc}) async {
    final titleController = TextEditingController(text: doc?['title'] ?? '');
    final imageController = TextEditingController(text: doc?['image'] ?? '');
    final typeController = TextEditingController(text: doc?['type'] ?? '');

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(doc == null ? 'إضافة تصنيف' : 'تعديل التصنيف'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'اسم التصنيف',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: imageController,
                  decoration: const InputDecoration(
                    labelText: 'رابط الصورة',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: typeController,
                  decoration: const InputDecoration(
                    labelText: 'النوع',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final image = imageController.text.trim();
                final type = typeController.text.trim();

                if (title.isEmpty) return;

                if (doc == null) {
                  await _firestore.collection('categories').add({
                    'title': title,
                    'image': image,
                    'type': type,
                  });
                } else {
                  await _firestore.collection('categories').doc(doc.id).update({
                    'title': title,
                    'image': image,
                    'type': type,
                  });
                }

                if (mounted) Navigator.pop(context);
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteCategory(String id) async {
    await _firestore.collection('categories').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة التصنيفات'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('categories').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'لا يوجد تصنيفات حالياً',
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
                    backgroundColor: Colors.pink.withOpacity(0.12),
                    backgroundImage: image.toString().isNotEmpty
                        ? NetworkImage(image.toString())
                        : null,
                    child: image.toString().isEmpty
                        ? const Icon(Icons.category, color: Colors.pink)
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
