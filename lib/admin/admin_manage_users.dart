import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/user_profile_service.dart';

class AdminManageUsers extends StatelessWidget {
  const AdminManageUsers({super.key});

  Future<void> _editLoyaltyPoints(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data();
    final currentPoints = (data['loyaltyPoints'] as num?)?.toInt() ?? 0;

    final controller = TextEditingController(
      text: currentPoints.toString(),
    );

    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تعديل نقاط بركة'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'رصيد نقاط بركة',
            helperText: 'مثال للاختبار: 1000 نقطة = 10 شيكل',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value < 0) return;
              Navigator.pop(dialogContext, value);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (result == null) return;

    await FirebaseFirestore.instance.collection('users').doc(document.id).set({
      'loyaltyPoints': result,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم تحديث نقاط بركة إلى $result نقطة.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _resetBarakahCardPin(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    const pin = '1234';

    final data = document.data();
    final existingCard = (data['barakahCardNumber'] ?? '').toString().trim();

    final random = Random.secure();

    String block() => List.generate(4, (_) => random.nextInt(10)).join();

    final cardNumber = existingCard.isNotEmpty
        ? existingCard
        : 'BRK-${block()}-${block()}-${block()}';

    final salt =
        '${DateTime.now().microsecondsSinceEpoch}-${random.nextInt(1 << 31)}';

    final hash = sha256
        .convert(
          utf8.encode(
            '${document.id}:$salt:$pin',
          ),
        )
        .toString();

    await FirebaseFirestore.instance.collection('users').doc(document.id).set({
      'barakahCardNumber': cardNumber,
      'barakahPinHash': hash,
      'barakahPinSalt': salt,
      'barakahCardActive': true,
      'barakahCardCreatedAt':
          data['barakahCardCreatedAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('بطاقة بركة جاهزة ✅'),
        content: Text(
          'رقم البطاقة:\n$cardNumber\n\n'
          'PIN التجريبي:\n1234\n\n'
          'استخدمي 1234 الآن لاختبار الدفع بنقاط بركة.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('تم'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = FirebaseAuth.instance.currentUser;
    return FutureBuilder<bool>(
      future: current == null
          ? Future.value(false)
          : UserProfileService().isAdmin(current.uid),
      builder: (context, permission) {
        if (permission.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (permission.data != true) {
          return const Scaffold(
            body: Center(child: Text('هذه الصفحة متاحة للأدمن فقط.')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('المشتركون والحسابات'),
            centerTitle: true,
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                    child: Text('تعذر تحميل بيانات المشتركين.'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final users = snapshot.data!.docs.toList()
                ..sort((a, b) {
                  final aName =
                      (a.data()['displayName'] ?? a.data()['email'] ?? '')
                          .toString();
                  final bName =
                      (b.data()['displayName'] ?? b.data()['email'] ?? '')
                          .toString();
                  return aName.toLowerCase().compareTo(bName.toLowerCase());
                });
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      leading:
                          const CircleAvatar(child: Icon(Icons.groups_rounded)),
                      title: const Text('إجمالي الحسابات',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                      trailing: Text('${users.length}',
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (users.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('لا توجد حسابات مسجلة بعد.',
                          textAlign: TextAlign.center),
                    )
                  else
                    ...users.map((document) {
                      final data = document.data();
                      final name = data['displayName']?.toString().trim() ?? '';
                      final email = data['email']?.toString().trim() ?? '';
                      final phone = data['phone']?.toString().trim() ?? '';
                      final loyaltyPoints =
                          (data['loyaltyPoints'] as num?)?.toInt() ?? 0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(14),
                          leading: CircleAvatar(
                            child: Text((name.isNotEmpty ? name : email).isEmpty
                                ? '؟'
                                : (name.isNotEmpty ? name : email)
                                    .characters
                                    .first),
                          ),
                          title: Text(name.isEmpty ? 'مشترك بدون اسم' : name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.email_outlined, size: 18),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: SelectableText(
                                        email.isEmpty
                                            ? 'سيظهر البريد عند دخول صاحب الحساب مجدداً'
                                            : email,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: email.isEmpty
                                              ? Colors.orange.shade800
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (phone.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      const Icon(Icons.phone_outlined,
                                          size: 18),
                                      const SizedBox(width: 7),
                                      Expanded(child: SelectableText(phone)),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.stars_rounded,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 7),
                                    Text(
                                      'نقاط بركة: $loyaltyPoints',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            tooltip: 'إدارة نقاط وبطاقة بركة',
                            icon: const Icon(
                              Icons.more_vert_rounded,
                            ),
                            onSelected: (value) async {
                              if (value == 'points') {
                                await _editLoyaltyPoints(
                                  context,
                                  document,
                                );
                              } else if (value == 'pin') {
                                await _resetBarakahCardPin(
                                  context,
                                  document,
                                );
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem<String>(
                                value: 'points',
                                child: Row(
                                  children: [
                                    Icon(Icons.stars_rounded),
                                    SizedBox(width: 10),
                                    Text('تعديل نقاط بركة'),
                                  ],
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'pin',
                                child: Row(
                                  children: [
                                    Icon(Icons.password_rounded),
                                    SizedBox(width: 10),
                                    Text('إعادة PIN بطاقة بركة'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
