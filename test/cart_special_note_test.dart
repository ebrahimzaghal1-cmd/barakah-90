import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import '../lib/services/cart_service.dart';

void main() {
  CartLine line(String note) => CartLine(
        productId: 'meal',
        title: 'وجبة',
        price: 10,
        image: '',
        businessId: 'restaurant',
        businessTitle: 'مطعم',
        specialNote: note,
      );

  test('meal note survives cart storage and checkout serialization', () {
    final saved = jsonDecode(jsonEncode(line(' بدون بصل ').toStorageMap()));
    final restored = CartLine.fromStorageMap(Map<String, dynamic>.from(saved));
    expect(restored.toOrderMap()['specialNote'], 'بدون بصل');
  });

  test('different notes keep the same meal on separate cart lines', () {
    expect(line('بدون بصل').customizationKey,
        isNot(line('مع شطة').customizationKey));
    expect(line('بدون بصل').customizationKey, isNot(line('').customizationKey));
  });
}
