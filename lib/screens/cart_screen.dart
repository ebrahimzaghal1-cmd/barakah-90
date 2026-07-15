import 'package:flutter/material.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("السلة"),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.shopping_cart, size: 70, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              "السلة فارغة حالياً 🛒",
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}