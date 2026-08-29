import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/firebase_state.dart';
import '../services/analytics_service.dart';
import '../services/cart_service.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_page.dart';
import '../widgets/advertisement_banner.dart';
import '../widgets/barakah_online_status_button.dart';
import '../widgets/barakah_brand.dart';
import 'categories_screen.dart';
import 'products_screen.dart';
import 'restaurant_details_screen.dart';
import 'restaurants_screen.dart';

/// واجهة الماركت: أقسام متتالية وبطاقات أفقية، على نمط تطبيقات التسوق.
class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  static const List<Map<String, String>> categories = [
    {
      'title': 'مخبوزات',
      'image': 'assets/images/categories/bakery.jpg',
      'desc': 'أفضل المخبوزات الطازجة يومياً',
    },
    {
      'title': 'دجاج',
      'image': 'assets/images/categories/chicken.jpg',
      'desc': 'منتجات دجاج طازجة ومتنوعة',
    },
    {
      'title': 'أسماك',
      'image': 'assets/images/categories/fish.jpg',
      'desc': 'أسماك ومأكولات بحرية طازجة',
    },
    {
      'title': 'خضار وفواكه',
      'image': 'assets/images/categories/fruits_veggies.jpg',
      'desc': 'خضار وفواكه يومية',
    },
    {
      'title': 'لحوم',
      'image': 'assets/images/categories/meat.jpg',
      'desc': 'أجود أنواع اللحوم',
    },
    {
      'title': 'صيدلية',
      'image': 'assets/images/categories/pharmacy.jpg',
      'desc': 'احتياجات صحية ومنزلية',
    },
    {
      'title': 'سوبرماركت',
      'image': 'assets/images/categories/supermarket.jpg',
      'desc': 'كل احتياجات المنزل',
    },
  ];

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  String _location = 'بيتي';

  Future<void> _chooseLocation() async {
    const locations = ['بيتي', 'رام الله', 'نابلس', 'الخليل', 'القدس'];
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('اختر موقع التوصيل',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            ...locations.map((location) => Card(
                  child: ListTile(
                    leading: Icon(
                        location == _location
                            ? Icons.home_rounded
                            : Icons.location_city_outlined,
                        color: location == _location
                            ? AppTheme.deepYellow
                            : AppTheme.ink),
                    title: Text(location,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    trailing: location == _location
                        ? const Icon(Icons.check_rounded,
                            color: AppTheme.deepYellow)
                        : const Icon(Icons.chevron_left_rounded),
                    onTap: () => Navigator.pop(context, location),
                  ),
                )),
          ]),
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _location = selected);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        endDrawer: const _MarketMenu(),
        body: BarakahBrandBackdrop(
          child: ResponsivePage(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(children: [
                _MarketHeader(
                  location: _location,
                  onLocationPressed: _chooseLocation,
                  onSearchPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const AllItemsScreen(autoFocus: true))),
                ),
                const SizedBox(height: 10),
                const AdvertisementBanner(placement: 'market_top'),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: BarakahOnlineStatusButton(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BarakahAuctionScreen(),
                        ),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [
                              Color(0xFF173762),
                              Color(0xFF07172D),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.coolYellow,
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: Color(0xFFFFD64A),
                              child: Icon(
                                Icons.gavel_rounded,
                                color: AppTheme.navy,
                                size: 28,
                              ),
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'مزاد بركة',
                                    style: TextStyle(
                                      color: AppTheme.coolYellow,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'بيع واشتري من مجتمع بركة',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                !FirebaseState.isReady
                    ? const _MarketContent(
                        categories: MarketScreen.categories, items: [])
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('market_categories')
                            .snapshots(),
                        builder: (context, categorySnapshot) {
                          final firestoreCategories = categorySnapshot
                                  .data?.docs
                                  .map((doc) => <String, String>{
                                        'id': doc.id,
                                        'title':
                                            doc.data()['title']?.toString() ??
                                                '',
                                        'image':
                                            doc.data()['image']?.toString() ??
                                                '',
                                        'desc':
                                            doc.data()['desc']?.toString() ??
                                                '',
                                      })
                                  .where((item) => item['title']!.isNotEmpty)
                                  .toList() ??
                              <Map<String, String>>[];
                          final categories = firestoreCategories.isEmpty
                              ? MarketScreen.categories
                              : firestoreCategories;
                          return StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('items')
                                .snapshots(),
                            builder: (context, itemSnapshot) => _MarketContent(
                              categories: categories,
                              items: itemSnapshot.data?.docs ?? [],
                            ),
                          );
                        },
                      ),
              ]),
            ),
          ),
        ),
      );
}

