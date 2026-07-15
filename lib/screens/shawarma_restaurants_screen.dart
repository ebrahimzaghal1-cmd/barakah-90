import 'package:flutter/material.dart';

class ShawarmaRestaurantsScreen extends StatelessWidget {
  ShawarmaRestaurantsScreen({super.key});

  final List<Map<String, String>> items = [
    {"name": "شاورما القدس", "desc": "شاورما عربية – دجاج – لحم"},
    {"name": "شاورما لبنان", "desc": "سندويش – بروستد – بطاطا"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.pink,
        title: const Text("مطاعم الشاورما"),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return Card(
            child: ListTile(
              title: Text(items[index]["name"]!),
              subtitle: Text(items[index]["desc"]!),
            ),
          );
        },
      ),
    );
  }
}
