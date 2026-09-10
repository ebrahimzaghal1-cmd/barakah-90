import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/agent_registration_service.dart';
import '../theme/app_theme.dart';
import 'authentication_screen.dart';

class AgentRegistrationScreen extends StatefulWidget {
  const AgentRegistrationScreen({super.key});

  @override
  State<AgentRegistrationScreen> createState() =>
      _AgentRegistrationScreenState();
}

class _AgentRegistrationScreenState extends State<AgentRegistrationScreen> {
  static const _agreementVersion = '2026-09-10-v1';

  static const _areas = <String>[
    'طولكرم',
    'الشعراوية',
    'قلقيلية',
    'رام الله',
    'نابلس',
    'الخليل',
    'القدس',
  ];

  final _formKey = GlobalKey<FormState>();

  final fullName = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final nationalId = TextEditingController();
  final locationLabel = TextEditingController();
  final payoutMethod = TextEditingController();
  final payoutAccount = TextEditingController();

  String? selectedArea;
  double? latitude;
  double? longitude;

  bool acceptedAgentTerms = false;
  bool acceptedPrivacyPolicy = false;
  bool locating = false;
  bool saving = false;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _syncUserFields();
  }

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

    setState(_syncUserFields);
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'هذا الحقل مطلوب';
    }
    return null;
  }

  Future<void> _useCurrentLocation() async {
    if (locating) return;

    setState(() => locating = true);

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();

      if (!enabled) {
        throw StateError('فعّل خدمة الموقع في الجهاز أولًا.');
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('يجب السماح لبركة باستخدام الموقع.');
      }

      final position = await Geolocator.getCurrentPosition();

      if (!mounted) return;

      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;

        if (locationLabel.text.trim().isEmpty) {
          locationLabel.text = '${position.latitude.toStringAsFixed(5)}, '
              '${position.longitude.toStringAsFixed(5)}';
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديد موقعك بنجاح ✅'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Bad state: ', ''),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => locating = false);
      }
    }
  }

  Future<void> _submit() async {
    final user = _currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('سجّل حسابًا في بركة أولًا ثم أرسل الطلب.'),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (selectedArea == null || selectedArea!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختر المنطقة.'),
        ),
      );
      return;
    }

    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب تحديد موقعك قبل إرسال الطلب.'),
        ),
      );
      return;
    }

    if (!acceptedAgentTerms || !acceptedPrivacyPolicy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يجب الموافقة على شروط الوسيطة وسياسة الخصوصية.',
          ),
        ),
      );
      return;
    }

    setState(() => saving = true);

    try {
      await AgentRegistrationService().apply(
        fullName: fullName.text,
        email: email.text,
        phone: phone.text,
        nationalId: nationalId.text,
        area: selectedArea!,
        locationLabel: locationLabel.text,
        latitude: latitude!,
        longitude: longitude!,
        payoutMethod: payoutMethod.text,
        payoutAccount: payoutAccount.text,
        acceptedAgentTerms: acceptedAgentTerms,
        acceptedPrivacyPolicy: acceptedPrivacyPolicy,
        agreementVersion: _agreementVersion,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إرسال طلب الانضمام كوسيطة للأدمن للمراجعة ✅',
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
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  void dispose() {
    fullName.dispose();
    email.dispose();
    phone.dispose();
    nationalId.dispose();
    locationLabel.dispose();
    payoutMethod.dispose();
    payoutAccount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = _currentUser != null;
    final hasLocation = latitude != null && longitude != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: const Text(
          'الانضمام كوسيطة بركة',
          style: TextStyle(fontWeight: FontWeight.w900),
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
                      Icons.support_agent_rounded,
                      size: 76,
                      color: AppTheme.coolYellow,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'انضمي إلى وسيطات بركة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'قدّمي طلبك وسيقوم الأدمن بمراجعة بياناتك وموقعك قبل التفعيل.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (!loggedIn) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7D6),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.coolYellow,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'أنشئي حساب بركة أو سجّلي الدخول أولًا حتى يُحفظ الطلب باسمك.',
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
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
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
              _sectionTitle('المنطقة والموقع'),
              DropdownButtonFormField<String>(
                value: selectedArea,
                decoration: const InputDecoration(
                  labelText: 'المنطقة',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
                items: _areas
                    .map(
                      (area) => DropdownMenuItem(
                        value: area,
                        child: Text(area),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => selectedArea = value);
                },
                validator: (value) => value == null ? 'اختر المنطقة' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: locationLabel,
                decoration: const InputDecoration(
                  labelText: 'وصف الموقع',
                  hintText: 'مثال: طولكرم - وسط البلد',
                  prefixIcon: Icon(Icons.map_outlined),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: locating ? null : _useCurrentLocation,
                  icon: locating
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          hasLocation
                              ? Icons.check_circle_rounded
                              : Icons.my_location_rounded,
                        ),
                  label: Text(
                    hasLocation ? 'تم تحديد الموقع ✓' : 'تحديد موقعي الحالي',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              if (hasLocation) ...[
                const SizedBox(height: 8),
                Text(
                  'الموقع: '
                  '${latitude!.toStringAsFixed(5)}, '
                  '${longitude!.toStringAsFixed(5)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              _sectionTitle('استلام المستحقات'),
              TextFormField(
                controller: payoutMethod,
                validator: _required,
                decoration: const InputDecoration(
                  labelText: 'طريقة استلام المستحقات',
                  hintText: 'مثال: حساب بنكي / محفظة',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: payoutAccount,
                validator: _required,
                decoration: const InputDecoration(
                  labelText: 'بيانات الحساب أو المحفظة',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: 20),
              CheckboxListTile(
                value: acceptedAgentTerms,
                onChanged: (value) {
                  setState(() {
                    acceptedAgentTerms = value == true;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'قرأت وأوافق على شروط وسيطات بركة',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(
                  'الإصدار 2026-09-10-v1',
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
                  'أوافق على سياسة الخصوصية',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.navy,
                    foregroundColor: Colors.white,
                  ),
                  icon: saving
                      ? const SizedBox(
                          width: 21,
                          height: 21,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: const Text(
                    'إرسال طلب الانضمام',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'لن يتم تفعيل حساب الوسيطة أو إظهاره للمستخدمين إلا بعد مراجعة الأدمن واعتماد الطلب.',
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
      padding: const EdgeInsets.only(bottom: 10),
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
