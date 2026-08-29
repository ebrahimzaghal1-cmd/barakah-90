import 'package:cloud_firestore/cloud_firestore.dart';

/// خدمة قراءة بطاقة بركة وسجل النقاط والقسائم.
/// جميع عمليات إضافة/خصم رصيد النقاط تتم حصريًا عبر الخادم الآمن.
class LoyaltyService {
  LoyaltyService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const pointsPerCoupon = 100;
  static const couponDiscountPercent = 10;

  final FirebaseFirestore _firestore;

  Stream<DocumentSnapshot<Map<String, dynamic>>> profile(String uid) =>
      _firestore.collection('users').doc(uid).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> transactions(String uid) =>
      _firestore
          .collection('loyalty_transactions')
          .where('customerId', isEqualTo: uid)
          .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> activeCoupons(String uid) =>
      _firestore
          .collection('coupons')
          .where('customerId', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .snapshots();

  /// لا تُمنح النقاط إلا مرة واحدة للطلب بعد تحويله إلى "تم التسليم".
  @Deprecated('Order rewards are finalized by the secure server only.')
  Future<void> rewardDeliveredOrder(String orderId) async {
    throw StateError(
      'منح نقاط الطلب يتم تلقائيًا من الخادم عند تأكيد التسليم.',
    );
  }
}
