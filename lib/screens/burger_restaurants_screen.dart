import 'package:flutter/material.dart';

class BurgerRestaurantsScreen extends StatelessWidget {
  BurgerRestaurantsScreen({super.key});

  final List<Map<String, String>> items = [
    {"name": "برغر كينغ", "desc": "برغر – وجبات سريعة"},
    {"name": "ماكدونالدز", "desc": "برغر – بطاطا – صوصات"},
    {"name": "بورغر فاكتوري", "desc": "برغر مشوي – صوصات مميزة"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.pink,
        title: const Text("مطاعم البرغر"),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return Card(
            elevation: 3,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              title: Text(
                items[index]["name"]!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(items[index]["desc"]!),
            ),
          );
        },
      ),
    );
  }
}
