import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/barber_booking_service.dart';
import '../theme/app_theme.dart';

class BarberBookingSection extends StatefulWidget {
  const BarberBookingSection(
      {super.key, required this.businessId, required this.business});

  final String businessId;
  final Map<String, dynamic> business;

  @override
  State<BarberBookingSection> createState() => _BarberBookingSectionState();
}

class _BarberBookingSectionState extends State<BarberBookingSection> {
  DateTime _date = DateTime.now();
  int? _selectedStart;
  int _serviceIndex = 0;

  List<Map<String, dynamic>> get _services {
    final isDoctor =
        widget.business['type']?.toString().toLowerCase() == 'doctor';
    final raw = widget.business['barberServices'];
    final parsed = raw is List
        ? raw
            .whereType<Map>()
            .map((value) => Map<String, dynamic>.from(value))
            .where((value) => value['title'] != null)
            .toList()
        : <Map<String, dynamic>>[];
    if (parsed.isNotEmpty) return parsed;
    return [
      {
        'title': isDoctor ? 'استشارة طبية' : 'حلاقة',
        'price': widget.business['bookingPrice'] ?? (isDoctor ? 0 : 30),
        'durationMinutes': widget.business['appointmentSlotMinutes'] ?? 30,
      }
    ];
  }

  int get _duration =>
      (_services[_serviceIndex]['durationMinutes'] as num?)?.toInt() ?? 30;
  double get _price =>
      (_services[_serviceIndex]['price'] as num?)?.toDouble() ?? 0;
  String get _dateKey => _key(_date);

