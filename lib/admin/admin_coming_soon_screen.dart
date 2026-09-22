import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AdminComingSoonScreen extends StatefulWidget {
  const AdminComingSoonScreen({super.key});

  @override
  State<AdminComingSoonScreen> createState() => _AdminComingSoonScreenState();
}

class _AdminComingSoonScreenState extends State<AdminComingSoonScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _setComingSoon(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> reference,
    bool value,
  ) async {
    try {
      await reference.update({
        'businessStatus': value ? 'coming_soon' : 'open',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'تمت إضافة المحل إلى قريبًا في بركة ✅'
                : 'تمت إزالة المحل من قريبًا في بركة.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر تحديث المحل: '
            '${error.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: const Text(
          'قريبًا في بركة',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (value) {
                setState(() => _query = value.trim().toLowerCase());
              },
              decoration: InputDecoration(
                hintText: 'ابحث عن محل...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream:
                  FirebaseFirestore.instance.collection('items').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'تعذر تحميل المحلات: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final businesses = (snapshot.data?.docs ?? const [])
                    .where((doc) {
                  final data = doc.data();

                  if (data['kind']?.toString() == 'product') return false;

                  final type =
                      data['type']?.toString().trim().toLowerCase() ?? '';

                  if (type == 'taxi') return false;

                  final title =
                      (data['title'] ?? data['name'] ?? '').toString().trim();

                  if (title.isEmpty) return false;

                  if (_query.isEmpty) return true;

                  final category =
                      data['category']?.toString().toLowerCase() ?? '';

                  return title.toLowerCase().contains(_query) ||
                      category.contains(_query);
                }).toList()
                  ..sort((a, b) {
                    final aData = a.data();
                    final bData = b.data();

                    final aComing = aData['businessStatus'] == 'coming_soon';
                    final bComing = bData['businessStatus'] == 'coming_soon';

                    if (aComing != bComing) {
                      return aComing ? -1 : 1;
                    }

                    final aTitle =
                        (aData['title'] ?? aData['name'] ?? '').toString();

                    final bTitle =
                        (bData['title'] ?? bData['name'] ?? '').toString();

                    return aTitle.compareTo(bTitle);
                  });

                if (businesses.isEmpty) {
                  return const Center(
                    child: Text('لا توجد محلات مطابقة.'),
                  );
                }

                final comingCount = businesses
                    .where(
                      (doc) => doc.data()['businessStatus'] == 'coming_soon',
                    )
                    .length;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: _CountCard(
                              title: 'كل المحلات',
                              value: businesses.length,
                              icon: Icons.storefront_rounded,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CountCard(
                              title: 'قريبًا الآن',
                              value: comingCount,
                              icon: Icons.upcoming_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          4,
                          16,
                          24,
                        ),
                        itemCount: businesses.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 9),
                        itemBuilder: (context, index) {
                          final business = businesses[index];
                          final data = business.data();

                          final title =
                              (data['title'] ?? data['name'] ?? 'محل بركة')
                                  .toString();

                          final category =
                              data['category']?.toString().trim() ?? '';

                          final status =
                              data['businessStatus']?.toString() ?? 'open';

                          final isComingSoon = status == 'coming_soon';

                          return Card(
                            color: Colors.white,
                            child: SwitchListTile.adaptive(
                              value: isComingSoon,
                              activeColor: AppTheme.deepYellow,
                              secondary: CircleAvatar(
                                backgroundColor: isComingSoon
                                    ? AppTheme.coolYellow
                                    : const Color(0xFFECEFF3),
                                child: Icon(
                                  isComingSoon
                                      ? Icons.upcoming_rounded
                                      : Icons.storefront_rounded,
                                  color: AppTheme.navy,
                                ),
                              ),
                              title: Text(
                                title,
                                style: const TextStyle(
                                  color: AppTheme.navy,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Text(
                                isComingSoon
                                    ? 'ظاهر في قسم قريبًا ولا يستقبل طلبات'
                                    : category.isEmpty
                                        ? 'غير مضاف إلى قريبًا'
                                        : '$category • غير مضاف إلى قريبًا',
                              ),
                              onChanged: (value) => _setComingSoon(
                                context,
                                business.reference,
                                value,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.deepYellow),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '$title\n$value',
              style: const TextStyle(
                color: AppTheme.navy,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
