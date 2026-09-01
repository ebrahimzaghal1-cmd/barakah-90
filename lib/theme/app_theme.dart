import 'package:flutter/material.dart';

class AppTheme {
  static const Color coolYellow = Color(0xFFE8C64A);
  static const Color deepYellow = Color(0xFF9A7600);
  static const Color navy = Color(0xFF122447);
  static const Color ink = Colors.black;
  static const Color background = Color(0xFFFCFCFB);
  static const Color glass = Color(0xDFFFFFFF);

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: 'Cairo',
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: ColorScheme.fromSeed(
          seedColor: coolYellow,
          primary: deepYellow,
          secondary: coolYellow,
          surface: const Color(0xFFF8FAFC),
          onSurface: ink,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          surfaceTintColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.black),
          actionsIconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
              color: Colors.black, fontSize: 61, fontWeight: FontWeight.w800),
          displayMedium: TextStyle(
              color: Colors.black, fontSize: 48, fontWeight: FontWeight.w800),
          displaySmall: TextStyle(
              color: Colors.black, fontSize: 39, fontWeight: FontWeight.w800),
          headlineLarge: TextStyle(
              color: Colors.black, fontSize: 34, fontWeight: FontWeight.w800),
          headlineMedium: TextStyle(
              color: Colors.black, fontSize: 30, fontWeight: FontWeight.w800),
          headlineSmall: TextStyle(
              color: Colors.black, fontSize: 26, fontWeight: FontWeight.w800),
          titleLarge: TextStyle(
              color: Colors.black, fontSize: 24, fontWeight: FontWeight.w900),
          titleMedium: TextStyle(
              color: Colors.black, fontSize: 18, fontWeight: FontWeight.w800),
          titleSmall: TextStyle(
              color: Colors.black, fontSize: 15, fontWeight: FontWeight.w700),
          bodyLarge: TextStyle(
              color: Colors.black, fontSize: 17, fontWeight: FontWeight.w700),
          bodyMedium: TextStyle(
              color: Colors.black, fontSize: 15, fontWeight: FontWeight.w700),
          bodySmall: TextStyle(
              color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600),
          labelLarge: TextStyle(
              color: Colors.black, fontSize: 15, fontWeight: FontWeight.w800),
          labelMedium: TextStyle(
              color: Colors.black, fontSize: 13, fontWeight: FontWeight.w700),
          labelSmall: TextStyle(
              color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700),
        ),
        cardTheme: CardThemeData(
          color: Colors.white.withOpacity(.72),
          surfaceTintColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.black.withOpacity(.12),
          margin: const EdgeInsets.symmetric(vertical: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: Colors.white.withOpacity(.92),
              width: 1.2,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(.76),
          labelStyle: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
          hintStyle: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
          prefixIconColor: Colors.black.withOpacity(.70),
          suffixIconColor: Colors.black.withOpacity(.70),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(.95),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: Colors.black.withOpacity(.08),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: coolYellow,
              width: 1.4,
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: coolYellow,
            foregroundColor: navy,
            elevation: 10,
            shadowColor: Colors.black.withOpacity(.48),
            surfaceTintColor: const Color(0xFFFFE98B),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFFFFE98B), width: 1.4),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: coolYellow,
            foregroundColor: navy,
            elevation: 10,
            shadowColor: Colors.black.withOpacity(.48),
            surfaceTintColor: const Color(0xFFFFE98B),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFFFFE98B), width: 1.4),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black,
            backgroundColor: Colors.white,
            elevation: 7,
            shadowColor: Colors.black.withOpacity(.4),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            side: BorderSide(color: coolYellow.withOpacity(.75), width: 1.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          indicatorColor: coolYellow.withOpacity(.34),
          elevation: 12,
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? Colors.black
                  : Colors.black54,
            ),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: Colors.black,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w900
                  : FontWeight.w700,
            ),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white.withOpacity(.94),
          surfaceTintColor: Colors.white,
          elevation: 12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: BorderSide(
              color: Colors.white.withOpacity(.95),
              width: 1.2,
            ),
          ),
          titleTextStyle: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
          contentTextStyle: const TextStyle(
            color: Colors.black87,
            fontSize: 15,
            height: 1.45,
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFAFFFFFF),
          surfaceTintColor: Colors.white,
          modalBackgroundColor: Color(0xFAFFFFFF),
          showDragHandle: true,
        ),
        listTileTheme: const ListTileThemeData(
          textColor: Colors.black,
          iconColor: Colors.black87,
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
          ),
          subtitleTextStyle: TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        expansionTileTheme: const ExpansionTileThemeData(
          textColor: Colors.black,
          collapsedTextColor: Colors.black,
          iconColor: deepYellow,
          collapsedIconColor: Colors.black54,
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: Colors.white.withOpacity(.97),
          surfaceTintColor: Colors.white,
          textStyle: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: coolYellow,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: navy,
          contentTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
}
