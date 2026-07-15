import 'package:flutter/material.dart';

class CoffeeRestaurantsScreen extends StatelessWidget {
  CoffeeRestaurantsScreen({super.key});

  final List<Map<String, String>> items = [
    {"name": "كوفي كورنر", "desc": "قهوة – حلويات – دونات"},
    {"name": "كافيه روز", "desc": "لاتيه – كابتشينو – موكا"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.pink,
        title: const Text("القهوة"),
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
