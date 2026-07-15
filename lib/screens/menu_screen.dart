import 'package:flutter/material.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.pink,
        title: const Text("العروض"),
      ),
      body: const Center(
        child: Text(
          "لا توجد عروض حالياً",
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
