import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class OrderService {
  OrderService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static const _apiBase =
      'https://barakah-secure-api.ebrahimzaghal1.workers.dev';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<QuerySnapshot<Map<String, dynamic>>> customerOrders() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _firestore
        .collection('orders')
        .where('customerId', isEqualTo: uid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> allOrders() =>
      _firestore.collection('orders').snapshots();

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    String? idempotencyKey,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('سجّل الدخول قبل متابعة العملية.');
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('انتهت جلسة الدخول. سجّل الدخول مجددًا.');
    }
    final response = await http
        .post(
          Uri.parse('$_apiBase$path'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json; charset=utf-8',
            if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 25));

    Map<String, dynamic> data = const {};
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) data = Map<String, dynamic>.from(decoded);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data['message']?.toString().trim();
      throw StateError(
        message == null || message.isEmpty
            ? 'تعذر إتمام الطلب الآن. حاول مرة أخرى.'
            : message,
      );
    }
    return data;
  }

  Future<List<Map<String, dynamic>>> merchantCoupons() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('سجّل الدخول أولًا.');
    }

    final token = await user.getIdToken();

    if (token == null || token.isEmpty) {
      throw StateError(
        'انتهت جلسة الدخول. سجّل الدخول مجددًا.',
      );
    }

    final response = await http.get(
      Uri.parse(
        '$_apiBase/v1/merchant/coupons',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=utf-8',
      },
    ).timeout(
      const Duration(seconds: 25),
    );

    Map<String, dynamic> data = const {};

    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(
        utf8.decode(response.bodyBytes),
      );

      if (decoded is Map) {
        data = Map<String, dynamic>.from(decoded);
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data['message']?.toString().trim();

      throw StateError(
        message == null || message.isEmpty
            ? 'تعذر تحميل كوبونات المتجر.'
            : message,
      );
    }

    final raw = data['coupons'];

    if (raw is! List) {
      return const [];
    }

    return raw
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

  Future<Map<String, dynamic>> createMerchantCoupon({
    required String businessId,
    required String code,
    required num discountPercent,
    num minimumOrderAmount = 0,
    int maxUses = 0,
    DateTime? expiresAt,
    bool isActive = true,
  }) {
    return _post(
      '/v1/merchant/coupons',
      {
        'businessId': businessId,
        'code': code,
        'discountPercent': discountPercent,
        'minimumOrderAmount': minimumOrderAmount,
        'maxUses': maxUses,
        if (expiresAt != null)
          'expiresAtMillis': expiresAt.millisecondsSinceEpoch,
        'isActive': isActive,
      },
    );
  }

  Future<Map<String, dynamic>> updateMerchantCoupon({
    required String couponId,
    required String code,
    required num discountPercent,
    num minimumOrderAmount = 0,
    int maxUses = 0,
    DateTime? expiresAt,
    bool isActive = true,
  }) {
    return _post(
      '/v1/merchant/coupons/$couponId/update',
      {
        'code': code,
        'discountPercent': discountPercent,
        'minimumOrderAmount': minimumOrderAmount,
        'maxUses': maxUses,
        if (expiresAt != null)
          'expiresAtMillis': expiresAt.millisecondsSinceEpoch,
        'isActive': isActive,
      },
    );
  }

  Future<void> deleteMerchantCoupon(
    String couponId,
  ) async {
    await _post(
      '/v1/merchant/coupons/$couponId/delete',
      const <String, dynamic>{},
    );
  }

  Future<String> createOrder({
    required List<Map<String, dynamic>> items,
    required num total,
    required String deliveryMethod,
    required String paymentMethod,
    DateTime? scheduledFor,
    int barakahPointsToUse = 0,
    String? barakahPin,
    String? couponId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('سجّل الدخول قبل إتمام الطلب.');

    final profileSnapshot =
        await _firestore.collection('users').doc(user.uid).get();
    final profile = profileSnapshot.data() ?? <String, dynamic>{};

    final customerPhone =
        (profile['phone'] ?? user.phoneNumber ?? '').toString().trim();
    final deliveryAddress = (profile['address'] ?? '').toString().trim();
    final deliveryLatitude = (profile['agentLatitude'] as num?)?.toDouble();
    final deliveryLongitude = (profile['agentLongitude'] as num?)?.toDouble();

    if (deliveryMethod == 'delivery') {
      if (customerPhone.isEmpty) {
        throw StateError('أضيفي رقم الهاتف في الملف الشخصي قبل طلب التوصيل.');
      }
      if (deliveryAddress.isEmpty) {
        throw StateError(
            'أضيفي عنوان التوصيل في الملف الشخصي قبل متابعة الطلب.');
      }
      if (deliveryLatitude == null || deliveryLongitude == null) {
        throw StateError(
            'حددي موقع التوصيل على الخريطة من الملف الشخصي أولًا.');
      }
    }

    final secureRandom = Random.secure();
    final key = '${user.uid}-${DateTime.now().microsecondsSinceEpoch}-'
        '${secureRandom.nextInt(1 << 31)}';
    final safeItems = items
        .map((item) => {
              'productId': item['productId']?.toString(),
              'quantity': item['quantity'] ?? 1,
              if (item['image']?.toString().trim().isNotEmpty == true)
                'image': item['image'].toString().trim(),
            })
        .where((item) => (item['productId'] as String?)?.isNotEmpty == true)
        .toList();
    if (safeItems.isEmpty) throw StateError('السلة لا تحتوي أصنافًا صالحة.');

    final data = await _post(
      '/v1/orders',
      {
        'items': safeItems,
        'deliveryMethod': deliveryMethod,
        if (customerPhone.isNotEmpty) 'customerPhone': customerPhone,
        if (deliveryAddress.isNotEmpty) 'deliveryAddress': deliveryAddress,
        if (deliveryLatitude != null) 'deliveryLatitude': deliveryLatitude,
        if (deliveryLongitude != null) 'deliveryLongitude': deliveryLongitude,
        // الدفع الإلكتروني ما زال «قريبًا»؛ الخادم يقبل الدفع عند الاستلام فقط.
        'paymentMethod': 'cash',
        if (barakahPointsToUse > 0) 'barakahPointsToUse': barakahPointsToUse,
        if (barakahPointsToUse > 0) 'barakahPin': barakahPin?.trim() ?? '',
        if (couponId != null && couponId.trim().isNotEmpty)
          'couponId': couponId.trim(),
        if (scheduledFor != null)
          'scheduledForMillis': scheduledFor.millisecondsSinceEpoch,
      },
      idempotencyKey: key,
    );
    final orderId = data['orderId']?.toString();
    if (orderId == null || orderId.isEmpty) {
      throw StateError('تعذر إنشاء رقم الطلب التسلسلي.');
    }
    return orderId;
  }

  Future<Map<String, dynamic>> normalizeLoyaltyHistory({
    required String uid,
  }) async {
    return _post(
      '/v1/admin/normalize-loyalty-history',
      {
        'uid': uid,
      },
    );
  }

  Future<Map<String, dynamic>> repairLoyaltyBalance({
    required String uid,
  }) async {
    return _post(
      '/v1/admin/repair-loyalty-balance',
      {
        'uid': uid,
      },
    );
  }

  Future<Map<String, dynamic>> auditLoyaltyBalance({
    String? uid,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('سجّل الدخول أولًا.');
    }

    final token = await user.getIdToken();

    if (token == null || token.isEmpty) {
      throw StateError(
        'انتهت جلسة الدخول. سجّل الدخول مجددًا.',
      );
    }

    final uri = Uri.parse(
      '$_apiBase/v1/admin/loyalty-audit',
    ).replace(
      queryParameters: {
        if (uid != null && uid.trim().isNotEmpty) 'uid': uid.trim(),
      },
    );

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=utf-8',
      },
    ).timeout(
      const Duration(seconds: 25),
    );

    Map<String, dynamic> data = const {};

    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(
        utf8.decode(response.bodyBytes),
      );

      if (decoded is Map) {
        data = Map<String, dynamic>.from(decoded);
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data['message']?.toString().trim();

      throw StateError(
        message == null || message.isEmpty
            ? 'تعذر فحص رصيد نقاط بركة.'
            : message,
      );
    }

    return data;
  }

  Future<void> resetBarakahPin({
    required String newPin,
  }) async {
    await _post(
      '/v1/barakah-card/reset-pin',
      {
        'newPin': newPin,
      },
    );
  }

  Future<void> changeBarakahPin({
    required String currentPin,
    required String newPin,
  }) async {
    await _post(
      '/v1/barakah-card/change-pin',
      {
        'currentPin': currentPin,
        'newPin': newPin,
      },
    );
  }

  Future<void> cancelOrder(String orderId) async {
    await _post(
      '/v1/orders/$orderId/cancel',
      const <String, dynamic>{},
    );
  }

  Future<void> updateStatus(String orderId, String status) async {
    print('🔵 UPDATE STATUS START: $orderId => $status');

    try {
      final result = await _post(
        '/v1/orders/$orderId/status',
        {'status': status},
      );

      print('🟢 UPDATE STATUS SUCCESS: $result');
    } catch (e) {
      print('🔴 UPDATE STATUS ERROR: $e');
      rethrow;
    }
  }
}
