import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // المكتبة الأساسية للربط
import 'navigation/main_navigation_bar.dart';
import 'services/upload_data.dart';
import 'firebase_options.dart'; // الملف الذي يتم إنشاؤه تلقائياً بواسطة FlutterFire CLI

void main() async {
  // 1. التأكد من تهيئة أدوات فلاتر
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 2. تهيئة Firebase - الخطوة التي كانت مفقودة في لقطة الشاشة 2.21.14 ص
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // 3. رفع البيانات (يفضل تشغيلها مرة واحدة فقط ثم إغلاقها)
    // await uploadRestaurants(); 
    
  } catch (e) {
    print("خطأ في تهيئة Firebase: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Barakah App',
      home: MainNavBar(), // يفتح على الواجهة التي رأيناها في لقطات الشاشة السابقة
    );
  }
}