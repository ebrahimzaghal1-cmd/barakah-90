import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/admin_notification_service.dart';
import '../services/driver_service.dart';
import '../theme/app_theme.dart';

class DriverDashboard extends StatelessWidget {
  const DriverDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('سجّل الدخول أولاً.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة السائق'), centerTitle: true),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, profileSnapshot) {
          final profile =
              profileSnapshot.data?.data() ?? const <String, dynamic>{};
          final available = profile['driverAvailable'] == true;
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Card(
                child: SwitchListTile.adaptive(
                  value: available,
                  secondary: CircleAvatar(
                    backgroundColor: available
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    child: Icon(
                        available ? Icons.check_circle : Icons.delivery_dining),
                  ),
                  title: Text(
                      available ? 'متاح لاستلام طلب' : 'مشغول أو غير متاح',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: const Text(
                      'عند التفعيل تظهر لك طلبات التوصيل الجديدة ويمكنك قبولها قبل باقي السائقين.'),
                  onChanged: (value) async {
                    try {
                      if (value) {
                        final notificationsReady =
                            await AdminNotificationService.instance
                                .requestPermissionForCurrentUser();

                        if (!context.mounted) return;

                        if (!notificationsReady) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'تم تفعيل السائق، لكن إشعارات الجهاز غير مفعلة.',
                              ),
                            ),
                          );
                        }
                      }

                      await DriverService().setAvailable(value);
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 18),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('driverId', isEqualTo: user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  final now = DateTime.now();
                  final start = DateTime(now.year, now.month, now.day);
                  final end = start.add(const Duration(days: 1));

                  final deliveredToday =
                      (snapshot.data?.docs ?? []).where((doc) {
                    final data = doc.data();

                    if (data['status']?.toString() != 'delivered') {
                      return false;
                    }

                    final rawDate = data['deliveredAt'] ??
                        data['updatedAt'] ??
                        data['createdAt'];

                    if (rawDate is! Timestamp) return false;

                    final date = rawDate.toDate();

                    return !date.isBefore(start) && date.isBefore(end);
                  }).toList();

                  const commissionRate = 10.0;

                  final deliveryTotal = deliveredToday.fold<double>(
                    0,
                    (total, doc) =>
                        total +
                        ((doc.data()['deliveryFee'] as num?)?.toDouble() ?? 0),
                  );

                  final barakahCommission =
                      deliveryTotal * commissionRate / 100;

                  final driverNet = deliveryTotal - barakahCommission;

                  Widget box(String title, String value) {
                    return Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.deepYellow.withOpacity(.25),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              value,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppTheme.ink,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet_rounded,
                                color: AppTheme.deepYellow,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'محاسبة اليوم',
                                style: TextStyle(
                                  color: AppTheme.ink,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              box(
                                'الطلبات',
                                '${deliveredToday.length}',
                              ),
                              const SizedBox(width: 8),
                              box(
                                'تحصيل التوصيل',
                                '${deliveryTotal.toStringAsFixed(2)} ₪',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              box(
                                'عمولة بركة 10%',
                                '${barakahCommission.toStringAsFixed(2)} ₪',
                              ),
                              const SizedBox(width: 8),
                              box(
                                'صافي السائق',
                                '${driverNet.toStringAsFixed(2)} ₪',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              const Text(
                'طلبات متاحة الآن',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              StreamBuilder<int>(
                stream: Stream<int>.periodic(
                  const Duration(seconds: 8),
                  (value) => value,
                ),
                initialData: 0,
                builder: (context, _) {
                  return FutureBuilder<List<Map<String, dynamic>>>(
                    future: DriverService().availableOrders(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (snapshot.hasError) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'خطأ تحميل الطلبات المتاحة: ${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        );
                      }

                      final availableOrders = snapshot.data ?? const [];

                      if (availableOrders.isEmpty) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'لا توجد طلبات متاحة الآن.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: availableOrders.map((order) {
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'طلب ${order['orderNumber'] ?? order['id']}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    '${order['businessTitle'] ?? 'المطعم'} • ${order['total'] ?? 0} ₪',
                                  ),
                                  const SizedBox(height: 10),
                                  FilledButton.icon(
                                    onPressed: () async {
                                      try {
                                        await DriverService().claimOrder(
                                          order['id'].toString(),
                                        );

                                        if (!context.mounted) return;

                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'تم قبول الطلب وتثبيته لك ✅',
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } catch (error) {
                                        if (!context.mounted) return;

                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(error.toString()),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.check_circle_outline_rounded,
                                    ),
                                    label: const Text('قبول الطلب'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 18),
              const Text(
                'طلبات التوصيل الخاصة بي',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: DriverService().myOrders(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final orders = snapshot.data!.docs
                      .where((doc) => doc.data()['status'] != 'delivered')
                      .toList();
                  if (orders.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(26),
                        child: Text('لا يوجد طلب توصيل نشط حالياً.',
                            textAlign: TextAlign.center),
                      ),
                    );
                  }
                  return Column(
                      children: orders.map((order) {
                    final data = order.data();
                    final status =
                        data['status']?.toString() ?? 'driver_assigned';
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('طلب ${data['orderNumber'] ?? order.id}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18)),
                              Text(
                                  '${data['businessTitle'] ?? 'المطعم'} • ${data['total'] ?? 0} ₪'),
                              if (data['estimatedReadyAt'] is Timestamp)
                                Text(
                                    'موعد الجاهزية: ${(data['estimatedReadyAt'] as Timestamp).toDate().toLocal()}'),
                              const SizedBox(height: 10),
                              if (status == 'driver_assigned')
                                FilledButton.icon(
                                  onPressed: () => DriverService()
                                      .updateDeliveryStatus(
                                          order.id, 'picked_up'),
                                  icon: const Icon(Icons.delivery_dining),
                                  label: const Text('استلمت الطلب من المطعم'),
                                ),
                              if (status == 'picked_up')
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.ink),
                                  onPressed: () => DriverService()
                                      .updateDeliveryStatus(
                                          order.id, 'delivered'),
                                  icon: const Icon(Icons.task_alt),
                                  label: const Text('تم تسليم الطلب للزبون'),
                                ),
                            ]),
                      ),
                    );
                  }).toList());
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
