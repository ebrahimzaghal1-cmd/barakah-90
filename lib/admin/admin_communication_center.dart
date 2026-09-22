import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/chat_media_service.dart';
import '../services/customer_service_service.dart';
import '../widgets/chat_media_widgets.dart';
import '../theme/app_theme.dart';
import 'admin_broadcast_campaigns.dart';

class AdminCommunicationCenter extends StatefulWidget {
  const AdminCommunicationCenter({super.key});

  @override
  State<AdminCommunicationCenter> createState() =>
      _AdminCommunicationCenterState();
}

class _AdminCommunicationCenterState extends State<AdminCommunicationCenter> {
  final _search = TextEditingController();
  String _query = '';
  bool _opening = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _labelFor(Map<String, dynamic> data) {
    final role = data['role']?.toString() ?? '';

    if (data['taxiDriverEnabled'] == true) {
      return 'سائق تكسي بركة';
    }

    if (role == 'driver') return 'سائق توصيل';
    if (role == 'merchant') return 'شريك / صاحب محل';

    if (role == 'customer_service' && data['customerServiceEnabled'] == true) {
      return 'خدمة العملاء';
    }

    final agentNumber = data['agentNumber']?.toString().trim() ?? '';

    if (agentNumber.isNotEmpty) return 'وسيطة بركة';

    if (role == 'admin' || data['isAdmin'] == true) {
      return 'أدمن';
    }

    return 'عميل / مشترك';
  }

  Future<void> _openConversation(
    DocumentSnapshot<Map<String, dynamic>> userDoc,
  ) async {
    if (_opening) return;

    setState(() => _opening = true);

    try {
      final data = userDoc.data() ?? const <String, dynamic>{};

      final displayName = (data['displayName'] ??
              data['fullName'] ??
              data['email'] ??
              'مستخدم بركة')
          .toString()
          .trim();

      final email = data['email']?.toString().trim() ?? '';

      final thread = FirebaseFirestore.instance
          .collection('support_threads')
          .doc(userDoc.id);

      final snapshot = await thread.get();

      if (!snapshot.exists) {
        await thread.set({
          'customerId': userDoc.id,
          'customerName': displayName.isEmpty ? 'مستخدم بركة' : displayName,
          'customerEmail': email,
          'status': 'open',
          'assignedAgentId': '',
          'assignedAgentName': '',
          'lastMessage': '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _AdminDirectConversation(
            threadId: userDoc.id,
            userName: displayName.isEmpty ? 'مستخدم بركة' : displayName,
            email: email,
            phone: data['phone']?.toString().trim() ?? '',
            accountType: _labelFor(data),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر فتح المحادثة: '
            '${error.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: const Text(
          'مركز تواصل بركة',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'الحملات والرسائل الجماعية',
            icon: const Icon(Icons.campaign_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminBroadcastCampaigns(),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5D6),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              'محادثات فردية داخل بركة مع أي حساب. '
              'الرسائل الجماعية والحملات ستظهر هنا في المرحلة التالية.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: TextField(
              controller: _search,
              onChanged: (value) {
                setState(() => _query = value.trim().toLowerCase());
              },
              decoration: const InputDecoration(
                hintText: 'ابحث بالاسم أو البريد أو الهاتف...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream:
                  FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'تعذر تحميل الحسابات: ${snapshot.error}',
                    ),
                  );
                }

                final currentUid = FirebaseAuth.instance.currentUser?.uid;

                final users = snapshot.data!.docs.where((doc) {
                  if (doc.id == currentUid) return false;

                  if (_query.isEmpty) return true;

                  final data = doc.data();

                  final haystack = [
                    data['displayName'],
                    data['fullName'],
                    data['email'],
                    data['phone'],
                    data['agentNumber'],
                  ].map((value) => value?.toString() ?? '').join(' ')
                    ..toLowerCase();

                  return haystack.toLowerCase().contains(_query);
                }).toList()
                  ..sort((a, b) {
                    final aData = a.data();
                    final bData = b.data();

                    final aName = (aData['displayName'] ??
                            aData['fullName'] ??
                            aData['email'] ??
                            '')
                        .toString()
                        .toLowerCase();

                    final bName = (bData['displayName'] ??
                            bData['fullName'] ??
                            bData['email'] ??
                            '')
                        .toString()
                        .toLowerCase();

                    return aName.compareTo(bName);
                  });

                if (users.isEmpty) {
                  return const Center(
                    child: Text('لا توجد حسابات مطابقة.'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final userDoc = users[index];
                    final data = userDoc.data();

                    final name = (data['displayName'] ??
                            data['fullName'] ??
                            data['email'] ??
                            'مستخدم بركة')
                        .toString();

                    final email = data['email']?.toString().trim() ?? '';

                    final phone = data['phone']?.toString().trim() ?? '';

                    return Card(
                      color: Colors.white,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(13),
                        leading: const CircleAvatar(
                          backgroundColor: AppTheme.coolYellow,
                          child: Icon(
                            Icons.person_rounded,
                            color: AppTheme.navy,
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                            color: AppTheme.navy,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        subtitle: Text(
                          [
                            _labelFor(data),
                            if (email.isNotEmpty) email,
                            if (phone.isNotEmpty) phone,
                          ].join(' • '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chat_rounded),
                        onTap:
                            _opening ? null : () => _openConversation(userDoc),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminDirectConversation extends StatefulWidget {
  const _AdminDirectConversation({
    required this.threadId,
    required this.userName,
    required this.email,
    required this.phone,
    required this.accountType,
  });

  final String threadId;
  final String userName;
  final String email;
  final String phone;
  final String accountType;

  @override
  State<_AdminDirectConversation> createState() =>
      _AdminDirectConversationState();
}

class _AdminDirectConversationState extends State<_AdminDirectConversation> {
  final _message = TextEditingController();
  final _mediaDraft = ChatMediaDraft();
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    _mediaDraft.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _message.text.trim();

    if ((text.isEmpty && !_mediaDraft.hasAttachment) ||
        _sending ||
        _mediaDraft.isBusy) {
      return;
    }

    setState(() => _sending = true);

    try {
      final media = await _mediaDraft.upload();
      if (!mounted) return;
      await CustomerServiceService().sendAdminMessage(
        widget.threadId,
        text,
        imageUrl: media['imageUrl'],
        videoUrl: media['videoUrl'],
        mediaType: media['mediaType'],
      );
      if (!mounted) return;

      _message.clear();
      _mediaDraft.clear();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    final thread = FirebaseFirestore.instance
        .collection('support_threads')
        .doc(widget.threadId);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: Text(
          widget.userName,
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
              [
                widget.accountType,
                if (widget.email.isNotEmpty) widget.email,
                if (widget.phone.isNotEmpty) widget.phone,
              ].join(' • '),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: thread
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'تعذر تحميل الرسائل: ${snapshot.error}',
                    ),
                  );
                }

                final messages = snapshot.data?.docs ?? const [];

                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'لا توجد رسائل بعد.\nابدأ المحادثة من الأسفل.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data();

                    final mine = data['senderId'] == currentUid;

                    return Align(
                      alignment: mine
                          ? AlignmentDirectional.centerEnd
                          : AlignmentDirectional.centerStart,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 360),
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
                            ChatMessageContent(
                              data: data,
                              textStyle: TextStyle(
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ChatMediaPicker(draft: _mediaDraft, enabled: !_sending),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _message,
                          enabled: !_sending,
                          minLines: 1,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            hintText: 'اكتب رسالة...',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ],
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
