import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class TaxiOrderService {
  TaxiOrderService._();

  static final instance = TaxiOrderService._();

  static const _apiBase =
      'https://barakah-secure-api.ebrahimzaghal1.workers.dev';

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('taxi_orders');

  Future<String> createOrder({
    required String businessId,
    required String businessName,
    required String pickupAddress,
    double? pickupLatitude,
    double? pickupLongitude,
    required String destination,
    String? notes,
    String? customerName,
    String? customerPhone,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('يجب تسجيل الدخول لطلب التاكسي.');
    }

    // Unique request id makes retries idempotent on the server.
    final requestId = _collection.doc().id;

    final result = await _post('/v1/taxi-orders', {
      'requestId': requestId,
      'businessId': businessId,
      'pickupAddress': pickupAddress.trim(),
      'pickupLatitude': pickupLatitude,
      'pickupLongitude': pickupLongitude,
      'destination': destination.trim(),
      'notes': notes?.trim() ?? '',
      'customerName': customerName?.trim() ?? '',
      'customerPhone': customerPhone?.trim() ?? '',
    });

    final orderId = result['orderId']?.toString() ?? '';
    if (orderId.isEmpty) {
      throw StateError('لم يُرجع الخادم رقم طلب التاكسي.');
    }

    return orderId;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchCustomerActiveOrders({
    required String customerId,
    required String businessId,
  }) {
    return _collection
        .where('customerId', isEqualTo: customerId)
        .where('businessId', isEqualTo: businessId)
        .where(
      'status',
      whereIn: [
        'pending',
        'dispatched',
        'awaiting_customer_confirmation',
      ],
    ).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchBusinessOrders(
    String businessId,
  ) {
    return _collection.where('businessId', isEqualTo: businessId).snapshots();
  }

  Future<void> dispatchTaxi({
    required String orderId,
    required String vehicleInfo,
    int? etaMinutes,
  }) async {
    await _post(
      '/v1/taxi-orders/${Uri.encodeComponent(orderId)}/action',
      {
        'action': 'dispatch',
        'vehicleInfo': vehicleInfo.trim(),
        'etaMinutes': etaMinutes ?? 5,
      },
    );
  }

  Future<void> completeTrip({
    required String orderId,
    required double fareAmount,
  }) async {
    await _post(
      '/v1/taxi-orders/${Uri.encodeComponent(orderId)}/action',
      {
        'action': 'complete',
        'fareAmount': fareAmount,
      },
    );
  }

  Future<void> confirmArrival({
    required String orderId,
  }) async {
    await _post(
      '/v1/taxi-orders/${Uri.encodeComponent(orderId)}/action',
      {'action': 'confirm'},
    );
  }

  Future<void> cancelTrip({
    required String orderId,
    String? reason,
  }) async {
    await _post(
      '/v1/taxi-orders/${Uri.encodeComponent(orderId)}/action',
      {
        'action': 'cancel',
        'reason': reason?.trim() ?? '',
      },
    );
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('يجب تسجيل الدخول.');
    }

    final token = await user.getIdToken();

    final response = await http
        .post(
          Uri.parse('$_apiBase$path'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    Map<String, dynamic> result;
    try {
      result =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw StateError('استجابة خادم التكسي غير صالحة.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        result['message']?.toString() ?? 'تعذر تنفيذ طلب التاكسي.',
      );
    }

    return result;
  }
}
