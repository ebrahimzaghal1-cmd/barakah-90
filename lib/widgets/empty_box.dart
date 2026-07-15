import 'package:flutter/material.dart';

class EmptyBox extends StatelessWidget {
  final String text;

  const EmptyBox({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black54,
        ),
      ),
    );
  }
}
