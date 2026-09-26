import 'mediator_settings_screen.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/mediator_service.dart';
import '../theme/app_theme.dart';
import '../widgets/barakah_brand.dart';

String mediatorAmount(Object? cents) =>
    '${((cents as num? ?? 0) / 100).toStringAsFixed(2)} ₪';
const mediatorLabels = {
  'pending': 'بانتظار القبول',
  'in_progress': 'قيد التنفيذ',
  'delivered': 'تم التسليم',
  'disputed': 'قيد الاعتراض',
  'settled': 'تم دفع المستحق',
  'rejected': 'مرفوض'
};

class MediatorOrderForm extends StatefulWidget {
  const MediatorOrderForm(
      {super.key, required this.businessId, required this.business});
  final String businessId;
  final Map<String, dynamic> business;
  @override
  State<MediatorOrderForm> createState() => _MediatorOrderFormState();
}

class _MediatorOrderFormState extends State<MediatorOrderForm> {
  final details = TextEditingController(),
      address = TextEditingController(),
      budget = TextEditingController();
  final requestId =
      List.generate(24, (_) => Random.secure().nextInt(16).toRadixString(16))
          .join();
  bool busy = false;
  @override
  void dispose() {
    details.dispose();
    address.dispose();
    budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fee = ((widget.business['mediatorFee'] as num? ?? 0) * 100).round();
    final delivery =
        ((widget.business['deliveryFee'] as num? ?? 0) * 100).round();
    final value = double.tryParse(budget.text) ?? 0;
    return Scaffold(
        appBar: AppBar(title: const Text('طلب وسيطة')),
        body: BarakahBrandBackdrop(
            child: ListView(padding: const EdgeInsets.all(20), children: [
          Text(widget.business['title']?.toString() ?? '',
              style: Theme.of(context).textTheme.headlineSmall),
          TextField(
              controller: details,
              maxLines: 4,
              decoration: const InputDecoration(
                  labelText: 'تفاصيل المشتريات المطلوبة')),
          TextField(
              controller: address,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: 'عنوان التسليم بالتفصيل')),
          TextField(
              controller: budget,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                  labelText: 'قيمة المشتريات المتفق عليها بالشيكل')),
          const SizedBox(height: 20),
          Text(
              'المشتريات: ${mediatorAmount((value * 100).round())}\nأجرة الوسيطة: ${mediatorAmount(fee)}\nالتوصيل: ${mediatorAmount(delivery)}\nالإجمالي: ${mediatorAmount((value * 100).round() + fee + delivery)}',
              style: const TextStyle(fontSize: 18, height: 1.8)),
          const ListTile(
              leading: Icon(Icons.payments_outlined),
              title: Text('الدفع نقدًا عند الاستلام')),
          const ListTile(
              enabled: false,
              leading: Icon(Icons.credit_card),
              title: Text('الدفع بالبطاقة — قريبًا')),
          const Text(
              'القيمة ثابتة لهذا الطلب. راجعي المشتريات والرسوم قبل الإرسال؛ أي تغيير يستلزم طلبًا جديدًا. لا تشاركي رمز التسليم قبل استلام الطلب.'),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: busy || widget.business['mediatorFee'] == null
                  ? null
                  : () async {
                      if (details.text.trim().isEmpty ||
                          address.text.trim().isEmpty ||
                          double.tryParse(budget.text) == null ||
                          value < 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'أكمل التفاصيل والعنوان والقيمة الصحيحة')));
                        return;
                      }
                      setState(() => busy = true);
                      try {
                        final result = await MediatorService().call('create', {
                          'businessId': widget.businessId,
                          'requestId': requestId,
                          'details': details.text,
                          'address': address.text,
                          'budget': value,
                          'paymentMethod': 'cash',
                          'expectedFeeCents': fee,
                          'expectedDeliveryCents': delivery
                        });
                        if (context.mounted) {
                          Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => MediatorOrderDetails(
                                      orderId: result['orderId'])));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('$e')));
                        }
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
              child: Text(busy
                  ? 'جارٍ الإرسال…'
                  : widget.business['mediatorFee'] == null
                      ? 'بانتظار تحديد أجرة الوسيطة'
                      : 'تأكيد الطلب')),
        ])));
  }
}

