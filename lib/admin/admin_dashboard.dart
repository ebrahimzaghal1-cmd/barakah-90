import 'package:flutter/material.dart';
import 'admin_manage_categories.dart';
import 'admin_manage_products.dart';
import 'admin_manage_restaurants.dart';
import 'admin_manage_orders.dart';
import 'admin_add_item_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _AdminItem(
        title: 'إدارة المطاعم',
        icon: Icons.storefront,
        page: const AdminManageRestaurants(),
      ),
      _AdminItem(
        title: 'إدارة التصنيفات',
        icon: Icons.category,
        page: const AdminManageCategories(),
      ),
      _AdminItem(
        title: 'إدارة المنتجات',
        icon: Icons.fastfood,
        page: const AdminManageProducts(),
      ),
      _AdminItem(
        title: 'إدارة الطلبات',
        icon: Icons.receipt_long,
        page: const AdminManageOrders(),
      ),
      _AdminItem(
        title: 'إضافة مطعم / متجر',
        icon: Icons.add_business,
        page: const AdminAddItemScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم الأدمن'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.9,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return _AdminCard(
              title: item.title,
              icon: item.icon,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => item.page,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AdminItem {
  final String title;
  final IconData icon;
  final Widget page;

  _AdminItem({
    required this.title,
    required this.icon,
    required this.page,
  });
}

class _AdminCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _AdminCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: Colors.pink.withOpacity(0.12),
              child: Icon(
                icon,
                size: 34,
                color: Colors.pink,
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}