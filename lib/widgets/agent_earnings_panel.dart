import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AgentEarningsPanel extends StatelessWidget {
  const AgentEarningsPanel({
    super.key,
    required this.agentId,
  });

  final String agentId;

  double _money(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _status(String value) {
    switch (value) {
      case 'due':
        return 'مستحق';
      case 'paid':
      case 'settled':
        return 'تم الدفع';
      case 'frozen':
        return 'معلّق بسبب اعتراض';
      case 'cancelled':
        return 'ملغي';
      default:
        return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(
        Icons.account_balance_wallet_rounded,
        color: AppTheme.deepYellow,
      ),
      title: const Text(
        'أرباحي',
        style: TextStyle(
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: const Text(
        'قيد التنفيذ والمستحقات والمدفوعات وسجل العمليات',
      ),
      children: [
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('agent_earnings')
              .where('agentId', isEqualTo: agentId)
              .snapshots(),
          builder: (context, earningsSnapshot) {
            if (earningsSnapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'تعذر تحميل بيانات الأرباح.',
                ),
              );
            }

            if (!earningsSnapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(22),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final earnings = earningsSnapshot.data!.docs.toList()
              ..sort((a, b) {
                final aTime = a.data()['createdAt'];
                final bTime = b.data()['createdAt'];

                final aMs =
                    aTime is Timestamp ? aTime.millisecondsSinceEpoch : 0;
                final bMs =
                    bTime is Timestamp ? bTime.millisecondsSinceEpoch : 0;

                return bMs.compareTo(aMs);
              });

            double due = 0;
            double paid = 0;
            double frozen = 0;

            for (final doc in earnings) {
              final data = doc.data();
              final amount = _money(data['amount']);
              final status = data['status']?.toString() ?? 'due';

              switch (status) {
                case 'due':
                  due += amount;
                  break;
                case 'paid':
                case 'settled':
                  paid += amount;
                  break;
                case 'frozen':
                  frozen += amount;
                  break;
                case 'cancelled':
                  break;
              }
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('agent_orders')
                  .where('agentId', isEqualTo: agentId)
                  .snapshots(),
              builder: (context, ordersSnapshot) {
                double inProgress = 0;

                if (ordersSnapshot.hasData) {
                  for (final doc in ordersSnapshot.data!.docs) {
                    final data = doc.data();

                    if (data['status']?.toString() == 'accepted') {
                      inProgress += _money(data['agentFee']);
                    }
                  }
                }

                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                    12,
                    4,
                    12,
                    18,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _MoneyBox(
                              title: 'قيد التنفيذ',
                              amount: inProgress,
                              icon: Icons.hourglass_top_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MoneyBox(
                              title: 'مستحق',
                              amount: due,
                              icon: Icons.payments_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _MoneyBox(
                              title: 'مدفوع',
                              amount: paid,
                              icon: Icons.verified_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MoneyBox(
                              title: 'معلّق باعتراض',
                              amount: frozen,
                              icon: Icons.lock_clock_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'سجل الأرباح',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (earnings.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              'لا توجد أرباح مسجلة بعد.',
                            ),
                          ),
                        )
                      else
                        ...earnings.map((doc) {
                          final data = doc.data();
                          final amount = _money(data['amount']);

                          return Card(
                            margin: const EdgeInsets.only(
                              bottom: 8,
                            ),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: AppTheme.coolYellow,
                                child: Icon(
                                  Icons.receipt_long_rounded,
                                  color: AppTheme.navy,
                                ),
                              ),
                              title: Text(
                                data['agentName']?.toString() ?? 'الوسيطة',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Text(
                                _status(
                                  data['status']?.toString() ?? 'due',
                                ),
                              ),
                              trailing: Text(
                                '${amount.toStringAsFixed(2)} ₪',
                                style: const TextStyle(
                                  color: AppTheme.navy,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _MoneyBox extends StatelessWidget {
  const _MoneyBox({
    required this.title,
    required this.amount,
    required this.icon,
  });

  final String title;
  final double amount;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.navy.withOpacity(.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.coolYellow.withOpacity(.35),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: AppTheme.deepYellow,
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${amount.toStringAsFixed(2)} ₪',
            style: const TextStyle(
              color: AppTheme.navy,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
