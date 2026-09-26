import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/mediator_service.dart';
import '../widgets/barakah_brand.dart';
import 'location_picker_screen.dart';
import 'legal_documents_screen.dart';

class MediatorJoinScreen extends StatefulWidget {
  const MediatorJoinScreen({super.key});
  @override
  State<MediatorJoinScreen> createState() => _MediatorJoinScreenState();
}

class _MediatorJoinScreenState extends State<MediatorJoinScreen> {
  final name = TextEditingController(),
      phone = TextEditingController(),
      area = TextEditingController();
  late Future<Map<String, dynamic>> terms = MediatorService().call('terms', {});
  double? latitude, longitude;
  bool privacy = false, contract = false, busy = false;
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    area.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('الانضمام كوسيطة')),
      body: BarakahBrandBackdrop(
          child: FirebaseAuth.instance.currentUser == null
              ? const Center(
                  child: Text(
                      'سجّلي الدخول أولًا من صفحتي، ثم عودي لطلب الانضمام'))
              : FutureBuilder<Map<String, dynamic>>(
                  future: terms,
                  builder: (context, s) {
                    if (s.hasError) {
                      return Center(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text(
                            'تعذر تحميل الاتفاق. لا يمكن تقديم الطلب دون عرضه.'),
                        TextButton(
                            onPressed: () => setState(() =>
                                terms = MediatorService().call('terms', {})),
                            child: const Text('إعادة المحاولة'))
                      ]));
                    }
                    if (!s.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final t = s.data!;
                    return ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          const Text('اعملي كوسيطة مع بركة',
                              style: TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.bold)),
                          const Text(
                              'أكملي بياناتك، اقرئي سياسة الخصوصية والاتفاق، ثم أرسلي الطلب لمراجعة الإدارة. لن تظهر صفحتك للعامة قبل الاعتماد.'),
                          TextField(
                              controller: name,
                              decoration: const InputDecoration(
                                  labelText: 'الاسم الذي سيظهر للعملاء')),
                          TextField(
                              controller: phone,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                  labelText: 'رقم الهاتف الخاص — للإدارة فقط')),
                          TextField(
                              controller: area,
                              decoration: const InputDecoration(
                                  labelText: 'المنطقة التي تخدمينها')),
                          OutlinedButton.icon(
                              icon: const Icon(Icons.map_outlined),
                              label: Text(latitude == null
                                  ? 'اختاري موقع ظهورك على الخريطة'
                                  : 'تم تحديد الموقع — تعديل'),
                              onPressed: () async {
                                final p =
                                    await Navigator.push<Map<String, double>>(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                LocationPickerScreen(
                                                    latitude: latitude,
                                                    longitude: longitude)));
                                if (p != null && mounted) {
                                  setState(() {
                                    latitude = p['latitude'];
                                    longitude = p['longitude'];
                                  });
                                }
                              }),
                          const Text(
                              'اختاري نقطة خدمة مناسبة للنشر؛ الموقع المختار سيظهر للعملاء على الخريطة.'),
                          const SizedBox(height: 20),
                          Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const Text('سياسة خصوصية الوسيطة',
                                            style: TextStyle(
                                                fontSize: 21,
                                                fontWeight: FontWeight.bold)),
                                        SelectableText('${t['privacyText']}'),
                                        TextButton(
                                            onPressed: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        const LegalDocumentScreen(
                                                            type:
                                                                LegalDocumentType
                                                                    .privacy))),
                                            child: const Text(
                                                'سياسة خصوصية بركة العامة')),
                                        CheckboxListTile(
                                            value: privacy,
                                            onChanged: busy
                                                ? null
                                                : (v) => setState(
                                                    () => privacy = v ?? false),
                                            title: const Text(
                                                'قرأت سياسة الخصوصية وأوافق عليها'))
                                      ]))),
                          Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const Text('اتفاق عمل الوسيطة',
                                            style: TextStyle(
                                                fontSize: 21,
                                                fontWeight: FontWeight.bold)),
                                        Text('نسخة ${t['agreementVersion']}'),
                                        SelectableText('${t['contractText']}'),
                                        const Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 12),
                                            child: Text(
                                                'مثال: أجرتك 20 ₪ ← عمولة بركة 1 ₪ ← صافيك 19 ₪',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        CheckboxListTile(
                                            value: contract,
                                            onChanged: busy
                                                ? null
                                                : (v) => setState(() =>
                                                    contract = v ?? false),
                                            title: const Text(
                                                'قرأت الاتفاق وأوافق على عمولة بركة 5% من أجرتي فقط'))
                                      ]))),
                          FilledButton(
                              onPressed: busy || !privacy || !contract
                                  ? null
                                  : () async {
                                      if (name.text.trim().isEmpty ||
                                          phone.text.trim().isEmpty ||
                                          area.text.trim().isEmpty ||
                                          latitude == null) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    'أكملي البيانات وحددي الموقع')));
                                        return;
                                      }
                                      setState(() => busy = true);
                                      try {
                                        final r = await MediatorService()
                                            .call('apply', {
                                          'name': name.text,
                                          'phone': phone.text,
                                          'area': area.text,
                                          'latitude': latitude,
                                          'longitude': longitude,
                                          'agreementVersion':
                                              t['agreementVersion'],
                                          'acceptPrivacy': privacy,
                                          'acceptContract': contract
                                        });
                                        if (context.mounted) {
                                          await showDialog<void>(
                                              context: context,
                                              builder: (c) => AlertDialog(
                                                      title: const Text(
                                                          'حالة طلبك'),
                                                      content: Text(r[
                                                                  'status'] ==
                                                              'approved'
                                                          ? 'حسابك معتمد بالفعل. افتحي طلبات الوسيطة وأرباحي من صفحتي.'
                                                          : 'طلبك بانتظار مراجعة الإدارة. يمكنك متابعة حالته هنا.'),
                                                      actions: [
                                                        TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    c),
                                                            child: const Text(
                                                                'حسنًا'))
                                                      ]));
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                                  content: Text('$e')));
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(() => busy = false);
                                        }
                                      }
                                    },
                              child: Text(busy
                                  ? 'جارٍ الإرسال…'
                                  : 'إرسال طلب الانضمام')),
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance
                                  .collection('mediator_applications')
                                  .doc(FirebaseAuth.instance.currentUser!.uid)
                                  .snapshots(),
                              builder: (context, s) {
                                final a = s.data?.data();
                                return a == null
                                    ? const SizedBox.shrink()
                                    : Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                            'حالة الطلب: ${a['status'] == 'approved' ? 'معتمد' : a['status'] == 'rejected' ? 'مرفوض' : 'بانتظار المراجعة'}\n${a['reviewNote'] ?? ''}'));
                              }),
                        ]);
                  })));
}

