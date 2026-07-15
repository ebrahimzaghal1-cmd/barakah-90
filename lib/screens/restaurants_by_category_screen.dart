import 'package:flutter/material.dart';

class RestaurantsScreen extends StatelessWidget {
  const RestaurantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("المطاعم"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _restaurantCard("مطعم الشام", "أكل شرقي"),
          _restaurantCard("بيتزا تايم", "بيتزا"),
          _restaurantCard("برغر كينغ", "وجبات سريعة"),
        ],
      ),
    );
  }

  Widget _restaurantCard(String name, String type) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: const Icon(Icons.restaurant),
        title: Text(name),
        subtitle: Text(type),
        trailing: const Icon(Icons.arrow_forward_ios),
      ),
    );
  }
}
