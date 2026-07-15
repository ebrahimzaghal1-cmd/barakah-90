import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:cloud_firestore/cloud_firestore.dart';

class SetupCategories extends StatefulWidget {
  const SetupCategories({super.key});

  @override
  State<SetupCategories> createState() => _SetupCategoriesState();
}

class _SetupCategoriesState extends State<SetupCategories> {
  bool _loading = false;

  Future<void> uploadDefaultCategories() async {
    final categories = [
      {"title": "مطاعم", "image": "restaurants"},
      {"title": "سوبرماركت", "image": "supermarket"},
      {"title": "خضار وفواكه", "image": "fruits"},
      {"title": "لحوم", "image": "meat"},
      {"title": "دجاج", "image": "chicken"},
      {"title": "أسماك", "image": "fish"},
      {"title": "مخبوزات", "image": "bakery"},
      {"title": "حلويات", "image": "sweets"},
      {"title": "مشروبات", "image": "drinks"},
      {"title": "صيدلية", "image": "pharmacy"},
      {"title": "ملابس", "image": "fashion"},
      {"title": "عناية وجمال", "image": "beauty"},
    ];

    try {
      setState(() => _loading = true);

      final ref = newMethod.collection("categories");

      for (var cat in categories) {
        await ref.add(cat);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🎉 تم رفع الأصناف بنجاح"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("حدث خطأ: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  FirebaseFirestore get newMethod => FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("إعداد الأصناف"),
        backgroundColor: Colors.pink,
        centerTitle: true,
      ),

      body: Center(
        child: _loading
            ? const CircularProgressIndicator(color: Colors.pink)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.category, size: 80, color: Colors.pink),
                  const SizedBox(height: 20),
                  const Text(
                    "رفع الأصناف الافتراضية",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 30),
                    child: Text(
                      "اضغط على الزر بالأسفل لرفع الأصناف الأساسية تلقائيًا إلى قاعدة البيانات.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // زر التنفيذ
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 40,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: uploadDefaultCategories,
                    child: const Text(
                      "رفع الأصناف الآن",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

