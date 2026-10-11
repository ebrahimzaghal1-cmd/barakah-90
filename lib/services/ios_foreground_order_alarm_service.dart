import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'foreground_notification_presenter.dart';
import 'foreground_order_alarm_coordinator.dart';
import 'user_profile_service.dart';

class IosForegroundOrderAlarmService with WidgetsBindingObserver {
  IosForegroundOrderAlarmService._();
  static final instance = IosForegroundOrderAlarmService._();
  ForegroundOrderAlarmCoordinator? _coordinator;

  void initialize() {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS ||
        _coordinator != null) {
      return;
    }
    final firestore = FirebaseFirestore.instance;
    final coordinator = ForegroundOrderAlarmCoordinator(
      accounts:
          FirebaseAuth.instance.authStateChanges().map((user) => user?.uid),
      accessForAccount: (uid) {
        // The existing rules grant global order reads to this owner account.
        // Never subscribe a customer or a supervisor to all customers' orders.
        if (uid != UserProfileService.primaryAdminUid) {
          return Stream.value(false);
        }
        return firestore
            .collection('users')
            .doc(uid)
            .snapshots(includeMetadataChanges: true)
            .where((snapshot) => !snapshot.metadata.isFromCache)
            .map((snapshot) => snapshot.data()?['role'] == 'admin');
      },
      pendingOrders: (collection) {
        final query = collection == 'orders'
            ? firestore
                .collection(collection)
                .where('status', whereIn: ['new', 'scheduled'])
            : firestore
                .collection(collection)
                .where('status', isEqualTo: 'pending');
        return query
            .snapshots(includeMetadataChanges: true)
            .where((snapshot) => !snapshot.metadata.isFromCache)
            .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
      },
      startAlarm: startAdminOrderAlarm,
      stopAlarm: stopAdminOrderAlarm,
      onError: (error) => debugPrint('تعذر متابعة نغمة طلبات الأدمن: $error'),
    );
    _coordinator = coordinator;
    coordinator.setForeground(WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);
    WidgetsBinding.instance.addObserver(this);
    coordinator.initialize();
    debugPrint('Barakah: foreground order alarm listener initialized');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _coordinator?.setForeground(state == AppLifecycleState.resumed);
  }
}
