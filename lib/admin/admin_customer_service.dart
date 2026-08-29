import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../screens/recruitment_chat_screen.dart';

class AdminCustomerService extends StatefulWidget {
  const AdminCustomerService({super.key});

  @override
  State<AdminCustomerService> createState() => _AdminCustomerServiceState();
}

class _AdminCustomerServiceState extends State<AdminCustomerService> {
  static const _contractVersion = 'customer-service-v1';
  static const _defaultContractTerms = '''
وثيقة مباشرة عمل رقمية – موظف خدمة عملاء بركة

1. يلتزم الموظف بسرية بيانات العملاء والطلبات وعدم مشاركتها خارج أنظمة بركة.
2. تقتصر صلاحيات الموظف على محادثات الدعم وعرض حالة الطلب اللازمة للمساعدة، ولا تمنحه الوثيقة صلاحيات الأدمن.
3. يلتزم الموظف باللباقة والدقة وعدم تعديل أي مبلغ أو طلب خارج الإجراءات المعتمدة.
4. يكون الدوام وفق النوع المتفق عليه في طلب التوظيف، ويحدد الموظف حالة توفره من بوابته.
5. يحق لإدارة بركة تعليق حساب الخدمة أو إنهاء الصلاحية عند مخالفة السياسات.

هذه وثيقة تشغيل رقمية داخل التطبيق، وتخضع الصيغة النهائية للقانون والسياسات المعتمدة لدى المؤسسة.
''';
  final _firestore = FirebaseFirestore.instance;
  final _message = TextEditingController();
  final _contactPhone = TextEditingController();
  final _whatsAppPhone = TextEditingController();
  bool _saving = false;
  bool _contactSaving = false;
  bool? _hiringOpen;

  DocumentReference<Map<String, dynamic>> get _settings =>
      _firestore.collection('app_settings').doc('customer_service_recruitment');

  DocumentReference<Map<String, dynamic>> get _contactSettings =>
      _firestore.collection('app_settings').doc('support_contact');

  @override
  void dispose() {
    _message.dispose();
    _contactPhone.dispose();
    _whatsAppPhone.dispose();
    super.dispose();
  }

