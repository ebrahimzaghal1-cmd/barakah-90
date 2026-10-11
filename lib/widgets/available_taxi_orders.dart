import 'dart:async';
import 'package:flutter/material.dart';
import '../services/taxi_order_service.dart';
import '../services/foreground_notification_presenter.dart';

class AvailableTaxiOrders extends StatefulWidget {
  const AvailableTaxiOrders({super.key});
  @override
  State<AvailableTaxiOrders> createState() => _AvailableTaxiOrdersState();
}

class _AvailableTaxiOrdersState extends State<AvailableTaxiOrders> {
  Timer? _timer;
  final Set<String> _announced = {};
  List<Map<String, dynamic>> _orders = [];
  String? _error;
  bool _loading = false;
  String? _accepting;
  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    _loading = true;
    try {
      final orders = await TaxiOrderService.instance.availableOrders();
      if (!mounted) return;
      for (final order in orders) {
        if (_announced.add(order['orderId'].toString())) {
          showForegroundNotification(
              title: 'طلب تكسي متاح 🚕',
              body: 'افتح قائمة الطلبات لقبول الرحلة.',
              tag: 'taxi-available-${order['orderId']}',
              urgent: true,
              coinSound: true);
        }
      }
      if (mounted)
        setState(() {
          _orders = orders;
          _error = null;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = 'تعذر تحميل طلبات التكسي. حاول تحديث القائمة.';
          _orders = [];
        });
    } finally {
      _loading = false;
    }
  }

  Future<void> _accept(String id) async {
    setState(() => _accepting = id);
    try {
      await TaxiOrderService.instance.acceptOrder(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم قبول رحلة التكسي وتعيينها لك.')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _accepting = null);
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(
              child: Text('طلبات تكسي متاحة للقبول',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))
        ]),
        const Text(
            'أول سائق يقبل تُعيّن له الرحلة. يظهر موقع الزبون وتفاصيله بعد القبول.'),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        if (_orders.isEmpty && _error == null)
          const Padding(
              padding: EdgeInsets.all(16),
              child: Text('لا توجد طلبات تكسي متاحة حاليًا.')),
        ..._orders.map((order) => Card(
            child: ListTile(
                title: Text('${order['orderNumber']}'),
                trailing: FilledButton(
                    onPressed: _accepting != null
                        ? null
                        : () => _accept(order['orderId'].toString()),
                    child: Text(_accepting == order['orderId']
                        ? 'جارٍ القبول...'
                        : 'قبول الرحلة'))))),
        const SizedBox(height: 18),
      ]);
}
