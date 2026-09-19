import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/taxi_order_service.dart';

class AdminTaxiOrdersScreen extends StatelessWidget {
  const AdminTaxiOrdersScreen({super.key});

  String _statusLabel(String status) => switch (status) {
        'pending' => 'بانتظار إرسال سيارة',
        'dispatched' => 'تم إرسال السيارة',
        'awaiting_customer_confirmation' => 'بانتظار تأكيد العميل',
        'completed' => 'رحلة مكتملة',
        'cancelled' => 'ملغي',
        _ => status,
      };

  String _formatAuditDate(dynamic value) {
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate().toLocal();
    } else if (value is DateTime) {
      date = value.toLocal();
    }

    if (date == null) return '';

    String two(int value) => value.toString().padLeft(2, '0');
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final period = date.hour >= 12 ? 'م' : 'ص';

    return '${two(date.day)}/${two(date.month)}/${date.year}'
        ' — $hour12:${two(date.minute)} $period';
  }

  Future<void> _dispatch(
    BuildContext context,
    String orderId,
    String businessId,
  ) async {
    try {
      if (businessId.trim().isEmpty) {
        throw StateError('طلب التكسي لا يحتوي رقم المكتب الداخلي.');
      }

      final driversSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'driver')
          .where('taxiDriverEnabled', isEqualTo: true)
          .where('taxiBusinessId', isEqualTo: businessId)
          .get();

      if (!context.mounted) return;

      final drivers = driversSnapshot.docs;

      if (drivers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لا يوجد سائق تكسي معتمد مرتبط بالمكتب المسؤول عن هذا الطلب.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final vehicleController = TextEditingController();
      final etaController = TextEditingController(text: '5');
      String? selectedDriverUid;

      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('تعيين سائق للطلب'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedDriverUid,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'السائق المعتمد',
                          prefixIcon: Icon(Icons.person_pin_circle_outlined),
                        ),
                        items: drivers.map((doc) {
                          final data = doc.data();

                          final name = (data['displayName'] ??
                                  data['name'] ??
                                  data['fullName'] ??
                                  'سائق بركة')
                              .toString()
                              .trim();

                          final phone =
                              (data['phone'] ?? data['phoneNumber'] ?? '')
                                  .toString()
                                  .trim();

                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(
                              phone.isEmpty ? name : '$name — $phone',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedDriverUid = value;

                            if (value != null) {
                              for (final doc in drivers) {
                                if (doc.id == value) {
                                  final data = doc.data();

                                  final vehicle = (data['vehicleInfo'] ??
                                          data['vehicle'] ??
                                          data['carInfo'] ??
                                          '')
                                      .toString()
                                      .trim();

                                  if (vehicle.isNotEmpty) {
                                    vehicleController.text = vehicle;
                                  }
                                  break;
                                }
                              }
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: vehicleController,
                        decoration: const InputDecoration(
                          labelText: 'بيانات السيارة',
                          hintText: 'مثال: سكودا أبيض - رقم 1234',
                          prefixIcon: Icon(Icons.local_taxi_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: etaController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'وقت الوصول المتوقع بالدقائق',
                          prefixIcon: Icon(Icons.timer_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.local_taxi_rounded),
                  label: const Text('تعيين وإرسال'),
                  onPressed: () {
                    final driverUid = selectedDriverUid?.trim() ?? '';
                    final vehicle = vehicleController.text.trim();
                    final eta = int.tryParse(etaController.text.trim());

                    if (driverUid.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('اختر السائق أولًا.'),
                        ),
                      );
                      return;
                    }

                    if (vehicle.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('أدخل بيانات السيارة.'),
                        ),
                      );
                      return;
                    }

                    if (eta == null || eta < 1 || eta > 240) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'أدخل وقت وصول صحيحًا من 1 إلى 240 دقيقة.',
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(dialogContext, {
                      'driverUid': driverUid,
                      'vehicle': vehicle,
                      'eta': eta,
                    });
                  },
                ),
              ],
            );
          },
        ),
      );

      vehicleController.dispose();
      etaController.dispose();

      if (result == null || !context.mounted) return;

      await TaxiOrderService.instance.dispatchTaxi(
        orderId: orderId,
        driverUid: result['driverUid'].toString(),
        vehicleInfo: result['vehicle'].toString(),
        etaMinutes: result['eta'] as int,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تعيين السائق وإرسال السيارة للعميل ✅'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر تعيين السائق: '
            '${e.toString().replaceFirst('Bad state: ', '')}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _complete(
    BuildContext context,
    String orderId,
  ) async {
    final fareController = TextEditingController();

    final fare = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إنهاء رحلة التكسي'),
        content: TextField(
          controller: fareController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'أجرة الرحلة الفعلية',
            suffixText: '₪',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('تراجع'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(fareController.text.trim());

              if (value == null || value <= 0) return;
              Navigator.pop(dialogContext, value);
            },
            child: const Text('تسجيل انتهاء الرحلة'),
          ),
        ],
      ),
    );

    fareController.dispose();

    if (fare == null || !context.mounted) return;

    try {
      await TaxiOrderService.instance.completeTrip(
        orderId: orderId,
        fareAmount: fare,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم تسجيل انتهاء المشوار وبانتظار تأكيد العميل ✅',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إنهاء الرحلة: $e')),
      );
    }
  }

  Future<void> _cancel(
    BuildContext context,
    String orderId,
  ) async {
    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء طلب التكسي'),
        content: TextField(
          controller: controller,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'سبب الإلغاء',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('تراجع'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (reason == null || !context.mounted) return;

    try {
      await TaxiOrderService.instance.cancelTrip(
        orderId: orderId,
        reason: reason,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إلغاء الطلب: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات تكسي بركة'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance.collection('taxi_orders').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'تعذر تحميل طلبات التكسي:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final aTime = a.data()['createdAt'];
              final bTime = b.data()['createdAt'];

              final aDate =
                  aTime is Timestamp ? aTime.toDate() : DateTime(1970);
              final bDate =
                  bTime is Timestamp ? bTime.toDate() : DateTime(1970);

              return bDate.compareTo(aDate);
            });

          if (orders.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد طلبات تكسي حتى الآن.',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final doc = orders[index];
              final data = doc.data();

              final status = data['status']?.toString() ?? 'pending';
              final customer = data['customerName']?.toString().trim() ?? '';
              final phone = data['customerPhone']?.toString().trim() ?? '';
              final email = data['customerEmail']?.toString().trim() ?? '';
              final pickup = data['pickupAddress']?.toString().trim() ?? '';
              final destination = data['destination']?.toString().trim() ?? '';
              final notes = data['notes']?.toString().trim() ?? '';
              final vehicle =
                  data['dispatchedVehicle']?.toString().trim() ?? '';

              final fare = data['fareAmount'];
              final rate = data['commissionRate'];
              final commission = data['commissionAmount'];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_taxi_rounded),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              data['orderNumber']?.toString() ?? 'طلب تكسي',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Chip(
                            label: Text(_statusLabel(status)),
                          ),
                        ],
                      ),
                      const Divider(),
                      Text(
                        customer.isEmpty
                            ? 'العميل: عميل بركة'
                            : 'العميل: $customer',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (phone.isNotEmpty) Text('الهاتف: $phone'),
                      if (email.isNotEmpty) Text('الإيميل: $email'),
                      const SizedBox(height: 8),
                      Text(
                        'موقع الركوب: ${pickup.isEmpty ? "غير محدد" : pickup}',
                      ),
                      Text(
                        'الوجهة: ${destination.isEmpty ? "غير محددة" : destination}',
                      ),
                      if (notes.isNotEmpty) Text('ملاحظات: $notes'),
                      const Divider(),
                      const Text(
                        'سجل الطلب',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      if (_formatAuditDate(data['createdAt']).isNotEmpty)
                        Text(
                          'إنشاء الطلب: ${_formatAuditDate(data['createdAt'])}',
                        ),
                      if (_formatAuditDate(data['dispatchedAt']).isNotEmpty)
                        Text(
                          'إرسال السيارة: ${_formatAuditDate(data['dispatchedAt'])}',
                        ),
                      if (_formatAuditDate(data['tripEndedAt']).isNotEmpty)
                        Text(
                          'انتهاء المشوار: ${_formatAuditDate(data['tripEndedAt'])}',
                        ),
                      if (_formatAuditDate(data['confirmedByCustomerAt'])
                          .isNotEmpty)
                        Text(
                          'تأكيد العميل: ${_formatAuditDate(data['confirmedByCustomerAt'])}',
                        ),
                      if (_formatAuditDate(data['completedAt']).isNotEmpty)
                        Text(
                          'اكتمال الرحلة: ${_formatAuditDate(data['completedAt'])}',
                        ),
                      if (_formatAuditDate(data['cancelledAt']).isNotEmpty)
                        Text(
                          'إلغاء الطلب: ${_formatAuditDate(data['cancelledAt'])}',
                        ),
                      if (vehicle.isNotEmpty) ...[
                        const Divider(),
                        Text(
                          'السيارة: $vehicle',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (data['dispatchedEtaMinutes'] != null)
                          Text(
                            'وقت الوصول المتوقع: '
                            '${data['dispatchedEtaMinutes']} دقائق',
                          ),
                      ],
                      if (fare != null) ...[
                        const Divider(),
                        Text(
                          'أجرة الرحلة: $fare ₪',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (rate != null) Text('نسبة عمولة بركة: $rate%'),
                        if (commission != null)
                          Text(
                            'عمولة بركة: $commission ₪',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),
                      if (status == 'pending')
                        FilledButton.icon(
                          onPressed: () => _dispatch(
                            context,
                            doc.id,
                            data['businessId']?.toString() ?? '',
                          ),
                          icon: const Icon(Icons.local_taxi_rounded),
                          label: const Text('إرسال سيارة'),
                        ),
                      if (status == 'dispatched')
                        FilledButton.icon(
                          onPressed: () => _complete(context, doc.id),
                          icon: const Icon(
                            Icons.check_circle_outline,
                          ),
                          label: const Text(
                            'إنهاء المشوار وإدخال الأجرة',
                          ),
                        ),
                      if (status == 'pending' || status == 'dispatched') ...[
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          onPressed: () => _cancel(context, doc.id),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'إلغاء الطلب',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
