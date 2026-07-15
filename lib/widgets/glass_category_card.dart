import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCategoryCard extends StatelessWidget {
  final String title;
  final String image;

  const GlassCategoryCard({
    super.key,
    required this.title,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        fit: StackFit.expand,
        children: [
          /// 🔹 الصورة (ضرورية قبل الـ Blur)
          Image.asset(
            image,
            fit: BoxFit.cover,
          ),

          /// 🔹 تغميق خفيف
          Container(
            color: Colors.black.withOpacity(0.2),
          ),

          /// 🔹 الزجاج الحقيقي
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withOpacity(0.25),
                ),
              ),
            ),
          ),

          /// 🔹 النص
          Center(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    blurRadius: 8,
                    color: Colors.black54,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
