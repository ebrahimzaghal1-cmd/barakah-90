import 'package:flutter/foundation.dart';

class FirebaseState {
  static final ValueNotifier<bool> ready = ValueNotifier<bool>(false);

  static bool get isReady => ready.value;

  static set isReady(bool value) {
    if (ready.value == value) return;
    ready.value = value;
  }
}
