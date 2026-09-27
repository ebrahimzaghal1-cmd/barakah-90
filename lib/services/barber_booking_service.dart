import 'dart:convert';
import 'package:http/http.dart' as http;
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

    // Keep the same request id for retries of this submission.
    final requestId = _firestore.collection('barber_bookings').doc().id;
    final result = await _post('/v1/barber-bookings', {
      'requestId': requestId,
      'businessId': businessId,
      'serviceId': serviceId,
      'dateKey': _dateKey(start),
      'startMinutes': start.hour * 60 + start.minute,
      'scheduledAt': start.toUtc().toIso8601String(),
      'expectedPrice': price,
      'customerName': customerName.trim(),
      'customerPhone': customerPhone.trim(),
    });
    return result['bookingId'] as String;
  }

  Future<void> updateBookingStatus({
    required String bookingId,
    required String status,
    required String businessId,
    String? dateKey,
    int? startMinutes,
  }) async {
    await _post('/v1/barber-bookings/${Uri.encodeComponent(bookingId)}/status',
        {'status': status});
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('يجب تسجيل الدخول.');
    final token = await user.getIdToken();
    final response = await http.post(
      Uri.parse('https://barakah-secure-api.ebrahimzaghal1.workers.dev$path'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));
    final result = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(result['message']?.toString() ?? 'تعذر تنفيذ الحجز.');
    }
    return result;
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
