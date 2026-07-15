import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:barakah90/widgets/category_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  final List<String> homeBanners = [
    'assets/images/banners/banner1.jpg',
    'assets/images/banners/banner2.jpg',
    'assets/images/banners/banner3.jpg',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // الخلفية
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/welcome_pomegranate.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // تعتيم خفيف
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.15),
            ),
          ),

          // الشيت
          DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.45,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    color: Colors.white.withOpacity(0.85),
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        // المقبض
                        Center(
                          child: Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey[400],
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        const Text(
                          'التصنيفات',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),

                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2, // عرض عنصرين مثل شاشة المنتجات
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.8,
                          ),
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final item = categories[index];
                            return CategoryCard(
                              title: item['title']!,
                              image: item['image']!,
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/products',
                                  arguments: item['title'],
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

final List<Map<String, String>> categories = [
  {'title': 'مطاعم', 'image': 'assets/images/categories/restaurants.jpg'},
  {'title': 'مخبوزات', 'image': 'assets/images/categories/bakery.jpg'},
  {'title': 'دجاج', 'image': 'assets/images/categories/chicken.jpg'},
  {'title': 'لحوم', 'image': 'assets/images/categories/meat.jpg'},
  {
    'title': 'خضار وفواكه',
    'image': 'assets/images/categories/fruits_veggies.jpg'
  },
  {'title': 'أسماك', 'image': 'assets/images/categories/fish.jpg'},
  {'title': 'صيدلية', 'image': 'assets/images/categories/pharmacy.jpg'},
  {'title': 'سوبرماركت', 'image': 'assets/images/categories/supermarket.jpg'},
];