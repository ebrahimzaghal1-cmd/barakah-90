import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/agent_order_service.dart';
import '../theme/app_theme.dart';

class CustomerAgentOrdersPanel extends StatelessWidget {
  const CustomerAgentOrdersPanel({super.key});

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'تم قبول الطلب';
      case 'completed':
        return 'تم التسليم';
      case 'disputed':
        return 'الاعتراض قيد المراجعة';
      case 'rejected':
        return 'تم رفض الطلب';
      default:
        return 'بانتظار قبول الوسيطة';
    }
  }

  Future<void> _showDeliveryCode(
    BuildContext context,
    String orderId,
  ) async {
    try {
      final code = await AgentOrderService().getDeliveryCode(
        orderId: orderId,
      );

      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.password_rounded,
            color: AppTheme.deepYellow,
            size: 46,
          ),
          title: const Text(
            'رمز تسليم الطلب',
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'أعطِ هذا الرمز للوسيطة فقط بعد وصول الطلب إليك.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.navy,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppTheme.coolYellow,
                    width: 1.4,
                  ),
                ),
                child: SelectableText(
                  code,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.coolYellow,
                    fontSize: 34,
                    letterSpacing: 7,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'لا ترسل الرمز قبل استلام الطلب.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('تم'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message.toString()
                : 'تعذر جلب رمز التسليم.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _createDispute(
    BuildContext context,
    String orderId,
  ) async {
    final controller = TextEditingController();

    try {
      final reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text(
            'تقديم اعتراض',
            textAlign: TextAlign.center,
          ),
          content: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'اكتب سبب الاعتراض بوضوح...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();

                if (value.length < 5) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('اكتب سبب الاعتراض بوضوح.'),
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext, value);
              },
              child: const Text('إرسال الاعتراض'),
            ),
          ],
        ),
      );

      if (reason == null || reason.trim().isEmpty) return;

      await AgentOrderService().createDispute(
        orderId: orderId,
        reason: reason,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم تسجيل الاعتراض وتجميد مستحق هذا الطلب للمراجعة.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message.toString()
                : 'تعذر تسجيل الاعتراض.',
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
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('agent_orders')
          .where('customerId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData) {
          return const SizedBox(
            height: 64,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final orders = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aTime = a.data()['createdAt'];
            final bTime = b.data()['createdAt'];

            final aMillis =
                aTime is Timestamp ? aTime.millisecondsSinceEpoch : 0;

            final bMillis =
                bTime is Timestamp ? bTime.millisecondsSinceEpoch : 0;

            return bMillis.compareTo(aMillis);
          });

        if (orders.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.92),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: AppTheme.coolYellow.withOpacity(.45),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.coolYellow,
                    child: Icon(
                      Icons.support_agent_rounded,
                      color: AppTheme.navy,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'طلبات الوسيطات',
                      style: TextStyle(
                        color: AppTheme.navy,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...orders.map((doc) {
                final data = doc.data();
                final status = data['status']?.toString() ?? 'pending';

                final accepted = status == 'accepted';
                final earningStatus =
                    data['earningStatus']?.toString() ?? 'none';
                final disputed =
                    status == 'disputed' || earningStatus == 'frozen';
                final canDispute =
                    status == 'completed' && earningStatus == 'due';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.navy.withOpacity(.055),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.navy.withOpacity(.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              data['agentName']?.toString() ?? 'الوسيطة',
                              style: const TextStyle(
                                color: AppTheme.navy,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: accepted
                                  ? Colors.green.withOpacity(.12)
                                  : AppTheme.coolYellow.withOpacity(.20),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _statusLabel(status),
                              style: TextStyle(
                                color: accepted
                                    ? Colors.green.shade800
                                    : AppTheme.navy,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data['details']?.toString() ?? '',
                        style: const TextStyle(
                          color: Colors.black87,
                          height: 1.45,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'العنوان: ${data['deliveryAddress'] ?? ''}',
                        style: const TextStyle(
                          color: Colors.black54,
                        ),
                      ),
                      if (accepted) ...[
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _showDeliveryCode(
                            context,
                            doc.id,
                          ),
                          icon: const Icon(
                            Icons.password_rounded,
                          ),
                          label: const Text(
                            'إظهار رمز التسليم',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                      if (status == 'completed' || disputed) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              disputed
                                  ? Icons.lock_clock_rounded
                                  : Icons.verified_rounded,
                              color: disputed ? Colors.orange : Colors.green,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                disputed
                                    ? 'الاعتراض قيد المراجعة — تم تجميد مستحق هذا الطلب فقط'
                                    : 'تم تسليم الطلب بنجاح',
                                style: TextStyle(
                                  color: disputed
                                      ? Colors.orange.shade800
                                      : Colors.green,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (canDispute) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => _createDispute(
                            context,
                            doc.id,
                          ),
                          icon: const Icon(
                            Icons.report_problem_rounded,
                          ),
                          label: const Text(
                            'تقديم اعتراض',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
