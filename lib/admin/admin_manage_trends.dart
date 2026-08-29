import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AdminManageTrends extends StatelessWidget {
  const AdminManageTrends({super.key});

  bool _isBusiness(Map<String, dynamic> data) =>
      data['kind']?.toString() != 'product';

  String _section(Map<String, dynamic> data) =>
      data['type']?.toString().toLowerCase() == 'market'
          ? 'ترندات الماركت'
          : 'ترندات المطاعم';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('إدارة الترندات'),
          centerTitle: true,
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('items').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('تعذر تحميل المحلات.'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs
                .where((doc) => _isBusiness(doc.data()))
                .toList()
              ..sort((a, b) {
                final type = _section(a.data()).compareTo(_section(b.data()));
                if (type != 0) return type;
                final right = (b.data()['rating'] as num?)?.toDouble() ?? 0;
                final left = (a.data()['rating'] as num?)?.toDouble() ?? 0;
                return right.compareTo(left);
              });
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final title = data['title']?.toString() ?? 'بدون اسم';
                final image = data['image']?.toString() ?? '';
                final rating = (data['rating'] as num?)?.toDouble() ?? 0;
                final selected = data['isTrending'] == true;
                return Card(
                  child: SwitchListTile.adaptive(
                    value: selected,
                    onChanged: (value) =>
                        doc.reference.update({'isTrending': value}),
                    secondary: CircleAvatar(
                      backgroundColor: AppTheme.coolYellow.withOpacity(.3),
                      backgroundImage:
                          image.isNotEmpty ? NetworkImage(image) : null,
                      child: image.isEmpty
                          ? const Icon(Icons.storefront_rounded)
                          : null,
                    ),
                    title: Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text(
                        '${_section(data)}  •  ${rating.toStringAsFixed(1)} ★'),
                  ),
                );
              },
            );
          },
        ),
      );
}