  @override
  Widget build(BuildContext context) {
    final opening =
        _parseTime(widget.business['openingTime']?.toString()) ?? 9 * 60;
    final closing =
        _parseTime(widget.business['closingTime']?.toString()) ?? 21 * 60;
    final slots = _slots(opening, closing, _duration);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
          widget.business['type']?.toString().toLowerCase() == 'doctor'
              ? 'احجز موعدك عند الطبيب'
              : 'احجز موعدك عند الحلاق',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 5),
      Text('ساعات العمل: ${_formatTime(opening)} - ${_formatTime(closing)}',
          style: const TextStyle(color: Colors.black54)),
      const SizedBox(height: 12),
      Card(
        color: Colors.white.withOpacity(.9),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            DropdownButtonFormField<int>(
              value: _serviceIndex,
              decoration: const InputDecoration(
                  labelText: 'اختر الخدمة',
                  prefixIcon: Icon(Icons.content_cut_rounded)),
              items: [
                for (var i = 0; i < _services.length; i++)
                  DropdownMenuItem(
                      value: i,
                      child: Text(
                          '${_services[i]['title']} — ${_services[i]['price'] ?? 0} ₪'))
              ],
              onChanged: (value) => setState(() {
                _serviceIndex = value ?? 0;
                _selectedStart = null;
              }),
            ),
            const SizedBox(height: 10),
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text('روزنامة المواعيد',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.coolYellow.withOpacity(.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: CalendarDatePicker(
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 90)),
                initialDate:
                    _date.isBefore(DateTime.now()) ? DateTime.now() : _date,
                currentDate: DateTime.now(),
                onDateChanged: (value) => setState(() {
                  _date = value;
                  _selectedStart = null;
                }),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                      color: AppTheme.deepYellow, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              const Text('متاح'),
              const SizedBox(width: 16),
              Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade400, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              const Text('محجوز'),
            ]),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text('أوقات ${_date.day}/${_date.month}/${_date.year}',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: BarberBookingService.instance
                  .watchLocks(businessId: widget.businessId, dateKey: _dateKey),
              builder: (context, snapshot) {
                final locked = (snapshot.data?.docs ?? [])
                    .map((doc) => doc.data())
                    .toList();
                final reservedCount = slots
                    .where((start) => locked.any((lock) {
                          if (lock['dateKey']?.toString() != _dateKey ||
                              lock['status']?.toString() != 'reserved')
                            return false;
                          final from =
                              (lock['startMinutes'] as num?)?.toInt() ?? 0;
                          final to = (lock['endMinutes'] as num?)?.toInt() ?? 0;
                          return start < to && start + _duration > from;
                        }))
                    .length;
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                          'المتاح: ${slots.length - reservedCount} من ${slots.length} موعد',
                          style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final start in slots)
                          _slotButton(context, start, locked),
                      ]),
                    ]);
              },
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _selectedStart == null
                    ? null
                    : () => _confirmBooking(context),
                icon: const Icon(Icons.event_available_rounded),
                label: Text(_selectedStart == null
                    ? 'اختر وقتاً أولاً'
                    : 'تأكيد حجز ${_formatTime(_selectedStart!)} — $_price ₪'),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _slotButton(
      BuildContext context, int start, List<Map<String, dynamic>> locked) {
    final unavailable = locked.any((lock) {
      if (lock['dateKey']?.toString() != _dateKey ||
          lock['status']?.toString() != 'reserved') {
        return false;
      }
      final from = (lock['startMinutes'] as num?)?.toInt() ?? 0;
      final to = (lock['endMinutes'] as num?)?.toInt() ?? 0;
      return start < to && start + _duration > from;
    });
    final selected = start == _selectedStart;
    return ChoiceChip(
      label: Text(_formatTime(start)),
      selected: selected,
      onSelected:
          unavailable ? null : (_) => setState(() => _selectedStart = start),
      selectedColor: AppTheme.deepYellow,
      disabledColor: Colors.grey.shade300,
      labelStyle: TextStyle(
          color: unavailable
              ? Colors.grey
              : (selected ? Colors.white : AppTheme.navy),
          fontWeight: FontWeight.w800),
    );
  }

  Future<void> _confirmBooking(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('سجّل الدخول أولاً حتى يتم حفظ الموعد.')));
      return;
    }
    final name = TextEditingController(text: user.displayName ?? '');
    final phone = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('بيانات الحجز'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'الاسم')),
          const SizedBox(height: 10),
          TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'رقم الهاتف')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext,
                  name.text.trim().isNotEmpty && phone.text.trim().isNotEmpty),
              child: const Text('حجز')),
        ],
      ),
    );
    if (confirmed != true || _selectedStart == null) {
      name.dispose();
      phone.dispose();
      return;
    }
    try {
      final start = DateTime(_date.year, _date.month, _date.day,
          _selectedStart! ~/ 60, _selectedStart! % 60);
      await BarberBookingService.instance.createBooking(
        businessId: widget.businessId,
        serviceId: widget.business['type']?.toString().toLowerCase() == 'doctor'
            ? 'consultation'
            : 'service_${_serviceIndex + 1}',
        serviceTitle: _services[_serviceIndex]['title'].toString(),
        price: _price,
        durationMinutes: _duration,
        start: start,
        customerName: name.text,
        customerPhone: phone.text,
      );
      if (!context.mounted) return;
      setState(() => _selectedStart = null);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال طلب الحجز للحلاق ✅')));
    } on FirebaseException catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.code == 'already-exists'
                ? 'هذا الوقت محجوز، اختَر وقتاً آخر.'
                : 'تعذر حفظ الحجز الآن.'),
            backgroundColor: Colors.red));
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذر حفظ الحجز الآن.'),
            backgroundColor: Colors.red));
    } finally {
      name.dispose();
      phone.dispose();
    }
  }

  List<int> _slots(int opening, int closing, int duration) {
    final step = (widget.business['appointmentSlotMinutes'] as num?)?.toInt() ??
        duration;
    final result = <int>[];
    for (var value = opening; value + duration <= closing; value += step)
      result.add(value);
    return result;
  }

  static int? _parseTime(String? value) {
    final parts = (value ?? '').split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) return null;
    return hour * 60 + minute;
  }

  static String _formatTime(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  static String _key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