class MediatorOrdersScreen extends StatelessWidget {
  const MediatorOrdersScreen(
      {super.key, this.mediator = false, this.admin = false});
  final bool mediator, admin;
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('سجّل الدخول أولًا')));
    }
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('mediator_orders');
    if (!admin) {
      query =
          query.where(mediator ? 'mediatorId' : 'customerId', isEqualTo: uid);
    }
    return Scaffold(
        appBar: AppBar(
            actions: [
              if (mediator || admin)
                IconButton(
                    tooltip: 'إعدادات الوسيطات',
                    icon: const Icon(Icons.settings),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                MediatorSettingsScreen(admin: admin))))
            ],
            title: Text(admin
                ? 'إدارة طلبات الوسيطات'
                : mediator
                    ? 'طلبات الوسيطة وأرباحي'
                    : 'طلباتي من الوسيطات')),
        body: BarakahBrandBackdrop(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: query.snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return const Center(
                        child: Text(
                            'تعذر تحميل الطلبات؛ تحقق من الاتصال والصلاحيات'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data!.docs.toList()
                    ..sort((a, b) => ((b.data()['createdAt'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0)
                        .compareTo((a.data()['createdAt'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0));
                  int sum(String status) => docs
                      .where((d) => d.data()['earningStatus'] == status)
                      .fold(
                          0,
                          (s, d) =>
                              s +
                              ((d.data()['netFeeCents'] ?? d.data()['feeCents'])
                                      as num)
                                  .toInt());
                  return ListView(padding: const EdgeInsets.all(16), children: [
                    if (mediator || admin)
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Text(
                                  'متوقعة / قيد التنفيذ: ${mediatorAmount(sum('pending'))}\nمستحقة: ${mediatorAmount(sum('due'))}\nمدفوعة: ${mediatorAmount(sum('paid'))}\nمعلّقة باعتراض: ${mediatorAmount(sum('held'))}',
                                  style: const TextStyle(
                                      fontSize: 18, height: 1.8)))),
                    if (docs.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('لا توجد طلبات بعد')),
                    for (final doc in docs)
                      Card(
                          child: ListTile(
                              title: Text(
                                  '${doc.data()['orderNumber']} • ${doc.data()['title']}'),
                              subtitle: Text(
                                  '${mediatorLabels[doc.data()['status']] ?? doc.data()['status']}\nالإجمالي ${mediatorAmount(doc.data()['totalCents'])} • الأجرة ${mediatorAmount(doc.data()['feeCents'])}'),
                              isThreeLine: true,
                              trailing: const Icon(Icons.chevron_left),
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => MediatorOrderDetails(
                                          orderId: doc.id, admin: admin))))),
                  ]);
                })));
  }
}

class MediatorOrderDetails extends StatefulWidget {
  const MediatorOrderDetails(
      {super.key, required this.orderId, this.admin = false});
  final String orderId;
  final bool admin;
  @override
  State<MediatorOrderDetails> createState() => _MediatorOrderDetailsState();
}

class _MediatorOrderDetailsState extends State<MediatorOrderDetails> {
  final text = TextEditingController(), otp = TextEditingController();
  bool busy = false, cash = false;
  @override
  void dispose() {
    text.dispose();
    otp.dispose();
    super.dispose();
  }

