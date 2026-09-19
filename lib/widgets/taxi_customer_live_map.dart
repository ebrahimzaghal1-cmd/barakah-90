import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';

/// Read-only live map for the customer side of an active taxi order.
///
/// The customer never writes location data. The Worker writes the coordinates
/// and server timestamp, while this widget only renders a recent, valid point.
class TaxiCustomerLiveMap extends StatefulWidget {
  const TaxiCustomerLiveMap({
    super.key,
    required this.driverLatitude,
    required this.driverLongitude,
    required this.driverLocationUpdatedAt,
  });

  final Object? driverLatitude;
  final Object? driverLongitude;
  final Object? driverLocationUpdatedAt;

  @override
  State<TaxiCustomerLiveMap> createState() => _TaxiCustomerLiveMapState();
}

class _TaxiCustomerLiveMapState extends State<TaxiCustomerLiveMap> {
  static const _maxLocationAge = Duration(minutes: 2);

  final _mapController = MapController();
  Timer? _freshnessTimer;
  LatLng? _lastCenter;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    // A stopped driver may not produce another Firestore snapshot. Rebuild
    // periodically so an old point is hidden even without a new server event.
    _freshnessTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  double? _coordinate(Object? value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    return number != null && number.isFinite ? number : null;
  }

  DateTime? _timestamp(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  LatLng? _point() {
    final latitude = _coordinate(widget.driverLatitude);
    final longitude = _coordinate(widget.driverLongitude);
    if (latitude == null || longitude == null) return null;
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    return LatLng(latitude, longitude);
  }

  bool _isFresh(DateTime? updatedAt) {
    if (updatedAt == null) return false;
    return DateTime.now().difference(updatedAt) <= _maxLocationAge;
  }

  @override
  void didUpdateWidget(covariant TaxiCustomerLiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextPoint = _point();
    if (!_mapReady || nextPoint == null || nextPoint == _lastCenter) return;

    // Keep the current point visible as the driver moves. A customer can still
    // pan/zoom the map afterwards; the next server update recenters it.
    _mapController.move(nextPoint, _mapController.camera.zoom);
    _lastCenter = nextPoint;
  }

  @override
  void dispose() {
    _freshnessTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Widget _message(
      {required IconData icon, required String title, String? body}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.navy.withOpacity(.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.navy.withOpacity(.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.navy),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                if (body != null) ...[
                  const SizedBox(height: 3),
                  Text(body, style: const TextStyle(color: Colors.black54)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final point = _point();
    final updatedAt = _timestamp(widget.driverLocationUpdatedAt);

    if (point == null || !_isFresh(updatedAt)) {
      return _message(
        icon: Icons.gps_not_fixed_rounded,
        title: point == null
            ? 'بانتظار موقع السائق'
            : 'موقع السائق غير متاح مؤقتًا',
        body: point == null
            ? 'ستظهر الخريطة عند بدء الرحلة ووصول أول تحديث.'
            : 'سنخفي الموقع القديم حتى يصل تحديث حديث وآمن.',
      );
    }

    final age = DateTime.now().difference(updatedAt!);
    final ageLabel = age.inSeconds < 60 ? 'الآن' : 'قبل ${age.inMinutes} د';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.gps_fixed_rounded, color: AppTheme.navy, size: 20),
            const SizedBox(width: 7),
            const Expanded(
              child: Text(
                'موقع السيارة مباشر',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              ageLabel,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 220,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: point,
                initialZoom: 15,
                onMapReady: () {
                  _mapReady = true;
                  _mapController.move(point, 15);
                  _lastCenter = point;
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.barakah90.app',
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 58,
                      height: 58,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppTheme.coolYellow,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 5,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.local_taxi_rounded,
                          color: AppTheme.navy,
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
