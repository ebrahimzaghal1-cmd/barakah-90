import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Notification messages are displayed by iOS/Android while the app is in
  // the background. This entry point keeps future data messages supported.
}

class AdminNotificationService {
  AdminNotificationService._();

  static final instance = AdminNotificationService._();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;
  String? _userUid;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // iOS push registration is attempted whenever Firebase Messaging is
    // available. The signed iOS target must include the Push Notifications
    // capability and an aps-environment entitlement.

    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen(_handleUserChanged);
    _tokenSubscription =
        FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      final uid = _userUid;
      if (uid != null) _saveToken(uid, token);
    });
  }

  Future<void> _handleUserChanged(User? user) async {
    _userUid = null;
    if (user == null) return;

    try {
      _userUid = user.uid;
      final permission = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (permission.authorizationStatus == AuthorizationStatus.denied) return;

      // APNs can need a brief moment after permission is accepted before it
      // provides the FCM token on a physical iPhone.
      for (var attempt = 0; attempt < 4; attempt++) {
        try {
          const webVapidKey = String.fromEnvironment('BARAKAH_WEB_VAPID_KEY');
          final token = kIsWeb && webVapidKey.isNotEmpty
              ? await FirebaseMessaging.instance.getToken(
                  vapidKey: webVapidKey,
                )
              : await FirebaseMessaging.instance.getToken();
          if (token != null && token.isNotEmpty) {
            await _saveToken(user.uid, token);
            return;
          }
        } catch (_) {
          // Retry while APNs finishes registering this physical device.
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    } catch (error) {
      debugPrint('تعذر تفعيل إشعارات بركة: $error');
    }
  }

  Future<void> _saveToken(String uid, String token) =>
      FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<bool> requestPermissionForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      _userUid = user.uid;

      final permission = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        return false;
      }

      const webVapidKey = String.fromEnvironment('BARAKAH_WEB_VAPID_KEY');

      final token = kIsWeb && webVapidKey.isNotEmpty
          ? await FirebaseMessaging.instance.getToken(
              vapidKey: webVapidKey,
            )
          : await FirebaseMessaging.instance.getToken();

      if (token == null || token.isEmpty) {
        return false;
      }

      await _saveToken(user.uid, token);

      return true;
    } catch (error) {
      debugPrint(
        'تعذر تفعيل إشعارات بركة يدويًا: $error',
      );
      return false;
    }
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenSubscription?.cancel();
  }
}
