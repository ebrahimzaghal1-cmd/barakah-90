import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barakah90/widgets/order_navigation.dart';

void main() {
  testWidgets('exact navigation requires a valid coordinate pair', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: OrderNavigation(label: 'الزبون', address: 'شارع الاختبار', latitude: 91, longitude: 35))));
    expect(find.text('البحث عن عنوان الزبون'), findsOneWidget);
    expect(find.text('الملاحة إلى الزبون'), findsNothing);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: OrderNavigation(label: 'الزبون', address: 'شارع الاختبار', latitude: 32.3, longitude: 35))));
    expect(find.text('الملاحة إلى الزبون'), findsOneWidget);
    expect(find.text('الموقع: 32.300000, 35.000000'), findsOneWidget);
  });
  testWidgets('missing location is explicit and has no navigation action', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: OrderNavigation(label: 'المحل', address: ''))));
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.textContaining('الموقع الدقيق غير محفوظ'), findsOneWidget);
  });
}
