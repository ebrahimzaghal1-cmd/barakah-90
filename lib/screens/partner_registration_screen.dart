import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/app_theme.dart';
import 'legal_documents_screen.dart';
import 'location_picker_screen.dart';

class PartnerRegistrationScreen extends StatefulWidget {
  const PartnerRegistrationScreen({super.key});

  @override
  State<PartnerRegistrationScreen> createState() =>
      _PartnerRegistrationScreenState();
}

class _PartnerRegistrationScreenState extends State<PartnerRegistrationScreen> {
  static const double _defaultCommissionRate = 10;
  static const String _agreementVersion = '2026-08-17-v1';

  final _formKey = GlobalKey<FormState>();

  final _businessName = TextEditingController();
  final _ownerName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _nationalId = TextEditingController();
  final _area = TextEditingController();
  final _description = TextEditingController();
  final _locationUrl = TextEditingController();
  final _barberServices = TextEditingController();
  final _barberOpeningTime = TextEditingController(text: '09:00');
  final _barberClosingTime = TextEditingController(text: '21:00');
  final _barberSlotMinutes = TextEditingController(text: '30');
  final _doctorSpecialty = TextEditingController();
  final _doctorLicense = TextEditingController();
  final _doctorConsultationFee = TextEditingController(text: '0');

  final _payoutOwnerName = TextEditingController();
  final _payoutMethod = TextEditingController();
  final _payoutAccount = TextEditingController();

  // مراجع الوثائق مؤقتًا لحين تركيب رفع ملفات خاص وآمن.
  final _identityDocumentRef = TextEditingController();
  final _businessDocumentRef = TextEditingController();
  final _payoutDocumentRef = TextEditingController();

  String _activityType = 'مطعم';
  String? _businessCategory;

  bool _acceptedPartnerAgreement = false;
  bool _acceptedPrivacyPolicy = false;
  bool _saving = false;
  bool _submitted = false;
  double? _latitude;
  double? _longitude;

  static const _activityTypes = <String>[
    'مطعم',
    'سوبرماركت',
    'حلويات ومخبوزات',
    'خضار وفواكه',
    'لحوم',
    'دجاج',
    'أسماك',
    'صيدلية',
    'متجر',
    'حلاق',
    'طبيب',
    'أخرى',
  ];

