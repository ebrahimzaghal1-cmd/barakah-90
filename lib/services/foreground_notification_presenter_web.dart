import 'dart:js_interop';

import 'package:web/web.dart' as web;

@JS('barakahPlayCoin')
external void _barakahPlayCoin();

@JS('barakahStartAdminOrderAlarm')
external void _barakahStartAdminOrderAlarm();

@JS('barakahStopAdminOrderAlarm')
external void _barakahStopAdminOrderAlarm();

void startAdminOrderAlarm() {
  try {
    _barakahStartAdminOrderAlarm();
  } catch (_) {}
}

void stopAdminOrderAlarm() {
  try {
    _barakahStopAdminOrderAlarm();
  } catch (_) {}
}

void showForegroundNotification({
  required String title,
  required String body,
  required String tag,
  bool urgent = false,
  bool coinSound = false,
}) {
  if (coinSound) {
    try {
      _barakahPlayCoin();
    } catch (_) {}
  }

  if (web.Notification.permission != 'granted') return;

  web.Notification(
    title,
    web.NotificationOptions(
      body: body,
      tag: tag,
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      dir: 'rtl',
      lang: 'ar',
    ),
  );
}
