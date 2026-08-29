import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AdminManageDrivers extends StatelessWidget {
  const AdminManageDrivers({super.key});

  Future<void> _setVerification(
    DocumentReference<Map<String, dynamic>> ref,
    String field,
    bool value,
  ) async {
    await ref.update({
      field: value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _approve(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> application,
  ) async {
    final data = application.data() ?? const <String, dynamic>{};

    final identityVerified = data['identityVerified'] == true;
    final driverLicenseVerified = data['driverLicenseVerified'] == true;
    final vehicleDocumentsVerified = data['vehicleDocumentsVerified'] == true;
    final payoutVerified = data['payoutVerified'] == true;

    final acceptedTerms = data['acceptedDriverTerms'] == true;
    final acceptedPrivacy = data['acceptedPrivacyPolicy'] == true;

    if (!identityVerified ||
        !driverLicenseVerified ||
        !vehicleDocumentsVerified ||
        !payoutVerified ||
        !acceptedTerms ||
        !acceptedPrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا يمكن اعتماد السائق قبل اكتمال التحقق من جميع المتطلبات.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'اعتماد السائق',
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'تم التحقق من جميع بيانات السائق. هل تريد تفعيل حسابه كسائق بركة؟',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('اعتماد'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final batch = FirebaseFirestore.instance.batch();

    batch.set(
      FirebaseFirestore.instance.collection('users').doc(application.id),
      {
        if (application.id != 'Y3YeLin9gYTbqN4if72o3iTrUSn2') 'role': 'driver',
        'driverPhone': data['phone'],
        'driverVehicle': data['vehicle'],
        'driverAvailable': false,
        'driverBusy': false,
        'activeOrderId': null,
        'identityVerified': true,
        'driverLicenseVerified': true,
        'vehicleDocumentsVerified': true,
        'payoutVerified': true,
        'driverAgreementVersion': data['agreementVersion'],
        'driverActivatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(
      application.reference,
      {
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم اعتماد السائق وتفعيل حسابه ✅'),
      ),
    );
  }

  Future<void> _reject(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> application,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'رفض طلب السائق',
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'هل تريد رفض طلب انضمام هذا السائق؟',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('رفض'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await application.reference.update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم رفض طلب السائق'),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> application,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'إزالة طلب السائق',
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'هل تريد حذف طلب السائق نهائيًا؟',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await application.reference.delete();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حذف طلب السائق'),
      ),
    );
  }

  String _value(
    Map<String, dynamic> data,
    String key,
  ) {
    final value = data[key]?.toString().trim() ?? '';
    return value.isEmpty ? 'غير مضاف' : value;
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
            size: 20,
            color: AppTheme.deepYellow,
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
                  value,
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

  Widget _verificationTile({
    required DocumentReference<Map<String, dynamic>> reference,
    required Map<String, dynamic> data,
    required String field,
    required String title,
    required String subtitle,
  }) {
    final value = data[field] == true;

    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: (next) => _setVerification(
        reference,
        field,
        next,
      ),
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
        style: const TextStyle(
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: const Text(
          'إدارة سائقي التوصيل',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('driver_applications')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'تعذر تحميل طلبات السائقين.',
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final applications = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final left = a.data()['createdAt'] as Timestamp?;
              final right = b.data()['createdAt'] as Timestamp?;

              return (right?.millisecondsSinceEpoch ?? 0).compareTo(
                left?.millisecondsSinceEpoch ?? 0,
              );
            });

          if (applications.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد طلبات سائقين حاليًا.',
                style: TextStyle(
                  color: AppTheme.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: applications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final application = applications[index];
              final data = application.data();

              final status = data['status']?.toString() ?? 'pending';

              final approved = status == 'approved';
              final rejected = status == 'rejected';

              final identityVerified = data['identityVerified'] == true;
              final licenseVerified = data['driverLicenseVerified'] == true;
              final vehicleVerified = data['vehicleDocumentsVerified'] == true;
              final payoutVerified = data['payoutVerified'] == true;

              final acceptedTerms = data['acceptedDriverTerms'] == true;
              final acceptedPrivacy = data['acceptedPrivacyPolicy'] == true;

              final readyToApprove = identityVerified &&
                  licenseVerified &&
                  vehicleVerified &&
                  payoutVerified &&
                  acceptedTerms &&
                  acceptedPrivacy;

              return Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(17),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: approved
                                  ? const Color(0xFFE0F6EA)
                                  : rejected
                                      ? const Color(0xFFFFE8E8)
                                      : AppTheme.coolYellow.withOpacity(.25),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              approved
                                  ? Icons.verified_rounded
                                  : rejected
                                      ? Icons.close_rounded
                                      : Icons.delivery_dining_rounded,
                              color: approved
                                  ? const Color(0xFF1B8A5A)
                                  : rejected
                                      ? Colors.red
                                      : AppTheme.navy,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _value(
                                    data,
                                    'fullName',
                                  ),
                                  style: const TextStyle(
                                    color: AppTheme.navy,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  approved
                                      ? 'سائق معتمد'
                                      : rejected
                                          ? 'الطلب مرفوض'
                                          : readyToApprove
                                              ? 'جاهز للاعتماد'
                                              : 'بانتظار التحقق',
                                  style: TextStyle(
                                    color: approved
                                        ? const Color(
                                            0xFF1B8A5A,
                                          )
                                        : rejected
                                            ? Colors.red
                                            : const Color(
                                                0xFF9A6A00,
                                              ),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 28),
                      _infoRow(
                        Icons.email_outlined,
                        'البريد الإلكتروني',
                        _value(data, 'email'),
                      ),
                      _infoRow(
                        Icons.phone_outlined,
                        'رقم الهاتف',
                        _value(data, 'phone'),
                      ),
                      _infoRow(
                        Icons.badge_outlined,
                        'رقم الهوية',
                        _value(data, 'nationalId'),
                      ),
                      _infoRow(
                        Icons.two_wheeler_rounded,
                        'المركبة',
                        _value(data, 'vehicle'),
                      ),
                      _infoRow(
                        Icons.credit_card_rounded,
                        'رخصة القيادة',
                        _value(
                          data,
                          'driverLicenseNumber',
                        ),
                      ),
                      _infoRow(
                        Icons.description_outlined,
                        'رخصة المركبة',
                        _value(
                          data,
                          'vehicleLicenseNumber',
                        ),
                      ),
                      _infoRow(
                        Icons.verified_user_outlined,
                        'التأمين',
                        _value(
                          data,
                          'vehicleInsuranceNumber',
                        ),
                      ),
                      _infoRow(
                        Icons.account_balance_wallet_outlined,
                        'طريقة استلام المستحقات',
                        _value(
                          data,
                          'payoutMethod',
                        ),
                      ),
                      _infoRow(
                        Icons.account_balance_outlined,
                        'رقم الحساب / IBAN / المحفظة',
                        _value(
                          data,
                          'payoutAccount',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          children: [
                            _verificationTile(
                              reference: application.reference,
                              data: data,
                              field: 'identityVerified',
                              title: 'تم التحقق من الهوية',
                              subtitle: 'طابق بيانات الهوية مع صاحب الحساب.',
                            ),
                            const Divider(height: 1),
                            _verificationTile(
                              reference: application.reference,
                              data: data,
                              field: 'driverLicenseVerified',
                              title: 'تم التحقق من رخصة القيادة',
                              subtitle:
                                  'تأكد من صلاحية الرخصة وارتباطها بالسائق.',
                            ),
                            const Divider(height: 1),
                            _verificationTile(
                              reference: application.reference,
                              data: data,
                              field: 'vehicleDocumentsVerified',
                              title: 'تم التحقق من وثائق المركبة',
                              subtitle: 'رخصة المركبة والتأمين حسب المطلوب.',
                            ),
                            const Divider(height: 1),
                            _verificationTile(
                              reference: application.reference,
                              data: data,
                              field: 'payoutVerified',
                              title: 'تم التحقق من بيانات المستحقات',
                              subtitle: 'تحقق من وسيلة استلام مستحقات السائق.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            acceptedTerms
                                ? Icons.check_circle_rounded
                                : Icons.cancel_outlined,
                            color: acceptedTerms
                                ? const Color(0xFF1B8A5A)
                                : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              acceptedTerms
                                  ? 'وافق على شروط السائق'
                                  : 'لم يوافق على شروط السائق',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            acceptedPrivacy
                                ? Icons.check_circle_rounded
                                : Icons.cancel_outlined,
                            color: acceptedPrivacy
                                ? const Color(0xFF1B8A5A)
                                : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              acceptedPrivacy
                                  ? 'وافق على سياسة الخصوصية'
                                  : 'لم يوافق على سياسة الخصوصية',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!approved && !rejected) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: readyToApprove
                                ? () => _approve(
                                      context,
                                      application,
                                    )
                                : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1B8A5A),
                            ),
                            icon: const Icon(
                              Icons.verified_rounded,
                            ),
                            label: const Text(
                              'اعتماد السائق',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        if (!readyToApprove) ...[
                          const SizedBox(height: 6),
                          const Text(
                            'أكمل جميع خطوات التحقق أولًا ليتم تفعيل زر الاعتماد.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _reject(
                            context,
                            application,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          icon: const Icon(
                            Icons.close_rounded,
                          ),
                          label: const Text('رفض الطلب'),
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _delete(
                          context,
                          application,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                        ),
                        label: const Text(
                          'إزالة الطلب',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
