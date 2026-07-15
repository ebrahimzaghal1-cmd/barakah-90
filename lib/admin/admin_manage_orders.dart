import 'package:flutter/material.dart';

class AdminManageOrders extends StatefulWidget {
  const AdminManageOrders({super.key});

  @override
  State<AdminManageOrders> createState() => _AdminManageOrdersState();
}

class _AdminManageOrdersState extends State<AdminManageOrders> {
  final List<String> orders = [
    'طلب #1001',
    'طلب #1002',
    'طلب #1003',
  ];

  void _deleteItem(int index) {
    setState(() {
      orders.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الطلبات'),
        centerTitle: true,
      ),
      body: orders.isEmpty
          ? const Center(
              child: Text(
                'لا يوجد طلبات حالياً',
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
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
                      child: const Icon(Icons.receipt_long, color: Colors.pink),
                    ),
                    title: Text(
                      orders[index],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('يمكن حذف الطلب أو ربطه لاحقًا بقاعدة البيانات'),
                    trailing: IconButton(
                      onPressed: () => _deleteItem(index),
                      icon: const Icon(Icons.delete, color: Colors.red),
                    ),
                  ),
                );
              },
            ),
    );
  }
}