import 'package:flutter/material.dart';
import '../widgets/glass_bottom_nav.dart';
import '../widgets/app_background.dart';

import 'home_screen.dart';
import 'cart_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> pages = [
    const HomeScreen(),
    const CartScreen(),
  ];

  int get _safeCurrentIndex =>
      _currentIndex.clamp(0, pages.length - 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: pages[_safeCurrentIndex],
      ),
      bottomNavigationBar: GlassBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index < 0 || index >= pages.length) return;
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}

class ProfileScreen {
  const ProfileScreen();
}
