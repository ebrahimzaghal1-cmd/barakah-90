import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firebase_state.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_page.dart';
import '../widgets/advertisement_banner.dart';
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
            child: Column(children: [
              _MarketHeader(
                location: _location,
                onLocationPressed: _chooseLocation,
                onSearchPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AllItemsScreen(autoFocus: true))),
              ),
              Expanded(
                child: !FirebaseState.isReady
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
              ),
            ]),
          ),
        ),
      );
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
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.82),
          border:
              Border(bottom: BorderSide(color: Colors.black.withOpacity(.05))),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/images/barakah_header_bunny.png',
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
                const SizedBox(width: 10),
                const Flexible(
                  child: BarakahBrandName(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            IconButton(
              tooltip: 'بحث',
              onPressed: onSearchPressed,
              icon: const Icon(Icons.search_rounded, size: 31),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onLocationPressed,
                icon: const Icon(Icons.home_work_outlined,
                    color: AppTheme.deepYellow),
                label: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(location,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const Text('اختر موقع التوصيل',
                      style: TextStyle(fontSize: 11, color: Colors.black54)),
                ]),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  side: BorderSide(color: AppTheme.coolYellow.withOpacity(.7)),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Builder(
              builder: (context) => IconButton(
                tooltip: 'القائمة',
                onPressed: () => Scaffold.of(context).openEndDrawer(),
                icon: const Icon(Icons.menu_rounded, size: 32),
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
      _TrendingMarketSection(items: items),
      ...categories.map((category) {
        final title = category['title']!;
        return _MarketSection(
          title: title,
          image: category['image'] ?? '',
          description: category['desc'] ?? '',
          items: items
              .where((item) =>
                  item.data()['category']?.toString().trim() == title &&
                  item.data()['kind']?.toString() != 'product')
              .toList(),
        );
      }),
    ];
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 28),
      itemCount: sections.length,
      separatorBuilder: (_, __) => const SizedBox(height: 24),
      itemBuilder: (_, index) => sections[index],
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
                (constraints.maxWidth - 40).clamp(300.0, 460.0).toDouble();
            final cardHeight = cardWidth * .60;
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
