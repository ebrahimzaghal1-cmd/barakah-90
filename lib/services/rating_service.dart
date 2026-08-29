import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RatingSummary {
  const RatingSummary({required this.average, required this.count});
  final double average;
  final int count;

  factory RatingSummary.fromData(Map<String, dynamic>? data) => RatingSummary(
        average: (data?['average'] as num?)?.toDouble() ?? 0,
        count: (data?['count'] as num?)?.toInt() ?? 0,
      );
}

class RatingService {
  RatingService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<DocumentSnapshot<Map<String, dynamic>>> summaryFor(
          String businessId) =>
      _firestore.collection('rating_summaries').doc(businessId).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> allSummaries() =>
      _firestore.collection('rating_summaries').snapshots();

  Future<void> rateBusiness(String businessId, int value) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('سجّل الدخول أولاً لإضافة تقييمك.');
    if (value < 1 || value > 5) throw ArgumentError.value(value);
    await _firestore
        .collection('business_ratings')
        .doc(businessId)
        .collection('votes')
        .doc(user.uid)
        .set({
      'value': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
