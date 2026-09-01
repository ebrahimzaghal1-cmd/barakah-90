import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AdminSubmissionNotificationService {
  static const _endpoint =
      'https://barakah-secure-api.ebrahimzaghal1.workers.dev/v1/admin/new-request';

  static Future<bool> notify({
    required String type,
    required String documentId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      if (token == null || token.isEmpty) return false;

      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode({
              'type': type,
              'documentId': documentId,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      debugPrint(
        'تعذر إرسال إشعار الطلب الإداري: ${response.statusCode}',
      );
    } catch (error) {
      debugPrint('تعذر إرسال إشعار الطلب الإداري: $error');
    }
    return false;
  }
}
