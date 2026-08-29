import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CheckPointsScreen extends StatefulWidget {
  const CheckPointsScreen({super.key});

  @override
  State<CheckPointsScreen> createState() => _CheckPointsScreenState();
}

class _CheckPointsScreenState extends State<CheckPointsScreen> {
  String output = 'جاري الفحص...';

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() => output = '❌ لا يوجد مستخدم مسجل دخول');
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final tx = await FirebaseFirestore.instance
        .collection('loyalty_transactions')
        .where('customerId', isEqualTo: user.uid)
        .get();

    final docs = tx.docs.toList()
      ..sort((a, b) {
        final ad = a.data()['createdAt'];
        final bd = b.data()['createdAt'];

        final da = ad is Timestamp
            ? ad.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);

        final db = bd is Timestamp
            ? bd.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);

        return da.compareTo(db);
      });

    num sum = 0;
    final buffer = StringBuffer();

    buffer.writeln('===== CURRENT POINTS =====');
    buffer.writeln('uid: ${user.uid}');
    buffer.writeln(
      'loyaltyPoints: ${userDoc.data()?['loyaltyPoints']}',
    );

    buffer.writeln('');
    buffer.writeln('===== LOYALTY TRANSACTIONS =====');

    for (final doc in docs) {
      final d = doc.data();
      final delta = (d['pointsDelta'] as num?) ?? 0;
      sum += delta;

      buffer.writeln({
        'id': doc.id,
        'type': d['type'],
        'pointsDelta': delta,
        'balanceBefore': d['balanceBefore'],
        'balanceAfter': d['balanceAfter'],
        'orderNumber': d['orderNumber'],
        'source': d['source'],
      });
    }

    buffer.writeln('');
    buffer.writeln('sum(pointsDelta): $sum');

    setState(() => output = buffer.toString());

    debugPrint(output);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فحص نقاط بركة'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: SelectableText(output),
      ),
    );
  }
}
