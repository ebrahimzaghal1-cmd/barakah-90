import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firebase_state.dart';
import '../theme/app_theme.dart';
import '../widgets/barakah_brand.dart';
import '../widgets/restaurant_card.dart';
import 'restaurant_details_screen.dart';

class ProductsScreen extends StatelessWidget {
  final String category;
  final String itemType;

  const ProductsScreen({
    super.key,
    required this.category,
    this.itemType = 'market',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(category)),
      backgroundColor: Colors.transparent,
      body: BarakahBrandBackdrop(
        child: !FirebaseState.isReady
            ? const Center(
                child: Text('تتوفر المنتجات بعد ربط قاعدة البيانات.'))
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream:
                    FirebaseFirestore.instance.collection('items').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final products = (snapshot.data?.docs ?? []).where((doc) {
                    final data = doc.data();
                    return data['category']?.toString().trim() == category &&
                        data['type']?.toString().toLowerCase() == itemType &&
                        data['kind']?.toString() != 'product';
                  }).toList();
                  if (products.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                            itemType == 'restaurant'
                                ? 'لا توجد مطاعم مضافة في قسم $category حالياً.'
                                : 'لا توجد محلات أو منتجات مضافة في قسم $category حالياً.',
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    );
                  }
                  return LayoutBuilder(builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 700 ? 3 : 2;
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: products.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: .66,
                      ),
                      itemBuilder: (context, index) => GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => RestaurantDetailsScreen(
                                    restaurant: products[index]))),
                        child: RestaurantCard(restaurant: products[index]),
                      ),
                    );
                  });
                },
              ),
      ),
    );
  }
}