class MediatorApplicationsScreen extends StatefulWidget {
  const MediatorApplicationsScreen({super.key});
  @override
  State<MediatorApplicationsScreen> createState() =>
      _MediatorApplicationsScreenState();
}

class _MediatorApplicationsScreenState
    extends State<MediatorApplicationsScreen> {
  bool busy = false;
  Future<void> review(String uid, bool approve) async {
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: Text(approve ? 'اعتماد الوسيطة' : 'رفض الطلب'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (approve)
                    const Text(
                        'سيُنشأ ملف وسيطة عام بالاسم والموقع، ويبقى رقمها خاصًا. عليها تحديد أجرتها قبل استقبال الطلبات.'),
                  TextField(
                      controller: note,
                      decoration: InputDecoration(
                          labelText: approve
                              ? 'ملاحظة المراجعة'
                              : 'سبب الرفض (مطلوب)'))
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('إلغاء')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('تأكيد'))
                ]));
    final reason = note.text;
    note.dispose();
    if (confirmed != true) return;
    setState(() => busy = true);
    try {
      await MediatorService().call(
          approve ? 'approve_application' : 'reject_application',
          {'applicantId': uid, 'note': reason});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('طلبات انضمام الوسيطات')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('mediator_applications')
              .snapshots(),
          builder: (context, s) {
            if (s.hasError) {
              return const Center(child: Text('تعذر تحميل الطلبات'));
            }
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(padding: const EdgeInsets.all(16), children: [
              if (s.data!.docs.isEmpty) const Text('لا توجد طلبات انضمام'),
              for (final doc in s.data!.docs)
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                  '${doc.data()['name']} • ${doc.data()['area']}'),
                              Text('هاتف خاص: ${doc.data()['phone']}'),
                              Text(
                                  'الحالة: ${doc.data()['status']} • الاتفاق ${doc.data()['agreementVersion']} • العمولة 5%'),
                              Text(
                                  'الموافقة: ${(doc.data()['acceptedAt'] as Timestamp?)?.toDate().toLocal() ?? ''}'),
                              ExpansionTile(
                                  title: const Text(
                                      'نسخة الاتفاق والسياسة المقبولة'),
                                  children: [
                                    SelectableText(
                                        '${doc.data()['contractText']}\n\n${doc.data()['privacyText']}')
                                  ]),
                              if (doc.data()['status'] == 'pending')
                                Wrap(spacing: 12, children: [
                                  FilledButton(
                                      onPressed: busy
                                          ? null
                                          : () => review(doc.id, true),
                                      child: const Text('اعتماد')),
                                  OutlinedButton(
                                      onPressed: busy
                                          ? null
                                          : () => review(doc.id, false),
                                      child: const Text('رفض'))
                                ])
                            ])))
            ]);
          }));
}
