import 'package:flutter/material.dart';

class PizzaRestaurantsScreen extends StatelessWidget {
  PizzaRestaurantsScreen({super.key});

  final List<Map<String, String>> items = [
    {"name": "بيتزا هت", "desc": "بيتزا – باستا"},
    {"name": "بيتزا هوم", "desc": "بيتزا – لازانيا"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.pink,
        title: const Text("مطاعم البيتزا"),
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
