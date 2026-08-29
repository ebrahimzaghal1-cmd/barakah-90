import 'package:barakah90/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('responsive page keeps its child visible', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ResponsivePage(child: Text('Barakah'))),
    ));
    expect(find.text('Barakah'), findsOneWidget);
  });
}
