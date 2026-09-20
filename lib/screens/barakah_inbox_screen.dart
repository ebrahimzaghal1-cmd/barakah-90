import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'تعذر تحميل الرسائل: ${snapshot.error}',
              ),
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

              final title = data['title']?.toString() ?? 'رسالة من بركة';

              final body = data['body']?.toString() ?? '';

              final type = data['type']?.toString() ?? 'message';

              return Card(
                color: Colors.white,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFFFF5D6),
                    child: Icon(
                      _icon(type),
                      color: AppTheme.navy,
                    ),
                  ),
                  title: Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Text(body),
                  ),
                  trailing: Text(
                    _label(type),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
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
