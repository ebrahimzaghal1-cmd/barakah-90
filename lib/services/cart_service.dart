import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartLine {
  CartLine({
    required this.productId,
    required this.title,
    required this.price,
    required this.image,
    required this.businessId,
    required this.businessTitle,
    this.quantity = 1,
  });

  final String productId;
  final String title;
  final num price;
  final String image;
  final String businessId;
  final String businessTitle;
  int quantity;

  num get lineTotal => price * quantity;

  Map<String, dynamic> toOrderMap() => {
        'productId': productId,
        'title': title,
        'price': price,
        'quantity': quantity,
        'image': image,
        'businessId': businessId,
        'businessTitle': businessTitle,
      };

  Map<String, dynamic> toStorageMap() => {
        'productId': productId,
        'title': title,
        'price': price,
        'image': image,
        'businessId': businessId,
        'businessTitle': businessTitle,
        'quantity': quantity,
      };

  factory CartLine.fromStorageMap(Map<String, dynamic> data) {
    return CartLine(
      productId: data['productId']?.toString() ?? '',
      title: data['title']?.toString() ?? 'منتج',
      price: (data['price'] as num?) ?? 0,
      image: data['image']?.toString() ?? '',
      businessId: data['businessId']?.toString() ?? '',
      businessTitle: data['businessTitle']?.toString() ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
    );
  }
}

/// سلة محفوظة محليًا على الجهاز وتُفرغ بعد تأكيد الطلب.
class CartService extends ChangeNotifier {
  CartService._() {
    _restore();
  }

  static final CartService instance = CartService._();

  static const _storageKey = 'barakah_cart_v1';

  final List<CartLine> _items = [];
  bool _restored = false;

  bool get restored => _restored;

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);

      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);

        if (decoded is List) {
          _items
            ..clear()
            ..addAll(
              decoded
                  .whereType<Map>()
                  .map(
                    (item) => CartLine.fromStorageMap(
                      Map<String, dynamic>.from(item),
                    ),
                  )
                  .where(
                    (item) =>
                        item.productId.isNotEmpty &&
                        item.businessId.isNotEmpty &&
                        item.quantity > 0,
                  ),
            );
        }
      }
    } catch (error) {
      debugPrint('تعذر استرجاع سلة بركة: $error');
    } finally {
      _restored = true;
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_items.isEmpty) {
        await prefs.remove(_storageKey);
        return;
      }

      await prefs.setString(
        _storageKey,
        jsonEncode(
          _items.map((item) => item.toStorageMap()).toList(),
        ),
      );
    } catch (error) {
      debugPrint('تعذر حفظ سلة بركة: $error');
    }
  }

  List<CartLine> get items => List.unmodifiable(_items);
  num get total => _items.fold<num>(0, (sum, item) => sum + item.lineTotal);

  void addProduct(String id, Map<String, dynamic> product) {
    final businessId = product['businessId']?.toString().trim() ?? '';
    if (id.trim().isEmpty || businessId.isEmpty) {
      throw StateError('هذا الصنف غير مرتبط بمحل صالح.');
    }
    if (_items.isNotEmpty && _items.first.businessId != businessId) {
      throw StateError(
        'السلة تحتوي أصنافًا من ${_items.first.businessTitle}. '
        'أتمم الطلب الحالي أو أفرغ السلة قبل الطلب من محل آخر.',
      );
    }
    final current = _items.where((item) => item.productId == id);
    if (current.isNotEmpty) {
      current.first.quantity++;
    } else {
      _items.add(CartLine(
        productId: id,
        title: product['title']?.toString() ?? 'منتج',
        price: (product['price'] as num?) ?? 0,
        image: product['image']?.toString() ?? '',
        businessId: businessId,
        businessTitle: product['businessTitle']?.toString() ?? '',
      ));
    }
    notifyListeners();
    _persist();
  }

  void increment(CartLine item) {
    item.quantity++;
    notifyListeners();
    _persist();
  }

  void decrement(CartLine item) {
    if (item.quantity > 1) {
      item.quantity--;
    } else {
      _items.remove(item);
    }
    notifyListeners();
    _persist();
  }

  void clear() {
    _items.clear();
    notifyListeners();
    _persist();
  }
}
