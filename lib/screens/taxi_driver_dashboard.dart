import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/taxi_driver_tracking.dart';

class TaxiDriverDashboard extends StatelessWidget {
  const TaxiDriverDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('سجّل الدخول أولاً.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة سائق تكسي بركة'),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(includeMetadataChanges: true),
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState == ConnectionState.waiting &&
              !profileSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (profileSnapshot.hasError) {
            return const Center(
              child: Text(
                'تعذر التحقق من حساب سائق التكسي.',
                textAlign: TextAlign.center,
              ),
            );
          }

          final profile =
              profileSnapshot.data?.data() ?? const <String, dynamic>{};

          final taxiBusinessId =
              profile['taxiBusinessId']?.toString().trim() ?? '';

          final isTaxiDriver =
              profile['taxiDriverEnabled'] == true && taxiBusinessId.isNotEmpty;

          if (!isTaxiDriver) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'حسابك غير مفعّل حاليًا كسائق تكسي بركة أو لم يتم ربطه بمكتب تكسي.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: AppTheme.deepYellow,
                        child: Icon(
                          Icons.local_taxi_rounded,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'سائق تكسي بركة',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              (profile['taxiBusinessName'] ?? '')
                                      .toString()
                                      .trim()
                                      .isNotEmpty
                                  ? profile['taxiBusinessName']
                                      .toString()
                                      .trim()
                                  : 'مرتبط بمكتب تكسي بركة',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'رحلات التكسي المعيّنة لي',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('taxi_orders')
                    .where('driverUid', isEqualTo: user.uid)
                    .snapshots(includeMetadataChanges: true),
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
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          'تعذر تحميل رحلات التكسي: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    );
                  }

                  final trips = (snapshot.data?.docs ?? []).where((doc) {
                    final status = doc.data()['status']?.toString() ?? '';
                    return status == 'dispatched' ||
                        status == 'awaiting_customer_confirmation';
                  }).toList();

                  if (trips.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(22),
                        child: Text(
                          'لا توجد رحلة تكسي نشطة معيّنة لك حاليًا.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: trips.map((trip) {
                      final data = trip.data();

                      final customerName = (data['customerName'] ?? 'عميل بركة')
                          .toString()
                          .trim();

                      final customerPhone =
                          (data['customerPhone'] ?? '').toString().trim();

                      final pickupAddress =
                          (data['pickupAddress'] ?? '').toString().trim();

                      final destination =
                          (data['destination'] ?? '').toString().trim();

                      final vehicle =
                          (data['dispatchedVehicle'] ?? '').toString().trim();

                      final eta = data['dispatchedEtaMinutes'];

                      final status = data['status']?.toString() ?? 'dispatched';

                      final createdAt = data['createdAt'];
                      String createdText = '';

                      if (createdAt is Timestamp) {
                        final date = createdAt.toDate().toLocal();
                        final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
                        final period = date.hour >= 12 ? 'م' : 'ص';

                        String two(int value) =>
                            value.toString().padLeft(2, '0');

                        createdText =
                            '${two(date.day)}/${two(date.month)}/${date.year}'
                            ' — $hour:${two(date.minute)} $period';
                      }

                      final sameOffice =
                          data['businessId']?.toString() == taxiBusinessId;

                      final trackingAllowed = !profileSnapshot.hasError &&
                          profileSnapshot.data != null &&
                          !profileSnapshot.data!.metadata.isFromCache &&
                          snapshot.data != null &&
                          !snapshot.data!.metadata.isFromCache &&
                          profile['taxiDriverEnabled'] == true &&
                          sameOffice;

                      return Card(
                        key: ValueKey('taxi-${trip.id}'),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(
                                    backgroundColor: AppTheme.deepYellow,
                                    child: Icon(
                                      Icons.local_taxi_rounded,
                                      color: AppTheme.ink,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'تكسي بركة • ${trip.id}',
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        Text(
                                          status == 'dispatched'
                                              ? 'رحلة نشطة'
                                              : 'بانتظار تأكيد العميل',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Text(
                                'العميل: $customerName',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (customerPhone.isNotEmpty)
                                SelectableText('الهاتف: $customerPhone'),
                              if (createdText.isNotEmpty)
                                Text('وقت الطلب: $createdText'),
                              const SizedBox(height: 10),
                              Text(
                                '📍 نقطة الانطلاق: '
                                '${pickupAddress.isEmpty ? 'غير محددة' : pickupAddress}',
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '🏁 الوجهة: '
                                '${destination.isEmpty ? 'غير محددة' : destination}',
                              ),
                              if (vehicle.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text('🚕 السيارة: $vehicle'),
                              ],
                              if (eta != null) ...[
                                const SizedBox(height: 5),
                                Text('⏱️ الوصول المتوقع: $eta دقيقة'),
                              ],
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.deepYellow.withOpacity(.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'هذه الرحلة معيّنة لك من نظام تكسي بركة.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TaxiDriverTracking(
                                key: ValueKey(trip.id),
                                orderId: trip.id,
                                driverUid: user.uid,
                                assignedDriverUid:
                                    data['driverUid']?.toString() ?? '',
                                status: status,
                                tripStarted: data['tripStartedAt'] != null,
                                allowed: trackingAllowed,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'ملاحظة: مشاركة الموقع تعمل أثناء فتح التطبيق وتشغيل تتبع الرحلة.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
