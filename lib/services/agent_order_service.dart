import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AgentOrderService {
  static const _baseUrl =
      'https://barakah-secure-api.ebrahimzaghal1.workers.dev';

  Future<void> updateStatus({
    required String orderId,
    required String status,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }

    if (status != 'accepted' && status != 'rejected') {
      throw StateError('حالة طلب الوسيطة غير صالحة.');
    }

    final token = await user.getIdToken(true);
    final action = status == 'accepted' ? 'accept' : 'reject';

    final response = await http.post(
      Uri.parse('$_baseUrl/v1/agent-orders/$orderId/$action'),
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'authorization': 'Bearer $token',
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    String message = 'تعذر تحديث طلب الوسيطة.';

    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));

      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      }
    } catch (_) {}

    throw StateError(message);
  }
}

extension AgentOrderDeliveryActions on AgentOrderService {
  Future<String> getDeliveryCode({
    required String orderId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }

    final token = await user.getIdToken(true);

    final response = await http.get(
      Uri.parse(
        '${AgentOrderService._baseUrl}/v1/agent-orders/$orderId/delivery-code',
      ),
      headers: {
        'authorization': 'Bearer $token',
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(utf8.decode(response.bodyBytes));

      if (body is Map && body['code'] != null) {
        return body['code'].toString();
      }

      throw StateError('تعذر قراءة رمز التسليم.');
    }

    String message = 'تعذر جلب رمز التسليم.';

    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));

      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      }
    } catch (_) {}

    throw StateError(message);
  }

  Future<void> completeDelivery({
    required String orderId,
    required String code,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }

    if (!RegExp(r'^[0-9]{6}$').hasMatch(code.trim())) {
      throw StateError(
        'رمز التسليم يجب أن يتكون من 6 أرقام.',
      );
    }

    final token = await user.getIdToken(true);

    final response = await http.post(
      Uri.parse(
        '${AgentOrderService._baseUrl}/v1/agent-orders/$orderId/complete',
      ),
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'code': code.trim(),
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    String message = 'تعذر تأكيد التسليم.';

    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));

      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      }
    } catch (_) {}

    throw StateError(message);
  }
}

extension AgentOrderFinanceActions on AgentOrderService {
  Future<void> createDispute({
    required String orderId,
    required String reason,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }

    final cleanReason = reason.trim();

    if (cleanReason.length < 5) {
      throw StateError('اكتب سبب الاعتراض بوضوح.');
    }

    final token = await user.getIdToken(true);

    final response = await http.post(
      Uri.parse(
        '${AgentOrderService._baseUrl}/v1/agent-orders/$orderId/dispute',
      ),
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'reason': cleanReason,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw StateError(
      _agentFinanceError(
        response,
        'تعذر تسجيل الاعتراض.',
      ),
    );
  }

  Future<void> resolveDispute({
    required String orderId,
    required String decision,
    String adminNote = '',
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }

    if (decision != 'release' && decision != 'cancel') {
      throw StateError('قرار الاعتراض غير صالح.');
    }

    final token = await user.getIdToken(true);

    final response = await http.post(
      Uri.parse(
        '${AgentOrderService._baseUrl}/v1/agent-orders/$orderId/resolve-dispute',
      ),
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'decision': decision,
        'adminNote': adminNote.trim(),
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw StateError(
      _agentFinanceError(
        response,
        'تعذر معالجة الاعتراض.',
      ),
    );
  }

  Future<void> settleEarning({
    required String orderId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('يجب تسجيل الدخول أولاً.');
    }

    final token = await user.getIdToken(true);

    final response = await http.post(
      Uri.parse(
        '${AgentOrderService._baseUrl}/v1/agent-orders/$orderId/settle',
      ),
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'authorization': 'Bearer $token',
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw StateError(
      _agentFinanceError(
        response,
        'تعذر تسجيل دفع المستحق.',
      ),
    );
  }
}

String _agentFinanceError(
  http.Response response,
  String fallback,
) {
  try {
    final body = jsonDecode(
      utf8.decode(response.bodyBytes),
    );

    if (body is Map && body['message'] != null) {
      return body['message'].toString();
    }
  } catch (_) {}

  return fallback;
}
