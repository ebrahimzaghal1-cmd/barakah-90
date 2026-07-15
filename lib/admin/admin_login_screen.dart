import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController userCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل دخول الأدمن")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: userCtrl,
              decoration: const InputDecoration(labelText: "البريد الإلكتروني"),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: "كلمة المرور"),
            ),
            const SizedBox(height: 32),
            isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: loginAdmin,
                      child: const Text("تسجيل الدخول"),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> loginAdmin() async {
    setState(() {
      isLoading = true;
    });

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: userCtrl.text.trim(),
        password: passCtrl.text.trim(),
      );

      if (!mounted) return;

      // تحقق إذا المستخدم مسموح له بالدخول (هنا البريد الأدمن)
      const adminUserEmail = "admin@example.com"; // عدل البريد للأدمن الحقيقي
      if (userCredential.user != null && userCtrl.text.trim() == adminUserEmail) {
        Navigator.pushReplacementNamed(context, "/admin-dashboard");
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("غير مسموح بالدخول")),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ في تسجيل الدخول: ${e.message}")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
}