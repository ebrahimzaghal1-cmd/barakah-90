import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/agent_order_service.dart';
import '../theme/app_theme.dart';

class AdminAgentFinanceScreen extends StatelessWidget {
  const AdminAgentFinanceScreen({super.key});

  double _money(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'due':
        return 'مستحق';
      case 'paid':
      case 'settled':
        return 'مدفوع';
      case 'frozen':
        return 'معلّق';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  Future<void> _settleEarning(
    BuildContext context,
    String orderId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'تأكيد دفع المستحق',
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'هل تم دفع مستحق الوسيطة فعليًا؟ بعد التأكيد سيتم تسجيل العملية كسداد نهائي لهذا الطلب.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.verified_rounded),
            label: const Text('نعم، تم الدفع'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await AgentOrderService().settleEarning(
        orderId: orderId,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسجيل دفع مستحق الوسيطة بنجاح ✅'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message.toString()
                : 'تعذر تسجيل دفع المستحق.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resolveDispute(
    BuildContext context,
    String orderId,
    String decision,
  ) async {
    final controller = TextEditingController();

    final isRelease = decision == 'release';

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            isRelease ? 'رفض اعتراض العميل' : 'قبول اعتراض العميل',
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isRelease
                    ? 'سيتم فك تجميد المستحق وإعادته لحالة مستحق.'
                    : 'سيتم إلغاء مستحق الوسيطة لهذا الطلب فقط.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                minLines: 2,
                maxLines: 5,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة الأدمن (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('رجوع'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                isRelease ? 'إعادة المستحق' : 'إلغاء المستحق',
              ),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      await AgentOrderService().resolveDispute(
        orderId: orderId,
        decision: decision,
        adminNote: controller.text,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRelease
                ? 'تم رفض الاعتراض وإعادة مستحق الوسيطة.'
                : 'تم قبول الاعتراض وإلغاء مستحق هذا الطلب.',
          ),
          backgroundColor: isRelease ? Colors.green : Colors.orange,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message.toString()
                : 'تعذر معالجة الاعتراض.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مالية الوسيطات'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance.collection('agent_earnings').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'تعذر تحميل مستحقات الوسيطات.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final rows = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final aTime = a.data()['createdAt'];
              final bTime = b.data()['createdAt'];

              final aMs = aTime is Timestamp ? aTime.millisecondsSinceEpoch : 0;
              final bMs = bTime is Timestamp ? bTime.millisecondsSinceEpoch : 0;

              return bMs.compareTo(aMs);
            });

          double due = 0;
          double paid = 0;
          double frozen = 0;

          for (final row in rows) {
            final data = row.data();
            final amount = _money(data['amount']);
            final status = data['status']?.toString() ?? 'due';

            switch (status) {
              case 'paid':
              case 'settled':
                paid += amount;
                break;
              case 'frozen':
                frozen += amount;
                break;
              default:
                due += amount;
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryCard(
                title: 'المستحقات الحالية',
                value: due,
                icon: Icons.payments_rounded,
              ),
              const SizedBox(height: 10),
              _SummaryCard(
                title: 'تم دفعه',
                value: paid,
                icon: Icons.verified_rounded,
              ),
              const SizedBox(height: 10),
              _SummaryCard(
                title: 'معلّق بسبب اعتراض',
                value: frozen,
                icon: Icons.lock_clock_rounded,
              ),
              const SizedBox(height: 22),
              const Text(
                'سجل مستحقات الوسيطات',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(
                    child: Text(
                      'لا توجد مستحقات وسيطات حتى الآن.',
                    ),
                  ),
                )
              else
                ...rows.map((doc) {
                  final data = doc.data();
                  final amount = _money(data['amount']);
                  final status = data['status']?.toString() ?? 'due';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: AppTheme.coolYellow,
                                child: Icon(
                                  Icons.support_agent_rounded,
                                  color: AppTheme.navy,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['agentName']?.toString() ??
                                          'الوسيطة',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'طلب: ${data['orderId'] ?? doc.id}',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${amount.toStringAsFixed(2)} ₪',
                                style: const TextStyle(
                                  color: AppTheme.navy,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Chip(
                                label: Text(
                                  _statusLabel(status),
                                ),
                              ),
                              if (data['frozen'] == true) ...[
                                const SizedBox(width: 7),
                                const Chip(
                                  avatar: Icon(
                                    Icons.warning_amber_rounded,
                                    size: 17,
                                  ),
                                  label: Text('عليه اعتراض'),
                                ),
                              ],
                            ],
                          ),
                          if (data['disputeId'] != null) ...[
                            const SizedBox(height: 5),
                            Text(
                              'رقم الاعتراض: ${data['disputeId']}',
                              style: const TextStyle(
                                color: Colors.deepOrange,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          if (status == 'due' && data['frozen'] != true)
                            FilledButton.icon(
                              onPressed: () => _settleEarning(
                                context,
                                (data['orderId'] ?? doc.id).toString(),
                              ),
                              icon: const Icon(
                                Icons.payments_rounded,
                              ),
                              label: const Text(
                                'تم الدفع',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          if (status == 'frozen' || data['frozen'] == true) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _resolveDispute(
                                      context,
                                      (data['orderId'] ?? doc.id).toString(),
                                      'release',
                                    ),
                                    icon: const Icon(
                                      Icons.lock_open_rounded,
                                    ),
                                    label: const Text(
                                      'رفض الاعتراض',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => _resolveDispute(
                                      context,
                                      (data['orderId'] ?? doc.id).toString(),
                                      'cancel',
                                    ),
                                    icon: const Icon(
                                      Icons.cancel_rounded,
                                    ),
                                    label: const Text(
                                      'قبول الاعتراض',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final double value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.navy,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.coolYellow.withOpacity(.45),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.coolYellow.withOpacity(.18),
            child: Icon(
              icon,
              color: AppTheme.coolYellow,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '${value.toStringAsFixed(2)} ₪',
            style: const TextStyle(
              color: AppTheme.coolYellow,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
