import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random.secure();

  String? _sessionId;
  bool _appVisitRecorded = false;

  String get _currentSessionId {
    return _sessionId ??= _generateSessionId();
  }

  String _generateSessionId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final randomPart = List.generate(
      4,
      (_) => _random.nextInt(1 << 31).toRadixString(16),
    ).join();

    return '$now-$randomPart';
  }

  Future<void> recordAppVisit() async {
    if (_appVisitRecorded) return;

    _appVisitRecorded = true;

    try {
      await _firestore.collection('analytics_events').add({
        'eventType': 'app_visit',
        'sessionId': _currentSessionId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      _appVisitRecorded = false;
    }
  }

  Future<void> recordCategoryView(String category) async {
    final value = category.trim();

    if (value.isEmpty) return;

    try {
      await _firestore.collection('analytics_events').add({
        'eventType': 'category_view',
        'category': value,
        'sessionId': _currentSessionId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // الإحصائيات لا يجب أن تمنع المستخدم من تصفح التطبيق.
    }
  }
}
