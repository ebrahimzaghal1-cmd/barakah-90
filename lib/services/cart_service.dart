import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartSelectedOption {
  const CartSelectedOption({
    required this.groupId,
    required this.groupTitle,
    required this.optionId,
    required this.optionTitle,
    required this.priceDelta,
  });

  final String groupId;
  final String groupTitle;
  final String optionId;
  final String optionTitle;
  final num priceDelta;

  Map<String, dynamic> toMap() => {
        'groupId': groupId,
        'groupTitle': groupTitle,
        'optionId': optionId,
        'optionTitle': optionTitle,
        'priceDelta': priceDelta,
      };

  factory CartSelectedOption.fromMap(Map<String, dynamic> data) {
    return CartSelectedOption(
      groupId: data['groupId']?.toString() ?? '',
      groupTitle: data['groupTitle']?.toString() ?? '',
      optionId: data['optionId']?.toString() ?? '',
      optionTitle: data['optionTitle']?.toString() ?? '',
      priceDelta: (data['priceDelta'] as num?) ?? 0,
    );
  }
}

class CartLine {
  CartLine({
    required this.productId,
    required this.title,
    required this.price,
    required this.image,
    required this.businessId,
    required this.businessTitle,
    num? basePrice,
    this.quantity = 1,
    this.selectedOptions = const [],
    this.specialNote = '',
    String? customizationKey,
  })  : basePrice = basePrice ?? price,
        customizationKey = customizationKey ??
            CartService.buildCustomizationKey(
              productId,
              selectedOptions,
              specialNote,
            );

  final String productId;
  final String title;

  /// السعر الأصلي للمنتج قبل أي إضافات.
  final num basePrice;

  /// سعر الوحدة النهائي بعد إضافة الاختيارات.
  final num price;

  final String image;
  final String businessId;
  final String businessTitle;

  int quantity;

  final List<CartSelectedOption> selectedOptions;
  final String specialNote;

  /// يميز نفس المنتج إذا كانت له اختيارات أو ملاحظات مختلفة.
  final String customizationKey;

  num get optionsTotal => selectedOptions.fold<num>(
        0,
        (sum, option) => sum + option.priceDelta,
      );

  num get lineTotal => price * quantity;

  bool get hasCustomization =>
      selectedOptions.isNotEmpty || specialNote.trim().isNotEmpty;

  Map<String, dynamic> toOrderMap() => {
        'productId': productId,
        'title': title,
        'basePrice': basePrice,
        'price': price,
        'quantity': quantity,
        'image': image,
        'businessId': businessId,
        'businessTitle': businessTitle,
        'selectedOptions':
            selectedOptions.map((option) => option.toMap()).toList(),
        if (specialNote.trim().isNotEmpty) 'specialNote': specialNote.trim(),
        'customizationKey': customizationKey,
      };

  Map<String, dynamic> toStorageMap() => {
        'productId': productId,
        'title': title,
        'basePrice': basePrice,
        'price': price,
        'image': image,
        'businessId': businessId,
        'businessTitle': businessTitle,
        'quantity': quantity,
        'selectedOptions':
            selectedOptions.map((option) => option.toMap()).toList(),
        'specialNote': specialNote,
        'customizationKey': customizationKey,
      };

  factory CartLine.fromStorageMap(Map<String, dynamic> data) {
    final rawOptions = data['selectedOptions'];

    final selectedOptions = rawOptions is List
        ? rawOptions
            .whereType<Map>()
            .map(
              (item) => CartSelectedOption.fromMap(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
        : <CartSelectedOption>[];

    final productId = data['productId']?.toString() ?? '';
    final specialNote = data['specialNote']?.toString() ?? '';

    return CartLine(
      productId: productId,
      title: data['title']?.toString() ?? 'منتج',
      basePrice: (data['basePrice'] as num?) ?? (data['price'] as num?) ?? 0,
      price: (data['price'] as num?) ?? 0,
      image: data['image']?.toString() ?? '',
      businessId: data['businessId']?.toString() ?? '',
      businessTitle: data['businessTitle']?.toString() ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      selectedOptions: selectedOptions,
      specialNote: specialNote,
      customizationKey:
          data['customizationKey']?.toString().trim().isNotEmpty == true
              ? data['customizationKey'].toString()
              : CartService.buildCustomizationKey(
                  productId,
                  selectedOptions,
                  specialNote,
                ),
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

  static String buildCustomizationKey(
    String productId,
    List<CartSelectedOption> options,
    String note,
  ) {
    final normalizedOptions = [...options]..sort((a, b) {
        final groupCompare = a.groupId.compareTo(b.groupId);
        if (groupCompare != 0) return groupCompare;
        return a.optionId.compareTo(b.optionId);
      });

    return jsonEncode({
      'productId': productId.trim(),
      'options': normalizedOptions
          .map(
            (option) => {
              'groupId': option.groupId,
              'optionId': option.optionId,
            },
          )
          .toList(),
      'note': note.trim(),
    });
  }

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

  void addProduct(
    String id,
    Map<String, dynamic> product, {
    List<CartSelectedOption> selectedOptions = const [],
    String specialNote = '',
    int quantity = 1,
    num? unitPrice,
  }) {
    final businessId = product['businessId']?.toString().trim() ?? '';

    if (product['soldOut'] == true) {
      throw StateError('هذا الصنف نفد من المخزون.');
    }

    if (id.trim().isEmpty || businessId.isEmpty) {
      throw StateError('هذا الصنف غير مرتبط بمحل صالح.');
    }

    if (quantity < 1 || quantity > 99) {
      throw StateError('الكمية المطلوبة غير صالحة.');
    }

    if (_items.isNotEmpty && _items.first.businessId != businessId) {
      throw StateError(
        'السلة تحتوي أصنافًا من ${_items.first.businessTitle}. '
        'أتمم الطلب الحالي أو أفرغ السلة قبل الطلب من محل آخر.',
      );
    }

    final basePrice = (product['price'] as num?) ?? 0;

    final optionsTotal = selectedOptions.fold<num>(
      0,
      (sum, option) => sum + option.priceDelta,
    );

    final finalUnitPrice = unitPrice ?? (basePrice + optionsTotal);

    if (finalUnitPrice < 0) {
      throw StateError('سعر المنتج غير صالح.');
    }

    final customizationKey = buildCustomizationKey(
      id,
      selectedOptions,
      specialNote,
    );

    final current = _items.where(
      (item) => item.customizationKey == customizationKey,
    );

    if (current.isNotEmpty) {
      current.first.quantity += quantity;
    } else {
      _items.add(
        CartLine(
          productId: id,
          title: product['title']?.toString() ?? 'منتج',
          basePrice: basePrice,
          price: finalUnitPrice,
          image: product['image']?.toString() ?? '',
          businessId: businessId,
          businessTitle: product['businessTitle']?.toString() ?? '',
          quantity: quantity,
          selectedOptions: List.unmodifiable(selectedOptions),
          specialNote: specialNote.trim(),
          customizationKey: customizationKey,
        ),
      );
    }

    notifyListeners();
    _persist();
  }

  void increment(CartLine item) {
    if (item.quantity >= 99) return;

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
