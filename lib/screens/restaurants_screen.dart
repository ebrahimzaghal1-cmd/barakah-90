import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'restaurant_details_screen.dart';
import '../widgets/restaurant_card.dart';

class RestaurantsScreen extends StatelessWidget {
  const RestaurantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("الرئيسية", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- قسم التصنيفات (أفقي) ---
            const Padding(
              padding: EdgeInsets.all(15.0),
              child: Text("التصنيفات", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              height: 100,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('categories').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: snapshot.data!.docs.length,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemBuilder: (context, index) {
                      var category = snapshot.data!.docs[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: NetworkImage(category['image'] ?? ''),
                            ),
                            const SizedBox(height: 5),
                            Text(category['name'] ?? '', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const Divider(),

            // --- قسم المطاعم (شبكة) ---
            const Padding(
              padding: EdgeInsets.all(15.0),
              child: Text("كل المطاعم", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('items').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("لا توجد مطاعم حالياً"));
                }

                return GridView.builder(
                  shrinkWrap: true, // مهم جداً داخل SingleChildScrollView
                  physics: const NeverScrollableScrollPhysics(), // تعطيل السكرول الداخلي
                  padding: const EdgeInsets.all(10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var restaurantDoc = snapshot.data!.docs[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RestaurantDetailsScreen(restaurant: restaurantDoc),
                          ),
                        );
                      },
                      child: RestaurantCard(restaurant: restaurantDoc),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}