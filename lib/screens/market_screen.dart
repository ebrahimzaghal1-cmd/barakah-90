import 'package:flutter/material.dart';
import 'categories_screen.dart';
import '../widgets/category_item.dart';

class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key});

  static const categories = [
    {
      'title': 'مخبوزات',
      'image': 'assets/images/categories/bakery.jpg',
      'desc': 'أفضل المخبوزات الطازجة يوميًا',
    },
    {
      'title': 'دجاج',
      'image': 'assets/images/categories/chicken.jpg',
      'desc': 'منتجات دجاج طازجة ومتنوعة',
    },
    {
      'title': 'أسماك',
      'image': 'assets/images/categories/fish.jpg',
      'desc': 'أسماك ومأكولات بحرية طازجة',
    },
    {
      'title': 'خضار وفواكه',
      'image': 'assets/images/categories/fruits_veggies.jpg',
      'desc': 'خضار وفواكه طازجة يوميًا',
    },
    {
      'title': 'لحوم',
      'image': 'assets/images/categories/meat.jpg',
      'desc': 'أجود أنواع اللحوم الطازجة',
    },
    {
      'title': 'صيدلية',
      'image': 'assets/images/categories/pharmacy.jpg',
      'desc': 'منتجات صيدلانية واحتياجات يومية',
    },
    {
      'title': 'سوبرماركت',
      'image': 'assets/images/categories/supermarket.jpg',
      'desc': 'كل احتياجات المنزل والمواد الغذائية',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF6F8),
      body: SafeArea(
        child: GridView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (context, index) {
            final item = categories[index];
            return CategoryItem(
              title: item['title']!,
              image: item['image']!,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CategoriesScreen(
                      title: item['title']!,
                      image: item['image']!,
                      description: item['desc']!,
                    ),
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