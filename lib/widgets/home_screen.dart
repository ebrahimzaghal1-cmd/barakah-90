import 'package:flutter/material.dart';
import 'package:barakah90/widgets/category_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          const SizedBox(height: 50),

          // العنوان
          const Text(
            'التصنيفات',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          // الشبكة
       Expanded(
  child: StreamBuilder(
    stream: FirebaseFirestore.instance
        .collection('categories')
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return const Center(
          child: Text(
            'لا توجد تصنيفات',
            style: TextStyle(color: Colors.white),
          ),
        );
      }

      final docs = snapshot.data!.docs;

      return GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: docs.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1,
        ),
        itemBuilder: (context, index) {
          final item = docs[index];

          return CategoryCard(
            title: item['title'],
            image: item['image'],
            onTap: () {
              Navigator.pushNamed(
                context,
                '/products',
                arguments: item['title'],
              );
            },
          );
        },
      );
    },
  ),
),
        ],
      ),
    );
  }
}