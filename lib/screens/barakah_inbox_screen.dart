import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/chat_media_widgets.dart';

class BarakahInboxScreen extends StatelessWidget {
  const BarakahInboxScreen({
    super.key,
    required this.userId,
  });

  final String userId;

  IconData _icon(String type) {
    if (type == 'offer') return Icons.local_offer_rounded;
    if (type == 'ad') return Icons.campaign_rounded;
    if (type == 'alert') return Icons.notification_important_rounded;
    return Icons.mail_rounded;
  }

  String _label(String type) {
    if (type == 'offer') return 'عرض';
    if (type == 'ad') return 'إعلان';
    if (type == 'alert') return 'تنبيه مهم';
    return 'رسالة';
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('user_inbox')
        .doc(userId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: const Text(
          'رسائل بركة',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'تعذر تحميل رسائل بركة.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final messages = snapshot.data!.docs;

          if (messages.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد رسائل من بركة حتى الآن.',
                style: TextStyle(
                  color: AppTheme.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: messages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final data = messages[index].data();

              final title = data['title']?.toString().trim().isNotEmpty == true
                  ? data['title'].toString()
                  : 'رسالة من بركة';

              final body = data['body']?.toString() ?? '';
              final type = data['type']?.toString() ?? 'message';

              return Card(
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFFFFF5D6),
                        child: Icon(
                          _icon(type),
                          color: AppTheme.navy,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      color: AppTheme.navy,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF5D6),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _label(type),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.navy,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // يدعم النص والصورة والفيديو بنفس مكوّن المحادثات.
                            ChatMessageContent(
                              data: {
                                ...data,
                                'text': body,
                              },
                            ),
                          ],
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
    );
  }
}
