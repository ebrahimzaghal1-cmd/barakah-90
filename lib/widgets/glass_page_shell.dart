import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GlassPageShell extends StatelessWidget {
  final String title;
  final Widget child;

  const GlassPageShell({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFFCFCFB), Color(0xFFF7F4EC)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.075),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: AppTheme.coolYellow.withOpacity(.36),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x73000000),
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                    BoxShadow(
                      color: Color(0x33FFFFFF),
                      blurRadius: 2,
                      offset: Offset(0, -1),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
