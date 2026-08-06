import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminManageRestaurants extends StatefulWidget {
  const AdminManageRestaurants({super.key});

  @override
  State<AdminManageRestaurants> createState() => _AdminManageRestaurantsState();
}

class _AdminManageRestaurantsState extends State<AdminManageRestaurants> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _showRestaurantDialog({DocumentSnapshot? doc}) async {
    final titleController = TextEditingController(text: doc?['title'] ?? '');
    final descriptionController =
        TextEditingController(text: doc?['description'] ?? '');
    final imageController = TextEditingController(text: doc?['image'] ?? '');
    final categoryController = TextEditingController(text: doc?['category'] ?? '');
    final typeController = TextEditingController(text: doc?['type'] ?? '');

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(doc == null ? 'إضافة مطعم' : 'تعديل المطعم'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'اسم المطعم',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'الوصف',
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
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'التصنيف',
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
                final description = descriptionController.text.trim();
                final image = imageController.text.trim();
                final category = categoryController.text.trim();
                final type = typeController.text.trim();

                if (title.isEmpty) return;

                final data = {
                  'title': title,
                  'description': description,
                  'image': image,
                  'category': category,
                  'type': type,
                };

                if (doc == null) {
                  await _firestore.collection('items').add(data);
                } else {
                  await _firestore.collection('items').doc(doc.id).update(data);
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

  Future<void> _deleteRestaurant(String id) async {
    await _firestore.collection('items').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المطاعم'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRestaurantDialog(),
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
                'لا يوجد مطاعم حالياً',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          final restaurantDocs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final type = (data['type'] ?? '').toString().toLowerCase();
            return type == 'restaurant';
          }).toList();

          if (restaurantDocs.isEmpty) {
            return const Center(
              child: Text(
                'لا يوجد مطاعم حالياً',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: restaurantDocs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = restaurantDocs[index];
              final data = doc.data() as Map<String, dynamic>;

              final title = (data['title'] ?? '').toString();
              final image = (data['image'] ?? '').toString();
              final description = (data['description'] ?? '').toString();
              final category = (data['category'] ?? '').toString();
              final type = (data['type'] ?? '').toString();

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
                    backgroundImage:
                        image.isNotEmpty ? NetworkImage(image) : null,
                    child: image.isEmpty
                        ? const Icon(Icons.storefront, color: Colors.pink)
                        : null,
                  ),
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    [description, category, type]
                        .where((e) => e.isNotEmpty)
                        .join(' • '),
                    style: const TextStyle(color: Colors.black54),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _showRestaurantDialog(doc: doc),
                        icon: const Icon(Icons.edit, color: Colors.blue),
                      ),
                      IconButton(
                        onPressed: () => _deleteRestaurant(doc.id),
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