  @override
  void dispose() {
    _businessName.dispose();
    _ownerName.dispose();
    _email.dispose();
    _phone.dispose();
    _nationalId.dispose();
    _area.dispose();
    _description.dispose();
    _locationUrl.dispose();
    _barberServices.dispose();
    _barberOpeningTime.dispose();
    _barberClosingTime.dispose();
    _barberSlotMinutes.dispose();
    _doctorSpecialty.dispose();
    _doctorLicense.dispose();
    _doctorConsultationFee.dispose();
    _payoutOwnerName.dispose();
    _payoutMethod.dispose();
    _payoutAccount.dispose();
    _identityDocumentRef.dispose();
    _businessDocumentRef.dispose();
    _payoutDocumentRef.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'هذا الحقل مطلوب';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) return 'البريد الإلكتروني مطلوب';

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
      return 'أدخل بريدًا إلكترونيًا صحيحًا';
    }

    return null;
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptedPartnerAgreement || !_acceptedPrivacyPolicy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يجب الموافقة على اتفاقية الشريك وسياسة الخصوصية.',
          ),
        ),
      );
      return;
    }

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حددي موقع المحل الحقيقي على الخريطة أولًا.'),
        ),
      );
      return;
    }

    if (_businessCategory == null || _businessCategory!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختاري القسم الذي ينتمي إليه نشاطك.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final response = await http
          .post(
            Uri.parse(
              'https://barakah-secure-api.ebrahimzaghal1.workers.dev/v1/partner-applications',
            ),
            headers: const {'content-type': 'application/json; charset=utf-8'},
            body: jsonEncode({
              'businessName': _businessName.text.trim(),
              'ownerName': _ownerName.text.trim(),
              'email': _email.text.trim(),
              'phone': _phone.text.trim(),
              'nationalId': _nationalId.text.trim(),
              'activityType': _activityType,
              'businessCategory': _businessCategory,
              'area': _area.text.trim(),
              'description': _description.text.trim(),
              'locationUrl': _locationUrl.text.trim(),
              if (_activityType == 'حلاق') ...{
                'barberServices': _parseBarberServices(),
                'barberOpeningTime': _barberOpeningTime.text.trim(),
                'barberClosingTime': _barberClosingTime.text.trim(),
                'barberSlotMinutes':
                    int.tryParse(_barberSlotMinutes.text.trim()) ?? 30,
              },
              if (_activityType == 'طبيب') ...{
                'doctorSpecialty': _doctorSpecialty.text.trim(),
                'doctorLicense': _doctorLicense.text.trim(),
                'doctorConsultationFee':
                    num.tryParse(_doctorConsultationFee.text.trim()) ?? 0,
              },
              'latitude': _latitude,
              'longitude': _longitude,
              'payoutOwnerName': _payoutOwnerName.text.trim(),
              'payoutMethod': _payoutMethod.text.trim(),
              'payoutAccount': _payoutAccount.text.trim(),
              'identityDocumentRef': _identityDocumentRef.text.trim(),
              'businessDocumentRef': _businessDocumentRef.text.trim(),
              'payoutDocumentRef': _payoutDocumentRef.text.trim(),
              'commissionRate': _defaultCommissionRate,
              'commissionAppliesTo': 'products_and_bookings',
              'subscriptionFee': 0,
              'acceptedPartnerAgreement': true,
              'acceptedPrivacyPolicy': true,
              'agreementVersion': _agreementVersion,
            }),
          )
          .timeout(const Duration(seconds: 25));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final decoded = response.body.isEmpty
            ? const <String, dynamic>{}
            : jsonDecode(utf8.decode(response.bodyBytes));
        final message = decoded is Map ? decoded['message']?.toString() : null;
        throw StateError(message ?? 'تعذر إرسال طلب الانضمام.');
      }

      if (!mounted) return;

      setState(() {
        _submitted = true;
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _saving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر إرسال الطلب: $error',
          ),
        ),
      );
    }
  }

  void _openLegal(LegalDocumentType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LegalDocumentScreen(type: type),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          title,
          style: const TextStyle(
            color: AppTheme.navy,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 40),
              child: _submitted ? _successCard() : _form(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
          decoration: BoxDecoration(
            color: AppTheme.navy,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.coolYellow,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset(
                    'assets/images/barakah_app_icon.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'انضم كشريك في بركة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'بدون رسوم اشتراك • عمولة بركة 10% على الطلبات والحجوزات المكتملة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.coolYellow,
                  height: 1.6,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 22,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _sectionTitle(
                  _activityType == 'طبيب' ? 'بيانات العيادة' : 'بيانات المتجر',
                ),
                if (_activityType == 'طبيب') ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF3FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFB9D6FA)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.local_hospital_rounded,
                            color: AppTheme.navy),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'سيظهر الطبيب في تبويب الصحة وعلى الخريطة، ويستطيع المرضى فتح صفحة العيادة وحجز موعد أو إرسال استشارة.',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                height: 1.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _businessName,
                  validator: _required,
                  decoration: InputDecoration(
                    labelText: _activityType == 'طبيب'
                        ? 'اسم العيادة'
                        : 'اسم المطعم / المحل',
                    prefixIcon: Icon(Icons.storefront_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                if (_activityType == 'حلاق') ...[
                  _sectionTitle('إعدادات مواعيد الحلاق'),
                  const Text(
                    'اكتبي كل خدمة في سطر بهذا الشكل: اسم الخدمة : السعر : المدة بالدقائق',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: Colors.black54, height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _barberServices,
                    maxLines: 4,
                    validator: (value) =>
                        _activityType == 'حلاق' ? _required(value) : null,
                    decoration: const InputDecoration(
                      labelText: 'الخدمات والأسعار *',
                      hintText: 'حلاقة شعر : 30 : 30\nلحية : 15 : 15',
                      prefixIcon: Icon(Icons.content_cut_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _barberOpeningTime,
                          validator: _activityType == 'حلاق' ? _required : null,
                          decoration: const InputDecoration(
                            labelText: 'بداية الدوام',
                            hintText: '09:00',
                            prefixIcon: Icon(Icons.login_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _barberClosingTime,
                          validator: _activityType == 'حلاق' ? _required : null,
                          decoration: const InputDecoration(
                            labelText: 'نهاية الدوام',
                            hintText: '21:00',
                            prefixIcon: Icon(Icons.logout_rounded),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _barberSlotMinutes,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (_activityType != 'حلاق') return null;
                      final minutes = int.tryParse(value?.trim() ?? '');
                      return minutes == null || minutes < 10 || minutes > 240
                          ? 'المدة بين 10 و240 دقيقة'
                          : null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'مدة الموعد الافتراضية بالدقائق',
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                if (_activityType == 'طبيب') ...[
                  _sectionTitle('بيانات العيادة والطبيب'),
                  TextFormField(
                    controller: _doctorSpecialty,
                    validator: _required,
                    decoration: const InputDecoration(
                      labelText: 'التخصص الطبي *',
                      hintText: 'طب أسنان، أطفال، جلدية...',
                      prefixIcon: Icon(Icons.medical_services_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _doctorLicense,
                    validator: _required,
                    decoration: const InputDecoration(
                      labelText: 'رقم ترخيص مزاولة المهنة *',
                      prefixIcon: Icon(Icons.verified_user_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _doctorConsultationFee,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'سعر الاستشارة (اختياري)',
                      suffixText: '₪',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                TextFormField(
                  controller: _ownerName,
                  validator: _required,
                  decoration: InputDecoration(
                    labelText: _activityType == 'طبيب'
                        ? 'اسم الطبيب المسؤول'
                        : 'اسم صاحب المحل / المسؤول',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  validator: _emailValidator,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  validator: _required,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nationalId,
                  validator: _required,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهوية',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _activityType,
                  decoration: const InputDecoration(
                    labelText: 'نوع النشاط',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: _activityTypes
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _activityType = value;
                        _businessCategory = value == 'طبيب' ? 'صحة' : null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection(
                        _activityType == 'مطعم'
                            ? 'restaurant_categories'
                            : 'market_categories',
                      )
                      .snapshots(),
                  builder: (context, snapshot) {
                    final categories = (snapshot.data?.docs ?? const [])
                        .map(
                          (doc) => doc.data()['title']?.toString().trim() ?? '',
                        )
                        .where((title) => title.isNotEmpty)
                        .toSet()
                        .toList()
                      ..sort();
                    if (_activityType == 'حلاق' &&
                        !categories.contains('حلاق')) {
                      categories.insert(0, 'حلاق');
                    }
                    if (_activityType == 'طبيب' &&
                        !categories.contains('صحة')) {
                      categories.insert(0, 'صحة');
                    }

                    return DropdownButtonFormField<String>(
                      value: categories.contains(_businessCategory)
                          ? _businessCategory
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'القسم',
                        prefixIcon: Icon(Icons.category_outlined),
                        helperText:
                            'اختاري القسم الذي سيظهر فيه نشاطك داخل بركة',
                      ),
                      hint: const Text('اختاري القسم الصحيح'),
                      items: categories
                          .map(
                            (title) => DropdownMenuItem<String>(
                              value: title,
                              child: Text(
                                title,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _businessCategory = value);
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _area,
                  validator: _required,
                  decoration: const InputDecoration(
                    labelText: 'المدينة / المنطقة',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () async {
                            final location =
                                await Navigator.push<Map<String, double>>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LocationPickerScreen(
                                  latitude: _latitude,
                                  longitude: _longitude,
                                ),
                              ),
                            );
                            if (location != null && mounted) {
                              setState(() {
                                _latitude = location['latitude'];
                                _longitude = location['longitude'];
                              });
                            }
                          },
                    icon: Icon(
                      _latitude == null
                          ? Icons.add_location_alt_outlined
                          : Icons.location_on_rounded,
                    ),
                    label: Text(
                      _latitude == null
                          ? 'تحديد موقع المحل الحقيقي على الخريطة *'
                          : 'تم تحديد موقع المحل — تغيير الموقع',
                    ),
                  ),
                ),
                if (_latitude != null && _longitude != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${_latitude!.toStringAsFixed(6)}, '
                    '${_longitude!.toStringAsFixed(6)}',
                    style: TextStyle(
                      color: AppTheme.ink.withOpacity(.55),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: _activityType == 'طبيب'
                        ? 'نبذة عن الطبيب والعيادة'
                        : 'وصف مختصر عن المحل',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationUrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'رابط Google Maps — اختياري',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                ),
                const SizedBox(height: 24),
                _sectionTitle('بيانات استلام وتسوية المستحقات'),
                TextFormField(
                  controller: _payoutOwnerName,
                  validator: _required,
                  decoration: const InputDecoration(
                    labelText: 'اسم صاحب الحساب المالي',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _payoutMethod,
                  validator: _required,
                  decoration: const InputDecoration(
                    labelText: 'البنك / المحفظة / وسيلة التسوية',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _payoutAccount,
                  validator: _required,
                  decoration: const InputDecoration(
                    labelText: 'رقم الحساب / IBAN / رقم المحفظة',
                    prefixIcon: Icon(Icons.account_balance_outlined),
                  ),
                ),
                const SizedBox(height: 24),
                _sectionTitle('مراجع مستندات التحقق'),
                const Text(
                  'سيتم لاحقًا استبدال هذه الخانات برفع صور ومستندات آمن داخل بركة. لا تضع مستندات حساسة في روابط عامة.',
                  style: TextStyle(
                    color: Colors.black54,
                    height: 1.5,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _identityDocumentRef,
                  decoration: const InputDecoration(
                    labelText: 'مرجع مستند الهوية — اختياري حاليًا',
                    prefixIcon: Icon(Icons.badge_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _businessDocumentRef,
                  decoration: const InputDecoration(
                    labelText: 'مرجع إثبات / رخصة المحل — اختياري حاليًا',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _payoutDocumentRef,
                  decoration: const InputDecoration(
                    labelText: 'مرجع إثبات الحساب المالي — اختياري حاليًا',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                  ),
                ),
                const SizedBox(height: 24),
                _sectionTitle('اتفاقية بركة'),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.coolYellow.withOpacity(.18),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'العمولة الافتراضية: 10%\n'
                    'تُحسب على قيمة المنتجات أو الحجز المكتمل فقط.\n'
                    'لا رسوم اشتراك ولا عمولة على رسوم التوصيل أو الطلب الملغي.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.navy,
                      height: 1.6,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _acceptedPartnerAgreement,
                  onChanged: (value) {
                    setState(() {
                      _acceptedPartnerAgreement = value == true;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'قرأت وأوافق على اتفاقية الشريك',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: TextButton(
                    onPressed: () =>
                        _openLegal(LegalDocumentType.partnerAgreement),
                    child: const Text('عرض اتفاقية الشريك'),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _acceptedPrivacyPolicy,
                  onChanged: (value) {
                    setState(() {
                      _acceptedPrivacyPolicy = value == true;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'قرأت وأوافق على سياسة الخصوصية',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: TextButton(
                    onPressed: () => _openLegal(LegalDocumentType.privacy),
                    child: const Text('عرض سياسة الخصوصية'),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.navy,
                      foregroundColor: Colors.white,
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 21,
                            height: 21,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      _saving ? 'جارٍ إرسال الطلب...' : 'إرسال طلب الانضمام',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _successCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 44, 28, 44),
      decoration: BoxDecoration(
        color: AppTheme.navy,
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Column(
        children: [
          CircleAvatar(
            radius: 46,
            backgroundColor: AppTheme.coolYellow,
            child: Icon(
              Icons.check_rounded,
              size: 52,
              color: AppTheme.navy,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'تم استلام طلبك',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'سيراجع فريق بركة بياناتك قبل تفعيل حساب التاجر.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.7,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _parseBarberServices() {
    return _barberServices.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) {
          final parts = line.split(':').map((part) => part.trim()).toList();
          final title = parts.first;
          final price = parts.length > 1
              ? num.tryParse(parts[1].replaceAll(',', '.')) ?? 0
              : 0;
          final duration = parts.length > 2
              ? int.tryParse(parts[2]) ?? 30
              : int.tryParse(_barberSlotMinutes.text.trim()) ?? 30;
          return <String, dynamic>{
            'title': title,
            'price': price,
            'durationMinutes': duration,
          };
        })
        .where((service) => (service['title'] as String).length >= 2)
        .toList();
  }
}
