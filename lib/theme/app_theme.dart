import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryPink = Color(0xFFFF2FAE); // فوشي
  static const Color gold = Color(0xFFFFD700);        // ذهبي
  static const Color blackBG = Color(0xFF0D0D0D);     // أسود أنيق

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: blackBG,
    primaryColor: primaryPink,
    fontFamily: "Cairo",

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: gold,
        fontSize: 26,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(
        color: primaryPink,
        size: 28,
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      selectedItemColor: primaryPink,
      unselectedItemColor: Colors.white70,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),
  );
}
