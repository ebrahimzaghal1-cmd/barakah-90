import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barakah'),
      ),
      body: const Center(
        child: Text(
          'Barakah App Clean Version',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
