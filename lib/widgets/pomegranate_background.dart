import 'dart:ui';
import 'package:flutter/material.dart';

class PomegranateBackground extends StatelessWidget {
  const PomegranateBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/backgrounds/pomegranate.png',
            fit: BoxFit.cover,
          ),
        ),

        // تعتيم خفيف
        Positioned.fill(
          child: Container(color: Colors.black.withOpacity(0.25)),
        ),

        // Blur خفيف
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }
}
