import 'package:flutter/material.dart';
import '../widgets/glass_card.dart';
import '../widgets/background_wrapper.dart';
import 'main_screen.dart';

class WelcomeBarakahScreen extends StatelessWidget {
  const WelcomeBarakahScreen({super.key});

  static const Color pomegranate = Color(0xFFB11226);

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  "assets/images/icons/pomegranate.png",
                  height: 80,
                ),
                const SizedBox(height: 16),
                const Text(
                  "أهلاً بك في بركة ماركت",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: pomegranate,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "متعة التسوق تبدأ من هنا",
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pomegranate,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MainScreen(),
                      ),
                    );
                  },
                  child: const Text("ابدأ التسوق"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
