import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SectionCover extends StatelessWidget {
  const SectionCover({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            height: 132,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.coolYellow.withOpacity(.62),
                  Colors.white.withOpacity(.78),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              border: Border.all(color: Colors.white.withOpacity(.85)),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.58),
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(color: Color(0x1A1D2430), blurRadius: 14),
                  ],
                ),
                child: Icon(icon, size: 43, color: AppTheme.deepYellow),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.ink)),
                    const SizedBox(height: 5),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Color(0xFF4F5964),
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ]),
          ),
        ),
      );
}
