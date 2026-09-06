import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _notificationChannel = MethodChannel('com.barakah.market/notifications');

void showForegroundNotification({
  required String title,
  required String body,
  required String tag,
}) {
  if (defaultTargetPlatform != TargetPlatform.android) return;

  _notificationChannel.invokeMethod<void>('show', {
    'title': title,
    'body': body,
    'tag': tag,
  }).catchError((Object error) {
    debugPrint('تعذر عرض إشعار بركة أثناء فتح التطبيق: $error');
  });
}
