import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class BarberBookingService {
  BarberBookingService._();

  static final instance = BarberBookingService._();
  final _firestore = FirebaseFirestore.instance;
  static const _apiBase =
      'https://barakah-secure-api.ebrahimzaghal1.workers.dev';

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

    // السعر والمدة واسم الخدمة معروضات للعميل فقط؛ الخادم يعيد قراءتها
    // من سجل المحل ولا يثق بهذه القيم القادمة من الشاشة.
    final result = await _post('/v1/appointments', {
      'businessId': businessId,
      'serviceId': serviceId,
      'startMillis': start.millisecondsSinceEpoch,
      'customerName': customerName.trim(),
      'customerPhone': customerPhone.trim(),
    });
    final bookingId = result['bookingId']?.toString();
    if (bookingId == null || bookingId.isEmpty) {
      throw StateError('تعذر إنشاء الموعد الآن.');
    }
    return bookingId;
  }

  Future<void> updateBookingStatus({
    required String bookingId,
    required String status,
    required String businessId,
    String? dateKey,
    int? startMinutes,
  }) async {
    await _post('/v1/appointments/$bookingId/status', {'status': status});
  }

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('يجب تسجيل الدخول أولاً.');
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('انتهت جلسة الدخول. سجّل الدخول مجددًا.');
    }
    final response = await http
        .post(Uri.parse('$_apiBase$path'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode(body))
        .timeout(const Duration(seconds: 25));
    final decoded = response.body.isEmpty ? const <String, dynamic>{} : jsonDecode(response.body);
    final data = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : const <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(data['message']?.toString() ?? 'تعذر حفظ الموعد الآن.');
    }
    return data;
  }

}
