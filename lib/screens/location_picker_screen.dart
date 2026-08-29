import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key, this.latitude, this.longitude});

  final double? latitude;
  final double? longitude;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late LatLng _selected =
      LatLng(widget.latitude ?? 31.7683, widget.longitude ?? 35.2137);
  final MapController _mapController = MapController();
  var _loadingLocation = false;

  Future<void> _useCurrentLocation() async {
    setState(() => _loadingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw Exception();
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception();
      }
      final position = await Geolocator.getCurrentPosition();
      _selected = LatLng(position.latitude, position.longitude);
      _mapController.move(_selected, 16);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'تعذر تحديد الموقع. فعّلي خدمة الموقع واسمحي للتطبيق بالوصول إليها.')));
      }
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('اختيار الموقع'), centerTitle: true),
        body: Column(children: [
          Expanded(
              child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
                initialCenter: _selected,
                initialZoom: 13,
                onTap: (_, point) => setState(() => _selected = point)),
            children: [
              TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.barakah90.app'),
              MarkerLayer(markers: [
                Marker(
                    point: _selected,
                    width: 52,
                    height: 52,
                    child: const Icon(Icons.location_pin,
                        color: Colors.red, size: 52))
              ]),
            ],
          )),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                OutlinedButton.icon(
                    onPressed: _loadingLocation ? null : _useCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: Text(_loadingLocation
                        ? 'جارٍ تحديد الموقع...'
                        : 'استخدام موقعي الحالي')),
                const SizedBox(height: 10),
                SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, {
                              'latitude': _selected.latitude,
                              'longitude': _selected.longitude
                            }),
                        child: const Text('حفظ الموقع'))),
              ])),
        ]),
      );
}
