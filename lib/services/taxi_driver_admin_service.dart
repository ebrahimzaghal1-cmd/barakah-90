import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class TaxiDriverAdminService {
  TaxiDriverAdminService._();

  static final TaxiDriverAdminService instance = TaxiDriverAdminService._();

  static const String _baseUrl =
      'https://barakah-secure-api.ebrahimzaghal1.workers.dev';

  Future<Map<String, dynamic>> assignDriver({
    required String driverUid,
    required String businessId,
  }) {
    return _send(
      driverUid: driverUid,
      businessId: businessId,
      action: 'assign',
    );
  }

  Future<Map<String, dynamic>> removeDriver({
    required String driverUid,
  }) {
    return _send(
      driverUid: driverUid,
      businessId: '',
      action: 'remove',
    );
  }

  Future<Map<String, dynamic>> _send({
    required String driverUid,
    required String businessId,
    required String action,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('يجب تسجيل الدخول أولًا.');
    }

    final token = await user.getIdToken(true);

    final response = await http.post(
      Uri.parse('$_baseUrl/v1/admin/taxi/drivers/assign'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'driverUid': driverUid,
        'businessId': businessId,
        'action': action,
      }),
    );

    Map<String, dynamic> body = <String, dynamic>{};

    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        }
      } catch (_) {
        // سيتم عرض رسالة آمنة أدناه إذا كانت الاستجابة غير متوقعة.
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = body['message']?.toString() ??
          body['error']?.toString() ??
          'تعذر تحديث ربط السائق بمكتب التكسي.';

      throw StateError(message);
    }

    return body;
  }
}
