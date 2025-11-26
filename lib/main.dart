import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

// شاشات التطبيق
import 'screens/onboarding_slider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const BarakahApp());
}

class BarakahApp extends StatelessWidget {
  const BarakahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // ⭐️ السلايدر يظهر دائمًا
      home: OnboardingSlider(),

      routes: {
        '/home': (_) => const HomeScreen(),
      },
    );
  }
}
