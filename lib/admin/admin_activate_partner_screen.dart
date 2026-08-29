import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AdminActivatePartnerScreen extends StatefulWidget {
  const AdminActivatePartnerScreen({
    super.key,
    required this.applicationId,
    required this.application,
  });

  final String applicationId;
  final Map<String, dynamic> application;

  @override
  State<AdminActivatePartnerScreen> createState() =>
      _AdminActivatePartnerScreenState();
}

class _AdminActivatePartnerScreenState
    extends State<AdminActivatePartnerScreen> {
  String? _selectedUserId;

  late bool _identityVerified;
  late bool _businessVerified;
  late bool _payoutVerified;

  late final TextEditingController _commissionController;

  bool _saving = false;

  String _text(String key) => widget.application[key]?.toString().trim() ?? '';

  bool get _agreementAccepted =>
      widget.application['acceptedPartnerAgreement'] == true;

  bool get _privacyAccepted =>
      widget.application['acceptedPrivacyPolicy'] == true;

  bool get _readyToActivate =>
      _selectedUserId != null &&
      _identityVerified &&
      _businessVerified &&
      _payoutVerified &&
      _agreementAccepted &&
      _privacyAccepted;

  @override
  void initState() {
    super.initState();

    _identityVerified = widget.application['identityVerified'] == true;

    _businessVerified = widget.application['businessVerified'] == true;

    _payoutVerified = widget.application['payoutVerified'] == true;

    final commission =
        (widget.application['commissionRate'] as num?)?.toDouble() ?? 10.0;

    _commissionController = TextEditingController(
      text: commission.toStringAsFixed(
        commission % 1 == 0 ? 0 : 1,
      ),
    );

    final linked = widget.application['linkedUserId']?.toString().trim() ?? '';

    if (linked.isNotEmpty) {
      _selectedUserId = linked;
    }
  }

  @override
  void dispose() {
    _commissionController.dispose();
    super.dispose();
  }

  Future<void> _setVerification(
    String field,
    bool value,
  ) async {
    setState(() {
      if (field == 'identityVerified') {
        _identityVerified = value;
      } else if (field == 'businessVerified') {
        _businessVerified = value;
      } else if (field == 'payoutVerified') {
        _payoutVerified = value;
      }
    });

    try {
      await FirebaseFirestore.instance
          .collection('merchant_applications')
          .doc(widget.applicationId)
          .set({
        field: value,
        'verificationUpdatedAt': FieldValue.serverTimestamp(),
        'verificationUpdatedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
      }, SetOptions(merge: true));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر حفظ حالة التحقق: $error'),
        ),
      );
    }
  }

  Future<void> _activateMerchant() async {
    if (_saving) return;

    final uid = _selectedUserId;

    if (uid == null || uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختر حساب صاحب المحل أولًا.'),
        ),
      );
      return;
    }

    final commission = double.tryParse(_commissionController.text.trim());

    if (commission == null || commission < 0 || commission > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل نسبة عمولة صحيحة من 0 إلى 100.'),
        ),
      );
      return;
    }

    final latitude = (widget.application['latitude'] as num?)?.toDouble();
    final longitude = (widget.application['longitude'] as num?)?.toDouble();

    final businessCategory = _text('businessCategory');

    if (businessCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا يمكن تفعيل الشريك قبل تحديد قسم النشاط في طلب الشراكة.',
          ),
        ),
      );
      return;
    }

    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا يمكن تفعيل الشريك قبل تحديد موقع المحل الحقيقي على الخريطة.',
          ),
        ),
      );
      return;
    }

    if (!_identityVerified || !_businessVerified || !_payoutVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'أكمل التحقق من الهوية والنشاط والحساب المالي أولًا.',
          ),
        ),
      );
      return;
    }

    if (!_agreementAccepted || !_privacyAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا يمكن تفعيل التاجر قبل موافقته على اتفاقية الشريك وسياسة الخصوصية.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'اعتماد وتفعيل المتجر',
          textAlign: TextAlign.center,
        ),
        content: Text(
          'سيتم تفعيل ${_text('businessName')} كتاجر في بركة.\n\n'
          'عمولة بركة: ${commission.toStringAsFixed(commission % 1 == 0 ? 0 : 1)}%\n'
          'العمولة على قيمة المنتجات في الطلب المكتمل فقط.\n'
          'لا توجد رسوم اشتراك.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('اعتماد وتفعيل'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _saving = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';

      final userRef = firestore.collection('users').doc(uid);

      final applicationRef = firestore
          .collection('merchant_applications')
          .doc(widget.applicationId);

      final batch = firestore.batch();

      final existingBusiness = await firestore
          .collection('items')
          .where('ownerId', isEqualTo: uid)
          .get();

      final existingBusinesses = existingBusiness.docs
          .where((doc) => doc.data()['kind'] != 'product')
          .toList();

      late final DocumentReference<Map<String, dynamic>> businessRef;

      if (existingBusinesses.isEmpty) {
        businessRef = firestore.collection('items').doc();

        batch.set(
          businessRef,
          {
            'title': _text('businessName'),
            'description': _text('description'),
            'phone': _text('phone'),
            'address': _text('area'),
            'latitude': latitude,
            'longitude': longitude,
            'category': businessCategory,
            'type': _merchantTypeFromActivity(
              _text('activityType'),
            ),
            'kind': 'business',
            'rating': 0,
            'discountPercent': 0,
            'commissionRate': commission,
            'hasDeliveryOffer': false,
            'isTrending': false,
            'businessStatus': 'open',
            'openingTime': '10:00',
            'closingTime': '03:00',
            'preparationMinutes': 30,
            'ownerId': uid,
            'ownerEmail': _text('email'),
            'partnerApplicationId': widget.applicationId,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      } else {
        businessRef = existingBusinesses.first.reference;

        batch.set(
          businessRef,
          {
            'ownerId': uid,
            'ownerEmail': _text('email'),
            'commissionRate': commission,
            'address': _text('area'),
            'latitude': latitude,
            'longitude': longitude,
            'category': businessCategory,
            'type': _merchantTypeFromActivity(_text('activityType')),
            'partnerApplicationId': widget.applicationId,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      batch.set(
        userRef,
        {
          if (uid != 'Y3YeLin9gYTbqN4if72o3iTrUSn2') 'role': 'merchant',
          'merchantEnabled': true,
          'partnerApplicationId': widget.applicationId,
          'merchantBusinessName': _text('businessName'),
          'merchantCategory': businessCategory,
          'merchantType': _merchantTypeFromActivity(_text('activityType')),
          'merchantPhone': _text('phone'),
          'merchantEmail': _text('email'),
          'commissionRate': commission,
          'commissionAppliesTo': 'products_only',
          'subscriptionFee': 0,
          'identityVerified': true,
          'businessVerified': true,
          'payoutVerified': true,
          'partnerAgreementAccepted': true,
          'privacyPolicyAccepted': true,
          'partnerAgreementVersion': _text('agreementVersion'),
          'merchantActivatedAt': FieldValue.serverTimestamp(),
          'merchantActivatedBy': adminUid,
          'merchantBusinessId': businessRef.id,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      batch.set(
        applicationRef,
        {
          'status': 'approved',
          'linkedUserId': uid,
          'merchantEnabled': true,
          'commissionRate': commission,
          'commissionAppliesTo': 'products_only',
          'subscriptionFee': 0,
          'identityVerified': true,
          'businessVerified': true,
          'payoutVerified': true,
          'activatedAt': FieldValue.serverTimestamp(),
          'activatedBy': adminUid,
          'businessId': businessRef.id,
          'approvedCategory': businessCategory,
          'approvedMerchantType':
              _merchantTypeFromActivity(_text('activityType')),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم اعتماد وتفعيل حساب التاجر ✅',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      setState(() => _saving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر تفعيل التاجر: $error',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _merchantTypeFromActivity(String activity) {
    final value = activity.trim();

    const restaurantTypes = <String>{
      'مطاعم',
      'مطعم',
      'حلويات',
      'مخبوزات',
      'مخابز',
      'عصائر',
      'قهوة',
      'كافيه',
      'كافيهات',
      'وجبات سريعة',
    };

    return restaurantTypes.contains(value) ? 'restaurant' : 'market';
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AppTheme.deepYellow,
            size: 21,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value.isEmpty ? 'غير مضاف' : value,
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _verificationSwitch({
    required String field,
    required bool value,
    required String title,
    required String subtitle,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: (next) => _setVerification(field, next),
      activeColor: const Color(0xFF1B8A5A),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.navy,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final businessName =
        _text('businessName').isEmpty ? 'المحل' : _text('businessName');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: const Text(
          'توثيق وتفعيل الشريك',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'تعذر تحميل حسابات المستخدمين.',
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final users = snapshot.data!.docs.where((doc) {
              final role = doc.data()['role']?.toString().trim() ?? 'customer';

              return role == 'customer' || role == 'merchant';
            }).toList();

            return ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.navy,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.storefront_rounded,
                        color: AppTheme.coolYellow,
                        size: 58,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        businessName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_text('ownerName')}\n${_text('email')}\n${_text('phone')}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'بيانات التوثيق',
                  style: TextStyle(
                    color: AppTheme.navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _infoRow(
                          Icons.badge_outlined,
                          'رقم الهوية',
                          _text('nationalId'),
                        ),
                        _infoRow(
                          Icons.account_balance_outlined,
                          'صاحب الحساب المالي',
                          _text('payoutOwnerName'),
                        ),
                        _infoRow(
                          Icons.account_balance_wallet_outlined,
                          'وسيلة التسوية',
                          _text('payoutMethod'),
                        ),
                        _infoRow(
                          Icons.credit_card_rounded,
                          'رقم الحساب / IBAN / المحفظة',
                          _text('payoutAccount'),
                        ),
                        _infoRow(
                          Icons.badge_rounded,
                          'مرجع مستند الهوية',
                          _text('identityDocumentRef'),
                        ),
                        _infoRow(
                          Icons.description_outlined,
                          'مرجع إثبات النشاط',
                          _text('businessDocumentRef'),
                        ),
                        _infoRow(
                          Icons.receipt_long_outlined,
                          'مرجع إثبات الحساب',
                          _text('payoutDocumentRef'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'تحقق الأدمن',
                  style: TextStyle(
                    color: AppTheme.navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Column(
                      children: [
                        _verificationSwitch(
                          field: 'identityVerified',
                          value: _identityVerified,
                          title: 'تم التحقق من الهوية',
                          subtitle: 'طابق رقم الهوية وبيانات صاحب النشاط.',
                        ),
                        const Divider(height: 1),
                        _verificationSwitch(
                          field: 'businessVerified',
                          value: _businessVerified,
                          title: 'تم التحقق من النشاط / المحل',
                          subtitle: 'تحقق من إثبات أو رخصة النشاط حسب المتوفر.',
                        ),
                        const Divider(height: 1),
                        _verificationSwitch(
                          field: 'payoutVerified',
                          value: _payoutVerified,
                          title: 'تم التحقق من الحساب المالي',
                          subtitle:
                              'تحقق من اسم صاحب الحساب ورقم الحساب أو المحفظة.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'الموافقات',
                  style: TextStyle(
                    color: AppTheme.navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  leading: Icon(
                    _agreementAccepted
                        ? Icons.check_circle_rounded
                        : Icons.cancel_outlined,
                    color: _agreementAccepted
                        ? const Color(0xFF1B8A5A)
                        : Colors.red,
                  ),
                  title: Text(
                    _agreementAccepted
                        ? 'وافق على اتفاقية الشريك'
                        : 'لم يوافق على اتفاقية الشريك',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  subtitle: Text(
                    'الإصدار: ${_text('agreementVersion').isEmpty ? 'غير مسجل' : _text('agreementVersion')}',
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  leading: Icon(
                    _privacyAccepted
                        ? Icons.check_circle_rounded
                        : Icons.cancel_outlined,
                    color:
                        _privacyAccepted ? const Color(0xFF1B8A5A) : Colors.red,
                  ),
                  title: Text(
                    _privacyAccepted
                        ? 'وافق على سياسة الخصوصية'
                        : 'لم يوافق على سياسة الخصوصية',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'عمولة بركة',
                  style: TextStyle(
                    color: AppTheme.navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _commissionController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'نسبة عمولة بركة %',
                    helperText:
                        'الافتراضي 10% من قيمة المنتجات في الطلب المكتمل فقط.',
                    prefixIcon: Icon(Icons.percent_rounded),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'اختر حساب صاحب المحل',
                  style: TextStyle(
                    color: AppTheme.navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                if (users.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'لا توجد حسابات متاحة للربط.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...users.map((user) {
                    final data = user.data();

                    final displayName =
                        data['displayName']?.toString().trim() ?? '';

                    final email = data['email']?.toString().trim() ?? '';

                    final phone = data['phone']?.toString().trim() ?? '';

                    final selected = _selectedUserId == user.id;

                    final title = displayName.isNotEmpty
                        ? displayName
                        : email.isNotEmpty
                            ? email
                            : 'حساب ${user.id.substring(0, 6)}';

                    return Card(
                      elevation: 0,
                      color: selected
                          ? AppTheme.coolYellow.withOpacity(.20)
                          : Colors.white,
                      child: RadioListTile<String>(
                        value: user.id,
                        groupValue: _selectedUserId,
                        onChanged: (value) {
                          setState(() {
                            _selectedUserId = value;
                          });
                        },
                        title: Text(
                          title,
                          style: const TextStyle(
                            color: AppTheme.navy,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        subtitle: Text(
                          [
                            if (email.isNotEmpty) email,
                            if (phone.isNotEmpty) phone,
                          ].join(' • '),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 22),
                SizedBox(
                  height: 58,
                  child: FilledButton.icon(
                    onPressed:
                        _saving || !_readyToActivate ? null : _activateMerchant,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1B8A5A),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.verified_rounded,
                          ),
                    label: Text(
                      _saving ? 'جارٍ التفعيل...' : 'اعتماد وتفعيل المتجر',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                if (!_readyToActivate) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'لن يعمل زر التفعيل حتى يتم اختيار حساب صاحب المحل، وإكمال التحقق، وتسجيل موافقة الشريك على الاتفاقية والخصوصية.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                      height: 1.5,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
