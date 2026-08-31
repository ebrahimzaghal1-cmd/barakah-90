import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AdminAccountDeletionRequests extends StatefulWidget {
  const AdminAccountDeletionRequests({super.key});

  @override
  State<AdminAccountDeletionRequests> createState() =>
      _AdminAccountDeletionRequestsState();
}

class _AdminAccountDeletionRequestsState
    extends State<AdminAccountDeletionRequests> {
  final Set<String> _processing = {};

  Future<void> _approveDeletion(
    String userId,
    String email,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد حذف الحساب'),
        content: Text(
          'سيتم حذف حساب ${email.isEmpty ? userId : email} نهائيًا '
          'وتنظيف بياناته الشخصية المرتبطة به.\n\n'
          'هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('موافقة وحذف الحساب'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processing.add(userId));

    try {
      final admin = FirebaseAuth.instance.currentUser;

      if (admin == null) {
        throw Exception('جلسة الأدمن غير متوفرة.');
      }

      final idToken = await admin.getIdToken(true);

      if (idToken == null || idToken.isEmpty) {
        throw Exception('تعذر الحصول على جلسة الأدمن.');
      }

      final response = await http.post(
        Uri.parse(
          'https://barakah-secure-api.ebrahimzaghal1.workers.dev/v1/admin/account/delete',
        ),
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'userId': userId,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'تعذر حذف الحساب.';

        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map) {
            message =
                (decoded['message'] ?? decoded['error'] ?? message).toString();
          }
        } catch (_) {}

        throw Exception(message);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف الحساب بنجاح.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      final message = error.toString().replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processing.remove(userId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات حذف الحساب'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('account_deletion_requests')
            .orderBy('requestedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'تعذر تحميل طلبات الحذف:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final requests = snapshot.data?.docs ?? [];

          if (requests.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد طلبات حذف حساب حاليًا',
                style: TextStyle(fontSize: 17),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = requests[index];
              final data = doc.data();

              final email = (data['email'] ?? '').toString();
              final userId = (data['userId'] ?? doc.id).toString();
              final status = (data['status'] ?? 'pending').toString();
              final requestedAt = data['requestedAt'];
              final processing = _processing.contains(userId);

              String dateText = 'الوقت غير متوفر';

              if (requestedAt is Timestamp) {
                final date = requestedAt.toDate();
                dateText = '${date.day}/${date.month}/${date.year} '
                    '${date.hour.toString().padLeft(2, '0')}:'
                    '${date.minute.toString().padLeft(2, '0')}';
              }

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        email.isEmpty ? 'بدون بريد إلكتروني' : email,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('الحالة: $status'),
                      const SizedBox(height: 4),
                      Text('تاريخ الطلب: $dateText'),
                      const SizedBox(height: 4),
                      SelectableText(
                        'UID: $userId',
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (status == 'pending') ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: processing
                                ? null
                                : () => _approveDeletion(
                                      userId,
                                      email,
                                    ),
                            icon: processing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.delete_forever_rounded),
                            label: Text(
                              processing
                                  ? 'جاري الحذف...'
                                  : 'موافقة وحذف الحساب',
                            ),
                          ),
                        ),
                      ],
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
