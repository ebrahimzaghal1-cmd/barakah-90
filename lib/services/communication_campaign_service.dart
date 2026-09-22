import 'dart:convert';

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
  });

  final String campaignId;
  final bool complete;
  final int recipientCount;
  final int scannedCount;
  final int pushTargetCount;
  final int pageCount;

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
    );
  }
}

class CommunicationCampaignService {
  CommunicationCampaignService({
    FirebaseAuth? auth,
    http.Client? client,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _client = client;

  static const _base = 'https://barakah-secure-api.ebrahimzaghal1.workers.dev';

  final FirebaseAuth _auth;
  final http.Client? _client;

  Future<String> createCampaign({
    required String title,
    required String body,
    required String audience,
    required String type,
    String? imageUrl,
    String? videoUrl,
    String? mediaType,
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
    final result = await _post(
      '/v1/admin/communications/campaigns/process',
      {'campaignId': campaignId},
    );

    return CommunicationCampaignProgress.fromJson(result);
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
    final campaignId = await createCampaign(
      title: title,
      body: body,
      audience: audience,
      type: type,
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      mediaType: mediaType,
    );

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
      throw StateError('توقفت الحملة قبل إنهاء جميع الحسابات.');
    }

    return progress;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
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

    throw StateError(
      decoded?['message']?.toString() ??
          decoded?['error']?.toString() ??
          'تعذر تنفيذ العملية.',
    );
  }
}