  Future<void> act(String action,
      [Map<String, dynamic> extra = const {}]) async {
    setState(() => busy = true);
    try {
      await MediatorService().call(
          action, {'orderId': widget.orderId, 'note': text.text, ...extra});
      text.clear();
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
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('mediator_orders')
        .doc(widget.orderId);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    Widget button(String label, String action,
            [Map<String, dynamic> extra = const {}]) =>
        FilledButton(
            onPressed: busy
                ? null
                : () => act(
                    action,
                    action == 'deliver'
                        ? {'otp': otp.text, 'cashCollected': cash}
                        : extra),
            child: Text(label));
    return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل طلب الوسيطة')),
        body: BarakahBrandBackdrop(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: ref.snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return const Center(child: Text('تعذر تحميل الطلب'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final o = snap.data!.data();
                  if (o == null) {
                    return const Center(child: Text('الطلب غير موجود'));
                  }
                  final customer = uid == o['customerId'],
                      mediator = uid == o['mediatorId'];
                  return ListView(padding: const EdgeInsets.all(20), children: [
                    Text(
                        '${o['orderNumber']}\n${mediatorLabels[o['status']] ?? o['status']}',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.navy)),
                    Text(
                        '${o['details']}\nالعنوان: ${o['address']}\nالمشتريات: ${mediatorAmount(o['budgetCents'])}\nأجرة الوسيطة: ${mediatorAmount(o['feeCents'])}\nالتوصيل: ${mediatorAmount(o['deliveryCents'])}\nالإجمالي النقدي: ${mediatorAmount(o['totalCents'])}',
                        style: const TextStyle(fontSize: 18, height: 1.8)),
                    if (mediator || widget.admin)
                      Text(
                          'عمولة بركة: ${mediatorAmount(o['platformFeeCents'])} • صافي أجرتك: ${mediatorAmount(o['netFeeCents'] ?? o['feeCents'])}\nالنقد المستلم يُطابق عند التسوية ولا يُدفع مرة ثانية.'),
                    if (customer &&
                        ['pending', 'in_progress'].contains(o['status']))
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: ref
                              .collection('private')
                              .doc('delivery')
                              .snapshots(),
                          builder: (context, s) => Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                      'رمز التسليم: ${s.data?.data()?['otp'] ?? '…'}\nأعطيه للوسيطة بعد الاستلام فقط',
                                      style: const TextStyle(fontSize: 22))))),
                    if (mediator && o['status'] == 'pending')
                      Wrap(spacing: 12, children: [
                        button('قبول الطلب', 'accept'),
                        button('رفض الطلب', 'reject')
                      ]),
                    if (mediator && o['status'] == 'in_progress') ...[
                      TextField(
                          controller: otp,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: const InputDecoration(
                              labelText: 'رمز التسليم من العميل')),
                      CheckboxListTile(
                          value: cash,
                          onChanged: busy
                              ? null
                              : (v) => setState(() => cash = v ?? false),
                          title: Text(
                              'استلمت ${mediatorAmount(o['totalCents'])} نقدًا')),
                      button('إتمام التسليم', 'deliver',
                          {'otp': otp.text, 'cashCollected': cash}),
                    ],
                    if (o['disputeReason'] != null)
                      Text('سبب الاعتراض: ${o['disputeReason']}'),
                    if (o['resolution'] != null)
                      Text('قرار الإدارة: ${o['resolution']}'),
                    if (o['settlementReference'] != null)
                      Text('مرجع دفع المستحق: ${o['settlementReference']}'),
                    const SizedBox(height: 20),
                    TextField(
                        controller: text,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            labelText: 'رسالة / سبب الاعتراض / مرجع العملية')),
                    Wrap(spacing: 8, children: [
                      if (!['rejected', 'settled'].contains(o['status']))
                        button('إرسال رسالة', 'message'),
                      if ((customer || mediator) &&
                          ['in_progress', 'delivered'].contains(o['status']))
                        button('فتح اعتراض', 'dispute'),
                      if (widget.admin && o['status'] == 'disputed')
                        button('حل الاعتراض مع تسجيل السبب', 'resolve'),
                      if (widget.admin && o['status'] == 'delivered')
                        button('تسجيل دفع المستحق مع المرجع', 'settle'),
                    ]),
                    const SizedBox(height: 20),
                    const Text('محادثة الطلب',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: ref
                            .collection('messages')
                            .orderBy('createdAt')
                            .snapshots(),
                        builder: (context, s) => Column(children: [
                              for (final m in s.data?.docs ??
                                  <QueryDocumentSnapshot<
                                      Map<String, dynamic>>>[])
                                ListTile(
                                    title: Text(m.data()['text'] ?? ''),
                                    subtitle: Text(
                                        '${m.data()['senderId'] == uid ? 'أنت' : 'الطرف الآخر'} • ${(m.data()['createdAt'] as Timestamp?)?.toDate().toLocal() ?? ''}'))
                            ])),
                    const Text('سجل العمليات',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: ref
                            .collection('events')
                            .orderBy('createdAt')
                            .snapshots(),
                        builder: (context, s) => Column(children: [
                              for (final e in s.data?.docs ??
                                  <QueryDocumentSnapshot<
                                      Map<String, dynamic>>>[])
                                ListTile(
                                    title: Text(
                                        '${e.data()['action']} ${e.data()['note'] ?? ''}'),
                                    subtitle: Text(
                                        '${(e.data()['createdAt'] as Timestamp?)?.toDate().toLocal() ?? ''}'))
                            ])),
                  ]);
                })));
  }
}
