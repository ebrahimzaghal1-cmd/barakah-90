import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'foreground_notification_presenter.dart';

const _webVapidKey = String.fromEnvironment(
  'BARAKAH_WEB_VAPID_KEY',
  defaultValue:
      'BJdTGI3DUEio70JOpJNDqSESGrhz-qJklhzIMXf90WabSSKa3fc1D9mAWOPnb7H6F-sX_HYnyXU9Lr-lqY8mz40',
);

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
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  String? _userUid;
  String? _permissionFailureMessage;
  bool _initialized = false;

  String get permissionFailureMessage =>
      _permissionFailureMessage ??
      'لم يتم تفعيل الإشعارات. تأكد من السماح بها من إعدادات المتصفح أو الجهاز.';

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
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      if (!kIsWeb) return;

      final notification = message.notification;
      final title = notification?.title ?? message.data['title']?.toString();
      final body = notification?.body ?? message.data['body']?.toString();
      if (title == null || title.isEmpty || body == null || body.isEmpty) {
        return;
      }

      showForegroundNotification(
        title: title,
        body: body,
        tag: message.data['orderId']?.toString() ?? message.messageId ?? title,
      );
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
          final token = await _getToken();
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
    _permissionFailureMessage = null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _permissionFailureMessage = 'سجّل الدخول أولًا لتفعيل الإشعارات.';
      return false;
    }

    try {
      _userUid = user.uid;

      if (kIsWeb && !await FirebaseMessaging.instance.isSupported()) {
        _permissionFailureMessage =
            'هذا المتصفح لا يدعم إشعارات بركة. استخدم Google Chrome.';
        return false;
      }

      final permission = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        _permissionFailureMessage =
            'الإشعارات محظورة للموقع. اجعلها «سماح» من إعدادات Chrome ثم أعد تحميل الصفحة.';
        return false;
      }

      String? token;
      Object? lastError;
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          token = await _getToken();
          if (token != null && token.isNotEmpty) break;
        } catch (error) {
          lastError = error;
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      }

      if (token == null || token.isEmpty) {
        final errorText = lastError?.toString().toLowerCase() ?? '';
        _permissionFailureMessage = errorText.contains('service worker')
            ? 'تعذر تشغيل خدمة الإشعارات في الخلفية. أعد تحميل الصفحة ثم حاول مرة أخرى.'
            : 'تعذر تسجيل هذا المتصفح لدى Firebase. أعد تحميل الصفحة وحاول مرة أخرى.';
        return false;
      }

      await _saveToken(user.uid, token);

      return true;
    } catch (error) {
      final errorText = error.toString().toLowerCase();
      _permissionFailureMessage = errorText.contains('permission') ||
              errorText.contains('denied') ||
              errorText.contains('blocked')
          ? 'الإشعارات محظورة للموقع. اجعلها «سماح» من إعدادات Chrome ثم أعد تحميل الصفحة.'
          : 'تعذر تسجيل إشعارات Chrome. أعد تحميل الصفحة ثم حاول مرة أخرى.';
      debugPrint(
        'تعذر تفعيل إشعارات بركة يدويًا: $error',
      );
      return false;
    }
  }

  Future<String?> _getToken() => kIsWeb
      ? FirebaseMessaging.instance.getToken(
          vapidKey: _webVapidKey,
          serviceWorkerScriptPath: '/firebase-messaging-sw.js',
        )
      : FirebaseMessaging.instance.getToken();

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
  }
}
