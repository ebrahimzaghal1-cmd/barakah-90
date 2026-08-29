import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/customer_service_service.dart';
import '../theme/app_theme.dart';
import 'authentication_screen.dart';

class CustomerSupportChatScreen extends StatefulWidget {
  const CustomerSupportChatScreen({super.key});

  @override
  State<CustomerSupportChatScreen> createState() =>
      _CustomerSupportChatScreenState();
}

class _CustomerSupportChatScreenState extends State<CustomerSupportChatScreen> {
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _message.text.trim().isEmpty) return;
    setState(() => _sending = true);
    final text = _message.text;
    _message.clear();
    try {
      await CustomerServiceService().sendCustomerMessage(text);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('محادثة خدمة العملاء')),
        body: Center(
          child: FilledButton.icon(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AuthenticationScreen()),
            ),
            icon: const Icon(Icons.login_rounded),
            label: const Text('سجّل الدخول لبدء المحادثة'),
          ),
        ),
      );
    }

    final thread =
        FirebaseFirestore.instance.collection('support_threads').doc(user.uid);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('خدمة عملاء بركة',
                style: TextStyle(fontWeight: FontWeight.w900)),
            Text('محادثة خاصة وآمنة', style: TextStyle(fontSize: 11)),
          ],
        ),
      ),
      body: Column(
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: thread.snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data();
              if (data == null) return const SizedBox.shrink();
              final agent = data['assignedAgentName']?.toString() ?? '';
              return Container(
                width: double.infinity,
                color: const Color(0xFFFFF3C4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                child: Text(
                  agent.isEmpty
                      ? 'بانتظار موظف خدمة عملاء متاح'
                      : 'يتابع معك الآن: $agent',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              );
            },
          ),
          _CustomerOwnOrdersPanel(customerId: user.uid),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: thread
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                final messages = snapshot.data?.docs ?? const [];
                if (messages.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: Text(
                        'أرسل رسالتك وسيرد عليك موظف خدمة العملاء من بوابته الخاصة.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54, height: 1.6),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (_, index) {
                    final data = messages[index].data();
                    final mine = data['senderId'] == user.uid;
                    return _MessageBubble(data: data, mine: mine);
                  },
                );
              },
            ),
          ),
          _composer(),
        ],
      ),
    );
  }

  Widget _composer() => SafeArea(
        top: false,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _message,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'اكتب رسالتك…',
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sending ? null : _send,
                style: IconButton.styleFrom(backgroundColor: AppTheme.navy),
                icon: const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
      );
}

class _CustomerOwnOrdersPanel extends StatelessWidget {
  const _CustomerOwnOrdersPanel({required this.customerId});
  final String customerId;

  String _status(dynamic value) => switch (value?.toString()) {
        'pending' => 'قيد المراجعة',
        'accepted' => 'تم قبول الطلب',
        'preparing' => 'قيد التحضير',
        'ready' => 'جاهز',
        'on_the_way' => 'في الطريق',
        'delivered' => 'تم التوصيل',
        'cancelled' => 'ملغي',
        _ => value?.toString() ?? 'قيد التنفيذ',
      };

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
        return SizedBox(
          height: 78,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final order = orders[index];
              final data = order.data();
              final shortId = order.id
                  .substring(0, order.id.length > 6 ? 6 : order.id.length);
              return Container(
                width: 180,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppTheme.deepYellow),
                ),
                child: Text(
                  'طلب #${data['orderNumber'] ?? shortId}\n${_status(data['status'])}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w900),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.data, required this.mine});
  final Map<String, dynamic> data;
  final bool mine;

  @override
  Widget build(BuildContext context) => Align(
        alignment: mine
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 310),
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: BoxDecoration(
            color: mine ? AppTheme.navy : Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine)
                Text(data['senderName']?.toString() ?? 'خدمة عملاء بركة',
                    style: const TextStyle(
                        color: AppTheme.deepYellow,
                        fontSize: 11,
                        fontWeight: FontWeight.w900)),
              Text(
                data['text']?.toString() ?? '',
                style: TextStyle(color: mine ? Colors.white : Colors.black87),
              ),
            ],
          ),
        ),
      );
}
