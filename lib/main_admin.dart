import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'admin/admin_dashboard.dart';
import 'firebase_options.dart';
import 'services/admin_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await AdminNotificationService.instance.initialize();

  runApp(const BarakahAdminApp());
}

class BarakahAdminApp extends StatelessWidget {
  const BarakahAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'إدارة بركة',
      locale: const Locale('ar'),
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFFFC107),
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
      ),
      home: const AdminAuthGate(),
    );
  }
}

class AdminAuthGate extends StatelessWidget {
  const AdminAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final user = authSnapshot.data;

        if (user == null) {
          return const AdminLoginScreen();
        }

        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen();
            }

            if (profileSnapshot.hasError) {
              return _AccessErrorScreen(
                message: 'تعذر التحقق من صلاحية الحساب.',
                onLogout: () => FirebaseAuth.instance.signOut(),
              );
            }

            final data = profileSnapshot.data?.data();
            final role = data?['role']?.toString().trim().toLowerCase();

            if (role != 'admin') {
              return _AccessErrorScreen(
                message: 'هذا الحساب لا يملك صلاحية دخول لوحة إدارة بركة.',
                onLogout: () => FirebaseAuth.instance.signOut(),
              );
            }

            return const _AdminDashboardWithNotifications();
          },
        );
      },
    );
  }
}

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'أدخلي البريد الإلكتروني وكلمة المرور.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = switch (error.code) {
          'invalid-credential' => 'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
          'user-not-found' => 'الحساب غير موجود.',
          'wrong-password' => 'كلمة المرور غير صحيحة.',
          'too-many-requests' => 'محاولات كثيرة. حاولي لاحقًا.',
          _ => 'تعذر تسجيل الدخول. (${error.code})',
        };
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'حدث خطأ أثناء تسجيل الدخول.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Card(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.admin_panel_settings_rounded,
                        size: 72,
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'لوحة إدارة بركة',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'دخول الإدارة فقط',
                        style: TextStyle(
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: _hidePassword,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _loading ? null : _login(),
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _hidePassword = !_hidePassword;
                              });
                            },
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _login,
                          icon: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.login),
                          label: Text(
                            _loading ? 'جاري التحقق...' : 'دخول لوحة الإدارة',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _AccessErrorScreen extends StatelessWidget {
  const _AccessErrorScreen({
    required this.message,
    required this.onLogout,
  });

  final String message;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_person_outlined,
                    size: 72,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout),
                    label: const Text('تسجيل الخروج'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _AdminDashboardWithNotifications extends StatefulWidget {
  const _AdminDashboardWithNotifications();

  @override
  State<_AdminDashboardWithNotifications> createState() =>
      _AdminDashboardWithNotificationsState();
}

class _AdminDashboardWithNotificationsState
    extends State<_AdminDashboardWithNotifications> {
  bool _busy = false;

  Future<void> _enableNotifications() async {
    if (_busy) return;

    setState(() => _busy = true);

    final ok = await AdminNotificationService.instance
        .requestPermissionForCurrentUser();

    if (!mounted) return;

    final message = ok
        ? 'تم تفعيل إشعارات لوحة الأدمن ✅'
        : AdminNotificationService.instance.permissionFailureMessage;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );

    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const AdminDashboard(),
        Positioned(
          left: 18,
          bottom: 18,
          child: SafeArea(
            child: FloatingActionButton.extended(
              heroTag: 'admin-notifications-button',
              onPressed: _busy ? null : _enableNotifications,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.notifications_active_outlined),
              label: Text(
                _busy ? 'جاري التفعيل...' : 'تفعيل الإشعارات',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
