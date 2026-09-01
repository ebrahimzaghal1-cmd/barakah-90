import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/favorites_service.dart';
import '../theme/app_theme.dart';
import '../widgets/barakah_brand.dart';
import 'restaurant_details_screen.dart';

class FavoritesScreen extends StatelessWidget {
  FavoritesScreen({super.key, required this.user});

  final User user;
  final FavoritesService _favorites = FavoritesService();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('المفضلة'),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.navy,
        ),
        backgroundColor: Colors.transparent,
        body: BarakahBrandBackdrop(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _favorites.watchFavorites(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const _FavoritesMessage(
                  icon: Icons.cloud_off_rounded,
                  text: 'تعذر تحميل المفضلة. حاول مرة أخرى.',
                );
              }
              final entries = snapshot.data?.docs ?? const [];
              if (entries.isEmpty) {
                return const _FavoritesMessage(
                  icon: Icons.favorite_border_rounded,
                  text: 'لم تضف محلات أو أصناف إلى المفضلة بعد.',
                );
              }
              final businesses = entries
                  .where((entry) => entry.data()['kind'] != 'product')
                  .toList();
              final products = entries
                  .where((entry) => entry.data()['kind'] == 'product')
                  .toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
                children: [
                  if (businesses.isNotEmpty) ...[
                    const _SectionTitle('المحلات المفضلة'),
                    ...businesses.map((entry) => _FavoriteTile(
                          entry: entry,
                          userId: user.uid,
                          service: _favorites,
                        )),
                  ],
                  if (products.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const _SectionTitle('الأصناف المفضلة'),
                    ...products.map((entry) => _FavoriteTile(
                          entry: entry,
                          userId: user.uid,
                          service: _favorites,
                        )),
                  ],
                ],
              );
            },
          ),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
        child: Text(
          title,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: AppTheme.navy,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({
    required this.entry,
    required this.userId,
    required this.service,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> entry;
  final String userId;
  final FavoritesService service;

  @override
  Widget build(BuildContext context) {
    final data = entry.data();
    final image = data['image']?.toString() ?? '';
    final title = data['title']?.toString().trim();
    final isProduct = data['kind'] == 'product';
    final subtitle = isProduct
        ? data['price'] == null
            ? 'صنف'
            : '${data['price']} ₪'
        : data['category']?.toString().trim().isNotEmpty == true
            ? data['category'].toString()
            : 'محل';

    return Card(
      color: Colors.white.withOpacity(.92),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(9),
        onTap: isProduct
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RestaurantDetailsScreen(
                      restaurant: {...data, 'id': entry.id},
                    ),
                  ),
                ),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: SizedBox.square(
            dimension: 58,
            child: image.isEmpty
                ? const ColoredBox(
                    color: Color(0xFFFFF1B8),
                    child: Icon(Icons.storefront_rounded),
                  )
                : image.startsWith('assets/')
                    ? Image.asset(image, fit: BoxFit.cover)
                    : Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Color(0xFFFFF1B8),
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
          ),
        ),
        title: Text(
          title?.isNotEmpty == true ? title! : (isProduct ? 'صنف' : 'محل'),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(subtitle),
        trailing: IconButton(
          tooltip: 'إزالة من المفضلة',
          icon: const Icon(Icons.favorite_rounded, color: Colors.redAccent),
          onPressed: () => service.remove(userId: userId, itemId: entry.id),
        ),
      ),
    );
  }
}

class _FavoritesMessage extends StatelessWidget {
  const _FavoritesMessage({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: AppTheme.deepYellow),
              const SizedBox(height: 14),
              Text(
                text,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      );
}
