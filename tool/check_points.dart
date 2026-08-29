import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import '../lib/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    print('❌ لا يوجد مستخدم مسجل دخول داخل هذا التشغيل');
    return;
  }

  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();

  print('===== CURRENT POINTS =====');
  print('uid: ${user.uid}');
  print('loyaltyPoints: ${userDoc.data()?['loyaltyPoints']}');

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

  print('');
  print('===== LOYALTY TRANSACTIONS =====');

  num calculated = 0;

  for (final doc in docs) {
    final d = doc.data();
    final delta = (d['pointsDelta'] as num?) ?? 0;
    calculated += delta;

    print({
      'id': doc.id,
      'type': d['type'],
      'pointsDelta': delta,
      'balanceBefore': d['balanceBefore'],
      'balanceAfter': d['balanceAfter'],
      'orderNumber': d['orderNumber'],
      'source': d['source'],
      'description': d['description'],
    });
  }

  print('');
  print('===== TOTAL FROM RECORDED HISTORY =====');
  print('sum(pointsDelta): $calculated');
}