class _MarketBarakahStatusBanner extends StatelessWidget {
  const _MarketBarakahStatusBanner();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('app_settings')
          .doc('app_hours')
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();

        if (data == null) {
          return const SizedBox.shrink();
        }

        final temporarilyClosed = data['temporarilyClosed'] == true;

        final openingTime = data['openingTime']?.toString().trim() ?? '10:00';

        final closingTime = data['closingTime']?.toString().trim() ?? '03:00';

        int? parseTime(String value) {
          final parts = value.split(':');

          if (parts.length != 2) return null;

          final hour = int.tryParse(parts[0]);
          final minute = int.tryParse(parts[1]);

          if (hour == null || minute == null) return null;
          if (hour < 0 || hour > 23) return null;
          if (minute < 0 || minute > 59) return null;

          return hour * 60 + minute;
        }

        final openMinutes = parseTime(openingTime);
        final closeMinutes = parseTime(closingTime);

        if (openMinutes == null || closeMinutes == null) {
          return const SizedBox.shrink();
        }

        final now = DateTime.now();
        final nowMinutes = now.hour * 60 + now.minute;

        const dayKeys = <String>[
          'mon',
          'tue',
          'wed',
          'thu',
          'fri',
          'sat',
          'sun',
        ];

        final enabledDays = data['enabledDays'];

        bool dayEnabled(String key) {
          if (enabledDays is Map) {
            return enabledDays[key] != false;
          }
          return true;
        }

        final todayKey = dayKeys[now.weekday - 1];
        final yesterdayKey = dayKeys[(now.weekday + 5) % 7];

        final crossesMidnight = closeMinutes <= openMinutes;

        bool isOpen;

        if (temporarilyClosed) {
          isOpen = false;
        } else if (crossesMidnight) {
          isOpen = (dayEnabled(todayKey) && nowMinutes >= openMinutes) ||
              (dayEnabled(yesterdayKey) && nowMinutes < closeMinutes);
        } else {
          isOpen = dayEnabled(todayKey) &&
              nowMinutes >= openMinutes &&
              nowMinutes < closeMinutes;
        }

        String title;
        String subtitle;
        Color background;
        Color foreground;
        IconData icon;

