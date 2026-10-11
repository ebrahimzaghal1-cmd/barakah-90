import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'chat_media_service.dart';

class CommunicationCampaignProgress {
  const CommunicationCampaignProgress({
    required this.campaignId,
    required this.complete,
    required this.recipientCount,
    required this.scannedCount,
    required this.pushTargetCount,
    required this.pageCount,
    this.pushSuccessCount = 0,
    this.pushFailureCount = 0,
    this.pushUnknownCount = 0,
  });

  final String campaignId;
  final bool complete;
  final int recipientCount;
  final int scannedCount;
  final int pushTargetCount;
  final int pageCount;
  final int pushSuccessCount;
  final int pushFailureCount;
  final int pushUnknownCount;

  factory CommunicationCampaignProgress.fromJson(
    Map<String, dynamic> json,
  ) {
    return CommunicationCampaignProgress(
      campaignId: json['campaignId']?.toString() ?? '',
      complete: json['complete'] == true,
      recipientCount: (json['recipientCount'] as num?)?.toInt() ?? 0,
      scannedCount: (json['scannedCount'] as num?)?.toInt() ?? 0,
      pushTargetCount: (json['pushTargetCount'] as num?)?.toInt() ?? 0,
      pageCount: (json['pageCount'] as num?)?.toInt() ?? 0,
      pushSuccessCount: (json['pushSuccessCount'] as num?)?.toInt() ?? 0,
      pushFailureCount: (json['pushFailureCount'] as num?)?.toInt() ?? 0,
      pushUnknownCount: (json['pushUnknownCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class CommunicationCampaignService {
  CommunicationCampaignService({
    FirebaseAuth? auth,
    http.Client? client,
    Future<void> Function(Duration)? delay,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _client = client,
        _delay = delay ?? Future<void>.delayed;

  static const _base = 'https://barakah-secure-api.ebrahimzaghal1.workers.dev';

  final FirebaseAuth _auth;
  final http.Client? _client;
  final Future<void> Function(Duration) _delay;
  String? _pendingPayload;
  String? _pendingCreationKey;
  String? _pendingCampaignId;

  Future<String> createCampaign({
    required String title,
    required String body,
    required String audience,
    required String type,
    String? imageUrl,
    String? videoUrl,
    String? mediaType,
    String? idempotencyKey,
  }) async {
    final media = chatMediaFields(
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      mediaType: mediaType,
    );
    if (title.trim().isEmpty || (body.trim().isEmpty && media.isEmpty)) {
      throw StateError('اكتب عنوان الحملة وأضف نصًا أو صورة أو فيديو.');
    }
    final result = await _post(
      '/v1/admin/communications/campaigns',
      {
        'title': title.trim(),
        'body': body.trim(),
        'audience': audience,
        'type': type,
        ...media,
      },
      idempotencyKey: idempotencyKey,
    );

    final campaignId = result['campaignId']?.toString() ?? '';

    if (campaignId.isEmpty) {
      throw StateError('لم يتم إنشاء الحملة.');
    }

    return campaignId;
  }

  Future<CommunicationCampaignProgress> processCampaign(
    String campaignId,
  ) async {
    for (var attempt = 0;; attempt++) {
      try {
        final result = await _post(
          '/v1/admin/communications/campaigns/process',
          {'campaignId': campaignId},
        );
        return CommunicationCampaignProgress.fromJson(result);
      } on _CampaignRequestError catch (error) {
        if (error.statusCode != 409 || attempt >= 3) rethrow;
        await _delay(Duration(seconds: 2 << attempt));
      }
    }
  }

  Future<CommunicationCampaignProgress> createAndSend({
    required String title,
    required String body,
    required String audience,
    required String type,
    String? imageUrl,
    String? videoUrl,
    String? mediaType,
    void Function(CommunicationCampaignProgress progress)? onProgress,
  }) async {
    final payload = jsonEncode({
      'title': title.trim(),
      'body': body.trim(),
      'audience': audience,
      'type': type,
      ...chatMediaFields(
        imageUrl: imageUrl,
        videoUrl: videoUrl,
        mediaType: mediaType,
      ),
    });
    if (_pendingPayload != payload) {
      final random = Random.secure();
      _pendingPayload = payload;
      _pendingCreationKey = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      _pendingCampaignId = null;
    }
    // Keep both the creation key and the returned ID after an interrupted send.
    // Retrying the same draft must resume its campaign instead of creating one.
    final campaignId = _pendingCampaignId ??= await createCampaign(
      title: title,
      body: body,
      audience: audience,
      type: type,
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      mediaType: mediaType,
      idempotencyKey: _pendingCreationKey,
    );
    return sendExisting(campaignId, onProgress: onProgress);
  }

  Future<CommunicationCampaignProgress> sendExisting(
    String campaignId, {
    void Function(CommunicationCampaignProgress progress)? onProgress,
  }) async {
    var progress = CommunicationCampaignProgress(
      campaignId: campaignId,
      complete: false,
      recipientCount: 0,
      scannedCount: 0,
      pushTargetCount: 0,
      pageCount: 0,
    );

    for (var batch = 0; batch < 500 && !progress.complete; batch++) {
      progress = await processCampaign(campaignId);
      onProgress?.call(progress);
    }

    if (!progress.complete) {
      throw StateError('لم تكتمل الحملة بعد. استأنفها من سجل الحملات.');
    }
    if (_pendingCampaignId == campaignId) {
      _pendingCampaignId = null;
      _pendingCreationKey = null;
      _pendingPayload = null;
    }

    return progress;
  }

  Future<Map<String, dynamic>> checkAdminFcmTokens({
    int offset = 0,
    bool apply = false,
  }) {
    return _post(
      '/v1/admin/communications/fcm-cleanup',
      {
        'offset': offset,
        'apply': apply,
      },
    );
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    String? idempotencyKey,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('سجّل الدخول أولًا.');
    }

    final token = await user.getIdToken();

    if (token == null || token.isEmpty) {
      throw StateError('انتهت جلسة الدخول. سجّل الدخول مجددًا.');
    }

    final post = _client?.post ?? http.post;
    final response = await post(
      Uri.parse('$_base$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=utf-8',
        if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));

    Map<String, dynamic>? decoded;

    try {
      final value = jsonDecode(utf8.decode(response.bodyBytes));

      if (value is Map<String, dynamic>) {
        decoded = value;
      } else if (value is Map) {
        decoded = Map<String, dynamic>.from(value);
      }
    } catch (_) {}

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        decoded != null) {
      return decoded;
    }

    throw _CampaignRequestError(
      response.statusCode,
      decoded?['message']?.toString() ??
          decoded?['error']?.toString() ??
          'تعذر تنفيذ العملية.',
    );
  }
}

class _CampaignRequestError extends StateError {
  _CampaignRequestError(this.statusCode, super.message);

  final int statusCode;
}
