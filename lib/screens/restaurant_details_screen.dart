import 'package:flutter/material.dart';

class RestaurantDetailsScreen extends StatelessWidget {
  final dynamic restaurant;

  const RestaurantDetailsScreen({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    // جلب البيانات بناءً على المسميات في قاعدة بياناتك
    final String name = restaurant['title'] ?? 'التفاصيل';
    final String image = restaurant['image'] ?? '';
    final String description = restaurant['description'] ?? 'لا يوجد وصف متوفر حالياً';

    return Scaffold(
      backgroundColor: Colors.white,
      // تم إلغاء الـ AppBar التقليدي واستبداله بتصميم عصري يظهر فوق الصورة
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // عرض الصورة في الأعلى
                if (image.isNotEmpty)
                  Image.network(
                    image,
                    width: double.infinity,
                    height: 300,
                    fit: BoxFit.cover,
                  )
                else
                  Container(
                    height: 300,
                    color: Colors.grey[300],
                    child: const Icon(Icons.restaurant, size: 100, color: Colors.white),
                  ),
                
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Divider(),
                      const SizedBox(height: 10),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[800],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // إضافة زر الرجوع يدوياً ليكون واضحاً جداً فوق الصورة
          Positioned(
            top: 50, // مسافة من الأعلى لتناسب حافة الهاتف
            right: 20, // جهة اليمين لأن التطبيق بالعربي
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5), // خلفية شبه شفافة لبيان الزر
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_ios, // سهم للرجوع يناسب اللغة العربية
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}