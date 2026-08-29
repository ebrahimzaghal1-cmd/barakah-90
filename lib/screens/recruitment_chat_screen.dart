import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class RecruitmentChatScreen extends StatefulWidget {
  const RecruitmentChatScreen({
    super.key,
    required this.applicantId,
    required this.applicantName,
    this.adminMode = false,
  });

  final String applicantId;
  final String applicantName;
  final bool adminMode;

  @override
  State<RecruitmentChatScreen> createState() => _RecruitmentChatScreenState();
}

class _RecruitmentChatScreenState extends State<RecruitmentChatScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  DocumentReference<Map<String, dynamic>> get _thread =>
      FirebaseFirestore.instance
          .collection('recruitment_chats')
          .doc(widget.applicantId);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final user = FirebaseAuth.instance.currentUser;
    final text = _controller.text.trim();
    if (user == null || text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.set(
        _thread,
        {
          'applicantId': widget.applicantId,
          'applicantName': widget.applicantName,
          'lastMessage': text,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      batch.set(_thread.collection('messages').doc(), {
        'senderId': user.uid,
        'senderRole': widget.adminMode ? 'admin' : 'applicant',
        'senderName': widget.adminMode ? 'إدارة بركة' : widget.applicantName,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إرسال الرسالة: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.adminMode ? widget.applicantName : 'فريق توظيف بركة',
                style: const TextStyle(fontWeight: FontWeight.w900)),
            const Text('محادثة توظيف خاصة داخل التطبيق',
                style: TextStyle(fontSize: 11)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _thread
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
                        'ابدأ المحادثة هنا للاستفسار عن الطلب أو إرسال تفاصيل المقابلة والوثيقة.',
                        textAlign: TextAlign.center,
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
                    final mine = data['senderId'] == currentId;
                    return Align(
                      alignment: mine
                          ? AlignmentDirectional.centerEnd
                          : AlignmentDirectional.centerStart,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 310),
                        margin: const EdgeInsets.only(bottom: 9),
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: mine ? AppTheme.navy : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          data['text']?.toString() ?? '',
                          style: TextStyle(
                              color: mine ? Colors.white : Colors.black87),
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
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: 4,
                      minLines: 1,
                      decoration: const InputDecoration(
                          hintText: 'اكتب رسالة التوظيف…'),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
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
