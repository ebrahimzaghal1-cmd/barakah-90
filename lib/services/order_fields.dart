/// Fields shared by checkout and order readers. Prices stay server-authoritative.
String orderText(Iterable<dynamic> values, {String fallback = ''}) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

Map<String, dynamic> orderRequestItem(Map<String, dynamic> item) => {
      'productId': item['productId']?.toString(),
      'quantity': item['quantity'] ?? 1,
      'addonIds': (item['addonIds'] as List? ?? const [])
          .map((id) => id.toString())
          .toList(),
      for (final key in ['optionId', 'note', 'image'])
        if (orderText([item[key]]).isNotEmpty) key: orderText([item[key]]),
    };

Map<String, dynamic> orderCustomerFields(
  Map<String, dynamic> order, [
  Map<String, dynamic> profile = const {},
]) =>
    {
      'name': orderText([
        order['customerName'],
        profile['fullName'],
        profile['name'],
        profile['displayName'],
        order['customerEmail'],
        profile['email'],
      ], fallback: 'غير مضاف'),
      'phone': orderText([
        order['customerPhone'],
        profile['phone'],
        profile['phoneNumber'],
        profile['mobile'],
      ], fallback: 'غير مضاف'),
      'email': orderText([order['customerEmail'], profile['email']],
          fallback: 'غير مضاف'),
    };

List<String> orderItemDetails(Map<String, dynamic> item) {
  final option = orderText([item['optionName']]);
  final rawAddons = item['addons'];
  final addons = rawAddons is List
      ? rawAddons
          .map((addon) => addon is Map
              ? orderText([addon['name'], addon['title']])
              : orderText([addon]))
          .where((name) => name.isNotEmpty)
          .toList()
      : <String>[];
  // Older orders combine the option and addons in optionName.
  final missingAddons = addons.where(
      (name) => !option.split(' + ').map((part) => part.trim()).contains(name));
  final note = orderText([item['note'], item['notes']]);
  return [
    'الكمية: ${item['quantity'] ?? 1}',
    if (option.isNotEmpty) 'الخيار: $option',
    if (missingAddons.isNotEmpty) 'الإضافات: ${missingAddons.join(' + ')}',
    if (note.isNotEmpty) 'ملاحظة: $note',
  ];
}