  Future<void> _saveContactSettings() async {
    setState(() => _contactSaving = true);
    try {
      await _contactSettings.set({
        'phone': _contactPhone.text.trim(),
        'whatsapp': _whatsAppPhone.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم حفظ أرقام التواصل ✅'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ الأرقام: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _contactSaving = false);
    }
  }

  Future<void> _saveHiring(bool value) async {
    final previousValue = _hiringOpen;
    setState(() {
      _saving = true;
      _hiringOpen = value;
    });
    try {
      await _settings.set({
        'hiringOpen': value,
        'message': _message.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
      }, SetOptions(merge: true));
      final saved =
          await _settings.get(const GetOptions(source: Source.server));
      if (saved.data()?['hiringOpen'] != value) {
        throw StateError('لم يؤكد الخادم حفظ حالة التوظيف.');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value
                ? 'تم فتح باب التوظيف وحفظه بنجاح ✅'
                : 'تم إغلاق باب التوظيف وحفظه بنجاح.'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _hiringOpen = previousValue);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر حفظ حالة التوظيف: $error'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _review(
    DocumentSnapshot<Map<String, dynamic>> application,
    String status,
  ) async {
    final data = application.data() ?? const <String, dynamic>{};
    final userId = data['userId']?.toString() ?? application.id;
    final batch = _firestore.batch();
    batch.update(application.reference, {
      'status': status,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
    });
    if (status == 'approved') {
      batch.set(
        _firestore.collection('users').doc(userId),
        {
          'role': 'customer_service',
          'customerServiceEnabled': true,
          'displayName': data['fullName']?.toString() ?? 'موظف بركة',
          'phone': data['phone']?.toString() ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      batch.set(
        _firestore.collection('employment_contracts').doc(userId),
        {
          'userId': userId,
          'employeeName': data['fullName']?.toString() ?? 'موظف بركة',
          'phone': data['phone']?.toString() ?? '',
          'email': data['email']?.toString() ?? '',
          'availability': data['availability']?.toString() ?? '',
          'title': 'وثيقة مباشرة عمل – خدمة عملاء بركة',
          'terms': _defaultContractTerms,
          'version': _contractVersion,
          'status': 'awaiting_signature',
          'issuedAt': FieldValue.serverTimestamp(),
          'issuedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
        },
        SetOptions(merge: true),
      );
      batch.set(
        _firestore.collection('customer_service_presence').doc(userId),
        {
          'displayName': data['fullName']?.toString() ?? 'موظف بركة',
          'isAvailable': false,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == 'approved'
              ? 'تم قبول الموظف وتفعيل بوابة خدمة العملاء ✅'
              : 'تم رفض الطلب.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        appBar: AppBar(
          backgroundColor: const Color(0xFF3D4147),
          foregroundColor: Colors.white,
          title: const Text('خدمة العملاء والتوظيف',
              style: TextStyle(fontWeight: FontWeight.w900)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _settings.snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() ?? const <String, dynamic>{};
                final remoteOpen = data['hiringOpen'] == true;
                _hiringOpen ??= remoteOpen;
                final open = _hiringOpen ?? remoteOpen;
                if (!_message.selection.isValid) {
                  _message.text = data['message']?.toString() ?? '';
                }
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('حالة استقبال الموظفين',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: open,
                          title: Text(open
                              ? 'نحتاج موظفين الآن'
                              : 'التوظيف مغلق حالياً'),
                          subtitle: const Text(
                              'عند الإغلاق لا يستطيع المستخدم إرسال طلب جديد.'),
                          onChanged: _saving ? null : _saveHiring,
                        ),
                        TextField(
                          controller: _message,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'الرسالة الظاهرة للمتقدمين',
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _saving ? null : () => _saveHiring(open),
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('حفظ الرسالة'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _contactSettings.snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() ?? const <String, dynamic>{};
                if (!_contactPhone.selection.isValid) {
                  _contactPhone.text = data['phone']?.toString() ?? '';
                }
                if (!_whatsAppPhone.selection.isValid) {
                  _whatsAppPhone.text = data['whatsapp']?.toString() ?? '';
                }
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('أرقام التواصل الظاهرة للعملاء',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        const Text(
                          'اتركي الرقم فارغاً لإخفاء خياره، ولن يستخدم التطبيق أي رقم شخصي ثابت.',
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _contactPhone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'رقم المكالمات',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _whatsAppPhone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'رقم واتساب',
                            prefixIcon: Icon(Icons.chat_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed:
                              _contactSaving ? null : _saveContactSettings,
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('حفظ أرقام التواصل'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('روابط المراسلة الاحتياطية عبر الموقع',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900)),
                    SizedBox(height: 10),
                    Text('للعملاء:',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    SelectableText('https://barakah-new.web.app/support',
                        style: TextStyle(color: AppTheme.navy)),
                    SizedBox(height: 10),
                    Text('للمتقدمين للوظيفة:',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    SelectableText('https://barakah-new.web.app/jobs',
                        style: TextStyle(color: AppTheme.navy)),
                    SizedBox(height: 8),
                    Text(
                      'نفس المحادثات والطلبات تظهر هنا في لوحة الأدمن ولا تحتاج إلى واتساب.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text('طلبات الانضمام',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('customer_service_applications')
                  .snapshots(),
              builder: (context, snapshot) {
                final applications = [...(snapshot.data?.docs ?? const [])]
                  ..sort((a, b) {
                    final at = a.data()['createdAt'] as Timestamp?;
                    final bt = b.data()['createdAt'] as Timestamp?;
                    return (bt?.millisecondsSinceEpoch ?? 0)
                        .compareTo(at?.millisecondsSinceEpoch ?? 0);
                  });
                if (applications.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('لا توجد طلبات حتى الآن.',
                          textAlign: TextAlign.center),
                    ),
                  );
                }
                return Column(
                  children: applications.map((application) {
                    final data = application.data();
                    final status = data['status']?.toString() ?? 'pending';
                    return Card(
                      child: ExpansionTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppTheme.coolYellow,
                          child: Icon(Icons.support_agent_rounded,
                              color: AppTheme.navy),
                        ),
                        title: Text(data['fullName']?.toString() ?? 'متقدم',
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text(
                            '${data['phone'] ?? ''} • ${data['city'] ?? ''} • $status'),
                        childrenPadding: const EdgeInsets.all(16),
                        children: [
                          _row('الخبرة', data['experience']),
                          _row('الدوام', data['availability']),
                          _row('سبب الانضمام', data['motivation']),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RecruitmentChatScreen(
                                    applicantId: application.id,
                                    applicantName:
                                        data['fullName']?.toString() ?? 'متقدم',
                                    adminMode: true,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.forum_rounded),
                              label: const Text('محادثة المتقدم داخل بركة'),
                            ),
                          ),
                          if (status == 'pending') ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () =>
                                        _review(application, 'approved'),
                                    icon: const Icon(Icons.check_rounded),
                                    label: const Text('قبول وإصدار الوثيقة'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _review(application, 'rejected'),
                                    icon: const Icon(Icons.close_rounded),
                                    label: const Text('رفض'),
                                  ),
                                ),
                              ],
                            ),
                          ] else if (status == 'approved') ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () =>
                                    _review(application, 'approved'),
                                icon: const Icon(Icons.description_rounded),
                                label: const Text(
                                    'إصدار وثيقة التوظيف وتفعيل الحساب'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      );

  Widget _row(String label, dynamic value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
            Expanded(child: Text(value?.toString() ?? '—')),
          ],
        ),
      );
}
