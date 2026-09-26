import 'package:flutter/material.dart';
import '../services/order_fields.dart';

/// Reads only the authorized order document, never a customer's private profile.
class OrderDetails extends StatelessWidget {
  const OrderDetails({super.key, required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final customer = orderCustomerFields(data);
    final rawItems = data['items'];
    final items = rawItems is List ? rawItems.whereType<Map>() : <Map>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('العميل: ${customer['name']}'),
        Text('الجوال: ${customer['phone']}'),
        if (orderText([data['deliveryAddress']]).isNotEmpty)
          Text('العنوان: ${data['deliveryAddress']}'),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text([
              orderText([item['title']], fallback: 'صنف'),
              ...orderItemDetails(Map<String, dynamic>.from(item)),
            ].join('\n')),
          ),
      ],
    );
  }
}
