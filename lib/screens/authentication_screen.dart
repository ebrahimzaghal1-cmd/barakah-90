import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/user_profile_service.dart';
import '../theme/app_theme.dart';
import '../navigation/main_navigation_bar.dart';
import '../widgets/barakah_brand.dart';

/// Customer sign-in and account creation in one place.
class AuthenticationScreen extends StatefulWidget {
  const AuthenticationScreen({super.key});

  @override
  State<AuthenticationScreen> createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController(text: '+970');
  final _auth = AuthService();
  bool _creatingAccount = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<String?> _askForCode() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('رمز التحقق'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'أدخل الرمز المرسل إلى هاتفك',
            prefixIcon: Icon(Icons.sms_outlined),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('تحقق')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  // يبقى التنفيذ جاهزًا للتفعيل مستقبلًا بعد تفعيل مزود SMS رسميًا.
  // ignore: unused_element
  Future<void> _signInWithPhone() async {
    final phone = _phone.text.replaceAll(' ', '').trim();
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('أدخل الرقم مع رمز الدولة، مثال: +970599123456')));
      return;
    }
    setState(() => _busy = true);
    try {
      UserCredential credential;
      if (kIsWeb) {
        final confirmation =
            await FirebaseAuth.instance.signInWithPhoneNumber(phone);
        if (!mounted) return;
        final code = await _askForCode();
        if (code == null || code.isEmpty) return;
        credential = await confirmation.confirm(code);
      } else {
        final completed = Completer<UserCredential>();
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: phone,
          verificationCompleted: (phoneCredential) async {
            if (!completed.isCompleted) {
              completed.complete(await FirebaseAuth.instance
                  .signInWithCredential(phoneCredential));
            }
          },
          verificationFailed: (error) {
            if (!completed.isCompleted) completed.completeError(error);
          },
          codeSent: (verificationId, _) async {
            if (!mounted) return;
            final code = await _askForCode();
            if (code == null || code.isEmpty) {
              if (!completed.isCompleted) {
                completed.completeError(StateError('تم إلغاء التحقق.'));
              }
              return;
            }
            final phoneCredential = PhoneAuthProvider.credential(
                verificationId: verificationId, smsCode: code);
            if (!completed.isCompleted) {
              completed.complete(await FirebaseAuth.instance
                  .signInWithCredential(phoneCredential));
            }
          },
          codeAutoRetrievalTimeout: (_) {},
        );
        credential = await completed.future;
      }
      final user = credential.user;
      if (user != null) {
        await UserProfileService().ensureCustomerProfile(user);
      }
      final issuedPin = _auth.lastIssuedBarakahPin;

      if (issuedPin != null && issuedPin.isNotEmpty && mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('بطاقة بركة جاهزة 🎉'),
            content: Text(
              'رقم البطاقة: ${_auth.lastBarakahCardNumber ?? ''}\n\n'
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

        _auth.clearIssuedBarakahPin();
      }

      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(switch (error.code) {
          'invalid-verification-code' => 'رمز التحقق غير صحيح.',
          'operation-not-allowed' =>
            'خدمة رسائل SMS غير مفعّلة بعد في إعدادات Firebase.',
          _ => error.message ?? 'تعذر التحقق من رقم الهاتف.',
        })));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر إتمام التحقق. حاول مرة أخرى.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (_creatingAccount) {
        final user = await _auth.signUp(
          _email.text,
          _password.text,
          displayName: _name.text,
        );

        if (user != null && mounted) {
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              title: const Text('أهلاً بك في بركة 🎁'),
              content: const Text(
                'تمت إضافة 50 نقطة هدية اشتراك إلى بطاقة بركة الخاصة بك.',
                textAlign: TextAlign.center,
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('ابدأ التسوق'),
                ),
              ],
            ),
          );
        }
      } else {
        await _auth.signIn(_email.text, _password.text);
      }

      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_messageFor(error))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('تعذر إتمام العملية. تأكد من اتصالك وحاول مجددًا.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('أدخل بريدك الإلكتروني أولاً ثم اضغط نسيت كلمة المرور.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم إرسال رابط استعادة كلمة المرور إلى بريدك.'),
        backgroundColor: Colors.green,
      ));
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.code == 'user-not-found'
              ? 'لا يوجد حساب مسجل بهذا البريد.'
              : (error.message ?? 'تعذر إرسال رابط الاستعادة.'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _messageFor(FirebaseAuthException error) => switch (error.code) {
        'invalid-email' => 'البريد الإلكتروني غير صالح.',
        'email-already-in-use' => 'هذا البريد مستخدم بالفعل.',
        'weak-password' => 'كلمة المرور يجب أن تتكون من 6 أحرف على الأقل.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
        'network-request-failed' =>
          'تعذر الاتصال بالخدمة. تحقق من الإنترنت ثم حاول مجددًا.',
        'too-many-requests' =>
          'محاولات كثيرة خلال وقت قصير. انتظر قليلًا ثم حاول مجددًا.',
        'operation-not-allowed' => 'طريقة تسجيل الدخول هذه غير مفعّلة حاليًا.',
        _ => error.message ?? 'حدث خطأ في تسجيل الدخول.',
      };

  @override
  Widget build(BuildContext context) {
    final title = _creatingAccount ? 'إنشاء حساب' : 'تسجيل الدخول';
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
      ),
      body: BarakahBrandBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.account_circle_outlined,
                      size: 76,
                      color: AppTheme.navy,
                    ),
                    const SizedBox(height: 20),
                    if (_creatingAccount) ...[
                      TextFormField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'الاسم'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'أدخل الاسم.'
                                : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration:
                          const InputDecoration(labelText: 'البريد الإلكتروني'),
                      validator: (value) =>
                          value == null || !value.contains('@')
                              ? 'أدخل بريدًا إلكترونيًا صالحًا.'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      onFieldSubmitted: (_) => _submit(),
                      decoration:
                          const InputDecoration(labelText: 'كلمة المرور'),
                      validator: (value) => value == null || value.length < 6
                          ? 'كلمة المرور 6 أحرف على الأقل.'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(title),
                    ),
                    if (!_creatingAccount)
                      TextButton(
                        onPressed: _busy ? null : _resetPassword,
                        child: const Text('نسيت كلمة المرور؟'),
                      ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(
                              () => _creatingAccount = !_creatingAccount),
                      child: Text(_creatingAccount
                          ? 'لديك حساب بالفعل؟ سجّل الدخول'
                          : 'ليس لديك حساب؟ أنشئ حسابًا'),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Row(children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('أو'),
                        ),
                        Expanded(child: Divider()),
                      ]),
                    ),
                    OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.phone_iphone_rounded),
                      label: const Text('الدخول برقم الهاتف — قريبًا'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute<void>(
                                  builder: (_) => const MainNavBar(),
                                ),
                                (route) => false,
                              ),
                      icon: const Icon(Icons.visibility_rounded),
                      label: const Text('الدخول بحساب ضيف'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'يمكنك التصفح كضيف، لكن الطلبات والنقاط وإضافة إعلانات المزاد تتطلب حساباً مسجلاً.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'التسجيل المتاح حاليًا بالبريد الإلكتروني، وتبقى الجلسة محفوظة على هذا الجهاز.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
