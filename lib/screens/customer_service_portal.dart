import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/customer_service_service.dart';
import '../theme/app_theme.dart';

class CustomerServicePortal extends StatelessWidget {
  const CustomerServicePortal({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('سجّل الدخول أولاً.')));
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final profile = snapshot.data?.data() ?? const <String, dynamic>{};
        final allowed = profile['role'] == 'customer_service' &&
            profile['customerServiceEnabled'] == true;
        if (!allowed) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Text(
                  'هذه البوابة مخصصة لموظفي خدمة العملاء المقبولين فقط، ولا تمنح صلاحيات الأدمن.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        final agentName = profile['displayName']?.toString() ?? 'موظف بركة';
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('employment_contracts')
              .doc(user.uid)
              .snapshots(),
          builder: (context, contractSnapshot) {
            final contract = contractSnapshot.data?.data();
            if (contract?['status'] != 'accepted') {
              return _ContractAcceptance(contract: contract);
            }
            return _AgentInbox(agentName: agentName);
          },
        );
      },
    );
  }
}

class _ContractAcceptance extends StatefulWidget {
  const _ContractAcceptance({required this.contract});
  final Map<String, dynamic>? contract;

  @override
  State<_ContractAcceptance> createState() => _ContractAcceptanceState();
}

class _ContractAcceptanceState extends State<_ContractAcceptance> {
  bool _agreed = false;
  bool _saving = false;

  Future<void> _accept() async {
    if (!_agreed || _saving) return;
    setState(() => _saving = true);
    try {
      await CustomerServiceService().acceptEmploymentContract();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contract = widget.contract;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4EC),
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: const Text('وثيقة التوظيف الرقمية'),
      ),
      body: contract == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'تم قبول الحساب، وننتظر إصدار وثيقة التوظيف من الأدمن.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.description_rounded,
                            color: AppTheme.deepYellow, size: 46),
                        const SizedBox(height: 10),
                        Text(
                          contract['title']?.toString() ?? 'وثيقة التوظيف',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 21, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 16),
                        Text(contract['terms']?.toString() ?? '',
                            style: const TextStyle(height: 1.75)),
                      ],
                    ),
                  ),
                ),
                CheckboxListTile(
                  value: _agreed,
                  onChanged: (value) => setState(() => _agreed = value == true),
                  title: const Text(
                    'قرأت الوثيقة وأوافق عليها إلكترونياً',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _agreed && !_saving ? _accept : null,
                  icon: const Icon(Icons.verified_rounded),
                  label: const Text('توقيع الوثيقة وفتح بوابة العمل'),
                ),
              ],
            ),
    );
  }
}

class _AgentInbox extends StatelessWidget {
  const _AgentInbox({required this.agentName});
  final String agentName;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('بوابة خدمة العملاء',
                style: TextStyle(fontWeight: FontWeight.w900)),
            Text('صلاحيات الدعم فقط', style: TextStyle(fontSize: 11)),
          ],
        ),
        actions: [_AvailabilityButton(agentName: agentName)],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('support_threads')
            .where('assignedAgentId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final threads = [...(snapshot.data?.docs ?? const [])]..sort((a, b) {
              final aTime = a.data()['updatedAt'] as Timestamp?;
              final bTime = b.data()['updatedAt'] as Timestamp?;
              return (bTime?.millisecondsSinceEpoch ?? 0)
                  .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
            });
          if (threads.isEmpty) {
            return const Center(child: Text('لا توجد محادثات دعم حالياً.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: threads.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final thread = threads[index];
              final data = thread.data();
              final assigned = data['assignedAgentId']?.toString() ?? '';
              return Card(
                color: Colors.white,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: CircleAvatar(
                    backgroundColor: assigned.isEmpty
                        ? AppTheme.coolYellow
                        : const Color(0xFFE6F5ED),
                    child: Icon(
                      assigned.isEmpty
                          ? Icons.mark_chat_unread_rounded
                          : Icons.support_agent_rounded,
                      color: AppTheme.navy,
                    ),
                  ),
                  title: Text(
                    data['customerName']?.toString() ?? 'عميل بركة',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    data['lastMessage']?.toString().trim().isEmpty == false
                        ? data['lastMessage'].toString()
                        : 'محادثة جديدة',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _AgentThreadScreen(
                        threadId: thread.id,
                        threadData: data,
                        agentName: agentName,
                      ),
                    ),
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

class _AvailabilityButton extends StatelessWidget {
  const _AvailabilityButton({required this.agentName});
  final String agentName;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('customer_service_presence')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final available = snapshot.data?.data()?['isAvailable'] == true;
        return Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: ActionChip(
            avatar: Icon(Icons.circle,
                size: 13, color: available ? Colors.green : Colors.grey),
            label: Text(available ? 'متاح' : 'غير متاح'),
            onPressed: () => CustomerServiceService()
                .setAgentAvailability(agentName, !available),
          ),
        );
      },
    );
  }
}

