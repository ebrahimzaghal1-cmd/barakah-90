import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminAppHours extends StatefulWidget {
  const AdminAppHours({super.key});

  @override
  State<AdminAppHours> createState() => _AdminAppHoursState();
}

class _AdminAppHoursState extends State<AdminAppHours> {
  final _firestore = FirebaseFirestore.instance;

  final _openingTime = TextEditingController(text: '10:00');
  final _closingTime = TextEditingController(text: '03:00');
  final _closedMessage = TextEditingController(
    text: 'بركة مغلق الآن، نعود لاستقبال الطلبات عند وقت الفتح.',
  );

  bool _temporarilyClosed = false;
  bool _saving = false;
  bool _loading = true;

  final Map<String, String> _days = const {
    'sat': 'السبت',
    'sun': 'الأحد',
    'mon': 'الاثنين',
    'tue': 'الثلاثاء',
    'wed': 'الأربعاء',
    'thu': 'الخميس',
    'fri': 'الجمعة',
  };

  final Map<String, bool> _enabledDays = {
    'sat': true,
    'sun': true,
    'mon': true,
    'tue': true,
    'wed': true,
    'thu': true,
    'fri': true,
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final doc =
          await _firestore.collection('app_settings').doc('app_hours').get();

      if (doc.exists) {
        final data = doc.data() ?? {};

        _openingTime.text = data['openingTime']?.toString() ?? '10:00';

        _closingTime.text = data['closingTime']?.toString() ?? '03:00';

        _closedMessage.text = data['closedMessage']?.toString() ??
            'بركة مغلق الآن، نعود لاستقبال الطلبات عند وقت الفتح.';

        _temporarilyClosed = data['temporarilyClosed'] == true;

        final days = data['enabledDays'];

        if (days is Map) {
          for (final key in _enabledDays.keys) {
            _enabledDays[key] = days[key] == null ? true : days[key] == true;
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    final open = _openingTime.text.trim();
    final close = _closingTime.text.trim();

    if (!_isValidTime(open) || !_isValidTime(close)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل الوقت بصيغة صحيحة مثل 10:00 أو 03:00.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await _firestore.collection('app_settings').doc('app_hours').set({
        'openingTime': open,
        'closingTime': close,
        'closedMessage': _closedMessage.text.trim(),
        'temporarilyClosed': _temporarilyClosed,
        'enabledDays': _enabledDays,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ أوقات عمل بركة.'),
          backgroundColor: Colors.green,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  bool _isValidTime(String value) {
    final parts = value.split(':');

    if (parts.length != 2) return false;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return false;

    return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;
  }

  @override
  void dispose() {
    _openingTime.dispose();
    _closingTime.dispose();
    _closedMessage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('أوقات عمل بركة'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 78,
                ),
                const SizedBox(height: 8),
                const Text(
                  'أوقات استقبال الطلبات',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'يمكن للزبون تصفح التطبيق خارج هذه الأوقات، لكن لا يمكنه تأكيد طلب جديد.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _openingTime,
                        keyboardType: TextInputType.datetime,
                        decoration: const InputDecoration(
                          labelText: 'وقت فتح بركة',
                          hintText: '10:00',
                          prefixIcon: Icon(
                            Icons.login_rounded,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _closingTime,
                        keyboardType: TextInputType.datetime,
                        decoration: const InputDecoration(
                          labelText: 'وقت إغلاق بركة',
                          hintText: '03:00',
                          prefixIcon: Icon(
                            Icons.logout_rounded,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'أيام عمل بركة',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                for (final entry in _days.entries)
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      entry.value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      (_enabledDays[entry.key] ?? true)
                          ? 'يستقبل الطلبات'
                          : 'عطلة',
                    ),
                    value: _enabledDays[entry.key] ?? true,
                    onChanged: _saving
                        ? null
                        : (value) {
                            setState(() {
                              _enabledDays[entry.key] = value;
                            });
                          },
                  ),
                const Divider(height: 34),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'إغلاق بركة مؤقتًا',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  subtitle: const Text(
                    'يوقف استقبال جميع الطلبات فورًا حتى لو كان الوقت ضمن ساعات العمل.',
                  ),
                  value: _temporarilyClosed,
                  onChanged: _saving
                      ? null
                      : (value) {
                          setState(() {
                            _temporarilyClosed = value;
                          });
                        },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _closedMessage,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'رسالة الإغلاق للزبون',
                    prefixIcon: Icon(
                      Icons.info_outline_rounded,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(
                    Icons.save_rounded,
                  ),
                  label: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'حفظ أوقات عمل بركة',
                        ),
                ),
              ],
            ),
    );
  }
}
