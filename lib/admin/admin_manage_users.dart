import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/user_profile_service.dart';

enum _UsersOrder { newestFirst, oldestFirst }

class AdminManageUsers extends StatefulWidget {
  const AdminManageUsers({super.key});

  @override
  State<AdminManageUsers> createState() => _AdminManageUsersState();
}

class _AdminManageUsersState extends State<AdminManageUsers> {
  _UsersOrder _usersOrder = _UsersOrder.newestFirst;
  final Set<String> _deletingUserIds = {};

  DateTime? _joinDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  DateTime? _joinDateFromData(Map<String, dynamic> data) {
    for (final field in const [
      'joinedAt',
      'createdAt',
      'registeredAt',
      'timestamp',
    ]) {
      final date = _joinDate(data[field]);
      if (date != null) return date;
    }
    return null;
  }

  String _joinDateText(Map<String, dynamic> data) {
    final date = _joinDateFromData(data)?.toLocal();
    if (date == null) return 'غير متوفر';

    String twoDigits(int number) => number.toString().padLeft(2, '0');
    const weekDays = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final period = date.hour < 12 ? 'ص' : 'م';

    return 'اليوم: ${weekDays[date.weekday - 1]}\n'
        'التاريخ: ${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year}\n'
        'الوقت: ${twoDigits(hour)}:${twoDigits(date.minute)} $period';
  }

  int _compareUsers(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    final aDate = _joinDateFromData(a.data());
    final bDate = _joinDateFromData(b.data());

    // الحسابات القديمة التي لا تحتوي على تاريخ تبقى في نهاية القائمة.
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;

    return _usersOrder == _UsersOrder.newestFirst
        ? bDate.compareTo(aDate)
        : aDate.compareTo(bDate);
  }

  Future<void> _deleteUser(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data();
    final currentUser = FirebaseAuth.instance.currentUser;
    final isAdmin = data['role']?.toString() == 'admin' ||
        data['isAdmin'] == true ||
        document.id == currentUser?.uid;

    if (isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن حذف حساب أدمن من لوحة المستخدمين.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final name = data['displayName']?.toString().trim() ?? '';
    final email = data['email']?.toString().trim() ?? '';
    final accountLabel = name.isNotEmpty
        ? name
        : email.isNotEmpty
            ? email
            : document.id;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف المشترك؟'),
        content: Text(
          'سيتم حذف حساب $accountLabel نهائيًا وتنظيف بياناته الشخصية. '
          'لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_forever_rounded),
            label: const Text('حذف نهائي'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingUserIds.add(document.id));

    try {
      if (currentUser == null) {
        throw Exception('جلسة الأدمن غير متوفرة.');
      }

      final idToken = await currentUser.getIdToken(true);
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
          'userId': document.id,
          'directAdminDelete': true,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        var message = 'تعذر حذف المشترك.';
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
        SnackBar(
          content: Text('تم حذف حساب $accountLabel بنجاح.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingUserIds.remove(document.id));
      }
    }
  }

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

  Future<void> _setOrderSupervisor(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> document,
    bool enabled,
  ) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != UserProfileService.primaryAdminUid) {
      throw StateError('صاحب التطبيق فقط يستطيع تعيين المشرفين.');
    }
    if (document.id == UserProfileService.primaryAdminUid) return;

    final reference =
        FirebaseFirestore.instance.collection('users').doc(document.id);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data() ?? const <String, dynamic>{};
      if (enabled) {
        final currentRole = data['role']?.toString() ?? 'customer';
        transaction.set(
          reference,
          {
            if (currentRole != 'order_supervisor')
              'roleBeforeSupervision': currentRole,
            'role': 'order_supervisor',
            'adminPermissions': {'manageOrders': true},
            'supervisorAssignedBy': currentUid,
            'supervisorAssignedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } else {
        final previousRole = data['roleBeforeSupervision']?.toString().trim();
        transaction.set(
          reference,
          {
            'role': previousRole == null || previousRole.isEmpty
                ? 'customer'
                : previousRole,
            'roleBeforeSupervision': FieldValue.delete(),
            'adminPermissions': FieldValue.delete(),
            'supervisorAssignedBy': FieldValue.delete(),
            'supervisorAssignedAt': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    });

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(enabled
            ? 'تم تعيين الحساب كمشرف طلبات.'
            : 'تم سحب صلاحية إشراف الطلبات.'),
        backgroundColor: Colors.green,
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
              final users = snapshot.data!.docs.toList()..sort(_compareUsers);
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
                  DropdownButtonFormField<_UsersOrder>(
                    initialValue: _usersOrder,
                    decoration: const InputDecoration(
                      labelText: 'ترتيب المستخدمين',
                      prefixIcon: Icon(Icons.sort_rounded),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: _UsersOrder.newestFirst,
                        child: Text('الأحدث انضمامًا إلى الأقدم'),
                      ),
                      DropdownMenuItem(
                        value: _UsersOrder.oldestFirst,
                        child: Text('الأقدم انضمامًا إلى الأحدث'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _usersOrder = value);
                    },
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
                      final isOrderSupervisor =
                          data['role']?.toString() == 'order_supervisor';
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
                                if (isOrderSupervisor) ...[
                                  const SizedBox(height: 5),
                                  const Text(
                                    'مشرف طلبات • بلا صلاحيات مالية',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
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
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_month_outlined,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: Text(
                                        _joinDateText(data),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          trailing: _deletingUserIds.contains(document.id)
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : PopupMenuButton<String>(
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
                                    } else if (value == 'delete') {
                                      await _deleteUser(document);
                                    } else if (value == 'supervisor') {
                                      await _setOrderSupervisor(
                                        context,
                                        document,
                                        !isOrderSupervisor,
                                      );
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    if (document.id !=
                                        UserProfileService.primaryAdminUid)
                                      PopupMenuItem<String>(
                                        value: 'supervisor',
                                        child: Row(
                                          children: [
                                            Icon(isOrderSupervisor
                                                ? Icons.person_off_outlined
                                                : Icons.admin_panel_settings),
                                            const SizedBox(width: 10),
                                            Text(isOrderSupervisor
                                                ? 'سحب إشراف الطلبات'
                                                : 'تعيين كمشرف طلبات'),
                                          ],
                                        ),
                                      ),
                                    const PopupMenuItem<String>(
                                      value: 'points',
                                      child: Row(
                                        children: [
                                          Icon(Icons.stars_rounded),
                                          SizedBox(width: 10),
                                          Text('تعديل نقاط بركة'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'pin',
                                      child: Row(
                                        children: [
                                          Icon(Icons.password_rounded),
                                          SizedBox(width: 10),
                                          Text('إعادة PIN بطاقة بركة'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuDivider(),
                                    const PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.delete_forever_rounded,
                                            color: Colors.red,
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            'حذف المشترك',
                                            style: TextStyle(color: Colors.red),
                                          ),
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
