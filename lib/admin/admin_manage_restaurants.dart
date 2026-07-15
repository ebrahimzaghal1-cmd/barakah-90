import 'package:flutter/material.dart';

class AdminManageRestaurants extends StatefulWidget {
  const AdminManageRestaurants({super.key});

  @override
  State<AdminManageRestaurants> createState() => _AdminManageRestaurantsState();
}

class _AdminManageRestaurantsState extends State<AdminManageRestaurants> {
  final List<String> restaurants = [
    'برغر',
    'قهوة',
    'دجاج مقلي',
    'بيتزا',
    'أرز',
    'شاورما',
  ];

  void _showAddDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة مطعم'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'اسم المطعم',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                setState(() {
                  restaurants.add(value);
                });
              }
              Navigator.pop(context);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(int index) {
    final controller = TextEditingController(text: restaurants[index]);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تعديل المطعم'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'اسم المطعم',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                setState(() {
                  restaurants[index] = value;
                });
              }
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _deleteItem(int index) {
    setState(() {
      restaurants.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المطاعم'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      body: restaurants.isEmpty
          ? const Center(
              child: Text(
                'لا يوجد مطاعم حالياً',
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: restaurants.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
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
                      child: const Icon(Icons.storefront, color: Colors.pink),
                    ),
                    title: Text(
                      restaurants[index],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _showEditDialog(index),
                          icon: const Icon(Icons.edit, color: Colors.blue),
                        ),
                        IconButton(
                          onPressed: () => _deleteItem(index),
                          icon: const Icon(Icons.delete, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}