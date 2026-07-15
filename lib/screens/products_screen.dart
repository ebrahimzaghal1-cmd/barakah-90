import 'package:flutter/material.dart';
import '../widgets/category_card.dart';

class ProductsScreen extends StatelessWidget {
  final String category;

  const ProductsScreen({
    super.key,
    required this.category,
  });

  final List<Map<String, String>> products = const [
    {"title": "برغر دجاج", "image": "assets/images/products/burger.jpg"},
    {"title": "بيتزا", "image": "assets/images/products/pizza.jpg"},
    {"title": "قهوة", "image": "assets/images/products/coffee.jpg"},
    {"title": "شاورما", "image": "assets/images/products/shawarma.jpg"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(category)),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: products.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemBuilder: (context, index) {
          final item = products[index];

          return CategoryCard(
            title: item['title']!,
            image: item['image']!,
            onTap: () {
              // لاحقًا تفتح ProductDetailsScreen
            },
          );
        },
      ),
    );
  }
}