        if (temporarilyClosed) {
          title = 'بركة مغلق مؤقتًا';

          subtitle = data['closedMessage']?.toString().trim().isNotEmpty == true
              ? data['closedMessage'].toString().trim()
              : 'لا نستقبل طلبات الآن.';

          background = const Color(0xFFFFE5E5);
          foreground = const Color(0xFFA52626);
          icon = Icons.pause_circle_filled_rounded;
        } else if (isOpen) {
          final remaining = crossesMidnight
              ? (nowMinutes >= openMinutes
                  ? (24 * 60 - nowMinutes) + closeMinutes
                  : closeMinutes - nowMinutes)
              : closeMinutes - nowMinutes;

          if (remaining <= 60) {
            title = 'بركة يغلق قريبًا';
            subtitle = 'نستقبل الطلبات حتى $closingTime';

            background = const Color(0xFFFFF3D8);
            foreground = const Color(0xFF9A6200);
            icon = Icons.schedule_rounded;
          } else {
            title = 'بركة مفتوح الآن';
            subtitle = 'نستقبل الطلبات حتى $closingTime';

            background = const Color(0xFFE8F8EF);
            foreground = const Color(0xFF167A45);
            icon = Icons.check_circle_rounded;
          }
        } else {
          final untilOpen = nowMinutes < openMinutes
              ? openMinutes - nowMinutes
              : (24 * 60 - nowMinutes) + openMinutes;

          if (dayEnabled(todayKey) && untilOpen <= 60) {
            title = 'بركة يفتح قريبًا';
            subtitle = 'يبدأ استقبال الطلبات الساعة $openingTime';

            background = const Color(0xFFFFF7CC);
            foreground = const Color(0xFF806400);
            icon = Icons.schedule_rounded;
          } else {
            title = 'بركة مغلق الآن';
            subtitle = 'يبدأ استقبال الطلبات الساعة $openingTime';

            background = const Color(0xFFF0F1F3);
            foreground = const Color(0xFF646B75);
            icon = Icons.lock_clock_rounded;
          }
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: foreground.withOpacity(.20),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: foreground,
                size: 23,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: foreground.withOpacity(.82),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MarketHeader extends StatelessWidget {
  const _MarketHeader({
    required this.location,
    required this.onLocationPressed,
    required this.onSearchPressed,
  });

  final String location;
  final VoidCallback onLocationPressed;
  final VoidCallback onSearchPressed;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 7, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFEFA),
          border: Border(
              bottom: BorderSide(color: AppTheme.coolYellow.withOpacity(.28))),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            height: 72,
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                SizedBox(
                  width: 66,
                  height: 70,
                  child: Image.asset(
                    'assets/images/barakah_profile_bunny.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(child: BarakahBrandName(compact: true)),
                Builder(
                  builder: (context) => IconButton(
                    tooltip: 'القائمة',
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                    icon: const Icon(
                      Icons.menu_rounded,
                      size: 31,
                      color: AppTheme.navy,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Row(children: [
            Expanded(
              child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: AppTheme.coolYellow.withOpacity(.55),
                  ),
                ),
                child: InkWell(
                  onTap: onSearchPressed,
                  borderRadius: BorderRadius.circular(14),
                  child: const SizedBox(
                    height: 46,
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        SizedBox(width: 14),
                        Icon(Icons.search_rounded, color: AppTheme.navy),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'ابحث عن منتج، قسم أو ماركت',
                            style: TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: onLocationPressed,
                icon: const Icon(
                  Icons.location_on_rounded,
                  size: 19,
                  color: AppTheme.deepYellow,
                ),
                label: Text(
                  location,
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: AppTheme.coolYellow.withOpacity(.55),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ),
          ]),
        ]),
      );
}

class _MarketContent extends StatelessWidget {
  const _MarketContent({required this.categories, required this.items});

  final List<Map<String, String>> categories;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> items;

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      const _MarketOfferBanner(),
      _MarketHomeStrips(fallbackCategories: categories, items: items),
      _TrendingMarketSection(items: items),
      const AdvertisementBanner(placement: 'market'),
      const SponsoredAdsFeed(placement: 'market_gallery'),
      const AdvertisementBanner(placement: 'market_between_1'),
    ];
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 28),
      itemCount: sections.length,
      separatorBuilder: (_, __) => const SizedBox(height: 24),
      itemBuilder: (_, index) => sections[index],
    );
  }
}

class _MarketHomeStrips extends StatelessWidget {
  const _MarketHomeStrips({
    required this.fallbackCategories,
    required this.items,
  });

  final List<Map<String, String>> fallbackCategories;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> items;

