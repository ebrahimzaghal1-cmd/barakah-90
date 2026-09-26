import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barakah90/services/cart_service.dart';
import 'package:barakah90/services/order_fields.dart';
import 'package:barakah90/widgets/order_details.dart';

void main() {
  test('customization survives storage and the outgoing request', () {
    final line = CartLine(
      productId: 'meal',
      title: 'وجبة',
      price: 25,
      image: '',
      businessId: 'shop',
      businessTitle: 'مطعم',
      quantity: 2,
      optionId: 'large',
      optionName: 'كبير + جبنة',
      addonIds: ['cheese'],
      note: 'بدون بصل',
    );
    final restored = CartLine.fromStorageMap(line.toStorageMap());
    final request = orderRequestItem(restored.toOrderMap());
    expect(request, {
      'productId': 'meal',
      'quantity': 2,
      'optionId': 'large',
      'addonIds': ['cheese'],
      'note': 'بدون بصل',
    });
    expect(request.containsKey('price'), isFalse);
  });

  test('old carts and orders remain readable without new fields', () {
    final line = CartLine.fromStorageMap({'productId': 'old', 'price': 10});
    expect(orderRequestItem(line.toOrderMap())['addonIds'], isEmpty);
    expect(orderItemDetails({'title': 'قديم'}), ['الكمية: 1']);
    expect(orderCustomerFields({})['name'], 'غير مضاف');
  });

  test('order snapshot wins, legacy profile fills missing fields', () {
    expect(
        orderCustomerFields({
          'customerName': 'اسم الطلب',
          'customerPhone': ' ',
        }, {
          'displayName': 'اسم جديد',
          'phoneNumber': '0590000000',
          'email': 'test@example.com',
        }),
        {
          'name': 'اسم الطلب',
          'phone': '0590000000',
          'email': 'test@example.com',
        });
    expect(
        orderCustomerFields({}, {'fullName': 'اسم قديم'})['name'], 'اسم قديم');
  });

  test('structured addons and legacy combined options display once', () {
    final addons = [
      {'id': 'cheese', 'name': 'جبنة', 'price': 5}
    ];
    expect(
        orderItemDetails(
            {'optionName': 'كبير', 'addons': addons, 'notes': 'بدون ملح'}),
        [
          'الكمية: 1',
          'الخيار: كبير',
          'الإضافات: جبنة',
          'ملاحظة: بدون ملح',
        ]);
    expect(orderItemDetails({'optionName': 'كبير + جبنة', 'addons': addons}),
        ['الكمية: 1', 'الخيار: كبير + جبنة']);
  });

  testWidgets('merchant sees customer, selection, quantity and note',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: OrderDetails(data: {
      'customerName': 'عميلة تجريبية',
      'customerPhone': '0590000000',
      'deliveryAddress': 'عنوان تجريبي',
      'items': [
        {
          'title': 'وجبة',
          'quantity': 2,
          'optionName': 'كبير + جبنة',
          'note': 'بدون بصل'
        }
      ],
    }))));
    expect(find.text('العميل: عميلة تجريبية'), findsOneWidget);
    expect(find.text('الجوال: 0590000000'), findsOneWidget);
    expect(find.textContaining('ملاحظة: بدون بصل'), findsOneWidget);
    expect(find.textContaining('الخيار: كبير + جبنة'), findsOneWidget);
    expect(find.textContaining('الكمية: 2'), findsOneWidget);
  });
}
