import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل الدخول")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: "الإيميل"),
            ),
            TextField(
              controller: password,
              decoration: const InputDecoration(labelText: "كلمة المرور"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                try {
                  await auth.signIn(email.text, password.text);
                  Navigator.pushReplacementNamed(context, '/home');
                } catch (e) {
                  print(e);
                }
              },
              child: const Text("دخول"),
            ),

            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/signup'),
              child: const Text("إنشاء حساب"),
            )
          ],
        ),
      ),
    );
  }
}
