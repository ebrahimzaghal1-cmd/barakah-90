import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/screens/cart_screen.dart';
void main() {
  for (final market in [true, false]) {
    testWidgets('purchase notes follow product type: market=$market', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () => showProductPurchaseOptions(context, 'example', {
          'title': 'منتج', 'price': 20, 'type': market ? 'market' : 'restaurant',
        }), child: const Text('open'))))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(market ? 'ملاحظات على المنتج' : 'ملاحظات على الوجبة'), findsOneWidget);
      expect(find.text(market ? 'مثال: اللون المطلوب، المقاس، أو تفاصيل التغليف...' : 'مثال: بدون بصل، الصوص على الجانب...'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
