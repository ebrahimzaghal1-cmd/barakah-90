import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'restaurants_screen.dart'; // للانتقال للمطاعم بعد اختيار التصنيف

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("التصنيفات"),
        backgroundColor: Colors.black,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // هنا نربط التطبيق بمجموعة التصنيفات التي يضيفها الأدمن
        stream: FirebaseFirestore.instance.collection('categories').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("لا توجد تصنيفات حالياً"));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var category = snapshot.data!.docs[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(category['image'] ?? ''),
                ),
                title: Text(category['name'] ?? 'بدون اسم'),
                onTap: () {
                  // عند الضغط على تصنيف (مثل "مطاعم")، يفتح صفحة المطاعم
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RestaurantsScreen()),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}