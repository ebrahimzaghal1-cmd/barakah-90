import 'package:flutter/material.dart';

import '../services/cart_service.dart';
import '../theme/app_theme.dart';
import '../widgets/barakah_media_image.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({
    super.key,
    required this.productId,
    required this.product,
  });

  final String productId;
  final Map<String, dynamic> product;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final _noteController = TextEditingController();
  late final List<_MealOption> _options;
  final Set<String> _selectedAddons = {};
  late final List<_MealOption> _addons;
  int _selectedOption = 0;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _options = _readOptions(widget.product);
    _addons = _readOptions({'mealOptions': widget.product['addons']})
        .where((o) => o.id != 'default')
        .toList();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  List<_MealOption> _readOptions(Map<String, dynamic> data) {
    final basePrice = (data['price'] as num?) ?? 0;
    final raw = data['mealOptions'] ?? data['variants'] ?? data['options'];
    if (raw is List) {
      final parsed = <_MealOption>[];
      for (var index = 0; index < raw.length; index++) {
        final value = raw[index];
        if (value is! Map) continue;
        final option = Map<String, dynamic>.from(value);
        final name =
            (option['name'] ?? option['title'])?.toString().trim() ?? '';
        final price = option['price'];
        if (name.isEmpty || price is! num || price < 0) continue;
        parsed.add(_MealOption(
          id: option['id']?.toString().trim().isNotEmpty == true
              ? option['id'].toString().trim()
              : 'option_$index',
          name: name,
          price: price,
        ));
      }
      if (parsed.isNotEmpty) return parsed;
    }
    return [_MealOption(id: 'default', name: 'عادي', price: basePrice)];
  }

  num get _addonTotal => _addons
      .where((a) => _selectedAddons.contains(a.id))
      .fold<num>(0, (sum, a) => sum + a.price);

  String _money(num value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);

  void _addToCart() {
    final selected = _options[_selectedOption];
    try {
      CartService.instance.addProduct(
        widget.productId,
        widget.product,
        quantity: _quantity,
        unitPrice: selected.price + _addonTotal,
        addonIds: _selectedAddons.toList()..sort(),
        optionId: selected.id,
        optionName: [
          selected.name,
          ..._addons
              .where((a) => _selectedAddons.contains(a.id))
              .map((a) => a.name)
        ].join(' + '),
        note: _noteController.text.trim(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تمت إضافة ${widget.product['title'] ?? 'الوجبة'} إلى السلة',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } on StateError catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message.toString()),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final isMarketProduct =
        (product['kind']?.toString().trim().toLowerCase() == 'product') ||
            (product['type']?.toString().trim().toLowerCase() == 'market');
    final title = product['title']?.toString().trim() ??
        (isMarketProduct ? 'منتج' : 'وجبة');
    final description = product['description']?.toString().trim() ?? '';
    final specs = product['specifications'];
    final specificationText = specs is Map
        ? specs.entries.map((e) => '${e.key}: ${e.value}').join('\n')
        : specs is List
            ? specs.join('\n')
            : specs?.toString() ?? '';
    final image = product['image']?.toString().trim() ?? '';
    final businessTitle = product['businessTitle']?.toString().trim() ?? '';
    final stock = (product['stock'] as num?)?.toInt();
    final soldOut = product['soldOut'] == true || (stock != null && stock <= 0);
    final selected = _options[_selectedOption];
    final total = (selected.price + _addonTotal) * _quantity;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F8F6),
        appBar: AppBar(
          title: Text(businessTitle.isEmpty ? 'تفاصيل الوجبة' : businessTitle),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: BarakahMediaImage(
                        path: image,
                        fit: BoxFit.cover,
                        fallback: const ColoredBox(
                          color: Color(0xFFFFF3C4),
                          child: Center(
                            child: Icon(
                              Icons.fastfood_rounded,
                              size: 72,
                              color: AppTheme.deepYellow,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              description,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 16,
                                height: 1.65,
                              ),
                            ),
                          ],
                          if (specificationText.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Text('مواصفات المنتج',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            Text(specificationText,
                                style: const TextStyle(height: 1.6)),
                          ],
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'النوع',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFE7A0),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: const Text(
                                  'مطلوب',
                                  style: TextStyle(
                                    color: AppTheme.deepYellow,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...List.generate(_options.length, (index) {
                            final option = _options[index];
                            return RadioListTile<int>(
                              value: index,
                              groupValue: _selectedOption,
                              activeColor: AppTheme.deepYellow,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                option.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              secondary: Text(
                                '${_money(option.price)} ₪',
                                style: const TextStyle(
                                  color: AppTheme.deepYellow,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              onChanged: soldOut
                                  ? null
                                  : (value) => setState(
                                        () => _selectedOption = value ?? 0,
                                      ),
                            );
                          }),
                          const Divider(height: 32),
                          Text(
                            isMarketProduct
                                ? 'هل لديك ملاحظة على المنتج؟'
                                : 'هل لديك ملاحظة خاصة؟',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_addons.isNotEmpty) ...[
                            const Text('إضافات اختيارية',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            for (final addon in _addons)
                              CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(addon.name),
                                  subtitle: Text('+ ${_money(addon.price)} ₪'),
                                  value: _selectedAddons.contains(addon.id),
                                  onChanged: (value) => setState(() {
                                        if (value == true) {
                                          _selectedAddons.add(addon.id);
                                        } else {
                                          _selectedAddons.remove(addon.id);
                                        }
                                      })),
                          ],
                          TextField(
                            controller: _noteController,
                            enabled: !soldOut,
                            maxLength: 300,
                            minLines: 2,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: isMarketProduct
                                  ? 'اللون، المقاس، أو تفاصيل التغليف (اختياري)'
                                  : 'أخبرنا بملاحظاتك هنا (اختياري)',
                              counterText: '',
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton.filledTonal(
                                onPressed: soldOut || _quantity <= 1
                                    ? null
                                    : () => setState(() => _quantity--),
                                icon: const Icon(Icons.remove_rounded),
                              ),
                              SizedBox(
                                width: 68,
                                child: Text(
                                  '$_quantity',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              IconButton.filledTonal(
                                onPressed: soldOut ||
                                        _quantity >= 99 ||
                                        (stock != null && _quantity >= stock)
                                    ? null
                                    : () => setState(() => _quantity++),
                                icon: const Icon(Icons.add_rounded),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 16,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: SizedBox(
                  height: 58,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: soldOut ? null : _addToCart,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          soldOut ? 'نفدت الكمية' : 'إضافة إلى السلة',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (!soldOut)
                          Text(
                            '${_money(total)} ₪',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MealOption {
  const _MealOption({
    required this.id,
    required this.name,
    required this.price,
  });

  final String id;
  final String name;
  final num price;
}
