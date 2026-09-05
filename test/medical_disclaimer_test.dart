import 'package:barakah90/widgets/medical_disclaimer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('medical disclaimer states the service limitations',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MedicalDisclaimer(),
        ),
      ),
    );

    expect(find.text(MedicalDisclaimer.text), findsOneWidget);
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
  });
}
