import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

import '../services/taxi_order_service.dart';
import '../theme/app_theme.dart';

/// Foreground-only GPS controls for one assigned taxi trip.
///
/// The server remains authoritative for assignment, lifecycle and timestamps.
/// This widget only owns the device subscription and the safe start/stop UI.
class TaxiDriverTracking extends StatefulWidget {
  const TaxiDriverTracking({
    super.key,
    required this.orderId,
    required this.driverUid,
    required this.assignedDriverUid,
    required this.status,
    required this.tripStarted,
    required this.allowed,
  });

  final String orderId;
  final String driverUid;
  final String assignedDriverUid;
  final String status;
  final bool tripStarted;
  final bool allowed;

  @override
  State<TaxiDriverTracking> createState() => _TaxiDriverTrackingState();
}

class _TaxiDriverTrackingState extends State<TaxiDriverTracking> {
  static const _sendInterval = Duration(seconds: 8);

  final _service = TaxiOrderService.instance;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _sendTimer;
  Position? _latestPosition;
  DateTime? _lastSentAt;
  int _generation = 0;
  bool _active = false;
  bool _busy = false;
  bool _sending = false;
  String? _error;

  bool get _assignmentIsValid =>
      widget.allowed &&
      widget.driverUid.isNotEmpty &&
      widget.driverUid == widget.assignedDriverUid &&
      widget.status == 'dispatched';

  @override
  void didUpdateWidget(covariant TaxiDriverTracking oldWidget) {
    super.didUpdateWidget(oldWidget);

    final lifecycleChanged = oldWidget.status != widget.status ||
        oldWidget.orderId != widget.orderId ||
        oldWidget.driverUid != widget.driverUid ||
        oldWidget.assignedDriverUid != widget.assignedDriverUid ||
        oldWidget.allowed != widget.allowed;

    if (lifecycleChanged && !_assignmentIsValid) {
      unawaited(_stopTracking());
    }
  }

  @override
  void dispose() {
    _generation++;
    _sendTimer?.cancel();
    unawaited(_positionSubscription?.cancel());
    super.dispose();
  }

  Future<void> _startTracking() async {
    if (_busy || _active || !_assignmentIsValid) return;

    final generation = ++_generation;
    _latestPosition = null;
    _lastSentAt = null;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final permissionReady = await _ensureLocationPermission();
      if (!_isCurrent(generation) || !permissionReady) return;

      final firstPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!_isCurrent(generation)) return;

      // The first location is sent only after the server records tripStartedAt.
      await _service.startTrip(orderId: widget.orderId);
      if (!_isCurrent(generation)) return;

      _latestPosition = firstPosition;
      await _sendPosition(firstPosition, generation);
      if (!_isCurrent(generation)) return;

      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      );
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen(
        (position) => _latestPosition = position,
        onError: (Object error, StackTrace stack) {
          if (_isCurrent(generation)) {
            _showError('توقف بث موقع السائق: $error');
            unawaited(_stopTracking());
          }
        },
        cancelOnError: true,
      );
      _sendTimer = Timer.periodic(_sendInterval, (_) {
        final position = _latestPosition;
        if (position != null && _isCurrent(generation)) {
          unawaited(_sendPosition(position, generation));
        }
      });

      if (_isCurrent(generation)) {
        setState(() {
          _active = true;
          _busy = false;
        });
      }
    } catch (error) {
      if (_isCurrent(generation)) {
        await _stopTracking(showError: 'تعذر بدء تتبع الرحلة: $error');
      }
    } finally {
      if (_isCurrent(generation) && _busy) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _sendPosition(Position position, int generation) async {
    if (!_isCurrent(generation) || _sending) return;

    final now = DateTime.now();
    if (_lastSentAt != null && now.difference(_lastSentAt!) < _sendInterval) {
      return;
    }

    _sending = true;
    try {
      await _service.updateDriverLocation(
        orderId: widget.orderId,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (_isCurrent(generation)) _lastSentAt = DateTime.now();
    } catch (error) {
      if (_isCurrent(generation)) {
        await _stopTracking(showError: 'توقف إرسال موقع السائق: $error');
      }
    } finally {
      _sending = false;
    }
  }

  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _showError('فعّل خدمة الموقع في الهاتف ثم أعد المحاولة.');
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      _showError(
          'صلاحية الموقع مرفوضة نهائيًا. افتح إعدادات التطبيق للسماح بها.');
      await Geolocator.openAppSettings();
      return false;
    }

    if (permission == LocationPermission.denied) {
      _showError('يلزم السماح بالموقع لبدء الرحلة.');
      return false;
    }

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<void> _stopTracking({String? showError}) async {
    _generation++;
    _sendTimer?.cancel();
    _sendTimer = null;
    final subscription = _positionSubscription;
    _positionSubscription = null;
    await subscription?.cancel();

    if (!mounted) return;
    setState(() {
      _active = false;
      _busy = false;
      _sending = false;
      if (showError != null) _error = showError;
    });
  }

  bool _isCurrent(int generation) =>
      mounted && generation == _generation && _assignmentIsValid;

  void _showError(String message) {
    if (mounted) setState(() => _error = message);
  }

  @override
  Widget build(BuildContext context) {
    if (!_assignmentIsValid) {
      return const SizedBox.shrink();
    }

    final canStart = !_active && !_busy;
    final label = _active
        ? 'إيقاف التتبع'
        : widget.tripStarted
            ? 'استئناف تتبع الموقع'
            : 'بدء الرحلة وإرسال الموقع';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.navy.withOpacity(.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.deepYellow.withOpacity(.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _active
                ? 'تتبع الموقع يعمل في مقدمة التطبيق فقط.'
                : 'ابدأ الرحلة لإرسال موقع السيارة للعميل.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy
                ? null
                : _active
                    ? _stopTracking
                    : canStart
                        ? _startTracking
                        : null,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_active ? Icons.stop_circle_outlined : Icons.gps_fixed),
            label: Text(_busy ? 'جارٍ التحقق من الموقع...' : label),
          ),
        ],
      ),
    );
  }
}
