import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class PlayTaskRewardSession {
  const PlayTaskRewardSession({
    required this.sessionId,
    required this.startedAt,
    required this.expiresAt,
  });

  final String sessionId;
  final DateTime startedAt;
  final DateTime expiresAt;
}

class PlayRewardClaimResult {
  const PlayRewardClaimResult({
    required this.newlyAwarded,
    this.loyaltyPoints,
  });

  final bool newlyAwarded;
  final int? loyaltyPoints;
}

class PlayRewardsService {
  PlayRewardsService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  static const taskPoints = 2;
  static const tasksPerOrder = 3;
  static const totalPointsPerOrder = taskPoints * tasksPerOrder;

  static const _apiBase =
      'https://barakah-secure-api.ebrahimzaghal1.workers.dev';

  final FirebaseAuth _auth;

  Future<PlayTaskRewardSession> startTask({
    required String orderId,
    required String taskId,
  }) async {
    final data = await _post(
      '/v1/orders/${Uri.encodeComponent(orderId)}'
      '/play-sessions/${Uri.encodeComponent(taskId)}',
      const <String, dynamic>{'rulesVersion': 5},
    );
    final sessionId = data['sessionId']?.toString() ?? '';
    final startedAt = DateTime.tryParse(data['startedAt']?.toString() ?? '');
    final expiresAt = DateTime.tryParse(data['expiresAt']?.toString() ?? '');
    if (sessionId.isEmpty || startedAt == null || expiresAt == null) {
      throw StateError('تعذر تثبيت عداد المهمة. حاول مجددًا.');
    }
    return PlayTaskRewardSession(
      sessionId: sessionId,
      startedAt: startedAt.toLocal(),
      expiresAt: expiresAt.toLocal(),
    );
  }

  Future<PlayRewardClaimResult> claimTask({
    required String orderId,
    required String taskId,
    required PlayTaskRewardSession session,
  }) async {
    final data = await _post(
      '/v1/orders/${Uri.encodeComponent(orderId)}'
      '/play-rewards/${Uri.encodeComponent(taskId)}',
      <String, dynamic>{
        'rulesVersion': 5,
        'sessionId': session.sessionId,
        'successfulUnits': 5,
      },
    );
    return PlayRewardClaimResult(
      newlyAwarded: data['alreadyClaimed'] != true,
      loyaltyPoints: (data['loyaltyPoints'] as num?)?.toInt(),
    );
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('سجّل الدخول قبل جمع النقاط.');
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
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 25));
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(response.bodyBytes));
    final data = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(data['message']?.toString() ?? 'تعذر تسجيل النقاط.');
    }
    return data;
  }
}
