import 'package:flutter/material.dart';

import '../services/order_service.dart';
import '../theme/app_theme.dart';

class OrderSupervisorScreen extends StatefulWidget {
  const OrderSupervisorScreen({super.key});

  @override
  State<OrderSupervisorScreen> createState() => _OrderSupervisorScreenState();
}

class _OrderSupervisorScreenState extends State<OrderSupervisorScreen> {
  late Future<List<Map<String, dynamic>>> _orders;
  final Set<String> _updating = {};

  static const _labels = {
    'new': 'جديد',
    'scheduled': 'مجدول',
    'accepted': 'مقبول',
    'preparing': 'قيد التحضير',
    'ready': 'جاهز',
    'driver_assigned': 'تم تعيين سائق',
    'picked_up': 'مع السائق',
    'rejected': 'مرفوض',
    'delivered': 'تم التسليم',
  };

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _orders = OrderService().supervisorOrders();

  List<String> _next(String status, String deliveryMethod) => switch (status) {
        'new' || 'scheduled' => const ['accepted', 'rejected'],
        'accepted' => const ['preparing', 'rejected'],
        'preparing' => const ['ready', 'rejected'],
        'ready' when deliveryMethod == 'pickup' => const ['delivered'],
        'driver_assigned' => const ['picked_up'],
        'picked_up' => const ['delivered'],
        _ => const [],
      };

  Future<void> _update(String id, String status) async {
    setState(() => _updating.add(id));
    try {
      await OrderService().updateStatus(id, status);
      if (!mounted) return;
      setState(_reload);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _updating.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('إشراف الطلبات'),
          centerTitle: true,
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _orders,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: FilledButton.icon(
                  onPressed: () => setState(_reload),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة'),
                ),
              );
            }
            final orders = snapshot.data ?? const [];
            return RefreshIndicator(
              onRefresh: () async {
                setState(_reload);
                await _orders;
              },
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final id = order['id']?.toString() ?? '';
                  final status = order['status']?.toString() ?? 'new';
                  final delivery =
                      order['deliveryMethod']?.toString() ?? 'delivery';
                  final items = order['items'] as List? ?? const [];
                  return Card(
                    child: ExpansionTile(
                      title: Text(
                        'طلب #${order['orderNumber'] ?? id}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                          '${_labels[status] ?? status} • ${order['businessTitle'] ?? ''}'),
                      childrenPadding: const EdgeInsets.all(16),
                      children: [
                        ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(
                              order['customerName']?.toString() ?? 'عميل بركة'),
                          subtitle: Text(
                              '${order['customerPhone'] ?? ''}\n${order['deliveryAddress'] ?? ''}'),
                        ),
                        ...items.whereType<Map>().map(
                              (item) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.inventory_2_outlined),
                                title: Text(item['title']?.toString() ?? 'صنف'),
                                trailing:
                                    Text('الكمية: ${item['quantity'] ?? 1}'),
                              ),
                            ),
                        if (_updating.contains(id))
                          const CircularProgressIndicator()
                        else
                          Wrap(
                            spacing: 8,
                            children: _next(status, delivery)
                                .map(
                                  (next) => FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: next == 'rejected'
                                          ? Colors.red
                                          : AppTheme.navy,
                                    ),
                                    onPressed: () => _update(id, next),
                                    child: Text(_labels[next] ?? next),
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      );
}
