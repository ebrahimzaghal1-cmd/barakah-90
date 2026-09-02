import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminHealthCommissionsScreen extends StatelessWidget {
  const AdminHealthCommissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('حجوزات الصحة وعمولة بركة'), centerTitle: true),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('barber_bookings')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final bookings = snapshot.data!.docs.toList()
            ..sort((a, b) => ((b.data()['createdAt'] as Timestamp?)
                        ?.millisecondsSinceEpoch ??
                    0)
                .compareTo((a.data()['createdAt'] as Timestamp?)
                        ?.millisecondsSinceEpoch ??
                    0));
          final total = bookings.fold<double>(
              0,
              (sum, doc) =>
                  sum +
                  ((doc.data()['commissionAmount'] as num?)?.toDouble() ?? 0));
          final received = bookings
              .where((doc) => doc.data()['commissionReceived'] == true)
              .fold<double>(
                  0,
                  (sum, doc) =>
                      sum +
                      ((doc.data()['commissionAmount'] as num?)?.toDouble() ??
                          0));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                  color: const Color(0xFFFFF4CE),
                  child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(children: [
                        const Text('إجمالي عمولة بركة المحفوظة',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text('${total.toStringAsFixed(2)} ₪',
                            style: const TextStyle(
                                fontSize: 30, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text(
                            'تم تأكيد تحصيل: ${received.toStringAsFixed(2)} ₪  •  متبقي: ${(total - received).toStringAsFixed(2)} ₪')
                      ]))),
              const SizedBox(height: 14),
              Text('كل الحجوزات: ${bookings.length}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              if (bookings.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(30),
                    child: Text('لا توجد حجوزات بعد.',
                        textAlign: TextAlign.center)),
              ...bookings.map((doc) {
                final data = doc.data();
                final scheduled = (data['scheduledAt'] as Timestamp?)?.toDate();
                final when = scheduled == null
                    ? data['dateKey']?.toString() ?? ''
                    : '${scheduled.day}/${scheduled.month}/${scheduled.year} ${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}';
                return Card(
                    child: ListTile(
                        title: Text(
                            '${data['customerName'] ?? 'مريض'} — ${data['serviceTitle'] ?? 'موعد'}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text(
                            '$when\nالحالة: ${data['status'] ?? ''} • قيمة الحجز: ${data['price'] ?? 0} ₪\nعمولة بركة 10%: ${data['commissionAmount'] ?? 0} ₪'),
                        isThreeLine: true,
                        trailing: data['commissionReceived'] == true
                            ? const Icon(Icons.check_circle,
                                color: Colors.green)
                            : IconButton(
                                tooltip: 'تأكيد استلام العمولة',
                                icon: const Icon(Icons.payments_outlined),
                                onPressed: () => doc.reference.update({
                                      'commissionReceived': true,
                                      'commissionReceivedAt':
                                          FieldValue.serverTimestamp()
                                    }))));
              }),
            ],
          );
        },
      ),
    );
  }
}