  @override
  Widget build(BuildContext context) {
    if (!FirebaseState.isReady) {
      return _MarketCategoriesStrip(
        title: 'سوق بركة',
        categories: fallbackCategories,
      );
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('home_category_strips')
          .snapshots(),
      builder: (context, snapshot) {
        final strips = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data();
          return data['surface'] == 'market' && data['enabled'] != false;
        }).toList()
          ..sort(
              (a, b) => ((a.data()['order'] as num?)?.toInt() ?? 0).compareTo(
                    (b.data()['order'] as num?)?.toInt() ?? 0,
                  ));

        if (strips.isEmpty) {
          return _MarketCategoriesStrip(
            title: 'سوق بركة',
            categories: fallbackCategories,
          );
        }

        return Column(
          children: [
            for (var index = 0; index < strips.length; index++) ...[
              if (index > 0) const SizedBox(height: 22),
              Builder(builder: (context) {
                final data = strips[index].data();
                final title = data['title']?.toString() ?? 'سوق بركة';
                final isBestSelling = data['stripType'] == 'bestSelling' ||
                    title.contains('مبيع');
                if (isBestSelling) {
                  return _BestSellingProductsStrip(
                    title: title,
                    items: items,
                  );
                }
                if (data['stripType'] == 'custom') {
                  final customItems =
                      ((data['customItems'] as List?) ?? const [])
                          .whereType<Map>()
                          .map((item) => Map<String, dynamic>.from(item))
                          .toList();
                  return _CustomMarketStrip(
                    title: title,
                    items: customItems,
                  );
                }
                final selected = ((data['categoryIds'] as List?) ?? const [])
                    .map((value) => value.toString())
                    .toSet();
                final showAll = data['showAllCategories'] == true ||
                    title.trim() == 'سوق بركة';
                final visible = showAll
                    ? fallbackCategories
                    : fallbackCategories
                        .where((category) => selected.contains(category['id']))
                        .toList();
                return _MarketCategoriesStrip(
                  title: title,
                  categories: visible,
                );
              }),
            ],
          ],
        );
      },
    );
  }
}

class _CustomMarketStrip extends StatelessWidget {
  const _CustomMarketStrip({
    required this.title,
    required this.items,
  });

