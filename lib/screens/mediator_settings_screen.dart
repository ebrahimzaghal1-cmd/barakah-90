import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'location_picker_screen.dart';

class MediatorSettingsScreen extends StatelessWidget {
  const MediatorSettingsScreen({super.key, this.admin = false});
  final bool admin;
  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> q =
        FirebaseFirestore.instance.collection('items');
    if (!admin) {
      q = q.where('ownerId',
          isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? '');
    }
    return Scaffold(
        appBar: AppBar(title: const Text('إعدادات الوسيطة')),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: q.snapshots(),
            builder: (context, s) {
              if (s.hasError) {
                return const Center(child: Text('تعذر تحميل الإعدادات'));
              }
              if (!s.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs =
                  s.data!.docs.where((d) => d.data()['kind'] == 'agent');
              return ListView(children: [
                for (final doc in docs)
                  ListTile(
                      title: Text('${doc.data()['title']}'),
                      subtitle: Text(
                          'الأجرة: ${doc.data()['mediatorFee'] ?? 'لم تحدد'} ₪'),
                      trailing: const Icon(Icons.edit),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => _EditMediator(doc: doc))))
              ]);
            }));
  }
}

class _EditMediator extends StatefulWidget {
  const _EditMediator({required this.doc});
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  @override
  State<_EditMediator> createState() => _EditMediatorState();
}

class _EditMediatorState extends State<_EditMediator> {
  late final fee =
      TextEditingController(text: '${widget.doc.data()['mediatorFee'] ?? ''}');
  late final delivery =
      TextEditingController(text: '${widget.doc.data()['deliveryFee'] ?? 0}');
  late final location = TextEditingController(
      text: '${widget.doc.data()['agentLocation'] ?? ''}');
  final phone = TextEditingController();
  late double? latitude = (widget.doc.data()['latitude'] as num?)?.toDouble();
  late double? longitude = (widget.doc.data()['longitude'] as num?)?.toDouble();
  bool busy = false, loaded = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final d = await FirebaseFirestore.instance
          .collection('mediator_private')
          .doc(widget.doc.id)
          .get();
      if (mounted) {
        phone.text = '${d.data()?['phone'] ?? ''}';
        setState(() => loaded = true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر تحميل الرقم الخاص')));
      }
    }
  }

  @override
  void dispose() {
    fee.dispose();
    delivery.dispose();
    location.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text('${widget.doc.data()['title']}')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        TextField(
            controller: fee,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration:
                const InputDecoration(labelText: 'أجرة الوسيطة بالشيكل')),
        TextField(
            controller: delivery,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration:
                const InputDecoration(labelText: 'رسوم التوصيل بالشيكل')),
        TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'رقم خاص للإدارة — لا يظهر للعملاء')),
        TextField(
            controller: location,
            decoration:
                const InputDecoration(labelText: 'المنطقة / وصف الموقع')),
        OutlinedButton.icon(
            icon: const Icon(Icons.map),
            label: Text(latitude == null ? 'تحديد الموقع' : 'تعديل الموقع'),
            onPressed: () async {
              final p = await Navigator.push<Map<String, double>>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => LocationPickerScreen(
                          latitude: latitude, longitude: longitude)));
              if (p != null && mounted) {
                setState(() {
                  latitude = p['latitude'];
                  longitude = p['longitude'];
                });
              }
            }),
        FilledButton(
            onPressed: busy || !loaded
                ? null
                : () async {
                    final f = double.tryParse(fee.text),
                        d = double.tryParse(delivery.text);
                    if (f == null ||
                        d == null ||
                        !f.isFinite ||
                        !d.isFinite ||
                        f < 0 ||
                        d < 0 ||
                        f > 100000 ||
                        d > 100000) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('أدخل أجرة ورسومًا صحيحة')));
                      return;
                    }
                    setState(() => busy = true);
                    try {
                      final db = FirebaseFirestore.instance;
                      final batch = db.batch();
                      batch.update(widget.doc.reference, {
                        'mediatorFee': f,
                        'deliveryFee': d,
                        'agentLocation': location.text.trim(),
                        'latitude': latitude,
                        'longitude': longitude
                      });
                      batch.set(
                          db.collection('mediator_private').doc(widget.doc.id),
                          {
                            'phone': phone.text.trim(),
                            'updatedAt': FieldValue.serverTimestamp()
                          });
                      await batch.commit();
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('تعذر الحفظ: $e')));
                      }
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            child: Text(busy ? 'جارٍ الحفظ…' : 'حفظ الإعدادات')),
      ]));
}
