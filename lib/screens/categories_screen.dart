import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/business_hours_service.dart';
import '../theme/app_theme.dart';
import '../widgets/barakah_brand.dart';
import '../widgets/barakah_media_image.dart';
import 'restaurant_details_screen.dart';

class CategoriesScreen extends StatelessWidget {
  final String title;
  final String image;
  final String description;
  final String itemType;

  const CategoriesScreen({
    super.key,
    required this.title,
    required this.image,
    required this.description,
    this.itemType = 'market',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
      ),
      backgroundColor: Colors.transparent,
      body: BarakahBrandBackdrop(
        child: ListView(
          children: [
            _CategoryCover(image: image),
            if (description.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 28, 20, 18),
              child: Center(
                child: Text(
                  'محلات',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('items')
                  .where('type', isEqualTo: itemType)
                  .where('category', isEqualTo: title)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(36),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                    child: Text(
                      'تعذر تحميل محلات القسم حالياً.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }

                final stores = (snapshot.data?.docs ?? []).where((doc) {
                  final data = doc.data();
                  final kind =
                      data['kind']?.toString().trim().toLowerCase() ?? '';

                  return kind != 'product';
                }).toList();

                if (stores.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 60),
                    child: Column(
                      children: [
                        SizedBox(height: 8),
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: Color(0xFFE5EAF2),
                          child: Icon(
                            Icons.storefront_rounded,
                            size: 44,
                            color: AppTheme.ink,
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'لا توجد محلات مضافة في هذا القسم حالياً.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'ستظهر المحلات هنا عند إضافتها من لوحة الإدارة.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                  itemCount: stores.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final store = stores[index];
                    final data = store.data();

                    final storeName = data['title']?.toString().trim() ?? 'محل';

                    final storeImage = data['image']?.toString().trim() ?? '';

                    final storeDescription =
                        data['description']?.toString().trim() ?? '';

                    final rating = data['rating'];
                    final hoursStatus =
                        BusinessHoursService.resolve(data: data);

                    return Material(
                      color: Colors.white.withOpacity(.92),
                      borderRadius: BorderRadius.circular(20),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RestaurantDetailsScreen(
                                restaurant: store,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: SizedBox(
                                  width: 92,
                                  height: 92,
                                  child: _StoreImage(
                                    image: storeImage,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      storeName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        color: AppTheme.ink,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    if (storeDescription.isNotEmpty) ...[
                                      const SizedBox(height: 5),
                                      Text(
                                        storeDescription,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 8,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.star_rounded,
                                              size: 19,
                                              color: AppTheme.deepYellow,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              rating == null ||
                                                      rating.toString() == '0'
                                                  ? 'جديد'
                                                  : rating.toString(),
                                              style: const TextStyle(
                                                color: AppTheme.ink,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                        _BusinessStatusBadge(
                                          status: hoursStatus,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.chevron_left_rounded,
                                color: AppTheme.ink,
                                size: 28,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessStatusBadge extends StatelessWidget {
  const _BusinessStatusBadge({required this.status});

  final BusinessHoursStatus status;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    final IconData icon;

    switch (status.code) {
      case 'open':
        background = const Color(0xFFE8F8EF);
        foreground = const Color(0xFF167A45);
        icon = Icons.check_circle_rounded;
        break;
      case 'closing_soon':
        background = const Color(0xFFFFF3D8);
        foreground = const Color(0xFF9A6200);
        icon = Icons.schedule_rounded;
        break;
      case 'opening_soon':
        background = const Color(0xFFFFF7CC);
        foreground = const Color(0xFF8A6A00);
        icon = Icons.schedule_rounded;
        break;
      case 'busy':
        background = const Color(0xFFFFE8D9);
        foreground = const Color(0xFFA74600);
        icon = Icons.local_fire_department_rounded;
        break;
      case 'temporarily_closed':
        background = const Color(0xFFFFE5E5);
        foreground = const Color(0xFFA52626);
        icon = Icons.pause_circle_filled_rounded;
        break;
      default:
        background = const Color(0xFFF0F1F3);
        foreground = const Color(0xFF646B75);
        icon = Icons.lock_clock_rounded;
    }

    var label = status.label;

    if (status.minutesUntilChange != null &&
        (status.code == 'closing_soon' || status.code == 'opening_soon')) {
      label = '$label • ${status.minutesUntilChange} د';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: foreground,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCover extends StatelessWidget {
  const _CategoryCover({required this.image});

  final String image;

  @override
  Widget build(BuildContext context) {
    if (image.isEmpty) {
      return const SizedBox(
        height: 200,
        child: ColoredBox(
          color: AppTheme.coolYellow,
          child: Center(
            child: Icon(
              Icons.storefront_rounded,
              size: 60,
              color: AppTheme.ink,
            ),
          ),
        ),
      );
    }

    return BarakahMediaImage(
      path: image,
      height: 200,
      width: double.infinity,
      fit: BoxFit.cover,
      fallback: const _CategoryImageError(),
    );
  }
}

class _CategoryImageError extends StatelessWidget {
  const _CategoryImageError();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 200,
      child: ColoredBox(
        color: AppTheme.coolYellow,
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            size: 50,
            color: AppTheme.ink,
          ),
        ),
      ),
    );
  }
}

class _StoreImage extends StatelessWidget {
  const _StoreImage({required this.image});

  final String image;

  @override
  Widget build(BuildContext context) {
    if (image.isEmpty) {
      return const ColoredBox(
        color: AppTheme.coolYellow,
        child: Center(
          child: Icon(
            Icons.storefront_rounded,
            size: 38,
            color: AppTheme.ink,
          ),
        ),
      );
    }

    if (image.startsWith('assets/')) {
      return Image.asset(
        image,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _StoreImageFallback(),
      );
    }

    return Image.network(
      image,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const _StoreImageFallback(),
    );
  }
}

class _StoreImageFallback extends StatelessWidget {
  const _StoreImageFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppTheme.coolYellow,
      child: Center(
        child: Icon(
          Icons.storefront_rounded,
          size: 38,
          color: AppTheme.ink,
        ),
      ),
    );
  }
}
