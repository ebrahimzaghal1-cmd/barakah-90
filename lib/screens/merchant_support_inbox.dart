import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/customer_service_service.dart';
import '../theme/app_theme.dart';

class MerchantSupportInbox extends StatelessWidget {
  const MerchantSupportInbox({
    super.key,
    required this.businessId,
    required this.businessTitle,
  });

  final String businessId;
  final String businessTitle;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('سجّل الدخول أولاً.')));
    }
    return Scaffold(
      appBar: AppBar(title: Text('رسائل $businessTitle')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('support_threads')
            .where('merchantId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('تعذر تحميل رسائل المحل.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final threads = snapshot.data!.docs
              .where((doc) => doc.data()['businessId'] == businessId)
              .toList()
            ..sort((a, b) {
              final aTime = (a.data()['lastMessageAt'] ?? a.data()['updatedAt'])
                  as Timestamp?;
              final bTime = (b.data()['lastMessageAt'] ?? b.data()['updatedAt'])
                  as Timestamp?;
              return (bTime?.millisecondsSinceEpoch ?? 0)
                  .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
            });
          if (threads.isEmpty) {
            return const Center(
                child: Text('لا توجد رسائل لهذا المحل حالياً.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: threads.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final thread = threads[index];
              final data = thread.data();
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline_rounded),
                  ),
                  title: Text(
                    data['customerName']?.toString() ?? 'عميل بركة',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    data['lastMessage']?.toString().trim().isNotEmpty == true
                        ? data['lastMessage'].toString()
                        : 'محادثة جديدة',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _MerchantSupportThread(
                        threadId: thread.id,
                        customerName:
                            data['customerName']?.toString() ?? 'عميل بركة',
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

class _MerchantSupportThread extends StatefulWidget {
  const _MerchantSupportThread({
    required this.threadId,
    required this.customerName,
  });

  final String threadId;
  final String customerName;

  @override
  State<_MerchantSupportThread> createState() => _MerchantSupportThreadState();
}

class _MerchantSupportThreadState extends State<_MerchantSupportThread> {
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await CustomerServiceService().sendMerchantMessage(widget.threadId, text);
      _message.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final messages = FirebaseFirestore.instance
        .collection('support_threads')
        .doc(widget.threadId)
        .collection('messages');
    return Scaffold(
      appBar: AppBar(title: Text(widget.customerName)),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFFFF3C4),
            padding: const EdgeInsets.all(10),
            child: const Text(
              'هذه المحادثة يراها العميل وصاحب المحل وأدمن بركة فقط.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream:
                  messages.orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return const Center(child: Text('لا توجد رسائل بعد.'));
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final mine = data['senderId'] == uid;
                    return Align(
                      alignment: mine
                          ? AlignmentDirectional.centerEnd
                          : AlignmentDirectional.centerStart,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 340),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: mine ? AppTheme.navy : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          data['text']?.toString() ?? '',
                          style: TextStyle(
                            color: mine ? Colors.white : Colors.black87,
                          ),
                        ),
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
                      minLines: 1,
                      maxLines: 4,
                      decoration:
                          const InputDecoration(hintText: 'اكتب ردك للعميل…'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
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
