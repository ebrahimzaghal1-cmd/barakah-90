import 'package:flutter/material.dart';

import '../models/home_strip_card_style.dart';

class HomeStripCardFrame extends StatelessWidget {
  const HomeStripCardFrame({
    super.key,
    required this.style,
    required this.child,
    required this.borderColor,
  });

  final HomeStripCardStyle style;
  final Widget child;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final shape = style.isCircle ? BoxShape.circle : BoxShape.rectangle;
    final radius = style.isCircle ? null : style.borderRadius;

    return Container(
      width: style.width,
      height: style.height,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: shape,
        borderRadius: radius,
        border: Border.all(
          color: borderColor,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(.50),
            blurRadius: 11,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: borderColor.withOpacity(.18),
            blurRadius: 14,
          ),
          BoxShadow(
            color: const Color(0xFF061326).withOpacity(.20),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: style.clip(
        Stack(
          fit: StackFit.expand,
          children: [
            child,
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0, .20, .45, .75, 1],
                    colors: [
                      Colors.white.withOpacity(.34),
                      Colors.white.withOpacity(.10),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.white.withOpacity(.05),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
