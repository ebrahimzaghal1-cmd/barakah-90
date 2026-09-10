import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AdminManageAgentApplications extends StatelessWidget {
  const AdminManageAgentApplications({super.key});

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
    final locationVerified = data['locationVerified'] == true;
    final payoutVerified = data['payoutVerified'] == true;
    final acceptedTerms = data['acceptedAgentTerms'] == true;
    final acceptedPrivacy = data['acceptedPrivacyPolicy'] == true;

    if (!identityVerified ||
        !locationVerified ||
        !payoutVerified ||
        !acceptedTerms ||
        !acceptedPrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا يمكن اعتماد الوسيطة قبل اكتمال التحقق من جميع المتطلبات.',
          ),
        ),
      );
      return;
    }

    final latitude = (data['latitude'] as num?)?.toDouble();
    final longitude = (data['longitude'] as num?)?.toDouble();

    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن اعتماد الوسيطة بدون موقع صحيح.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'اعتماد الوسيطة',
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'تم التحقق من البيانات والموقع. هل تريد تفعيل هذه الوسيطة في بركة؟',
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

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    final userRef = firestore.collection('users').doc(application.id);
    final agentRef = firestore.collection('agents').doc(application.id);
    final publicAgentRef =
        firestore.collection('items').doc('agent_${application.id}');

    batch.set(
      userRef,
      {
        'isAgent': true,
        'agentActive': true,
        'agentPhone': data['phone'],
        'agentArea': data['area'],
        'agentLocationLabel': data['locationLabel'],
        'agentLatitude': latitude,
        'agentLongitude': longitude,
        'agentLocation': GeoPoint(latitude, longitude),
        'agentPayoutMethod': data['payoutMethod'],
        'agentPayoutAccount': data['payoutAccount'],
        'agentAgreementVersion': data['agreementVersion'],
        'agentActivatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(
      agentRef,
      {
        'userId': application.id,
        'fullName': data['fullName'],
        'email': data['email'],
        'phone': data['phone'],
        'nationalId': data['nationalId'],
        'area': data['area'],
        'locationLabel': data['locationLabel'],
        'latitude': latitude,
        'longitude': longitude,
        'location': GeoPoint(latitude, longitude),
        'payoutMethod': data['payoutMethod'],
        'payoutAccount': data['payoutAccount'],
        'active': true,
        'approved': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'createdAt': data['createdAt'],
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // سجل عام آمن لظهور الوسيطة للمستخدمين حسب القرب.
    // لا نضع هنا الهاتف أو البريد أو الهوية أو بيانات المستحقات.
    batch.set(
      publicAgentRef,
      {
        'agentId': application.id,
        'ownerId': application.id,
        'title': data['fullName'],
        'kind': 'agent',
        'type': 'agent',
        'category': 'وسيطات',
        'area': data['area'],
        'description': 'وسيطة معتمدة من بركة',
        'locationLabel': data['locationLabel'],
        'latitude': latitude,
        'longitude': longitude,
        'location': GeoPoint(latitude, longitude),
        'image': '',
        'imageShape': 'rounded',
        'rating': 5.0,
        'active': true,
        'approved': true,
        'agentVerified': true,
        'createdAt': data['createdAt'],
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
        content: Text('تم اعتماد الوسيطة وتفعيلها بنجاح ✅'),
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
          'رفض طلب الوسيطة',
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'هل تريد رفض طلب انضمام هذه الوسيطة؟',
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
        content: Text('تم رفض طلب الوسيطة'),
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
          'حذف طلب الوسيطة',
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'هل تريد حذف هذا الطلب نهائيًا؟',
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
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await application.reference.delete();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حذف طلب الوسيطة'),
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
          'طلبات انضمام الوسيطات',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('agent_applications')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'تعذر تحميل طلبات الوسيطات.',
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
                'لا توجد طلبات وسيطات حاليًا.',
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
              final locationVerified = data['locationVerified'] == true;
              final payoutVerified = data['payoutVerified'] == true;

              final acceptedTerms = data['acceptedAgentTerms'] == true;
              final acceptedPrivacy = data['acceptedPrivacyPolicy'] == true;

              final readyToApprove = identityVerified &&
                  locationVerified &&
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
                                      : Icons.support_agent_rounded,
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
                                  _value(data, 'fullName'),
                                  style: const TextStyle(
                                    color: AppTheme.navy,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  approved
                                      ? 'وسيطة معتمدة'
                                      : rejected
                                          ? 'الطلب مرفوض'
                                          : readyToApprove
                                              ? 'جاهزة للاعتماد'
                                              : 'بانتظار التحقق',
                                  style: TextStyle(
                                    color: approved
                                        ? const Color(0xFF1B8A5A)
                                        : rejected
                                            ? Colors.red
                                            : const Color(0xFF9A6A00),
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
                        Icons.location_city_outlined,
                        'المنطقة',
                        _value(data, 'area'),
                      ),
                      _infoRow(
                        Icons.map_outlined,
                        'وصف الموقع',
                        _value(data, 'locationLabel'),
                      ),
                      _infoRow(
                        Icons.my_location_rounded,
                        'الإحداثيات',
                        '${data['latitude'] ?? '-'}, ${data['longitude'] ?? '-'}',
                      ),
                      _infoRow(
                        Icons.account_balance_wallet_outlined,
                        'طريقة استلام المستحقات',
                        _value(data, 'payoutMethod'),
                      ),
                      _infoRow(
                        Icons.payments_outlined,
                        'بيانات الحساب',
                        _value(data, 'payoutAccount'),
                      ),
                      if (!approved && !rejected) ...[
                        const Divider(height: 28),
                        _verificationTile(
                          reference: application.reference,
                          data: data,
                          field: 'identityVerified',
                          title: 'تم التحقق من الهوية',
                          subtitle: 'تأكد من مطابقة بيانات الهوية قبل التفعيل.',
                        ),
                        _verificationTile(
                          reference: application.reference,
                          data: data,
                          field: 'locationVerified',
                          title: 'تم التحقق من الموقع',
                          subtitle: 'تأكد من صحة المنطقة والإحداثيات.',
                        ),
                        _verificationTile(
                          reference: application.reference,
                          data: data,
                          field: 'payoutVerified',
                          title: 'تم التحقق من بيانات الدفع',
                          subtitle: 'تأكد من وسيلة استلام المستحقات.',
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: readyToApprove
                              ? () => _approve(context, application)
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1B8A5A),
                          ),
                          icon: const Icon(Icons.verified_rounded),
                          label: const Text(
                            'اعتماد الوسيطة',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _reject(
                            context,
                            application,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text(
                            'رفض الطلب',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
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
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('حذف الطلب'),
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
