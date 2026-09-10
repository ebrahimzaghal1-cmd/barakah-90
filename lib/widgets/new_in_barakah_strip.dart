import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../screens/restaurant_details_screen.dart';
import '../services/firebase_state.dart';
import '../theme/app_theme.dart';
import 'restaurant_card.dart';

class NewInBarakahStrip extends StatelessWidget {
  const NewInBarakahStrip({
    super.key,
    required this.itemType,
  });

  final String itemType;

  bool _matchesType(Map<String, dynamic> data) {
    final type = data['type']?.toString().trim().toLowerCase() ?? '';
    if (itemType == 'market') return type == 'market';
    return type.isEmpty ||
        type == 'restaurant' ||
        type == 'restaurants' ||
        type == 'barber';
  }

  @override
  Widget build(BuildContext context) {
    if (!FirebaseState.isReady) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('items').snapshots(),
      builder: (context, snapshot) {
        final stores = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data();
          return data['kind']?.toString() != 'product' &&
              data['isNewInBarakah'] == true &&
              data['businessStatus']?.toString() != 'coming_soon' &&
              _matchesType(data);
        }).toList()
          ..sort((a, b) {
            final aValue = a.data()['createdAt'];
            final bValue = b.data()['createdAt'];
            final aMillis =
                aValue is Timestamp ? aValue.millisecondsSinceEpoch : 0;
            final bMillis =
                bValue is Timestamp ? bValue.millisecondsSinceEpoch : 0;
            return bMillis.compareTo(aMillis);
          });

        if (stores.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.new_releases_rounded,
                  color: AppTheme.deepYellow,
                  size: 27,
                ),
                SizedBox(width: 7),
                Text(
                  'جديد في بركة',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 225,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: stores.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final store = stores[index];
                  return SizedBox(
                    width: 165,
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              RestaurantDetailsScreen(restaurant: store),
                        ),
                      ),
                      child: RestaurantCard(restaurant: store),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
