import 'package:flutter/material.dart';

class RestaurantCard extends StatelessWidget {
  final dynamic restaurant;

  const RestaurantCard({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    // جلب البيانات من الفيربيز باستخدام الحقول الصحيحة
    final String name = restaurant['title'] ?? 'بدون اسم';
    final String image = restaurant['image'] ?? '';

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        // تم تصحيح الخطأ هنا من CrossAttribute إلى CrossAxisAlignment
        crossAxisAlignment: CrossAxisAlignment.stretch, 
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              child: image.isNotEmpty
                  ? Image.network(
                      image, 
                      fit: BoxFit.cover,
                      // إضافة معالج خطأ في حال فشل تحميل الصورة
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.restaurant, color: Colors.grey),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}