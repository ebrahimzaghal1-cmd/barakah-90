import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/admin/admin_live_dashboard.dart';
import '../lib/admin/admin_live_order.dart';

class _Doc extends Fake implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Doc(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic> value;
  @override
  Map<String, dynamic> data() => value;
}

class _Metadata extends Fake implements SnapshotMetadata {
  @override
  bool get isFromCache => false;
}

class _Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Snapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  @override
  SnapshotMetadata get metadata => _Metadata();
}

void main() {
  test(
      'delivery alone never counts as payment; payable total preserves discounts',
      () {
    final order = AdminLiveOrder(
        '1', {'status': 'delivered', 'total': 120, 'payableTotal': 100});
    expect(order.total, 100);
    expect(order.paid, isNull);
    expect(order.paymentLabel, 'التحصيل غير مسجّل');
    expect(AdminLiveOrder('2', {'total': 100, 'paidAmount': 40}).paymentLabel,
        'دفع جزئي');
    expect(
        AdminLiveOrder('3', {'total': 100, 'paymentStatus': 'paid'}).paid, 100);
    expect(AdminLiveOrder('4', {'total': 100, 'payableTotal': 0}).total, 0);
    expect(AdminLiveOrder('5', {'status': 'rejected'}).active, false);
  });
  for (final size in [
    const Size(1440, 1000),
    const Size(1050, 800),
    const Size(390, 844)
  ]) {
    testWidgets('live data, search, and layout at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final snapshot = _Snapshot(List.generate(
          5,
          (i) => _Doc('order-$i', {
                'orderNumber': 1000 + i,
                'customerName': 'عميل اختبار $i',
                'businessTitle': 'متجر بركة',
                'status': i == 4 ? 'delivered' : 'new',
                'total': 100,
                'commissionAmount': 10,
                'createdAt': Timestamp.now(),
                'items': [
                  {'title': 'منديل أهل العرسان', 'quantity': 1}
                ],
              })));
      await tester.pumpWidget(MaterialApp(
          home: AdminLiveDashboard(
              onTools: () {}, ordersStream: Stream.value(snapshot))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('عميل اختبار 0'), findsWidgets);
      expect(find.text('منديل أهل العرسان'), findsWidgets);
      await tester.enterText(find.byType(TextField), '1001');
      await tester.pumpAndSettle();
      expect(find.text('عميل اختبار 1'), findsWidgets);
      expect(find.text('عميل اختبار 0'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
