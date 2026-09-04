import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/barber_booking_section.dart';
import '../widgets/favorite_button.dart';

class DoctorClinicScreen extends StatefulWidget {
  const DoctorClinicScreen({super.key, required this.doctor});
  final DocumentSnapshot<Map<String, dynamic>> doctor;

  @override
  State<DoctorClinicScreen> createState() => _DoctorClinicScreenState();
}

class _DoctorClinicScreenState extends State<DoctorClinicScreen> {
  final _consultation = TextEditingController();
  var _sending = false;

  @override
  void dispose() {
    _consultation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doctor.data() ?? <String, dynamic>{};
    final title = data['title']?.toString() ?? 'عيادة الطبيب';
    final image = data['image']?.toString() ?? '';
    final fee = data['consultationFee'] ?? data['doctorConsultationFee'] ?? 0;
    final bookingData = <String, dynamic>{
      ...data,
      'type': 'doctor',
      'barberServices': [
        {
          'title': 'استشارة طبية',
          'price': fee,
          'durationMinutes': data['appointmentSlotMinutes'] ?? 30
        }
      ]
    };
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: [
        FavoriteButton(
            itemId: widget.doctor.id,
            item: data,
            backgroundColor: AppTheme.navy)
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          if (image.isNotEmpty)
            ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.network(image,
                    height: 190,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                        height: 190,
                        child: Icon(Icons.medical_services_rounded, size: 72))))
          else
            Container(
                height: 190,
                decoration: BoxDecoration(
                    color: AppTheme.coolYellow,
                    borderRadius: BorderRadius.circular(22)),
                child: const Icon(Icons.medical_services_rounded,
                    size: 72, color: AppTheme.navy)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w900))),
            FavoriteButton(
                itemId: widget.doctor.id,
                item: data,
                backgroundColor: AppTheme.navy)
          ]),
          const SizedBox(height: 5),
          Text(data['doctorSpecialty']?.toString() ?? 'طبيب',
              style: const TextStyle(
                  color: Colors.black54, fontWeight: FontWeight.w700)),
          if ((data['description']?.toString() ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(data['description'].toString(),
                style: const TextStyle(fontSize: 16, height: 1.6))
          ],
          const SizedBox(height: 22),
          _consultationBox(context),
          const SizedBox(height: 26),
          BarberBookingSection(
              businessId: widget.doctor.id, business: bookingData),
        ],
      ),
    );
  }

  Widget _consultationBox(BuildContext context) => Card(
        color: Colors.white.withOpacity(.92),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('مربع الاستشارة',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('اكتب سؤالك للطبيب وسيظهر له داخل لوحة العيادة.',
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 10),
            TextField(
                controller: _consultation,
                maxLines: 4,
                decoration: const InputDecoration(
                    hintText: 'اكتب تفاصيل الاستشارة...',
                    prefixIcon: Icon(Icons.chat_bubble_outline_rounded))),
            const SizedBox(height: 10),
            FilledButton.icon(
                onPressed: _sending ? null : _sendConsultation,
                icon: const Icon(Icons.send_rounded),
                label:
                    Text(_sending ? 'جارٍ الإرسال...' : 'إرسال طلب استشارة')),
          ]),
        ),
      );

  Future<void> _sendConsultation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('سجّل الدخول أولاً لإرسال الاستشارة.')));
      return;
    }
    if (_consultation.text.trim().length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اكتب تفاصيل أكثر للاستشارة.')));
      return;
    }
    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance.collection('doctor_consultations').add({
        'doctorId': widget.doctor.id,
        'patientId': user.uid,
        'message': _consultation.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      _consultation.clear();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال طلب الاستشارة للطبيب ✅')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذر إرسال الاستشارة.'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