  final String title;
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              title,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 158,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 11),
            itemBuilder: (context, index) {
              final item = items[index];
              final image = item['image']?.toString() ?? '';
              final heroTag = 'custom-market-${image.hashCode}-$index';
              return GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _CustomMarketItemScreen(
                      item: item,
                      heroTag: heroTag,
                    ),
                  ),
                ),
                child: SizedBox(
                  width: 112,
                  child: Column(
                    children: [
                      Hero(
                        tag: heroTag,
                        child: Container(
                          width: 98,
                          height: 98,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.deepYellow,
                              width: 1.2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x26071B3C),
                                blurRadius: 15,
                                offset: Offset(0, 7),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: image.startsWith('http')
                                ? Image.network(
                                    image,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.auto_awesome_rounded,
                                      color: AppTheme.deepYellow,
                                    ),
                                  )
                                : Image.asset(
                                    image,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.auto_awesome_rounded,
                                      color: AppTheme.deepYellow,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['title']?.toString() ?? 'بطاقة',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CustomMarketItemScreen extends StatelessWidget {
  const _CustomMarketItemScreen({
    required this.item,
    required this.heroTag,
  });

  final Map<String, dynamic> item;
  final String heroTag;

  Future<void> _openDestination(BuildContext context, String value) async {
    final normalized = value.contains('://') ? value : 'https://$value';
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الرابط حالياً.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = item['title']?.toString() ?? 'بركة';
    final description = item['description']?.toString().trim() ?? '';
    final image = item['image']?.toString() ?? '';
    final destination = item['destinationUrl']?.toString().trim() ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFFFFCF5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.navy,
        elevation: 0,
        title: const Text(
          'قريباً في بركة',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
          children: [
            Hero(
              tag: heroTag,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: AspectRatio(
                  aspectRatio: 1.1,
                  child: image.startsWith('http')
                      ? Image.network(image, fit: BoxFit.cover)
                      : Image.asset(image, fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppTheme.coolYellow.withOpacity(.25),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    'قريباً',
                    style: TextStyle(
                      color: AppTheme.navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.local_fire_department_rounded,
                    color: AppTheme.deepYellow, size: 30),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppTheme.navy,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                description,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 16,
                  height: 1.7,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (destination.isNotEmpty) ...[
              const SizedBox(height: 26),
              FilledButton.icon(
                onPressed: () => _openDestination(context, destination),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.navy,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.arrow_outward_rounded),
                label: const Text(
                  'فتح الوجهة',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BestSellingProductsStrip extends StatelessWidget {
  const _BestSellingProductsStrip({
    required this.title,
    required this.items,
  });

  final String title;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> items;

  @override
  Widget build(BuildContext context) {
    final products = items.where((doc) {
      final data = doc.data();
      return data['type']?.toString().toLowerCase() == 'market' &&
          data['kind']?.toString() == 'product' &&
          data['isActive'] != false;
    }).toList()
      ..sort((a, b) {
        final salesCompare =
            ((b.data()['salesCount'] as num?)?.toInt() ?? 0).compareTo(
          (a.data()['salesCount'] as num?)?.toInt() ?? 0,
        );
        if (salesCompare != 0) return salesCompare;
        return ((b.data()['rating'] as num?)?.toDouble() ?? 0).compareTo(
          (a.data()['rating'] as num?)?.toDouble() ?? 0,
        );
      });
    final visible = products.take(12).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              title,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 205,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: visible.length,
            separatorBuilder: (_, __) => const SizedBox(width: 11),
            itemBuilder: (context, index) {
              final product = visible[index];
              final data = product.data();
              final image = data['image']?.toString() ?? '';
              final sales = (data['salesCount'] as num?)?.toInt() ?? 0;
              final price = data['price'] ?? 0;
              return SizedBox(
                width: 148,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      try {
                        CartService.instance.addProduct(product.id, data);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'تمت إضافة ${data['title'] ?? 'الصنف'} إلى السلة',
                            ),
                          ),
                        );
                      } on StateError catch (error) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(error.message.toString()),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (image.startsWith('http'))
                                Image.network(
                                  image,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.shopping_bag_rounded,
                                    color: AppTheme.deepYellow,
                                  ),
                                )
                              else if (image.isNotEmpty)
                                Image.asset(image, fit: BoxFit.cover)
                              else
                                const ColoredBox(
                                  color: Color(0xFFFFF8E2),
                                  child: Icon(
                                    Icons.shopping_bag_rounded,
                                    color: AppTheme.deepYellow,
                                    size: 42,
                                  ),
                                ),
                              PositionedDirectional(
                                top: 7,
                                start: 7,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.navy.withOpacity(.88),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    sales > 0 ? 'بيع $sales' : 'الأكثر طلباً',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(9, 7, 9, 9),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['title']?.toString() ?? 'صنف',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      '$price ₪',
                                      style: const TextStyle(
                                        color: AppTheme.deepYellow,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.add_circle_rounded,
                                color: AppTheme.navy,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MarketCategoriesStrip extends StatelessWidget {
  const _MarketCategoriesStrip({
    required this.title,
    required this.categories,
  });

  final String title;
  final List<Map<String, String>> categories;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              title,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 150,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final category = categories[index];
              final title = category['title'] ?? '';
              final image = category['image'] ?? category['imageUrl'] ?? '';
              final description = category['desc'] ?? '';

              Widget categoryImage;

              if (image.isEmpty) {
                categoryImage = const Center(
                  child: Icon(
                    Icons.storefront_rounded,
                    color: Colors.black,
                    size: 34,
                  ),
                );
              } else if (image.startsWith('http://') ||
                  image.startsWith('https://')) {
                categoryImage = Image.network(
                  image,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(
                      Icons.storefront_rounded,
                      color: Colors.black,
                      size: 34,
                    ),
                  ),
                );
              } else {
                categoryImage = Image.asset(
                  image,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(
                      Icons.storefront_rounded,
                      color: Colors.black,
                      size: 34,
                    ),
                  ),
                );
              }

              return SizedBox(
                width: 108,
                child: InkWell(
                  borderRadius: BorderRadius.circular(70),
                  onTap: () {
                    AnalyticsService.instance.recordCategoryView(title);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoriesScreen(
                          title: title,
                          image: image,
                          description: description,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 94,
                        height: 94,
                        padding: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.deepYellow,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(.50),
                              blurRadius: 11,
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: const Color(0xFF9DD6FF).withOpacity(.18),
                              blurRadius: 18,
                              spreadRadius: 0,
                            ),
                            BoxShadow(
                              color: const Color(0xFF061326).withOpacity(.42),
                              blurRadius: 20,
                              offset: const Offset(0, 9),
                            ),
                          ],
                        ),
                        child: Container(
                          padding: EdgeInsets.zero,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(.48),
                                const Color(0xFFD9EFFF).withOpacity(.18),
                                Colors.white.withOpacity(.08),
                              ],
                            ),
                            border: Border.all(color: Colors.transparent),
                          ),
                          child: Container(
                            padding: EdgeInsets.zero,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(.32),
                                  const Color(0xFF79BFFF).withOpacity(.10),
                                  Colors.transparent,
                                ],
                              ),
                              border: Border.all(color: Colors.transparent),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipOval(
                                  child: categoryImage,
                                ),

                                // طبقة Liquid Glass فوق الصورة
                                IgnorePointer(
                                  child: ClipOval(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          stops: const [
                                            0.00,
                                            0.18,
                                            0.40,
                                            0.72,
                                            1.00,
                                          ],
                                          colors: [
                                            Colors.white.withOpacity(.38),
                                            Colors.white.withOpacity(.12),
                                            Colors.transparent,
                                            Colors.transparent,
                                            Colors.white.withOpacity(.05),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // لمعة علوية قوية
                                Positioned(
                                  top: 7,
                                  left: 23,
                                  right: 23,
                                  child: Container(
                                    height: 9,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30),
                                      gradient: LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Colors.white.withOpacity(.04),
                                          Colors.white.withOpacity(.58),
                                          Colors.white.withOpacity(.06),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white.withOpacity(.42),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // لمعة جانبية
                                Positioned(
                                  top: 27,
                                  left: 6,
                                  child: Container(
                                    width: 5,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.white.withOpacity(.48),
                                          Colors.white.withOpacity(.02),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // لمعة سفلية
                                Positioned(
                                  bottom: 7,
                                  left: 30,
                                  right: 30,
                                  child: Container(
                                    height: 5,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      color: Colors.white.withOpacity(.25),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MarketOfferBanner extends StatelessWidget {
  const _MarketOfferBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const _MarketOffersScreen(),
                ),
              );
            },
            child: Image.asset(
              'assets/images/offers/market_offers.png',
              width: double.infinity,
              height: 150,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}

class _MarketOffersScreen extends StatelessWidget {
  const _MarketOffersScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F6EE),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF172B4D)),
        title: const Text(
          'عروض الماركت',
          style: TextStyle(
            color: Color(0xFF172B4D),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/images/offers/market_offers.png',
              width: double.infinity,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '🔥 أحدث عروض الماركت',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF172B4D),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'ستظهر هنا عروض الماركت التي يتم إضافتها من لوحة الإدارة.',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 15, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _TrendingMarketSection extends StatelessWidget {
  const _TrendingMarketSection({required this.items});
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> items;

  @override
  Widget build(BuildContext context) {
    final marketItems = items
        .where((item) =>
            item.data()['type']?.toString().toLowerCase() == 'market' &&
            item.data()['kind']?.toString() != 'product' &&
            item.data()['isTrending'] == true)
        .toList();
    marketItems.sort((a, b) {
      final right = (b.data()['rating'] as num?)?.toDouble() ?? 0;
      final left = (a.data()['rating'] as num?)?.toDouble() ?? 0;
      return right.compareTo(left);
    });
    if (marketItems.isEmpty) return const SizedBox.shrink();
    return _MarketSection(
      title: 'ترندات',
      image: '',
      description: '',
      items: marketItems,
      isTrendingSection: true,
    );
  }
}

class _MarketSection extends StatelessWidget {
  const _MarketSection({
    required this.title,
    required this.image,
    required this.description,
    required this.items,
    this.isTrendingSection = false,
  });

  final String title;
  final String image;
  final String description;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> items;
  final bool isTrendingSection;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Expanded(
                child: Row(children: [
                  if (isTrendingSection) ...[
                    const Icon(Icons.local_fire_department_rounded,
                        color: Color(0xFFFF8A00)),
                    const SizedBox(width: 5),
                  ],
                  Text(title,
                      style: const TextStyle(
                          fontSize: 25, fontWeight: FontWeight.w900)),
                ]),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => isTrendingSection
                            ? const AllItemsScreen(
                                trendingOnly: true, itemType: 'market')
                            : CategoriesScreen(
                                title: title,
                                image: image,
                                description: description,
                              ))),
                child: const Text('عرض الكل',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, constraints) {
            // على الجوال يظهر الكرت بعرض الشاشة تقريباً، وعلى الشاشات الكبيرة
            // يتوقف عند عرض مريح كي لا يصبح عريضاً جداً.
            final cardWidth =
                (constraints.maxWidth * .68).clamp(220.0, 310.0).toDouble();
            final cardHeight = cardWidth * .72;
            return SizedBox(
              height: cardHeight,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: items.isEmpty ? 1 : items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) => items.isEmpty
                    ? _MarketCard(
                        width: cardWidth,
                        title: title,
                        image: image,
                        subtitle: description,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => CategoriesScreen(
                                      title: title,
                                      image: image,
                                      description: description,
                                    ))),
                      )
                    : _MarketCard(
                        width: cardWidth,
                        title:
                            items[index].data()['title']?.toString() ?? title,
                        image:
                            items[index].data()['image']?.toString() ?? image,
                        subtitle:
                            items[index].data()['description']?.toString() ??
                                '',
                        rating: items[index].data()['rating'],
                        isTrending: items[index].data()['isTrending'] == true,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => RestaurantDetailsScreen(
                                    restaurant: items[index]))),
                      ),
              ),
            );
          }),
        ],
      );
}

class _MarketCard extends StatelessWidget {
  const _MarketCard({
    required this.width,
    required this.title,
    required this.image,
    required this.subtitle,
    required this.onTap,
    this.rating,
    this.isTrending = false,
  });

  final double width;
  final String title;
  final String image;
  final String subtitle;
  final Object? rating;
  final bool isTrending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Material(
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(fit: StackFit.expand, children: [
              image.isEmpty
                  ? const ColoredBox(
                      color: AppTheme.coolYellow,
                      child: Icon(Icons.storefront_rounded,
                          size: 64, color: AppTheme.ink))
                  : image.startsWith('assets/')
                      ? Image.asset(image, fit: BoxFit.cover)
                      : Image.network(image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                              color: AppTheme.coolYellow,
                              child: Icon(Icons.broken_image_outlined,
                                  size: 60, color: AppTheme.ink))),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(.05),
                      Colors.black.withOpacity(.72),
                    ],
                  ),
                ),
              ),
              if (isTrending)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.9),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Text('🔥 ترند',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
                      color: Colors.black.withOpacity(.25),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900)),
                            Text(
                                subtitle.isEmpty
                                    ? 'تسوّق الآن من بركة'
                                    : subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 5),
                            Row(children: [
                              const Icon(Icons.star_rounded,
                                  color: Color(0xFFFFD15C), size: 18),
                              const SizedBox(width: 4),
                              Text(rating?.toString() ?? 'جديد',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900)),
                              const Spacer(),
                              const Text('متوفر',
                                  style: TextStyle(
                                      color: Color(0xFF70E6AF),
                                      fontWeight: FontWeight.w900)),
                            ]),
                          ]),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
}

class _MarketMenu extends StatelessWidget {
  const _MarketMenu();

  @override
  Widget build(BuildContext context) => Drawer(
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.all(16), children: const [
            ListTile(
              leading:
                  Icon(Icons.storefront_rounded, color: AppTheme.deepYellow),
              title: Text('ماركت بركة',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              subtitle: Text('تصفح الأقسام والمتاجر القريبة'),
            ),
            Divider(),
            ListTile(
                leading: Icon(Icons.local_offer_outlined),
                title: Text('العروض')),
            ListTile(
                leading: Icon(Icons.favorite_border), title: Text('المفضلة')),
          ]),
        ),
      );
}
