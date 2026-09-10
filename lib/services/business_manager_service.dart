import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class BusinessManagerService {
  static const _endpoint =
      'https://barakah-secure-api.ebrahimzaghal1.workers.dev/v1/merchant/managers';

  Future<void> updateManager({
    required String businessId,
    required String email,
    required bool add,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('سجّل الدخول أولًا.');
    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw StateError('تعذر التحقق من جلسة الحساب.');
    }

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'businessId': businessId,
        'email': email.trim().toLowerCase(),
        'action': add ? 'add' : 'remove',
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'تعذر تحديث مديري المحل.';
      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is Map && body['message'] != null) {
          message = body['message'].toString();
        }
      } catch (_) {}
      throw StateError(message);
    }
  }
}
