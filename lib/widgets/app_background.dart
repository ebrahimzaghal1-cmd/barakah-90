import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/backgrounds/bg_pomegranate.png',
            fit: BoxFit.cover,
          ),
        ),

        // طبقة تفتيح خفيفة (glass feel)
        Positioned.fill(
          child: Container(
            color: Colors.white.withOpacity(0.82),
          ),
        ),

        child,
      ],
    );
  }
}
