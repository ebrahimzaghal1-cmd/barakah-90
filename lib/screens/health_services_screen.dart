import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';
import '../widgets/favorite_button.dart';
import '../widgets/medical_disclaimer.dart';
import 'doctor_clinic_screen.dart';

class HealthServicesScreen extends StatefulWidget {
  const HealthServicesScreen({super.key});

  @override
  State<HealthServicesScreen> createState() => _HealthServicesScreenState();
}

class _HealthServicesScreenState extends State<HealthServicesScreen> {
  LatLng _center = const LatLng(31.7683, 35.2137);
  final _doctorsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() => _center = LatLng(position.latitude, position.longitude));
      }
    } catch (_) {}
  }

  double _distance(Map<String, dynamic> data) {
    final lat = (data['latitude'] as num?)?.toDouble();
    final lng = (data['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return double.infinity;
    return const Distance().as(LengthUnit.Kilometer, _center, LatLng(lat, lng));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الخدمات الصحية'), centerTitle: true),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('items').snapshots(),
        builder: (context, snapshot) {
          final doctors = (snapshot.data?.docs ?? []).where((doc) {
            final data = doc.data();
            return data['kind']?.toString() != 'product' &&
                _isDoctor(data) &&
                data['businessStatus']?.toString() != 'closed';
          }).toList()
            ..sort(
                (a, b) => _distance(a.data()).compareTo(_distance(b.data())));
          final markers = doctors
              .map((doctor) {
                final data = doctor.data();
                final lat = (data['latitude'] as num?)?.toDouble();
                final lng = (data['longitude'] as num?)?.toDouble();
                if (lat == null || lng == null) return null;
                return Marker(
                  point: LatLng(lat, lng),
                  width: 54,
                  height: 64,
                  child: GestureDetector(
                    onTap: () => _openDoctor(context, doctor),
                    child: const Icon(Icons.location_on_rounded,
                        color: Colors.red, size: 48),
                  ),
                );
              })
              .whereType<Marker>()
              .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 30),
            children: [
              _HealthHeader(doctorCount: doctors.length),
              const SizedBox(height: 12),
              const MedicalDisclaimer(),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _HealthOptionCard(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'استشارة مجانية',
                      subtitle: 'اسأل طبيبًا منضمًا إلى بركة',
                      onTap: () => _showFreeConsultation(context, doctors),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HealthOptionCard(
                      icon: Icons.format_list_bulleted_rounded,
                      title: 'قائمة الأطباء',
                      subtitle: '${doctors.length} طبيب متاح',
                      onTap: _scrollToDoctors,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                height: 280,
                clipBehavior: Clip.antiAlias,
                decoration:
                    BoxDecoration(borderRadius: BorderRadius.circular(22)),
                child: FlutterMap(
                  options: MapOptions(initialCenter: _center, initialZoom: 9),
                  children: [
                    TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.barakah.market'),
                    MarkerLayer(markers: markers),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                key: _doctorsKey,
                child: const Text('قائمة الأطباء الأقربون لك',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 8),
              if (doctors.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('لا يوجد أطباء منضمون في منطقتك حتى الآن.',
                        textAlign: TextAlign.center)),
              ...doctors.map((doctor) => _DoctorTile(doctor: doctor)),
            ],
          );
        },
      ),
    );
  }

  bool _isDoctor(Map<String, dynamic> data) {
    final values = [
      data['type'],
      data['merchantType'],
      data['activityType'],
      data['category'],
    ].map((value) => value?.toString().toLowerCase().trim() ?? '');
    final joined = values.join(' ');
    return joined.contains('doctor') ||
        joined.contains('طبيب') ||
        joined.contains('دكتور') ||
        joined.contains('صحة');
  }

  void _scrollToDoctors() {
    final context = _doctorsKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
      );
    }
  }

  void _showFreeConsultation(
    BuildContext context,
    List<DocumentSnapshot<Map<String, dynamic>>> doctors,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('استشارة مجانية'),
        content: Text(
          doctors.isEmpty
              ? 'لا توجد عيادات مفعّلة حاليًا. أضيفي الطبيب من لوحة الأدمن ليظهر هنا.'
              : 'اختاري طبيبًا من قائمة الأطباء، ثم أرسلي سؤالك من مربع الاستشارة في صفحة العيادة بدون رسوم.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (doctors.isNotEmpty) _scrollToDoctors();
            },
            child: Text(doctors.isEmpty ? 'حسنًا' : 'عرض الأطباء'),
          ),
        ],
      ),
    );
  }

  void _openDoctor(
      BuildContext context, DocumentSnapshot<Map<String, dynamic>> doctor) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => DoctorClinicScreen(doctor: doctor)));
  }
}

class _HealthHeader extends StatelessWidget {
  const _HealthHeader({required this.doctorCount});
  final int doctorCount;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0B2A52), Color(0xFF1E6680)],
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.coolYellow,
              child: Icon(Icons.health_and_safety_rounded,
                  color: AppTheme.navy, size: 32),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('صحتك أولًا مع بركة',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(
                    '$doctorCount طبيبًا وعيادة على الخريطة بالقرب منك',
                    style: const TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _HealthOptionCard extends StatelessWidget {
  const _HealthOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.coolYellow, width: 1.3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppTheme.navy, size: 28),
              const SizedBox(height: 8),
              Text(title,
                  style: const TextStyle(
                      color: AppTheme.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
        ),
      );
}

class _DoctorTile extends StatelessWidget {
  const _DoctorTile({required this.doctor});
  final DocumentSnapshot<Map<String, dynamic>> doctor;

  @override
  Widget build(BuildContext context) {
    final data = doctor.data();
    if (data == null) return const SizedBox.shrink();
    final title = data['title']?.toString() ?? 'طبيب';
    return Card(
      child: ListTile(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => DoctorClinicScreen(doctor: doctor))),
        leading: const CircleAvatar(
            backgroundColor: AppTheme.coolYellow,
            child: Icon(Icons.medical_services_rounded, color: AppTheme.navy)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(data['doctorSpecialty']?.toString() ??
            data['category']?.toString() ??
            'عيادة طبية'),
        trailing: FavoriteButton(
            itemId: doctor.id, item: data, backgroundColor: AppTheme.navy),
      ),
    );
  }
}
