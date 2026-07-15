import 'package:flutter/material.dart';

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

      // 🔥 بدون blur
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.grey[100], // خلفية نظيفة بدل البلور
        child: child,
      ),
    );
  }
}