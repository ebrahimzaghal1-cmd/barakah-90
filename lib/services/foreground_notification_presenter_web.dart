import 'package:web/web.dart' as web;

void showForegroundNotification({
  required String title,
  required String body,
  required String tag,
}) {
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
