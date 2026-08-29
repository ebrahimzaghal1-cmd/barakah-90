import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/driver_service.dart';
import '../theme/app_theme.dart';
import 'authentication_screen.dart';

class DriverRegistrationScreen extends StatefulWidget {
  const DriverRegistrationScreen({super.key});

  @override
  State<DriverRegistrationScreen> createState() =>
      _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen> {
  static const _agreementVersion = '2026-08-17-v1';

  final _formKey = GlobalKey<FormState>();

  final fullName = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final nationalId = TextEditingController();
  final vehicle = TextEditingController();
  final driverLicenseNumber = TextEditingController();
  final vehicleLicenseNumber = TextEditingController();
  final vehicleInsuranceNumber = TextEditingController();
  final payoutMethod = TextEditingController();
  final payoutAccount = TextEditingController();

  bool acceptedDriverTerms = false;
  bool acceptedPrivacyPolicy = false;
  bool saving = false;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  void _syncUserFields() {
    final user = _currentUser;

    if (user == null) return;

    if (fullName.text.trim().isEmpty) {
      fullName.text = user.displayName?.trim() ?? '';
    }

    if (email.text.trim().isEmpty) {
      email.text = user.email?.trim() ?? '';
    }
  }

  Future<void> _openAuthentication() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AuthenticationScreen(),
      ),
    );

    if (!mounted) return;

    setState(() {
      _syncUserFields();
    });
  }

  @override
  void initState() {
    super.initState();
    _syncUserFields();
  }

  @override
  void dispose() {
    fullName.dispose();
    email.dispose();
    phone.dispose();
    nationalId.dispose();
    vehicle.dispose();
    driverLicenseNumber.dispose();
    vehicleLicenseNumber.dispose();
    vehicleInsuranceNumber.dispose();
    payoutMethod.dispose();
    payoutAccount.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'هذا الحقل مطلوب';
    }
    return null;
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'سجّل حسابًا في بركة أولًا ثم أرسل الطلب.',
          ),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (!acceptedDriverTerms || !acceptedPrivacyPolicy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يجب الموافقة على شروط السائق وسياسة الخصوصية.',
          ),
        ),
      );
      return;
    }

    setState(() => saving = true);

    try {
      await DriverService().apply(
        fullName: fullName.text,
        email: email.text,
        phone: phone.text,
        nationalId: nationalId.text,
        vehicle: vehicle.text,
        driverLicenseNumber: driverLicenseNumber.text,
        vehicleLicenseNumber: vehicleLicenseNumber.text,
        vehicleInsuranceNumber: vehicleInsuranceNumber.text,
        payoutMethod: payoutMethod.text,
        payoutAccount: payoutAccount.text,
        acceptedDriverTerms: acceptedDriverTerms,
        acceptedPrivacyPolicy: acceptedPrivacyPolicy,
        agreementVersion: _agreementVersion,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إرسال طلبك للأدمن للمراجعة والتوثيق ✅',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Bad state: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: const Text(
          'الاشتراك كسائق بركة',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 36),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppTheme.navy,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.delivery_dining_rounded,
                      size: 76,
                      color: AppTheme.coolYellow,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'انضم إلى سائقي بركة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'أدخل بياناتك بدقة ليقوم الأدمن بمراجعتها وتوثيقها.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (_currentUser == null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7D6),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.coolYellow.withOpacity(.65),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'حتى نرسل طلبك باسمك ونحفظه بأمان، أنشئ حساب بركة أو سجّل الدخول أولًا.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.navy,
                          fontWeight: FontWeight.w800,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _openAuthentication,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.coolYellow,
                            foregroundColor: AppTheme.navy,
                          ),
                          icon: const Icon(Icons.login_rounded),
                          label: const Text(
                            'تسجيل الدخول / إنشاء حساب',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              _sectionTitle('البيانات الشخصية'),
              TextFormField(
                controller: fullName,
                validator: _required,
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: email,
                validator: _required,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phone,
                validator: _required,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nationalId,
                validator: _required,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'رقم الهوية',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 22),
              _sectionTitle('بيانات المركبة والرخص'),
              TextFormField(
                controller: vehicle,
                validator: _required,
                decoration: const InputDecoration(
                  labelText: 'نوع المركبة ورقمها',
                  prefixIcon: Icon(Icons.two_wheeler_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: driverLicenseNumber,
                validator: _required,
                decoration: const InputDecoration(
                  labelText: 'رقم رخصة القيادة',
                  prefixIcon: Icon(Icons.credit_card_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: vehicleLicenseNumber,
                validator: _required,
                decoration: const InputDecoration(
                  labelText: 'رقم رخصة المركبة',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: vehicleInsuranceNumber,
                decoration: const InputDecoration(
                  labelText: 'رقم التأمين — إن وجد',
                  prefixIcon: Icon(Icons.verified_user_outlined),
                ),
              ),
              const SizedBox(height: 22),
              _sectionTitle('بيانات استلام المستحقات'),
              TextFormField(
                controller: payoutMethod,
                validator: _required,
                decoration: const InputDecoration(
                  labelText: 'طريقة استلام المستحقات',
                  hintText: 'بنك / محفظة / طريقة أخرى',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: payoutAccount,
                validator: _required,
                decoration: const InputDecoration(
                  labelText: 'رقم الحساب / IBAN / رقم المحفظة',
                  prefixIcon: Icon(Icons.account_balance_outlined),
                ),
              ),
              const SizedBox(height: 22),
              _sectionTitle('الموافقات'),
              CheckboxListTile(
                value: acceptedDriverTerms,
                onChanged: (value) {
                  setState(() {
                    acceptedDriverTerms = value == true;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'قرأت وأوافق على شروط سائق بركة',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: const Text(
                  'الإصدار 2026-08-17-v1',
                ),
              ),
              CheckboxListTile(
                value: acceptedPrivacyPolicy,
                onChanged: (value) {
                  setState(() {
                    acceptedPrivacyPolicy = value == true;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'قرأت وأوافق على سياسة الخصوصية',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: saving
                      ? null
                      : _currentUser == null
                          ? _openAuthentication
                          : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.navy,
                    foregroundColor: Colors.white,
                  ),
                  icon: saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    saving
                        ? 'جارٍ إرسال الطلب...'
                        : _currentUser == null
                            ? 'سجّل أو أنشئ حسابًا للمتابعة'
                            : 'إرسال طلب الاشتراك',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'لن يتم تفعيل حساب السائق إلا بعد مراجعة الأدمن للبيانات والوثائق المطلوبة.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  height: 1.5,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 10,
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.navy,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
