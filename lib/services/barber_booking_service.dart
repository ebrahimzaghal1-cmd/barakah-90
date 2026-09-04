import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BarberBookingService {
  BarberBookingService._();

  static final instance = BarberBookingService._();
  final _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchLocks({
    required String businessId,
    required String dateKey,
  }) {
    return _firestore
        .collection('barber_slot_locks')
        .where('businessId', isEqualTo: businessId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMerchantBookings(
    String businessId,
  ) {
    return _firestore
        .collection('barber_bookings')
        .where('businessId', isEqualTo: businessId)
        .snapshots();
  }

  Future<String> createBooking({
    required String businessId,
    required String serviceId,
    required String serviceTitle,
    required double price,
    required int durationMinutes,
    required DateTime start,
    required String customerName,
    required String customerPhone,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('يجب تسجيل الدخول لحجز موعد.');

    final dateKey = _dateKey(start);
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = startMinutes + durationMinutes;
    final lockId = '${businessId}_${dateKey}_$startMinutes';
    final lockRef = _firestore.collection('barber_slot_locks').doc(lockId);

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(lockRef);
      if (existing.exists) throw StateError('هذا الوقت محجوز.');
      transaction.set(lockRef, {
        'businessId': businessId,
        'dateKey': dateKey,
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
        'status': 'reserved',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    try {
      final commission = double.parse((price * .1).toStringAsFixed(2));
      final booking = await _firestore.collection('barber_bookings').add({
        'businessId': businessId,
        'serviceId': serviceId,
        'serviceTitle': serviceTitle,
        'customerId': user.uid,
        'customerName': customerName.trim(),
        'customerPhone': customerPhone.trim(),
        'dateKey': dateKey,
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
        'scheduledAt': Timestamp.fromDate(start),
        'price': price,
        'commissionRate': 10,
        'commissionAmount': commission,
        'businessNetAmount':
            double.parse((price - commission).toStringAsFixed(2)),
        'status': 'pending',
        'orderType': 'barber_booking',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return booking.id;
    } catch (_) {
      await lockRef.delete();
      rethrow;
    }
  }

  Future<void> updateBookingStatus({
    required String bookingId,
    required String status,
    required String businessId,
    String? dateKey,
    int? startMinutes,
  }) async {
    await _firestore.collection('barber_bookings').doc(bookingId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (status == 'cancelled' && dateKey != null && startMinutes != null) {
      await _firestore
          .collection('barber_slot_locks')
          .doc('${businessId}_${dateKey}_$startMinutes')
          .update({'status': 'cancelled'});
    }
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
