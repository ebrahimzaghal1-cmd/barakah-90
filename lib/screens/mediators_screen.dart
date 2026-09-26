import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../widgets/arabic_map_layer.dart';
import '../widgets/barakah_brand.dart';
import 'mediator_orders_screen.dart';

class MediatorsScreen extends StatefulWidget {
  const MediatorsScreen({super.key});
  @override
  State<MediatorsScreen> createState() => _MediatorsScreenState();
}

class _MediatorsScreenState extends State<MediatorsScreen> {
  LatLng? current;
  bool loading = false;
  @override
  void initState() {
    super.initState();
    locate();
  }

  Future<void> locate() async {
    setState(() => loading = true);
    try {
      final p = await LocationService.getCurrentLocation()
          .timeout(const Duration(seconds: 10));
      if (mounted) setState(() => current = LatLng(p.latitude, p.longitude));
    } catch (_) {
      /* The directory remains available without location permission. */
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  LatLng? coordinates(Map<String, dynamic> d) {
    final lat = double.tryParse('${d['latitude'] ?? d['agentLatitude']}');
    final lng = double.tryParse('${d['longitude'] ?? d['agentLongitude']}');
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180) {
      return null;
    }
    return LatLng(lat, lng);
  }

  double? distance(Map<String, dynamic> d) {
    final p = coordinates(d);
    return current == null || p == null ? null : const Distance()(current!, p);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('وسيطات بركة'), actions: [
        IconButton(
            onPressed: loading ? null : locate,
            icon: const Icon(Icons.my_location)),
        IconButton(
            tooltip: 'طلباتي',
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MediatorOrdersScreen())),
            icon: const Icon(Icons.receipt_long))
      ]),
      body: BarakahBrandBackdrop(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('items')
                  .where('kind', isEqualTo: 'agent')
                  .snapshots(),
              builder: (context, s) {
                if (s.hasError) {
                  return const Center(
                      child: Text('تعذر تحميل الوسيطات. حاول مرة أخرى.'));
                }
                if (!s.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = s.data!.docs.toList()
                  ..sort((a, b) {
                    final compare = (distance(a.data()) ?? double.infinity)
                        .compareTo(distance(b.data()) ?? double.infinity);
                    return compare != 0
                        ? compare
                        : '${a.data()['title']}'
                            .compareTo('${b.data()['title']}');
                  });
                final points = docs
                    .map((d) => coordinates(d.data()))
                    .whereType<LatLng>()
                    .toList();
                return ListView(padding: const EdgeInsets.all(16), children: [
                  if (loading) const LinearProgressIndicator(),
                  if (current == null)
                    const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                            'نعرض جميع الوسيطات. فعّلي الموقع لترتيبهن حسب القرب؛ لا نحسب المسافة من موقع افتراضي.')),
                  SizedBox(
                      height: 300,
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: FlutterMap(
                              key: ValueKey(
                                  '${current?.latitude}:${current?.longitude}:${points.join(',')}'),
                              options: MapOptions(
                                  initialCenter: current ??
                                      (points.isEmpty
                                          ? const LatLng(31.7683, 35.2137)
                                          : points.first),
                                  initialZoom: 11,
                                  initialCameraFit: points.isEmpty
                                      ? null
                                      : CameraFit.coordinates(
                                          coordinates: points,
                                          padding: const EdgeInsets.all(50),
                                          maxZoom: 14)),
                              children: [
                                arabicMapTileLayer(),
                                MarkerLayer(markers: [
                                  for (final d in docs)
                                    if (coordinates(d.data()) != null)
                                      Marker(
                                          point: coordinates(d.data())!,
                                          width: 124,
                                          height: 78,
                                          child: GestureDetector(
                                              onTap: () => open(d),
                                              child: ArabicMapMarker(
                                                  label:
                                                      '${d.data()['title'] ?? ''}')))
                                ]),
                                const ArabicMapAttribution()
                              ]))),
                  if (docs.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('لا توجد وسيطات مسجلة حاليًا.')),
                  for (final d in docs)
                    Card(
                        child: ListTile(
                            title: Text('${d.data()['title'] ?? ''}'),
                            subtitle: Text(
                                '${d.data()['agentLocation'] ?? ''}\n${distance(d.data()) == null ? coordinates(d.data()) == null ? 'لم يُحدد الموقع بعد' : 'المسافة غير متاحة' : '${(distance(d.data())! / 1000).toStringAsFixed(1)} كم'} • ${d.data()['mediatorFee'] == null ? 'الأجرة لم تحدد بعد' : 'الأجرة ${d.data()['mediatorFee']} ₪'}'),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_left),
                            onTap: () => open(d))),
                ]);
              })));
  void open(QueryDocumentSnapshot<Map<String, dynamic>> doc) => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              MediatorOrderForm(businessId: doc.id, business: doc.data())));
}
