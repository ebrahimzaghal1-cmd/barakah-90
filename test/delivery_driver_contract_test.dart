import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barakah90/admin/widgets/delivery_driver_contract.dart';

class Application extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  String get id => 'test-driver';
  @override
  Map<String, dynamic> data() =>
      {'fullName': 'سائق تجريبي', 'status': 'approved'};
}

void main() {
  test('rejects non-PDF and oversized files before writing', () {
    expect(
        () =>
            validateDeliveryContract(Uint8List.fromList(utf8.encode('image'))),
        throwsStateError);
    final large = Uint8List(maxDeliveryContractBytes + 1);
    large.setRange(0, 5, ascii.encode('%PDF-'));
    expect(() => validateDeliveryContract(large), throwsStateError);
    final boundary = Uint8List(maxDeliveryContractBytes);
    boundary.setRange(0, 5, ascii.encode('%PDF-'));
    expect(() => validateDeliveryContract(boundary), returnsNormally);
  });
  testWidgets('contract controls are available even for an approved driver',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: DeliveryDriverContract(application: Application()))));
    expect(find.text('طباعة العقد'), findsOneWidget);
    expect(find.text('تنزيل عقد PDF'), findsOneWidget);
    expect(find.text('رفع العقد الموقّع'), findsOneWidget);
    expect(find.text('تنزيل العقد الموقّع'), findsNothing);
  });
}
