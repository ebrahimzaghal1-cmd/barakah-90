import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminAppointmentsAccountingScreen extends StatelessWidget {
  const AdminAppointmentsAccountingScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final body = DefaultTabController(
      length: 2,
      child: Column(children: [
        const TabBar(tabs: [
          Tab(icon: Icon(Icons.content_cut_rounded), text: 'الحلاقون'),
          Tab(icon: Icon(Icons.medical_services_rounded), text: 'الأطباء'),
        ]),
        const Expanded(
            child: TabBarView(children: [
          _AppointmentLedger(type: 'barber'),
          _AppointmentLedger(type: 'doctor'),
        ])),
      ]),
    );
    if (embedded) return body;
    return Scaffold(
        appBar: AppBar(title: const Text('محاسبة الحجوزات'), centerTitle: true),
        body: body);
  }
}

class _AppointmentLedger extends StatelessWidget {
  const _AppointmentLedger({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('items').snapshots(),
        builder: (context, businessSnapshot) {
          if (businessSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Keep compatibility with older partner records that were saved
          // before `type: barber|doctor` was introduced.
          final businessIds = (businessSnapshot.data?.docs ?? [])
              .where((doc) => _matchesBusiness(doc.data()))
              .map((doc) => doc.id)
              .toSet();
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('barber_bookings')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final bookings = snapshot.data!.docs
                  .where((doc) => businessIds
                      .contains(doc.data()['businessId']?.toString()))
                  .toList();
              final total = bookings.fold<double>(
                  0,
                  (value, doc) =>
                      value +
                      ((doc.data()['commissionAmount'] as num?)?.toDouble() ??
                          0));
              final received = bookings
                  .where((doc) => doc.data()['commissionReceived'] == true)
                  .fold<double>(
                      0,
                      (value, doc) =>
                          value +
                          ((doc.data()['commissionAmount'] as num?)
                                  ?.toDouble() ??
                              0));
              return ListView(padding: const EdgeInsets.all(16), children: [
                Card(
                    color: const Color(0xFFFFF4CE),
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(children: [
                          Text(
                              type == 'doctor'
                                  ? 'تحصيل الأطباء'
                                  : 'تحصيل الحلاقين',
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          Text(
                              'الإجمالي: ${total.toStringAsFixed(2)} ₪   •   تم التحصيل: ${received.toStringAsFixed(2)} ₪',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700))
                        ]))),
                const SizedBox(height: 10),
                if (bookings.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(30),
                      child: Text('لا توجد حجوزات في هذا القسم.',
                          textAlign: TextAlign.center)),
                ...bookings.map((doc) {
                  final data = doc.data();
                  final scheduled =
                      (data['scheduledAt'] as Timestamp?)?.toDate();
                  final when = scheduled == null
                      ? data['dateKey']?.toString() ?? ''
                      : '${scheduled.day}/${scheduled.month}/${scheduled.year} ${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}';
                  final paid = data['commissionReceived'] == true;
                  return Card(
                      child: ListTile(
                          title: Text(
                              '${data['customerName'] ?? 'زبون'} — ${data['serviceTitle'] ?? 'موعد'}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900)),
                          subtitle: Text(
                              '$when\nقيمة الحجز: ${data['price'] ?? 0} ₪ • عمولة 10%: ${data['commissionAmount'] ?? 0} ₪'),
                          isThreeLine: true,
                          trailing: paid
                              ? const Icon(Icons.check_circle,
                                  color: Colors.green)
                              : IconButton(
                                  tooltip: 'تأكيد التحصيل',
                                  icon: const Icon(Icons.payments_outlined),
                                  onPressed: () => doc.reference.update({
                                        'commissionReceived': true,
                                        'commissionReceivedAt':
                                            FieldValue.serverTimestamp()
                                      }))));
                }),
              ]);
            },
          );
        },
      );

  bool _matchesBusiness(Map<String, dynamic> data) {
    final values = [
      data['type'],
      data['merchantType'],
      data['activityType'],
      data['category'],
    ].map((value) => value?.toString().toLowerCase().trim() ?? '');
    final joined = values.join(' ');
    if (type == 'doctor') {
      return joined.contains('doctor') ||
          joined.contains('طبيب') ||
          joined.contains('دكتور') ||
          joined.contains('صحة');
    }
    return joined.contains('barber') ||
        joined.contains('حلاق') ||
        joined.contains('صالون');
  }
}
