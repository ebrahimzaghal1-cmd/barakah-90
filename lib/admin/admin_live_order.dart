import 'package:cloud_firestore/cloud_firestore.dart';

/// Read-only projection of existing orders; delivery does not prove payment.
class AdminLiveOrder {
  AdminLiveOrder(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
  static double amount(dynamic value) {
    final number =
        value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return number.isFinite && number > 0 ? number : 0;
  }

  String get number => '${data['orderNumber'] ?? id}';
  String get customer =>
      '${data['customerName'] ?? data['customerEmail'] ?? 'عميل بركة'}';
  String get status => '${data['status'] ?? 'new'}';
  bool get cancelled => const ['cancelled', 'rejected'].contains(status);
  bool get complete => status == 'delivered';
  bool get active => !cancelled && !complete;
  DateTime? get createdAt => data['createdAt'] is Timestamp
      ? (data['createdAt'] as Timestamp).toDate().toLocal()
      : null;
  double get total => amount(data['payableTotal'] ?? data['total']);
  double get commission => amount(data['commissionAmount']);
  double? get paid {
    if (data['paidAmount'] != null)
      return amount(data['paidAmount']).clamp(0, total).toDouble();
    if (data['paymentStatus'] == 'paid') return total;
    if (data['paymentStatus'] == 'unpaid') return 0;
    return null;
  }

  String get paymentLabel => paid == null
      ? 'التحصيل غير مسجّل'
      : paid == 0
          ? 'غير مدفوع'
          : paid! < total
              ? 'دفع جزئي'
              : 'تم الدفع';
  String get statusLabel =>
      const {
        'new': 'طلب جديد',
        'scheduled': 'مجدول',
        'accepted': 'مقبول',
        'preparing': 'قيد التجهيز',
        'ready': 'جاهز للتسليم',
        'awaiting_driver': 'بانتظار سائق',
        'driver_assigned': 'تم تعيين سائق',
        'picked_up': 'مع السائق',
        'delivered': 'تم التسليم',
        'cancelled': 'ملغي',
        'rejected': 'مرفوض',
      }[status] ??
      status;
  List<Map<String, dynamic>> get items => (data['items'] as List? ?? [])
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
  bool matches(String query) =>
      '$number $customer ${data['customerPhone'] ?? ''} ${items.map((i) => i['title']).join(' ')}'
          .toLowerCase()
          .contains(query.trim().toLowerCase());
}
