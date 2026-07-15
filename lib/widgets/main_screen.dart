import 'package:flutter/material.dart';
import '../widgets/glass_bottom_nav.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // 🔥 مهم للـ Glass
      body: const Center(
        child: Text(
          'محتوى الشاشة',
          style: TextStyle(color: Colors.white),
        ),
      ),
      bottomNavigationBar: GlassBottomNav(
        currentIndex: index,
        onTap: (i) {
          setState(() => index = i);
        },
      ),
    );
  }
}
