import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إنشاء حساب")),
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
                final navigator = Navigator.of(context);
                try {
                  await auth.signUp(email.text, password.text);
                  if (!context.mounted) return;

                  final issuedPin = auth.lastIssuedBarakahPin;

                  if (issuedPin != null && issuedPin.isNotEmpty) {
                    await showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('بطاقة بركة جاهزة 🎉'),
                        content: Text(
                          'رقم البطاقة: ${auth.lastBarakahCardNumber ?? ''}\n\n'
                          'الرقم السري (PIN): $issuedPin\n\n'
                          'احتفظ بهذا الرقم السري. لن يتم عرضه مرة أخرى، ويمكنك تغييره لاحقًا من صفحتي.',
                        ),
                        actions: [
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('تم الحفظ'),
                          ),
                        ],
                      ),
                    );

                    auth.clearIssuedBarakahPin();
                  }

                  if (!mounted) return;
                  navigator.pushReplacementNamed('/home');
                } catch (e) {
                  print(e);
                }
              },
              child: const Text("إنشاء حساب"),
            ),
          ],
        ),
      ),
    );
  }
}
