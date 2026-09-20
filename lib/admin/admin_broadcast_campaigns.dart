import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/communication_campaign_service.dart';
import '../theme/app_theme.dart';

class AdminBroadcastCampaigns extends StatefulWidget {
  const AdminBroadcastCampaigns({super.key});

  @override
  State<AdminBroadcastCampaigns> createState() =>
      _AdminBroadcastCampaignsState();
}

class _AdminBroadcastCampaignsState extends State<AdminBroadcastCampaigns> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _service = CommunicationCampaignService();

  String _audience = 'all';
  String _type = 'message';
  bool _sending = false;
  String _progress = '';

  static const audiences = <String, String>{
    'all': 'جميع مستخدمي بركة',
    'customers': 'العملاء / المشتركون',
    'merchants': 'أصحاب المحلات / الشركاء',
    'delivery_drivers': 'سائقو التوصيل',
    'taxi_drivers': 'سائقو تكسي بركة',
    'agents': 'وسيطات بركة',
    'customer_service': 'خدمة العملاء',
  };

  static const types = <String, String>{
    'message': 'رسالة عامة',
    'offer': 'عرض',
    'ad': 'إعلان',
    'alert': 'تنبيه مهم',
  };

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _title.text.trim();
    final body = _body.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اكتب عنوان الرسالة ومحتواها أولًا.'),
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إرسال الحملة؟'),
        content: Text(
          'الجمهور: ${audiences[_audience]}\n'
          'النوع: ${types[_type]}\n\n'
          '$title\n\n$body',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إرسال'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    setState(() {
      _sending = true;
      _progress = 'جارٍ إنشاء الحملة...';
    });

    try {
      final result = await _service.createAndSend(
        title: title,
        body: body,
        audience: _audience,
        type: _type,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _progress = 'فحص ${progress.scannedCount} حساب • '
                'المستلمون ${progress.recipientCount}';
          });
        },
      );

      if (!mounted) return;

      _title.clear();
      _body.clear();

      setState(() {
        _progress = 'تم الإرسال إلى ${result.recipientCount} حساب ✅';
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Bad state: ', ''),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaigns = FirebaseFirestore.instance
        .collection('communication_campaigns')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: const Text(
          'الحملات والرسائل الجماعية',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: _audience,
            decoration: const InputDecoration(
              labelText: 'الجمهور',
            ),
            items: audiences.entries
                .map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value),
                  ),
                )
                .toList(),
            onChanged: _sending
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _audience = value);
                    }
                  },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(
              labelText: 'نوع الرسالة',
            ),
            items: types.entries
                .map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value),
                  ),
                )
                .toList(),
            onChanged: _sending
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _type = value);
                    }
                  },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'عنوان الرسالة',
            ),
          ),
          TextField(
            controller: _body,
            minLines: 4,
            maxLines: 8,
            maxLength: 1500,
            decoration: const InputDecoration(
              labelText: 'محتوى الرسالة',
            ),
          ),
          if (_progress.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _progress,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: const Icon(Icons.send_rounded),
            label: Text(
              _sending ? 'جارٍ الإرسال...' : 'إرسال الحملة',
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'سجل الحملات',
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: campaigns,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'لم يتم إرسال حملات بعد.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return Column(
                children: docs.map((doc) {
                  final data = doc.data();
                  final status = data['status']?.toString() ?? 'sending';
                  final count = (data['recipientCount'] as num?)?.toInt() ?? 0;

                  return Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.campaign_rounded,
                        color: AppTheme.navy,
                      ),
                      title: Text(
                        data['title']?.toString() ?? 'حملة بركة',
                      ),
                      subtitle: Text(
                        'المستلمون: $count',
                      ),
                      trailing: Text(
                        status == 'completed' ? 'مكتملة' : 'جارٍ الإرسال',
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