class _AgentThreadScreen extends StatefulWidget {
  const _AgentThreadScreen({
    required this.threadId,
    required this.threadData,
    required this.agentName,
  });
  final String threadId;
  final Map<String, dynamic> threadData;
  final String agentName;

  @override
  State<_AgentThreadScreen> createState() => _AgentThreadScreenState();
}

class _AgentThreadScreenState extends State<_AgentThreadScreen> {
  final _message = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    setState(() => _busy = true);
    try {
      await CustomerServiceService()
          .claimThread(widget.threadId, widget.agentName);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (_message.text.trim().isEmpty || _busy) return;
    setState(() => _busy = true);
    final text = _message.text;
    _message.clear();
    try {
      await CustomerServiceService().sendAgentMessage(widget.threadId, text);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final thread = FirebaseFirestore.instance
        .collection('support_threads')
        .doc(widget.threadId);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: Text(widget.threadData['customerName']?.toString() ?? 'عميل'),
      ),
      body: Column(
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: thread.snapshots(),
            builder: (context, snapshot) {
              final assigned =
                  snapshot.data?.data()?['assignedAgentId']?.toString() ?? '';
              if (assigned == user.uid) return const SizedBox.shrink();
              return Material(
                color: const Color(0xFFFFF2C4),
                child: ListTile(
                  title: Text(assigned.isEmpty
                      ? 'هذه المحادثة غير مستلمة'
                      : 'يعمل عليها موظف آخر'),
                  trailing: assigned.isEmpty
                      ? FilledButton(
                          onPressed: _busy ? null : _claim,
                          child: const Text('استلام'),
                        )
                      : null,
                ),
              );
            },
          ),
          _CustomerOrdersPanel(
            customerId:
                widget.threadData['customerId']?.toString() ?? widget.threadId,
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: thread
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (_, snapshot) {
                final messages = snapshot.data?.docs ?? const [];
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (_, index) {
                    final data = messages[index].data();
                    final mine = data['senderId'] == user.uid;
                    return Align(
                      alignment: mine
                          ? AlignmentDirectional.centerEnd
                          : AlignmentDirectional.centerStart,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 310),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: mine ? AppTheme.navy : Colors.white,
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Text(data['text']?.toString() ?? '',
                            style: TextStyle(
                                color: mine ? Colors.white : Colors.black87)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _message,
                      decoration: const InputDecoration(hintText: 'اكتب الرد…'),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: _busy ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerOrdersPanel extends StatelessWidget {
  const _CustomerOrdersPanel({required this.customerId});
  final String customerId;

  String _status(dynamic value) {
    return switch (value?.toString()) {
      'pending' => 'قيد المراجعة',
      'accepted' => 'تم القبول',
      'preparing' => 'قيد التحضير',
      'ready' => 'جاهز',
      'on_the_way' => 'في الطريق',
      'delivered' => 'تم التوصيل',
      'cancelled' => 'ملغي',
      _ => value?.toString() ?? 'قيد التنفيذ',
    };
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: customerId)
          .snapshots(),
      builder: (context, snapshot) {
        final orders = snapshot.data?.docs ?? const [];
        if (orders.isEmpty) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: const Color(0xFFFFF8DD),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('طلبات العميل',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              SizedBox(
                height: 58,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    final order = orders[index];
                    final data = order.data();
                    return Container(
                      width: 175,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.deepYellow),
                      ),
                      child: Text(
                        'طلب #${data['orderNumber'] ?? order.id.substring(0, order.id.length > 6 ? 6 : order.id.length)}\n${_status(data['status'])}',
                        maxLines: 2,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
