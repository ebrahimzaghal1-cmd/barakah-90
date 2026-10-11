import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'foreground_notification_presenter.dart';
import 'push_token_registration.dart';

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

const _androidNotificationPermissionAskedKey =
    'barakah_android_notification_permission_asked_v1';

class AdminNotificationService with WidgetsBindingObserver {
  AdminNotificationService._();

  static final instance = AdminNotificationService._();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  String? _userUid;
  String? _registeredToken;
  String? _permissionFailureMessage;
  final Set<String> _activeAdminAlarmOrderIds = <String>{};
  bool _initialized = false;
  Timer? _registrationRetry;
  bool _registering = false;
  Future<void> _tokenSaveQueue = Future<void>.value();
  final ValueNotifier<bool> notificationsEnabled = ValueNotifier(false);
  static const _iosPushAvailable =
      bool.fromEnvironment('BARAKAH_IOS_PUSH_AVAILABLE', defaultValue: true);
  bool get _unsupportedIos =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS &&
      !_iosPushAvailable;
  String get activationLabel => _unsupportedIos
      ? 'إشعارات الخلفية غير متاحة في النسخة التجريبية'
      : notificationsEnabled.value
          ? 'الإشعارات مفعّلة'
          : 'تفعيل الإشعارات';

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_handleUserChanged(FirebaseAuth.instance.currentUser));
    }
  }

  void _retryRegistration() {
    _registrationRetry?.cancel();
    if (_userUid == null || _unsupportedIos) return;
    _registrationRetry = Timer(const Duration(seconds: 30), () {
      unawaited(_handleUserChanged(FirebaseAuth.instance.currentUser));
    });
  }

  String get permissionFailureMessage =>
      _permissionFailureMessage ??
      'لم يتم تفعيل الإشعارات. تأكد من السماح بها من إعدادات المتصفح أو الجهاز.';

  Future<void> initialize() async {
    if (_initialized) return;

    // Messaging is not available in every browser/webview. Previously an
    // unsupported runtime could throw here after `_initialized` was set,
    // leaving the service permanently half-initialized and never listening
    // for auth/token changes.
    try {
      if (kIsWeb && !await FirebaseMessaging.instance.isSupported()) {
        _initialized = true;
        return;
      }

      // iOS push registration is attempted whenever Firebase Messaging is
      // available. The signed iOS target must include the Push Notifications
      // capability and an aps-environment entitlement.
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(
            firebaseMessagingBackgroundHandler);
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
        if (uid != null) {
          unawaited(_saveToken(uid, token).catchError((Object error) {
            debugPrint('تعذر تحديث توكن إشعارات بركة: $error');
            _retryRegistration();
          }));
        }
      });
      _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
        final type = message.data['type']?.toString() ?? '';
        final orderId = message.data['orderId']?.toString() ?? '';

        // iOS ringing follows the live order status even without APNs.
        final liveIosAlarm =
            !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
        if (!liveIosAlarm &&
            (type == 'new_order' || type == 'new_taxi_order') &&
            orderId.isNotEmpty) {
          _activeAdminAlarmOrderIds.add(orderId);
          startAdminOrderAlarm();
        }

        if (type == 'admin_order_alarm_stop' ||
            type == 'admin_taxi_alarm_stop') {
          if (orderId.isNotEmpty) {
            _activeAdminAlarmOrderIds.remove(orderId);
          }

          if (!liveIosAlarm && _activeAdminAlarmOrderIds.isEmpty) {
            stopAdminOrderAlarm();
          }

          return;
        }

        final notification = message.notification;
        final title = notification?.title ?? message.data['title']?.toString();
        final body = notification?.body ?? message.data['body']?.toString();

        if (title == null || title.isEmpty || body == null || body.isEmpty) {
          return;
        }

        showForegroundNotification(
          title: title,
          body: body,
          tag: orderId.isNotEmpty ? orderId : message.messageId ?? title,
          urgent: type == 'new_order' ||
              type == 'driver_order_available' ||
              type == 'new_taxi_order',
          coinSound: type == 'order_status' ||
              type == 'driver_order_available' ||
              type == 'taxi_order',
        );
      });
      WidgetsBinding.instance.addObserver(this);
      _initialized = true;
    } catch (error) {
      // Keep initialization retryable after a transient browser/APNs error.
      _initialized = false;
      debugPrint('تعذر تهيئة خدمة إشعارات بركة: $error');
    }
  }

  Future<void> _handleUserChanged(User? user) async {
    final changedUser = _userUid != user?.uid;
    if (changedUser) {
      _registrationRetry?.cancel();
      notificationsEnabled.value = false;
      _registeredToken = null;
    }
    _userUid = user?.uid;

    if (changedUser) {
      _activeAdminAlarmOrderIds.clear();
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
        stopAdminOrderAlarm();
      }
    }

    if (user == null || _unsupportedIos) return;
    if (_registering) {
      _retryRegistration();
      return;
    }
    _registering = true;
    try {
      _userUid = user.uid;
      // Chrome only accepts the permission prompt after an explicit user
      // gesture. On web we therefore register silently only when permission
      // was already granted; the profile button performs the actual request.
      // على Android وiOS نطلب الإذن تلقائيًا مرة واحدة فقط إذا لم يسبق
      // للنظام أن سأل المستخدم، ولا نكرر الطلب بعد الرفض الصريح.
      var permission =
          await FirebaseMessaging.instance.getNotificationSettings();

      final isAndroid =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

      if (isAndroid) {
        // On Android 13+, FlutterFire reports `denied` both before the first
        // permission prompt and after a real denial. Track our own first ask.
        final preferences = await SharedPreferences.getInstance();
        final askedBefore =
            preferences.getBool(_androidNotificationPermissionAskedKey) ??
                false;

        if (permission.authorizationStatus != AuthorizationStatus.authorized &&
            permission.authorizationStatus != AuthorizationStatus.provisional &&
            !askedBefore) {
          permission = await FirebaseMessaging.instance.requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          );

          await preferences.setBool(
            _androidNotificationPermissionAskedKey,
            true,
          );
        }
      } else if (!kIsWeb &&
          permission.authorizationStatus == AuthorizationStatus.notDetermined) {
        permission = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
      }

      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        notificationsEnabled.value = false;
        return;
      }
      if (permission.authorizationStatus != AuthorizationStatus.authorized &&
          permission.authorizationStatus != AuthorizationStatus.provisional) {
        notificationsEnabled.value = false;
        return;
      }

      // APNs can need a brief moment after permission is accepted before it
      // provides the FCM token on a physical iPhone.
      final maxAttempts =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS ? 15 : 4;
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        if (_userUid != user.uid) return;
        try {
          final token = await _getToken();
          if (token != null && token.isNotEmpty) {
            await _saveToken(user.uid, token);
            return;
          }
        } catch (error) {
          if (attempt == maxAttempts - 1) {
            debugPrint('تعذر تسجيل توكن الإشعارات بعد المحاولات: $error');
          }
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      _retryRegistration();
    } catch (error) {
      debugPrint('تعذر تفعيل إشعارات بركة: $error');
      _retryRegistration();
    } finally {
      _registering = false;
    }
  }

  Future<void> _saveToken(String uid, String token) {
    final operation = _tokenSaveQueue
        .catchError((Object _) {})
        .then((_) => _persistToken(uid, token));
    _tokenSaveQueue = operation;
    return operation;
  }

  Future<void> _persistToken(String uid, String token) async {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) return;

    if (_userUid != uid) return;
    final preferences = await SharedPreferences.getInstance();
    if (_userUid != uid) return;
    final previousToken =
        _registeredToken ?? preferences.getString('barakah_push_token_$uid');
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    // Preserve other devices and remove this device's previous token after rotation.
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final profile = await transaction.get(userRef);
      final existingTokens =
          (profile.data()?['fcmTokens'] as List<dynamic>? ?? const [])
              .whereType<String>();
      transaction.set(
          userRef,
          {
            'fcmTokens': tokensAfterRegistration(
              existingTokens,
              token: normalizedToken,
              previousToken: previousToken,
            ),
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });

    if (_userUid == uid) {
      _registeredToken = normalizedToken;
      notificationsEnabled.value = true;
      _registrationRetry?.cancel();
      await preferences.setString('barakah_push_token_$uid', normalizedToken);
    }
    debugPrint('Barakah: notification token registration succeeded');
    // Store verification evidence only after the Firestore transaction commits.
    // No token or account identifier is written to these diagnostics.
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'barakah_notification_token_registered_at_v110',
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (error) {
      debugPrint('تعذر حفظ حالة تسجيل الإشعارات: $error');
    }
  }

  Future<void> removeCurrentDeviceToken() async {
    await _tokenSaveQueue.catchError((Object _) {});
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? _userUid;
    if (uid == null || uid.isEmpty) return;

    String? token = _registeredToken;

    if (token == null || token.isEmpty) {
      try {
        token = await _getToken();
      } catch (_) {
        token = null;
      }
    }

    if (token != null && token.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayRemove([token]),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
      // Best effort. Firestore removal above is the important cleanup.
    }

    _registeredToken = null;
    notificationsEnabled.value = false;
    _registrationRetry?.cancel();
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('barakah_push_token_$uid');
  }

  Future<void> signOutCurrentUser() async {
    try {
      await removeCurrentDeviceToken();
    } catch (error) {
      debugPrint('تعذر تنظيف رمز الإشعارات قبل تسجيل الخروج: $error');
    }

    await FirebaseAuth.instance.signOut();
  }

  Future<bool> requestPermissionForCurrentUser() async {
    _permissionFailureMessage = null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _permissionFailureMessage = 'سجّل الدخول أولًا لتفعيل الإشعارات.';
      return false;
    }

    if (_unsupportedIos) {
      _permissionFailureMessage =
          'إشعارات الخلفية تحتاج نسخة موقّعة بحساب Apple Developer مدفوع. تكرار التفعيل لا يحل ذلك.';
      return false;
    }
    if (notificationsEnabled.value && _userUid == user.uid) return true;
    try {
      _userUid = user.uid;

      if (kIsWeb && !await FirebaseMessaging.instance.isSupported()) {
        _permissionFailureMessage =
            'هذا المتصفح لا يدعم إشعارات بركة. استخدم Google Chrome.';
        return false;
      }

      var permission =
          await FirebaseMessaging.instance.getNotificationSettings();
      if (permission.authorizationStatus != AuthorizationStatus.authorized &&
          permission.authorizationStatus != AuthorizationStatus.provisional) {
        permission = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
      }

      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        _permissionFailureMessage = kIsWeb
            ? 'الإشعارات محظورة للموقع. اجعلها «سماح» من إعدادات Chrome ثم أعد تحميل الصفحة.'
            : 'الإشعارات مرفوضة. فعّلها لتطبيق بركة من إعدادات الجهاز.';
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
        _retryRegistration();
        _permissionFailureMessage = !kIsWeb
            ? 'لم يكتمل تسجيل الجهاز بعد. سيعيد التطبيق المحاولة تلقائيًا.'
            : errorText.contains('service worker')
                ? 'تعذر تشغيل خدمة الإشعارات في الخلفية. أعد تحميل الصفحة ثم حاول مرة أخرى.'
                : 'تعذر تسجيل هذا المتصفح لدى Firebase. أعد تحميل الصفحة وحاول مرة أخرى.';
        return false;
      }

      await _saveToken(user.uid, token);

      return true;
    } catch (error) {
      final errorText = error.toString().toLowerCase();
      final permissionProblem = errorText.contains('permission') ||
          errorText.contains('denied') ||
          errorText.contains('blocked');
      _permissionFailureMessage = kIsWeb
          ? (permissionProblem
              ? 'الإشعارات محظورة للموقع. اجعلها «سماح» من إعدادات Chrome ثم أعد تحميل الصفحة.'
              : 'تعذر تسجيل إشعارات Chrome. أعد تحميل الصفحة ثم حاول مرة أخرى.')
          : (permissionProblem
              ? 'الإشعارات مرفوضة. فعّلها لتطبيق بركة من إعدادات الجهاز.'
              : 'تعذر تسجيل إشعارات الآيفون. حاول مرة أخرى من زر الإشعارات.');
      _retryRegistration();
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
    WidgetsBinding.instance.removeObserver(this);
    _registrationRetry?.cancel();
    await _authSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
  }
}
