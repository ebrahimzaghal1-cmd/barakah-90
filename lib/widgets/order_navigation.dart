import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderNavigation extends StatelessWidget {
  const OrderNavigation(
      {super.key,
      required this.label,
      required this.address,
      this.latitude,
      this.longitude});
  final String label;
  final String address;
  final Object? latitude;
  final Object? longitude;

  static double? coordinate(Object? value, double limit) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    return number != null && number.isFinite && number.abs() <= limit
        ? number
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final lat = coordinate(latitude, 90);
    final lng = coordinate(longitude, 180);
    final precise = lat != null && lng != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('$label: ${address.trim().isEmpty ? 'العنوان غير محفوظ' : address}'),
      Text(precise
          ? 'الموقع: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}'
          : 'الموقع الدقيق غير محفوظ؛ تحقّق من العنوان قبل الانطلاق.'),
      if (precise || address.trim().isNotEmpty)
        OutlinedButton.icon(
          icon: const Icon(Icons.navigation_outlined),
          label: Text(precise ? 'الملاحة إلى $label' : 'البحث عن عنوان $label'),
          onPressed: () async {
            final uri = Uri.https(
                'www.google.com', precise ? '/maps/dir/' : '/maps/search/', {
              'api': '1',
              if (precise)
                'destination': '$lat,$lng'
              else
                'query': address.trim(),
              if (precise) 'travelmode': 'driving',
            });
            try {
              if (!await launchUrl(uri, mode: LaunchMode.externalApplication))
                throw StateError('maps');
            } catch (_) {
              if (context.mounted)
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('تعذر فتح الخرائط. حاولي مرة أخرى.')));
            }
          },
        ),
    ]);
  }
}
