import 'package:flutter/material.dart';

class BarakahBackground extends StatelessWidget {
  final Widget child;

  const BarakahBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // الخلفية - صورة الرمان شفافة
        Opacity(
          opacity: 0.07,
          child: Center(
            child: Image.asset(
              "assets/images/backgrounds/pomegranate.png",
              width: 450,
              fit: BoxFit.contain,
            ),
          ),
        ),

        // المحتوى فوق الخلفية
        child,
      ],
    );
  }
}
