import 'dart:async';

/// Keeps the foreground alarm independent of APNs, using authorized live data.
class ForegroundOrderAlarmCoordinator {
  ForegroundOrderAlarmCoordinator({
    required this.accounts,
    required this.accessForAccount,
    required this.pendingOrders,
    required this.startAlarm,
    required this.stopAlarm,
    required this.onError,
    this.maxRingDuration = const Duration(seconds: 30),
  });

  final Stream<String?> accounts;
  final Stream<bool> Function(String uid) accessForAccount;
  final Stream<Set<String>> Function(String collection) pendingOrders;
  final void Function() startAlarm;
  final void Function() stopAlarm;
  final void Function(Object error) onError;
  final Duration maxRingDuration;
  StreamSubscription<String?>? _accountSubscription;
  StreamSubscription<bool>? _accessSubscription;
  final List<StreamSubscription<Set<String>>> _orderSubscriptions = [];
  final Map<String, Set<String>> _seen = {};
  final Map<String, Set<String>> _active = {};
  final Set<String> _baselines = {};
  Timer? _ringTimeout;
  bool _foreground = true;
  bool _authorized = false;
  bool _ringing = false;
  bool _disposed = false;
  int _accountGeneration = 0;
  int _orderGeneration = 0;

  void initialize() {
    if (_disposed || _accountSubscription != null) return;
    _accountSubscription =
        accounts.listen(_accountChanged, onError: (Object e) {
      _accountChanged(null);
      onError(e);
    });
  }

  void _accountChanged(String? uid) {
    final generation = ++_accountGeneration;
    final previous = _accessSubscription;
    if (previous != null) unawaited(previous.cancel());
    _accessSubscription = null;
    _authorized = false;
    _cancelOrders();
    _seen.clear();
    if (uid == null || _disposed) return;
    _accessSubscription = accessForAccount(uid).listen((allowed) {
      if (_disposed || generation != _accountGeneration) return;
      if (_authorized == allowed) return;
      _authorized = allowed;
      _cancelOrders();
      if (allowed && _foreground) _watchOrders();
    }, onError: (Object e) {
      if (_disposed || generation != _accountGeneration) return;
      _authorized = false;
      _cancelOrders();
      onError(e);
    });
  }

  void _watchOrders() {
    final generation = _orderGeneration;
    for (final collection in ['orders', 'taxi_orders']) {
      _orderSubscriptions.add(pendingOrders(collection).listen((ids) {
        if (_disposed || generation != _orderGeneration) return;
        final seen = _seen.putIfAbsent(collection, () => <String>{});
        // Initial/resumed snapshots contain backlog, not newly arriving orders.
        if (_baselines.add(collection)) {
          seen.addAll(ids);
          return;
        }
        final arriving = ids.difference(seen);
        seen.addAll(ids);
        final active = _active.putIfAbsent(collection, () => <String>{});
        active.removeWhere((id) => !ids.contains(id));
        active.addAll(arriving);
        _updateAlarm();
      }, onError: (Object e) {
        if (_disposed || generation != _orderGeneration) return;
        _active.remove(collection);
        _updateAlarm();
        onError(e);
      }));
    }
  }

  void _cancelOrders() {
    ++_orderGeneration;
    for (final subscription in _orderSubscriptions) {
      unawaited(subscription.cancel());
    }
    _orderSubscriptions.clear();
    _active.clear();
    _baselines.clear();
    _updateAlarm();
  }

  void _updateAlarm() {
    final shouldRing = !_disposed &&
        _foreground &&
        _authorized &&
        _active.values.any((ids) => ids.isNotEmpty);
    if (_ringing == shouldRing) return;
    _ringing = shouldRing;
    if (shouldRing) {
      startAlarm();
      _ringTimeout = Timer(maxRingDuration, () {
        // Expired orders remain seen, so metadata updates cannot rearm them.
        _active.clear();
        _updateAlarm();
      });
    } else {
      _ringTimeout?.cancel();
      _ringTimeout = null;
      stopAlarm();
    }
  }

  void setForeground(bool foreground) {
    if (_disposed || _foreground == foreground) return;
    _foreground = foreground;
    _cancelOrders();
    if (foreground && _authorized) _watchOrders();
  }

  Future<void> dispose() async {
    _disposed = true;
    ++_accountGeneration;
    _cancelOrders();
    await _accountSubscription?.cancel();
    await _accessSubscription?.cancel();
  }
}
