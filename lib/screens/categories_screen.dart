import 'package:flutter/material.dart';

class CategoriesScreen extends StatelessWidget {
  CategoriesScreen({super.key});

  final List<Map<String, String>> categories = [
    {"title": "مخبوزات", "image": "assets/images/categories/bakery.jpg"},
    {"title": "دجاج", "image": "assets/images/categories/chicken.jpg"},
    {"title": "أزياء", "image": "assets/images/categories/fashion.jpg"},
    {"title": "أسماك", "image": "assets/images/categories/fish.jpg"},
    {"title": "خضار وفواكه", "image": "assets/images/categories/fruits_veggies.jpg"},
    {"title": "لحوم", "image": "assets/images/categories/meat.jpg"},
    {"title": "صيدلية", "image": "assets/images/categories/pharmacy.jpg"},
    {"title": "مطاعم", "image": "assets/images/categories/restaurants.jpg"},
    {"title": "سوبرماركت", "image": "assets/images/categories/supermarket.jpg"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("التصنيفات"),
        backgroundColor: Colors.pink,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,       // 3 أعمدة
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          return InkWell(
            onTap: () {
              // هنا ننتقل لصفحة المنتجات لاحقًا
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(1, 2),
                  )
                ],
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Image.asset(
                        categories[index]["image"]!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Text(
                      categories[index]["title"]!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
