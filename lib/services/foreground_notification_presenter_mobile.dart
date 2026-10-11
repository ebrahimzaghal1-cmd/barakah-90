import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _notificationChannel = MethodChannel('com.barakah.market/notifications');

void startAdminOrderAlarm() {
  if (defaultTargetPlatform != TargetPlatform.iOS) return;
  _notificationChannel.invokeMethod<void>('startAdminOrderAlarm').catchError(
        (Object error) => debugPrint('تعذر تشغيل نغمة الطلب: $error'),
      );
}

void stopAdminOrderAlarm() {
  if (defaultTargetPlatform != TargetPlatform.iOS) return;
  _notificationChannel.invokeMethod<void>('stopAdminOrderAlarm').catchError(
        (Object error) => debugPrint('تعذر إيقاف نغمة الطلب: $error'),
      );
}

void showForegroundNotification({
  required String title,
  required String body,
  required String tag,
  bool urgent = false,
  bool coinSound = false,
}) {
  if (defaultTargetPlatform != TargetPlatform.android) return;

  _notificationChannel.invokeMethod<void>('show', {
    'title': title,
    'body': body,
    'tag': tag,
    'urgent': urgent,
    'coinSound': coinSound,
  }).catchError((Object error) {
    debugPrint('تعذر عرض إشعار بركة أثناء فتح التطبيق: $error');
  });
}
