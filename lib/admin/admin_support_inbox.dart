import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/customer_service_service.dart';
import '../theme/app_theme.dart';

class AdminSupportInbox extends StatelessWidget {
  const AdminSupportInbox({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        appBar: AppBar(
          backgroundColor: AppTheme.navy,
          foregroundColor: Colors.white,
          title: const Text(
            'رسائل خدمة العملاء',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('support_threads')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('تعذر تحميل الرسائل: ${snapshot.error}'),
                ),
              );
            }
            final threads = [...(snapshot.data?.docs ?? const [])]
              ..sort((a, b) {
                final aData = a.data();
                final bData = b.data();
                final aTime = (aData['lastMessageAt'] ?? aData['updatedAt'])
                    as Timestamp?;
                final bTime = (bData['lastMessageAt'] ?? bData['updatedAt'])
                    as Timestamp?;
                return (bTime?.millisecondsSinceEpoch ?? 0)
                    .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
              });
            if (threads.isEmpty) {
              return const Center(
                child: Text('لا توجد رسائل خدمة عملاء حاليًا.'),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: threads.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final thread = threads[index];
                final data = thread.data();
                final lastMessage = data['lastMessage']?.toString().trim();
                final status = data['status']?.toString() ?? 'open';
                return Card(
                  color: Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    leading: CircleAvatar(
                      backgroundColor: status == 'open'
                          ? const Color(0xFFFFE9A8)
                          : const Color(0xFFE4F4EA),
                      child: Icon(
                        status == 'open'
                            ? Icons.mark_chat_unread_rounded
                            : Icons.forum_rounded,
                        color: AppTheme.navy,
                      ),
                    ),
                    title: Text(
                      data['customerName']?.toString() ?? 'عميل بركة',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      lastMessage == null || lastMessage.isEmpty
                          ? 'محادثة جديدة'
                          : lastMessage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_left_rounded),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _AdminSupportThread(
                          threadId: thread.id,
                          initialData: data,
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

class _AdminSupportThread extends StatefulWidget {
  const _AdminSupportThread({
    required this.threadId,
    required this.initialData,
  });

  final String threadId;
  final Map<String, dynamic> initialData;

  @override
  State<_AdminSupportThread> createState() => _AdminSupportThreadState();
}

class _AdminSupportThreadState extends State<_AdminSupportThread> {
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
      await CustomerServiceService().sendAdminMessage(widget.threadId, text);
      _message.clear();
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final thread = FirebaseFirestore.instance
        .collection('support_threads')
        .doc(widget.threadId);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: Text(
          widget.initialData['customerName']?.toString() ?? 'عميل بركة',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFFFF5D6),
            padding: const EdgeInsets.all(12),
            child: Text(
              widget.initialData['customerEmail']?.toString().trim().isEmpty ==
                      false
                  ? widget.initialData['customerEmail'].toString()
                  : 'محادثة دعم داخل بركة',
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: thread
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                final messages = snapshot.data?.docs ?? const [];
                if (messages.isEmpty) {
                  return const Center(child: Text('لا توجد رسائل بعد.'));
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data();
                    final mine = data['senderId'] == uid;
                    return Align(
                      alignment: mine
                          ? AlignmentDirectional.centerEnd
                          : AlignmentDirectional.centerStart,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 330),
                        margin: const EdgeInsets.only(bottom: 9),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: mine ? AppTheme.navy : Colors.white,
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['senderName']?.toString() ?? '',
                              style: TextStyle(
                                color:
                                    mine ? Colors.white70 : AppTheme.deepYellow,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              data['text']?.toString() ?? '',
                              style: TextStyle(
                                color: mine ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
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
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'اكتب الرد للعميل…',
                      ),
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
