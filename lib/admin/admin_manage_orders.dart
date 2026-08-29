import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/order_service.dart';
import '../theme/app_theme.dart';

class AdminManageOrders extends StatelessWidget {
  const AdminManageOrders({super.key, this.embedded = false});

  final bool embedded;

  static const _statuses = {
    'new': 'جديد',
    'scheduled': 'مجدول',
    'accepted': 'مقبول',
    'preparing': 'قيد التحضير',
    'ready': 'جاهز',
    'awaiting_driver': 'بانتظار قبول سائق',
    'driver_assigned': 'تم تعيين سائق',
    'picked_up': 'مع السائق',
    'rejected': 'مرفوض',
    'delivered': 'تم التسليم'
  };

  static List<String> _nextStatuses(
    String status,
    String deliveryMethod,
  ) =>
      switch (status) {
        'new' || 'scheduled' => const ['accepted', 'rejected'],
        'accepted' => const ['preparing', 'rejected'],
        'preparing' => const ['ready', 'rejected'],
        'ready' when deliveryMethod == 'pickup' => const ['delivered'],
        'ready' => const [],
        'driver_assigned' => const ['picked_up'],
        'picked_up' => const ['delivered'],
        _ => const [],
      };

  String _firstNonEmpty(
    Iterable<dynamic> values, {
    String fallback = 'غير مضاف',
  }) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  Future<Map<String, dynamic>> _loadCustomerSummary(
    Map<String, dynamic> orderData,
  ) async {
    final firestore = FirebaseFirestore.instance;

    final customerId = _firstNonEmpty(
      [
        orderData['customerId'],
        orderData['userId'],
      ],
      fallback: '',
    );

    Map<String, dynamic> userData = <String, dynamic>{};

    if (customerId.isNotEmpty) {
      final userSnapshot =
          await firestore.collection('users').doc(customerId).get();

      userData = userSnapshot.data() ?? <String, dynamic>{};
    }

    int totalOrders = 0;
    int completedOrders = 0;

    if (customerId.isNotEmpty) {
      final ordersSnapshot = await firestore
          .collection('orders')
          .where('customerId', isEqualTo: customerId)
          .get();

      totalOrders = ordersSnapshot.docs.length;

      completedOrders = ordersSnapshot.docs
          .where(
            (doc) => doc.data()['status']?.toString() == 'delivered',
          )
          .length;
    }

    return {
      'name': _firstNonEmpty([
        orderData['customerName'],
        userData['fullName'],
        userData['name'],
        userData['displayName'],
        orderData['customerEmail'],
        userData['email'],
      ]),
      'phone': _firstNonEmpty([
        orderData['customerPhone'],
        userData['phone'],
        userData['phoneNumber'],
        userData['mobile'],
      ]),
      'email': _firstNonEmpty([
        orderData['customerEmail'],
        userData['email'],
      ]),
      'totalOrders': totalOrders,
      'completedOrders': completedOrders,
    };
  }

  Widget _customerInfoCard(Map<String, dynamic> data) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadCustomerSummary(data),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 10),
                Text('جاري تحميل بيانات العميل...'),
              ],
            ),
          );
        }

        final customer = snapshot.data ?? <String, dynamic>{};

        final totalOrders = customer['totalOrders'] as int? ?? 0;

        final completedOrders = customer['completedOrders'] as int? ?? 0;

        final isNewCustomer = totalOrders <= 1;

        Widget infoLine(
          IconData icon,
          String label,
          String value,
        ) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: AppTheme.navy,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$label: $value',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(
            top: 6,
            bottom: 14,
          ),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8DC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppTheme.coolYellow.withOpacity(.7),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.person_rounded,
                    color: AppTheme.navy,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'بيانات العميل',
                      style: TextStyle(
                        color: AppTheme.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (isNewCustomer)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.coolYellow,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Text(
                        'عميل جديد',
                        style: TextStyle(
                          color: AppTheme.navy,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              infoLine(
                Icons.badge_outlined,
                'الاسم',
                customer['name']?.toString() ?? 'غير مضاف',
              ),
              infoLine(
                Icons.phone_outlined,
                'الجوال',
                customer['phone']?.toString() ?? 'غير مضاف',
              ),
              infoLine(
                Icons.email_outlined,
                'البريد الإلكتروني',
                customer['email']?.toString() ?? 'غير مضاف',
              ),
              const Divider(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'إجمالي الطلبات: $totalOrders',
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'المكتملة: $completedOrders',
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: OrderService().allOrders(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('تعذر تحميل الطلبات.'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final orders = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final right = b.data()['createdAt'] as Timestamp?;
            final left = a.data()['createdAt'] as Timestamp?;

            return (right?.millisecondsSinceEpoch ?? 0)
                .compareTo(left?.millisecondsSinceEpoch ?? 0);
          });

        if (orders.isEmpty) {
          return const Center(
            child: Text('لا توجد طلبات حالياً'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final order = orders[index];
            final data = order.data();

            final status = (data['status'] ?? 'new').toString();

            print('===== ORDER DELIVERY DEBUG =====');
            print('orderId: ${order.id}');
            print('customerPhone: ${data['customerPhone']}');
            print('deliveryAddress: ${data['deliveryAddress']}');
            print('deliveryLatitude: ${data['deliveryLatitude']}');
            print('deliveryLongitude: ${data['deliveryLongitude']}');

            print('===== DRIVER ASSIGNMENT DEBUG =====');
            print('orderId: ${order.id}');
            print('status: ${data['status']}');
            print('awaitingDriver: ${data['awaitingDriver']}');
            print('driverAssignmentIssue: ${data['driverAssignmentIssue']}');
            print('restaurantLatitude: ${data['restaurantLatitude']}');
            print('restaurantLongitude: ${data['restaurantLongitude']}');
            print('driverId: ${data['driverId']}');
            print('driverName: ${data['driverName']}');

            final lines = (data['items'] as List?) ?? const [];

            return Card(
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.receipt_long_rounded),
                ),
                title: Text(
                  'طلب #${data['orderNumber'] ?? order.id.substring(0, 6).toUpperCase()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${lines.length} أصناف • ${data['total'] ?? 0} ₪',
                    ),
                    const SizedBox(height: 8),
                    _OrderActionPanel(
                      orderId: order.id,
                      status: status,
                      deliveryMethod:
                          data['deliveryMethod']?.toString() ?? 'delivery',
                    ),
                  ],
                ),
                childrenPadding: const EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  16,
                ),
                children: [
                  const Divider(),
                  _customerInfoCard(data),
                  ...lines.map((line) {
                    final item = line is Map
                        ? Map<String, dynamic>.from(line)
                        : <String, dynamic>{};

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.fastfood_rounded,
                      ),
                      title: Text(
                        item['title']?.toString() ?? 'صنف',
                      ),
                      subtitle: Text(
                        'الكمية: ${item['quantity'] ?? 1}',
                      ),
                      trailing: Text(
                        '${item['price'] ?? 0} ₪',
                      ),
                    );
                  }),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      '${data['deliveryMethod'] ?? ''} • ${data['paymentMethod'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الطلبات'),
        centerTitle: true,
      ),
      body: body,
    );
  }
}

