export 'foreground_notification_presenter_stub.dart'
    if (dart.library.io) 'foreground_notification_presenter_mobile.dart'
    if (dart.library.js_interop) 'foreground_notification_presenter_web.dart';
