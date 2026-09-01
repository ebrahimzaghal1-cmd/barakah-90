import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AdminAppShareSettings extends StatefulWidget {
  const AdminAppShareSettings({super.key});

  @override
  State<AdminAppShareSettings> createState() => _AdminAppShareSettingsState();
}

class _AdminAppShareSettingsState extends State<AdminAppShareSettings> {
  final _message = TextEditingController(
    text: 'اكتشف المطاعم والمحلات والعروض في تطبيق بركة 🛍️',
  );
  final _webUrl = TextEditingController(text: 'https://barakah-new.web.app');
  final _androidUrl = TextEditingController();
  final _iosUrl = TextEditingController();
  bool _enabled = true;
  bool _loading = true;
  bool _saving = false;

  DocumentReference<Map<String, dynamic>> get _settings =>
      FirebaseFirestore.instance.collection('app_settings').doc('app_share');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snapshot = await _settings.get();
      final data = snapshot.data();
      if (data != null) {
        _message.text = data['message']?.toString() ?? _message.text;
        _webUrl.text = data['webUrl']?.toString() ?? _webUrl.text;
        _androidUrl.text = data['androidUrl']?.toString() ?? '';
        _iosUrl.text = data['iosUrl']?.toString() ?? '';
        _enabled = data['enabled'] != false;
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _settings.set({
        'enabled': _enabled,
        'message': _message.text.trim(),
        'webUrl': _webUrl.text.trim(),
        'androidUrl': _androidUrl.text.trim(),
        'iosUrl': _iosUrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم حفظ إعدادات مشاركة التطبيق ✅'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر الحفظ: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _message.dispose();
    _webUrl.dispose();
    _androidUrl.dispose();
    _iosUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        appBar: AppBar(
          backgroundColor: AppTheme.navy,
          foregroundColor: Colors.white,
          title: const Text(
            'مشاركة تطبيق بركة',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  SwitchListTile.adaptive(
                    value: _enabled,
                    onChanged: (value) => setState(() => _enabled = value),
                    title: const Text(
                      'إظهار وتفعيل المشاركة للمستخدمين',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: const Text(
                      'عند إيقافها يبقى الزر ظاهرًا مع رسالة أن المشاركة متوقفة مؤقتًا.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _message,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'نص المشاركة',
                      prefixIcon: Icon(Icons.message_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _urlField(_webUrl, 'رابط نسخة الويب'),
                  const SizedBox(height: 12),
                  _urlField(_androidUrl, 'رابط Google Play عند نشره'),
                  const SizedBox(height: 12),
                  _urlField(_iosUrl, 'رابط App Store عند نشره'),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ ونشر الإعداد'),
                  ),
                ],
              ),
      );

  Widget _urlField(TextEditingController controller, String label) => TextField(
        controller: controller,
        keyboardType: TextInputType.url,
        textDirection: TextDirection.ltr,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.link_rounded),
        ),
      );
}
