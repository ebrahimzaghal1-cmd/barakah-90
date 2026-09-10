import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firebase_state.dart';
import '../theme/app_theme.dart';
import '../widgets/barakah_brand.dart';
import '../widgets/responsive_page.dart';
import '../widgets/restaurant_card.dart';

class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BarakahBrandBackdrop(
        child: ResponsivePage(
          child: SafeArea(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
                  child: Column(
                    children: [
                      Icon(
                        Icons.upcoming_rounded,
                        color: AppTheme.deepYellow,
                        size: 42,
                      ),
                      SizedBox(height: 6),
                      Text(
                        'قريبًا في بركة',
                        style: TextStyle(
                          color: AppTheme.ink,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'متاجر ومطاعم من مدن مختلفة تستعد لاستقبالكم',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _ComingSoonBusinesses()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComingSoonBusinesses extends StatelessWidget {
  const _ComingSoonBusinesses();

  @override
  Widget build(BuildContext context) {
    if (!FirebaseState.isReady) {
      return const Center(child: Text('لا توجد متاجر قريبة الافتتاح حاليًا.'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('items').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final stores = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data();
          return data['kind']?.toString() != 'product' &&
              data['businessStatus']?.toString() == 'coming_soon';
        }).toList()
          ..sort((a, b) {
            final aTime = a.data()['createdAt'];
            final bTime = b.data()['createdAt'];
            final aMillis =
                aTime is Timestamp ? aTime.millisecondsSinceEpoch : 0;
            final bMillis =
                bTime is Timestamp ? bTime.millisecondsSinceEpoch : 0;
            return bMillis.compareTo(aMillis);
          });

        if (stores.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Text(
                'لا توجد متاجر قريبة الافتتاح حاليًا.\nستظهر هنا تلقائيًا عند إضافتها.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  height: 1.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }

        final columns = MediaQuery.sizeOf(context).width >= 700 ? 3 : 2;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          itemCount: stores.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: .66,
          ),
          itemBuilder: (context, index) => GestureDetector(
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('هذا المتجر قريبًا في بركة ولا يستقبل طلبات بعد.'),
              ),
            ),
            child: RestaurantCard(restaurant: stores[index]),
          ),
        );
      },
    );
  }
}
