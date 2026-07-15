import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> uploadRestaurants() async {
  final firestore = FirebaseFirestore.instance;

  // تأكد من وضع الروابط الحقيقية التي نسختها من Firebase Storage هنا
  final List<Map<String, dynamic>> restaurants = [
    {
      "name": "دجاج مقلي", 
      "image": "ضع_هنا_رابط_الصورة_من_storage",
      "rating": "أفضل مطعم", // لإظهار النص الذي رأيناه في تصاميمك السابقة
    },
    {
      "name": "شاورما الشام", 
      "image": "ضع_هنا_رابط_الصورة_من_storage",
      "rating": "أفضل مطعم",
    },
  ];

  // فحص بسيط لمنع التكرار
  final existing = await firestore.collection('restaurants').limit(1).get();
  if (existing.docs.isEmpty) {
    for (var restaurant in restaurants) {
      await firestore.collection('restaurants').add(restaurant);
    }
    print("✅ تم رفع المطاعم بنجاح");
  } else {
    print("⚠️ البيانات موجودة مسبقاً في Firebase، لن يتم الرفع لتوفير المساحة");
  }
}