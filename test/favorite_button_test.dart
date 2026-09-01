import 'package:barakah90/services/firebase_state.dart';
import 'package:barakah90/widgets/favorite_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('favorite button requests login without initialized Firebase',
      (tester) async {
    FirebaseState.isReady = false;

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FavoriteButton(
            itemId: 'restaurant-1',
            item: {'title': 'مطعم بركة'},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(find.text('سجّل الدخول أولاً لاستخدام المفضلة.'), findsOneWidget);
  });
}
