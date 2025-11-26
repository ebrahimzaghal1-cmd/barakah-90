// File generated manually from your GoogleService-Info.plist
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return ios;
      case TargetPlatform.android:
        throw UnsupportedError(
          'Android config not provided yet. Run flutterfire configure.',
        );
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'Platform not supported or config not provided.',
        );
      default:
        return web;
    }
  }

  // 🌐 Web
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAKc4qF4Yc_j5qZilJ7KTawg2QgrX_EIik',
    appId: '1:584371966532:web:9a7dbefa687c7afa252211', 
    messagingSenderId: '584371966532',
    projectId: 'ebrahimzaghal1-f0347',
    storageBucket: 'ebrahimzaghal1-f0347.firebasestorage.app',
  );

  // 🍎 iOS
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAKc4qF4Yc_j5qZilJ7KTawg2QgrX_EIik',
    appId: '1:584371966532:ios:fd57a412e2c8ab28252211',
    messagingSenderId: '584371966532',
    projectId: 'ebrahimzaghal1-f0347',
    storageBucket: 'ebrahimzaghal1-f0347.firebasestorage.app',
    iosBundleId: 'barakah-90',
  );

  // 🍏 macOS — نفس بيانات iOS
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAKc4qF4Yc_j5qZilJ7KTawg2QgrX_EIik',
    appId: '1:584371966532:ios:fd57a412e2c8ab28252211',
    messagingSenderId: '584371966532',
    projectId: 'ebrahimzaghal1-f0347',
    storageBucket: 'ebrahimzaghal1-f0347.firebasestorage.app',
    iosBundleId: 'barakah-90',
  );
}