class _OrderActionPanel extends StatefulWidget {
  const _OrderActionPanel({
    required this.orderId,
    required this.status,
    required this.deliveryMethod,
  });

  final String orderId;
  final String status;
  final String deliveryMethod;

  @override
  State<_OrderActionPanel> createState() => _OrderActionPanelState();
}

class _OrderActionPanelState extends State<_OrderActionPanel> {
  bool _saving = false;

  static const _labels = {
    'accepted': 'قبول الطلب',
    'rejected': 'رفض الطلب',
    'preparing': 'بدء التحضير',
    'ready': 'تم تجهيز الطلب',
    'driver_assigned': 'تعيين سائق',
    'picked_up': 'استلم السائق',
    'delivered': 'تأكيد التسليم',
  };

  static const _icons = {
    'accepted': Icons.check_circle_outline_rounded,
    'rejected': Icons.cancel_outlined,
    'preparing': Icons.soup_kitchen_outlined,
    'ready': Icons.inventory_2_outlined,
    'driver_assigned': Icons.person_pin_circle_outlined,
    'picked_up': Icons.delivery_dining_rounded,
    'delivered': Icons.verified_rounded,
  };

  String get _instruction => switch (widget.status) {
        'new' || 'scheduled' => 'إجراء مطلوب: قبول الطلب أو رفضه',
        'accepted' => 'الخطوة التالية: بدء التحضير',
        'preparing' => 'بعد التجهيز: اجعلي الطلب جاهزًا',
        'ready' when widget.deliveryMethod == 'pickup' =>
          'الطلب جاهز للاستلام من المحل — يمكنك تأكيد التسليم',
        'ready' => 'الطلب جاهز — الخطوة التالية تعيين سائق توصيل متاح',
        'driver_assigned' => 'تم تعيين سائق؛ أكّدي استلامه',
        'picked_up' => 'الطلب مع السائق؛ أكّدي التسليم عند وصوله',
        'delivered' => 'اكتمل الطلب وتم تثبيت المحاسبة',
        'rejected' => 'تم رفض الطلب',
        _ => 'راجعي حالة الطلب الحالية',
      };

  Future<void> _update(String nextStatus) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await OrderService().updateStatus(widget.orderId, nextStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تحديث الطلب إلى ${AdminManageOrders._statuses[nextStatus]}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is StateError
          ? error.message.toString()
          : 'تعذر تحديث الطلب الآن.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final next = AdminManageOrders._nextStatuses(
      widget.status,
      widget.deliveryMethod,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8D9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF142B55), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF142B55),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  AdminManageOrders._statuses[widget.status] ?? widget.status,
                  style: const TextStyle(
                    color: Color(0xFFFFD84D),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _instruction,
                  style: const TextStyle(
                    color: Color(0xFF142B55),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (next.isNotEmpty) ...[
            const SizedBox(height: 9),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: next.map((status) {
                final reject = status == 'rejected';
                final icon = _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_icons[status], size: 18);
                return reject
                    ? OutlinedButton.icon(
                        onPressed: _saving ? null : () => _update(status),
                        icon: icon,
                        label: Text(_labels[status]!),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: _saving ? null : () => _update(status),
                        icon: icon,
                        label: Text(_labels[status]!),
                      );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
