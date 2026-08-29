import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../widgets/responsive_page.dart';
import '../widgets/restaurant_card.dart';
import '../widgets/barakah_brand.dart';
import '../widgets/barakah_media_image.dart';
import '../widgets/barakah_online_status_button.dart';
import '../widgets/advertisement_banner.dart';
import '../services/admin_notification_service.dart';
import '../services/firebase_state.dart';
import '../services/analytics_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../games/play_hub_screen.dart';
import 'categories_screen.dart';
import 'restaurant_details_screen.dart';
import 'authentication_screen.dart';
import 'restaurant_offers_screen.dart';
import 'location_picker_screen.dart';

const _barakahNavy = Color(0xFF071B3C);
const _barakahGold = Color(0xFFD7A928);

class RestaurantsScreen extends StatefulWidget {
  const RestaurantsScreen({super.key});

  @override
  State<RestaurantsScreen> createState() => _RestaurantsScreenState();
}

class _RestaurantsScreenState extends State<RestaurantsScreen> {
  String _query = '';
  String _selectedArea = 'اكتشف أفضل ما حولك';
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.recordAppVisit();
  }

  static const _areas = [
    'طولكرم',
    'الشعراوية',
    'قلقيلية',
    'رام الله',
    'نابلس',
    'الخليل',
    'القدس',
  ];

  String _closestArea(double latitude, double longitude) {
    const cities = {
      'طولكرم': [32.3090, 35.0285],
      'الشعراوية': [32.3923, 35.0881],
      'قلقيلية': [32.1967, 34.9811],
      'رام الله': [31.9038, 35.2034],
      'نابلس': [32.2211, 35.2544],
      'الخليل': [31.5326, 35.0998],
      'القدس': [31.7683, 35.2137],
    };
    var nearest = 'موقعي الحالي';
    var bestDistance = double.infinity;
    for (final entry in cities.entries) {
      final point = entry.value;
      final distance = LocationService.distanceBetween(
          latitude, longitude, point[0], point[1]);
      if (distance < bestDistance) {
        bestDistance = distance;
        nearest = entry.key;
      }
    }
    return bestDistance <= 35000 ? nearest : 'موقعي الحالي';
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final position = await LocationService.getCurrentLocation();
      if (!mounted) return;
      setState(() =>
          _selectedArea = _closestArea(position.latitude, position.longitude));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_selectedArea == 'موقعي الحالي'
            ? 'تم تحديد موقعك الحقيقي بنجاح.'
            : 'تم تحديد موقعك: $_selectedArea'),
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'تعذر تحديد الموقع. فعّلي GPS واسمحي لتطبيق بركة باستخدام الموقع.'),
      ));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _chooseArea() async {
    final location = await Navigator.push<Map<String, double>>(
      context,
      MaterialPageRoute(
        builder: (_) => const LocationPickerScreen(),
      ),
    );
    if (location == null || !mounted) return;
    setState(() {
      _selectedArea = _closestArea(
        location['latitude']!,
        location['longitude']!,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/profile_gold_background.jpg',
            fit: BoxFit.cover,
          ),
          const ColoredBox(color: Color(0xD9FFFCF5)),
          ResponsivePage(
            child: SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TurquoiseHomeHeader(
                            onSearchChanged: (value) => setState(
                              () => _query = value.trim().toLowerCase(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const AdvertisementBanner(
                            placement: 'restaurants_top',
                          ),
                          const SizedBox(height: 10),
                          const _OfferBanner(),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                              child: Material(
                                color: _barakahNavy,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  onTap: _chooseArea,
                                  borderRadius: BorderRadius.circular(18),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 11),
                                    child: Row(children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: const BoxDecoration(
                                          color: Color(0x2EFFFFFF),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _locating
                                              ? Icons.gps_fixed_rounded
                                              : Icons.location_on_outlined,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                _locating
                                                    ? 'جارٍ تحديد موقعك...'
                                                    : _selectedArea,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w900)),
                                            const Text(
                                                'اضغط لتحديد موقعك أو تغيير المدينة',
                                                style: TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: Colors.white,
                                      ),
                                    ]),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              tooltip: 'تفعيل الإشعارات',
                              onPressed: () async {
                                final enabled = await AdminNotificationService
                                    .instance
                                    .requestPermissionForCurrentUser();

                                if (!context.mounted) return;

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      enabled
                                          ? 'تم تفعيل إشعارات بركة على هذا الجهاز ✅'
                                          : 'لم يتم تفعيل الإشعارات. تأكد من السماح بها من إعدادات المتصفح أو الجهاز.',
                                    ),
                                    backgroundColor:
                                        enabled ? Colors.green : Colors.orange,
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.notifications_none_rounded,
                                color: _barakahGold,
                              ),
                            ),
                          ]),
                          const SizedBox(height: 14),
                          const SponsoredAdsFeed(
                            placement: 'restaurants_gallery',
                          ),
                          const SizedBox(height: 14),
                          const AdvertisementBanner(
                            placement: 'restaurants_between_1',
                          ),
                          const SizedBox(height: 22),
                          const _RestaurantHomeStrips(),
                          const SizedBox(height: 10),
                          const _TurquoiseQuickLinks(),
                          const SizedBox(height: 14),
                          const AdvertisementBanner(
                            placement: 'restaurants_between_2',
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'أقسام المطاعم',
                            style: TextStyle(
                              color: AppTheme.ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const SizedBox(
                            height: 154,
                            child: _FallbackCategories(),
                          ),
                          const SizedBox(height: 14),
                          const AdvertisementBanner(
                            placement: 'restaurants_between_3',
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'المطاعم المفضلة لديكم',
                            style: TextStyle(
                              color: AppTheme.ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const SizedBox(
                            height: 230,
                            child: _RestaurantsQuickRow(),
                          ),
                          const SizedBox(height: 14),
                          const AdvertisementBanner(
                            placement: 'restaurants_between_4',
                          ),
                          const SizedBox(height: 22),
                          const AdvertisementBanner(
                            placement: 'restaurants_between_5',
                          ),
                          Row(children: [
                            const Text('ترندات',
                                style: TextStyle(
                                    fontSize: 19, fontWeight: FontWeight.w800)),
                            const Spacer(),
                            TextButton(
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const AllItemsScreen(
                                          trendingOnly: true))),
                              child: const Text('عرض الكل',
                                  style: TextStyle(
                                      color: Color(0xFF007BFF),
                                      fontWeight: FontWeight.bold)),
                            )
                          ]),
                          const SizedBox(height: 8),
                          const AdvertisementBanner(
                            placement: 'restaurants_between_6',
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  if (!FirebaseState.isReady)
                    _StaticCatalogue(query: _query)
                  else
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('items')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SliverFillRemaining(
                              child:
                                  Center(child: CircularProgressIndicator()));
                        }
                        final docs = snapshot.data?.docs ?? [];

                        String normalizeSearch(dynamic value) {
                          var text = value.toString().toLowerCase();

                          const replacements = {
                            'أ': 'ا',
                            'إ': 'ا',
                            'آ': 'ا',
                            'ٱ': 'ا',
                            'ى': 'ي',
                            'ؤ': 'و',
                            'ئ': 'ي',
                            'ـ': '',
                          };

                          replacements.forEach((from, to) {
                            text = text.replaceAll(from, to);
                          });

                          text = text.replaceAll(
                            RegExp(r'[\u064B-\u065F\u0670]'),
                            '',
                          );

                          text = text.replaceAll(
                            RegExp(r'\s+'),
                            ' ',
                          );

                          return text.trim();
                        }

                        final normalizedQuery = normalizeSearch(_query);

                        bool matchesValue(dynamic value) {
                          if (normalizedQuery.isEmpty) return true;
                          if (value == null) return false;

                          if (value is Map) {
                            return value.values.any(matchesValue);
                          }

                          if (value is Iterable) {
                            return value.any(matchesValue);
                          }

                          return normalizeSearch(value)
                              .contains(normalizedQuery);
                        }

                        // المنتجات المطابقة للبحث.
                        final matchingProductBusinessIds = docs
                            .where((doc) {
                              final data = doc.data();

                              return data['kind']?.toString().toLowerCase() ==
                                      'product' &&
                                  matchesValue(data);
                            })
                            .map(
                              (doc) =>
                                  doc.data()['businessId']?.toString().trim() ??
                                  '',
                            )
                            .where((id) => id.isNotEmpty)
                            .toSet();

                        // المطاعم نفسها.
                        final restaurants = docs.where((doc) {
                          final data = doc.data();

                          final kind = data['kind']?.toString().toLowerCase();

                          if (kind == 'product') {
                            return false;
                          }

                          final type =
                              data['type']?.toString().toLowerCase().trim();

                          final isRestaurant = type == null ||
                              type.isEmpty ||
                              type == 'restaurant' ||
                              type == 'restaurants';

                          if (!isRestaurant) {
                            return false;
                          }

                          if (normalizedQuery.isEmpty) {
                            return true;
                          }

                          // يظهر المطعم إذا:
                          // 1- بيانات المطعم نفسه مطابقة
                          // 2- أو يوجد منتج مطابق تابع له
                          return matchesValue(data) ||
                              matchingProductBusinessIds.contains(doc.id);
                        }).toList();

                        final results = normalizedQuery.isEmpty
                            ? restaurants
                                .where(
                                  (item) => item.data()['isTrending'] == true,
                                )
                                .toList()
                            : restaurants;

                        if (results.isEmpty) {
                          return SliverFillRemaining(
                            child: Center(
                              child: Text(
                                _query.isEmpty
                                    ? 'لا توجد مطاعم في الترندات حالياً.'
                                    : 'ما لقينا نتائج لـ "$_query"',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                          );
                        }

                        final columns =
                            MediaQuery.sizeOf(context).width >= 700 ? 3 : 2;
                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          sliver: SliverGrid(
                            delegate:
                                SliverChildBuilderDelegate((context, index) {
                              final item = results[index];
                              return GestureDetector(
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => RestaurantDetailsScreen(
                                            restaurant: item))),
                                child: RestaurantCard(restaurant: item),
                              );
                            }, childCount: results.length),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: .66),
                          ),
                        );
                      },
                    ),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: AdvertisementBanner(
                        placement: 'restaurants_between_7',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AllItemsScreen extends StatefulWidget {
  const AllItemsScreen(
      {super.key,
      this.trendingOnly = false,
      this.autoFocus = false,
      this.itemType = 'restaurant'});

  final bool trendingOnly;
  final bool autoFocus;
  final String itemType;

  @override
  State<AllItemsScreen> createState() => _AllItemsScreenState();
}

class _TurquoiseHomeHeader extends StatelessWidget {
  const _TurquoiseHomeHeader({required this.onSearchChanged});

  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        height: 112,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          image: const DecorationImage(
            image: AssetImage(
              'assets/images/barakah_gold_header_bunny_16.png',
            ),
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
          ),
          border: Border.all(color: const Color(0xFFE7BE4D), width: 1.4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x330A1C39),
              blurRadius: 18,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(),
          child: Stack(
            children: [
              const Positioned(
                left: 0,
                right: 0,
                bottom: 17,
                child: Center(
                  child: SizedBox(
                    width: 178,
                    child: BarakahBrandName(light: true, compact: true),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                bottom: 14,
                child: Material(
                  color: const Color(0x33071B3C),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'البحث',
                    onPressed: () => _openSearch(context),
                    icon: const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const Positioned(
                left: 78,
                bottom: 18,
                child: BarakahOnlineStatusButton(),
              ),
            ],
          ),
        ),
      );

  Future<void> _openSearch(BuildContext context) async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          4,
          18,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 22,
        ),
        child: TextField(
          controller: controller,
          autofocus: true,
          onChanged: onSearchChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'ابحث عن مطعم، تصنيف أو وجبة',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(
              tooltip: 'إغلاق',
              onPressed: () => Navigator.pop(sheetContext),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ),
      ),
    );
    controller.dispose();
  }
}

class _TurquoiseQuickLinks extends StatelessWidget {
  const _TurquoiseQuickLinks();

  @override
  Widget build(BuildContext context) {
    Widget link(String title, IconData icon, VoidCallback onTap) => Expanded(
          child: Material(
            color: _barakahNavy,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onTap,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

    return Row(
      children: [
        link(
          'المطاعم',
          Icons.restaurant_rounded,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AllItemsScreen()),
          ),
        ),
        const SizedBox(width: 8),
        link(
          'التصنيفات',
          Icons.grid_view_rounded,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const _AllRestaurantCategoriesScreen(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        link(
          'عروض الماركت',
          Icons.shopping_cart_outlined,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AllItemsScreen(itemType: 'market'),
            ),
          ),
        ),
      ],
    );
  }
}

class _AllRestaurantCategoriesScreen extends StatelessWidget {
  const _AllRestaurantCategoriesScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFFFFCF5),
        appBar: AppBar(
          title: const Text(
            'تصنيفات المطاعم',
            style: TextStyle(
              color: AppTheme.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: AppTheme.navy),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('restaurant_categories')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'تعذر تحميل التصنيفات حالياً.',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              );
            }

            final docs = (snapshot.data?.docs ?? []).where((doc) {
              return doc.data()['enabled'] != false;
            }).toList()
              ..sort((a, b) {
                final aOrder = (a.data()['order'] as num?)?.toInt() ?? 9999;
                final bOrder = (b.data()['order'] as num?)?.toInt() ?? 9999;
                return aOrder.compareTo(bOrder);
              });

            if (docs.isEmpty) {
              return const Center(
                child: Text(
                  'لا توجد تصنيفات مطاعم حالياً.',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              itemCount: docs.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.08,
              ),
              itemBuilder: (context, index) {
                final data = docs[index].data();
                final title = data['title']?.toString().trim() ?? '';
                final image = data['image']?.toString().trim() ?? '';
                final description =
                    (data['description'] ?? data['desc'])?.toString().trim() ??
                        '';
                return _HomeCategoryTile(
                  title: title.isEmpty ? 'قسم' : title,
                  image: image,
                  description: description,
                );
              },
            );
          },
        ),
      );
}

class _AllItemsScreenState extends State<AllItemsScreen> {
  String _query = '';

  bool _matches(Map<String, dynamic> data) {
    if (_query.isEmpty) return true;
    String normalize(dynamic value) {
      var text = value?.toString().toLowerCase() ?? '';
      const replacements = {
        'أ': 'ا',
        'إ': 'ا',
        'آ': 'ا',
        'ٱ': 'ا',
        'ى': 'ي',
        'ؤ': 'و',
        'ئ': 'ي',
        'ة': 'ه',
        'ـ': '',
      };
      replacements.forEach((from, to) => text = text.replaceAll(from, to));
      return text.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '').trim();
    }

    final query = normalize(_query);
    final aliases = <String, List<String>>{
      'خضار': ['خضروات', 'خضره', 'فواكه', 'ماركت', 'سوبرماركت'],
      'خبز': ['مخبز', 'معجنات'],
      'لحم': ['لحوم', 'ملحمه'],
      'حلو': ['حلويات', 'كنافه'],
    };
    final terms = <String>{query};
    for (final entry in aliases.entries) {
      final key = normalize(entry.key);
      final values = entry.value.map(normalize);
      if (query.contains(key) || values.any((value) => query.contains(value))) {
        terms.add(key);
        terms.addAll(values);
      }
    }

    bool contains(dynamic value) {
      if (value == null) return false;
      if (value is Map) return value.values.any(contains);
      if (value is Iterable) return value.any(contains);
      final text = normalize(value);
      return terms.any((term) => text.contains(term) || term.contains(text));
    }

    return data.values.any(contains);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            AppBar(title: Text(widget.trendingOnly ? 'كل الترندات' : 'البحث')),
        backgroundColor: Colors.transparent,
        body: BarakahBrandBackdrop(
          child: SafeArea(
            top: false,
            child: Column(children: [
              if (!widget.trendingOnly)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    autofocus: widget.autoFocus,
                    onChanged: (value) => setState(() => _query = value.trim()),
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w700,
                    ),
                    cursorColor: AppTheme.coolYellow,
                    decoration: InputDecoration(
                      hintText: 'ابحث عن محل أو مطعم أو منتج',
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintStyle: const TextStyle(color: Colors.black54),
                      prefixIconColor: AppTheme.coolYellow,
                      filled: true,
                      fillColor: Colors.white.withOpacity(.76),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('items')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final allItems = snapshot.data?.docs ?? [];
                    final businesses = allItems.where((doc) {
                      final data = doc.data();
                      final type = data['type']?.toString().toLowerCase();
                      return data['kind']?.toString() != 'product' &&
                          (type == widget.itemType ||
                              (type == null &&
                                  widget.itemType == 'restaurant'));
                    }).toList();
                    final items = (widget.trendingOnly
                            ? businesses.where(
                                (doc) => doc.data()['isTrending'] == true)
                            : allItems)
                        .where((item) => _matches(item.data()))
                        .toList();
                    if (widget.trendingOnly) {
                      items.sort((a, b) {
                        final right =
                            (b.data()['rating'] as num?)?.toDouble() ?? 0;
                        final left =
                            (a.data()['rating'] as num?)?.toDouble() ?? 0;
                        return right.compareTo(left);
                      });
                    }
                    if (items.isEmpty) {
                      return Center(
                          child: Text(_query.isEmpty
                              ? 'لا توجد عناصر حالياً'
                              : 'لا توجد نتائج مطابقة للبحث.'));
                    }
                    return LayoutBuilder(builder: (context, constraints) {
                      // نستخدم عرض الصفحة الفعلي دائماً، حتى لا تظهر مساحة فارغة
                      // على الأجهزة الكبيرة أو عند تغيير اتجاه الشاشة.
                      final columns = constraints.maxWidth >= 700 ? 3 : 2;
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                        itemCount: items.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: .66,
                        ),
                        itemBuilder: (context, index) => GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => RestaurantDetailsScreen(
                                      restaurant: items[index]))),
                          child: RestaurantCard(restaurant: items[index]),
                        ),
                      );
                    });
                  },
                ),
              ),
            ]),
          ),
        ),
      );
}

class _OfferBanner extends StatelessWidget {
  const _OfferBanner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const RestaurantOffersScreen(),
          ),
        ),
        child: Container(
          height: 150,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF071B3C), Color(0xFF12345B)],
            ),
            borderRadius: BorderRadius.zero,
            boxShadow: [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                left: -8,
                bottom: -8,
                width: 155,
                height: 150,
                child: Image.asset(
                  'assets/images/barakah_discount.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
              Positioned(
                left: 92,
                bottom: 16,
                child: Transform.rotate(
                  angle: -0.08,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD100),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Text(
                      'خصومات بركة',
                      style: TextStyle(
                        color: AppTheme.navy,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned(
                right: 22,
                top: 26,
                left: 175,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'عروض اليوم',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Color(0xFFFFD100),
                        fontWeight: FontWeight.w900,
                        fontSize: 25,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'وفر حتى 79% على اختياراتك المفضلة',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.white,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestaurantsQuickRow extends StatelessWidget {
  const _RestaurantsQuickRow();

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseState.isReady
            ? FirebaseFirestore.instance.collection('items').snapshots()
            : const Stream.empty(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final restaurants = (snapshot.data?.docs ?? []).where((doc) {
            final data = doc.data();

            if (data['kind']?.toString().toLowerCase() == 'product') {
              return false;
            }

            final type = data['type']?.toString().toLowerCase().trim();

            return type == null ||
                type.isEmpty ||
                type == 'restaurant' ||
                type == 'restaurants';
          }).toList();

          if (restaurants.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد مطاعم حالياً',
                style: TextStyle(
                  color: AppTheme.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          }

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: restaurants.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final restaurant = restaurants[index];

              return SizedBox(
                width: 170,
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RestaurantDetailsScreen(
                        restaurant: restaurant,
                      ),
                    ),
                  ),
                  child: RestaurantCard(
                    restaurant: restaurant,
                  ),
                ),
              );
            },
          );
        },
      );
}

class _RestaurantHomeStrips extends StatelessWidget {
  const _RestaurantHomeStrips();

  Widget _fallback() => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'شو مخبيلك بركة اليوم🤔',
            style: TextStyle(
              color: AppTheme.ink,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 12),
          SizedBox(height: 145, child: _CategoriesRow()),
        ],
      );

  @override
  Widget build(BuildContext context) {
    if (!FirebaseState.isReady) return _fallback();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('home_category_strips')
          .snapshots(),
      builder: (context, stripSnapshot) {
        final strips = (stripSnapshot.data?.docs ?? []).where((doc) {
          final data = doc.data();
          return data['surface'] == 'restaurants' && data['enabled'] != false;
        }).toList()
          ..sort(
              (a, b) => ((a.data()['order'] as num?)?.toInt() ?? 0).compareTo(
                    (b.data()['order'] as num?)?.toInt() ?? 0,
                  ));
        if (strips.isEmpty) return _fallback();
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('restaurant_categories')
              .snapshots(),
          builder: (context, categorySnapshot) {
            final categories = (categorySnapshot.data?.docs ?? [])
                .where((doc) => doc.data()['enabled'] != false)
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < strips.length; index++) ...[
                  if (index > 0) const SizedBox(height: 22),
                  Text(
                    strips[index].data()['title']?.toString() ?? 'تصنيفات بركة',
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (strips[index].data()['useQuickActions'] == true)
                    SizedBox(
                      height: 145,
                      child: _CategoriesRow(
                        items: ((strips[index].data()['quickItems'] as List?) ??
                                const [])
                            .whereType<Map>()
                            .map((item) => Map<String, dynamic>.from(item))
                            .toList(),
                      ),
                    )
                  else
                    SizedBox(
                      height: 154,
                      child: Builder(
                        builder: (context) {
                          final selected =
                              ((strips[index].data()['categoryIds'] as List?) ??
                                      const [])
                                  .map((value) => value.toString())
                                  .toSet();
                          final showAll =
                              strips[index].data()['showAllCategories'] == true;
                          final visible = showAll
                              ? categories
                              : categories
                                  .where((doc) => selected.contains(doc.id))
                                  .toList();
                          if (visible.isEmpty) {
                            return const Center(
                              child: Text('لا توجد تصنيفات في هذا الشريط.'),
                            );
                          }
                          return ListView.separated(
                            scrollDirection: Axis.horizontal,
                            reverse: true,
                            itemCount: visible.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, categoryIndex) {
                              final data = visible[categoryIndex].data();
                              return _HomeCategoryTile(
                                title: data['title']?.toString() ?? 'تصنيف',
                                image: data['image']?.toString() ?? '',
                                description:
                                    (data['description'] ?? data['desc'])
                                            ?.toString() ??
                                        '',
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _CategoriesRow extends StatelessWidget {
  const _CategoriesRow({this.items = const []});

  final List<Map<String, dynamic>> items;

  Future<void> _openItem(
      BuildContext context, Map<String, dynamic> item) async {
    switch (item['actionType']?.toString() ?? 'details') {
      case 'play':
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => const PlayHubScreen()));
        return;
      case 'deliveryOffers':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const _SpecialOffersScreen(kind: _SpecialOfferKind.delivery),
          ),
        );
        return;
      case 'discounts':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const _SpecialOffersScreen(kind: _SpecialOfferKind.discount),
          ),
        );
        return;
      case 'nearby':
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const _NearbyPlacesScreen()));
        return;
      case 'market':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AllItemsScreen(itemType: 'market'),
          ),
        );
        return;
      case 'external':
        final raw = item['destinationUrl']?.toString().trim() ?? '';
        if (raw.isNotEmpty) {
          final uri = Uri.tryParse(raw.contains('://') ? raw : 'https://$raw');
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
        return;
      default:
        await showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (_) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 34),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item['title']?.toString() ?? 'بركة',
                    style: const TextStyle(
                        fontSize: 23, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Text(item['description']?.toString() ?? '',
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (items.isNotEmpty) {
      return ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          return _YellowHomeTile(
            title: item['title']?.toString() ?? 'اختصار',
            image: item['image']?.toString() ?? '',
            onTap: () => _openItem(context, item),
          );
        },
      );
    }
    return ListView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      children: [
        _YellowHomeTile(
          title: 'العب واربح',
          image: 'assets/images/play_with_barakah_selected.png',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PlayHubScreen(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _YellowHomeTile(
          title: 'عروض التوصيل',
          image: 'assets/images/home_icons/delivery.png',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const _SpecialOffersScreen(
                kind: _SpecialOfferKind.delivery,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _YellowHomeTile(
          title: 'خصومات بركة',
          image: 'assets/images/home_icons/barakah_discounts.png',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const _SpecialOffersScreen(
                kind: _SpecialOfferKind.discount,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _YellowHomeTile(
          title: 'أماكن قريبة منك',
          image: 'assets/images/home_icons/nearby.png',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const _NearbyPlacesScreen(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _YellowHomeTile(
          title: 'عروض الماركت',
          image: 'assets/images/home_icons/market_offers.png',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AllItemsScreen(itemType: 'market'),
              ),
            );
          },
        ),
        const SizedBox(width: 10),
        _YellowHomeTile(
          title: 'المنتجات الطازجة',
          image: 'assets/images/home_icons/fresh_products.png',
          onTap: () {
            AnalyticsService.instance.recordCategoryView('المنتجات الطازجة');

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CategoriesScreen(
                  title: 'المنتجات الطازجة',
                  image: 'assets/images/home_icons/fresh_products.png',
                  description: 'خضار وفواكه ومنتجات طازجة',
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 10),
        _YellowHomeTile(
          title: 'حلويات ومخبوزات',
          image: 'assets/images/home_icons/sweets.png',
          onTap: () {
            AnalyticsService.instance.recordCategoryView('حلويات ومخبوزات');

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CategoriesScreen(
                  title: 'حلويات ومخبوزات',
                  image: 'assets/images/home_icons/sweets.png',
                  description: 'حلويات ومخبوزات ومعجنات طازجة',
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 10),
        _YellowHomeTile(
          title: 'مزاد بركة',
          image: 'assets/images/barakah_app_icon.png',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const BarakahAuctionScreen(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _YellowHomeTile(
          title: 'تواصل مع بركة',
          image: 'assets/images/contact_barakah_sticker_v2.png',
          onTap: () {},
        ),
      ],
    );
  }
}

class _YellowHomeTile extends StatelessWidget {
  const _YellowHomeTile({
    required this.title,
    required this.image,
    required this.onTap,
  });

  final String title;
  final String image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: InkWell(
        borderRadius: BorderRadius.circular(52),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _barakahGold,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(.50),
                    blurRadius: 11,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: _barakahGold.withOpacity(.18),
                    blurRadius: 14,
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: const Color(0xFF061326).withOpacity(.18),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
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
                      ClipOval(child: _QuickActionImage(path: image)),

                      // Liquid Glass overlay
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

                      // انعكاس زجاجي علوي
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

                      // نفس اللمعة الجانبية والسفلية المستخدمة في الماركت.
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
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionImage extends StatelessWidget {
  const _QuickActionImage({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    Widget fallback(BuildContext _, Object __, StackTrace? ___) => Container(
          color: AppTheme.coolYellow,
          alignment: Alignment.center,
          child: const Icon(
            Icons.image_not_supported_outlined,
            color: AppTheme.navy,
            size: 42,
          ),
        );
    return BarakahMediaImage(
      path: path,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      fallback: fallback(context, Object(), null),
    );
  }
}

class _FallbackCategories extends StatelessWidget {
  const _FallbackCategories();

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('restaurant_categories')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'تعذر تحميل أقسام المطاعم',
                style: TextStyle(
                  color: AppTheme.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          }

          final docs = (snapshot.data?.docs ?? []).where((doc) {
            final data = doc.data();
            return data['enabled'] != false;
          }).toList()
            ..sort((a, b) {
              final aOrder = (a.data()['order'] as num?)?.toInt() ?? 9999;
              final bOrder = (b.data()['order'] as num?)?.toInt() ?? 9999;
              return aOrder.compareTo(bOrder);
            });

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد أقسام مطاعم حالياً',
                style: TextStyle(
                  color: AppTheme.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          }

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            reverse: true,
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final title = data['title']?.toString().trim() ?? '';
              final image = data['image']?.toString().trim() ?? '';
              final description =
                  (data['description'] ?? data['desc'])?.toString().trim() ??
                      '';

              return _HomeCategoryTile(
                title: title.isEmpty ? 'قسم' : title,
                image: image,
                description: description,
              );
            },
          );
        },
      );
}

class _BarakahAppStatusBanner extends StatelessWidget {
  const _BarakahAppStatusBanner();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('app_settings')
          .doc('app_hours')
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        if (data == null) return const SizedBox.shrink();

        final temporarilyClosed = data['temporarilyClosed'] == true;
        final openingTime = data['openingTime']?.toString().trim() ?? '10:00';
        final closingTime = data['closingTime']?.toString().trim() ?? '03:00';

        final now = DateTime.now();
        final nowMinutes = now.hour * 60 + now.minute;

        int? parseTime(String value) {
          final parts = value.split(':');
          if (parts.length != 2) return null;

          final hour = int.tryParse(parts[0]);
          final minute = int.tryParse(parts[1]);

          if (hour == null || minute == null) return null;
          if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
            return null;
          }

          return hour * 60 + minute;
        }

        final openMinutes = parseTime(openingTime);
        final closeMinutes = parseTime(closingTime);

        if (openMinutes == null || closeMinutes == null) {
          return const SizedBox.shrink();
        }

        const dayKeys = [
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
            vertical: 11,
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
                size: 24,
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
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: foreground.withOpacity(.82),
                        fontSize: 12,
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

class _NearbyPlacesTile extends StatelessWidget {
  const _NearbyPlacesTile();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 128,
        child: Material(
          color: Colors.white.withOpacity(.82),
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _NearbyPlacesScreen()),
            ),
            child: Column(children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [Color(0xFFFFE65B), AppTheme.coolYellow],
                    ),
                  ),
                  child: Image.asset(
                    'assets/images/barakah_nearby.png',
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 62,
                        color: AppTheme.navy,
                      ),
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 9),
                child: Text(
                  'أماكن قريبة منك',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.navy,
                    fontSize: 14,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
}

class _NearbyPlacesScreen extends StatefulWidget {
  const _NearbyPlacesScreen();

  @override
  State<_NearbyPlacesScreen> createState() => _NearbyPlacesScreenState();
}

class _NearbyPlacesScreenState extends State<_NearbyPlacesScreen> {
  double? _latitude;
  double? _longitude;
  bool _loadingLocation = true;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    if (mounted) {
      setState(() {
        _loadingLocation = true;
        _locationError = null;
      });
    }

    try {
      final position = await LocationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _loadingLocation = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingLocation = false;
        _locationError =
            'تعذر تحديد موقعك. فعّلي GPS واسمحي لتطبيق بركة باستخدام الموقع.';
      });
    }
  }

  ({double latitude, double longitude})? _coordinates(
      Map<String, dynamic> data) {
    final point = data['location'] ?? data['geoPoint'] ?? data['position'];
    if (point is GeoPoint) {
      return (latitude: point.latitude, longitude: point.longitude);
    }

    final latValue = data['latitude'] ?? data['lat'];
    final lngValue =
        data['longitude'] ?? data['lng'] ?? data['lon'] ?? data['long'];

    final lat =
        latValue is num ? latValue.toDouble() : double.tryParse('$latValue');
    final lng =
        lngValue is num ? lngValue.toDouble() : double.tryParse('$lngValue');

    if (lat == null || lng == null) return null;
    return (latitude: lat, longitude: lng);
  }

  double? _distanceFor(Map<String, dynamic> data) {
    if (_latitude == null || _longitude == null) return null;
    final coordinates = _coordinates(data);
    if (coordinates == null) return null;
    return LocationService.distanceBetween(
      _latitude!,
      _longitude!,
      coordinates.latitude,
      coordinates.longitude,
    );
  }

  String _distanceLabel(double meters) {
    if (meters < 1000) return '${meters.round()} م';
    final km = meters / 1000;
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} كم';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('أماكن قريبة منك'),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'تحديث موقعي',
              onPressed: _loadingLocation ? null : _loadLocation,
              icon: const Icon(Icons.my_location_rounded),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        body: BarakahBrandBackdrop(
          child: _loadingLocation
              ? const Center(child: CircularProgressIndicator())
              : _locationError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              decoration: const BoxDecoration(
                                color: AppTheme.coolYellow,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_off_rounded,
                                color: AppTheme.navy,
                                size: 38,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _locationError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppTheme.navy,
                                fontSize: 17,
                                height: 1.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadLocation,
                              icon: const Icon(Icons.my_location_rounded),
                              label: const Text('حاول مرة أخرى'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('items')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final places = (snapshot.data?.docs ?? []).where((doc) {
                          final data = doc.data();
                          final type = data['type']?.toString().toLowerCase();
                          final isBusiness =
                              data['kind']?.toString() != 'product';
                          final isRestaurant =
                              type == null || type == 'restaurant';
                          return isBusiness &&
                              isRestaurant &&
                              _distanceFor(data) != null;
                        }).toList();

                        places.sort((a, b) {
                          final left =
                              _distanceFor(a.data()) ?? double.infinity;
                          final right =
                              _distanceFor(b.data()) ?? double.infinity;
                          return left.compareTo(right);
                        });

                        if (places.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(30),
                              child: Text(
                                'لا توجد أماكن بإحداثيات موقع مسجلة حالياً.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppTheme.navy,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          );
                        }

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 700 ? 3 : 2;
                            return GridView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 18, 16, 28),
                              itemCount: places.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: .66,
                              ),
                              itemBuilder: (context, index) {
                                final place = places[index];
                                final distance =
                                    _distanceFor(place.data()) ?? 0;
                                return GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => RestaurantDetailsScreen(
                                        restaurant: place,
                                      ),
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: RestaurantCard(
                                          restaurant: place,
                                        ),
                                      ),
                                      PositionedDirectional(
                                        top: 8,
                                        start: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 9, vertical: 5),
                                          decoration: BoxDecoration(
                                            color:
                                                AppTheme.navy.withOpacity(.92),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                              color: AppTheme.coolYellow,
                                              width: 1.2,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.location_on_rounded,
                                                color: AppTheme.coolYellow,
                                                size: 15,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                _distanceLabel(distance),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
        ),
      );
}

enum _SpecialOfferKind { delivery, discount }

class _SpecialCategoryTile extends StatelessWidget {
  const _SpecialCategoryTile({
    required this.title,
    required this.kind,
  });

  final String title;
  final _SpecialOfferKind kind;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 128,
        child: Material(
          color: Colors.white.withOpacity(.82),
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _SpecialOffersScreen(kind: kind),
              ),
            ),
            child: Column(children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [Color(0xFFFFE65B), AppTheme.coolYellow],
                    ),
                  ),
                  child: Image.asset(
                    kind == _SpecialOfferKind.delivery
                        ? 'assets/images/barakah_delivery.png'
                        : 'assets/images/barakah_discount.png',
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      kind == _SpecialOfferKind.delivery
                          ? Icons.delivery_dining_rounded
                          : Icons.percent_rounded,
                      size: 54,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w900)),
              ),
            ]),
          ),
        ),
      );
}

class _SpecialOffersScreen extends StatelessWidget {
  const _SpecialOffersScreen({required this.kind});

  final _SpecialOfferKind kind;

  @override
  Widget build(BuildContext context) {
    final title =
        kind == _SpecialOfferKind.delivery ? 'عروض التوصيل' : 'خصومات بركة';
    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      backgroundColor: Colors.transparent,
      body: BarakahBrandBackdrop(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('items').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = (snapshot.data?.docs ?? []).where((doc) {
              final data = doc.data();
              final isBusiness = data['kind']?.toString() != 'product';
              if (!isBusiness) return false;
              if (kind == _SpecialOfferKind.delivery) {
                return data['hasDeliveryOffer'] == true;
              }
              return ((data['discountPercent'] as num?)?.toDouble() ?? 0) > 0;
            }).toList();
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    kind == _SpecialOfferKind.delivery
                        ? 'لا توجد عروض توصيل حالياً.'
                        : 'لا توجد خصومات بركة حالياً.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              );
            }
            return LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth >= 700 ? 3 : 2;
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                itemCount: items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: .66,
                ),
                itemBuilder: (_, index) => GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          RestaurantDetailsScreen(restaurant: items[index]),
                    ),
                  ),
                  child: RestaurantCard(restaurant: items[index]),
                ),
              );
            });
          },
        ),
      ),
    );
  }
}

class _HomeCategoryTile extends StatelessWidget {
  const _HomeCategoryTile({
    required this.title,
    required this.image,
    required this.description,
  });

  final String title;
  final String image;
  final String description;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 128,
        child: Material(
          color: Colors.white.withOpacity(.72),
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              AnalyticsService.instance.recordCategoryView(title);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoriesScreen(
                    title: title,
                    image: image.isEmpty
                        ? 'assets/images/categories/restaurant.jpg'
                        : image,
                    description: description,
                    itemType: 'restaurant',
                  ),
                ),
              );
            },
            child: Column(children: [
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: image.isEmpty
                      ? const ColoredBox(
                          color: AppTheme.coolYellow,
                          child: Icon(Icons.category_outlined,
                              color: AppTheme.ink, size: 38))
                      : BarakahMediaImage(
                          path: image,
                          fit: BoxFit.cover,
                          fallback: const ColoredBox(
                            color: AppTheme.coolYellow,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: AppTheme.ink,
                              size: 38,
                            ),
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w900)),
              )
            ]),
          ),
        ),
      );
}

class _StaticCatalogue extends StatelessWidget {
  const _StaticCatalogue({required this.query});
  final String query;

  static const _items = [
    {
      'title': 'مطعم بركة',
      'category': 'وجبات عربية',
      'price': 25,
      'rating': 4.8
    },
    {
      'title': 'قهوة الصباح',
      'category': 'قهوة وحلويات',
      'price': 12,
      'rating': 4.7
    },
    {
      'title': 'سوق بركة',
      'category': 'احتياجات المنزل',
      'price': 18,
      'rating': 4.9
    },
    {'title': 'بيت البيتزا', 'category': 'بيتزا', 'price': 30, 'rating': 4.6},
  ];

  @override
  Widget build(BuildContext context) {
    final items = _items
        .where((item) => item['title'].toString().toLowerCase().contains(query))
        .toList();
    if (items.isEmpty) {
      return const SliverFillRemaining(
          child: Center(child: Text('لا توجد عناصر مطابقة حالياً')));
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
            (context, index) => RestaurantCard(restaurant: items[index]),
            childCount: items.length),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.sizeOf(context).width >= 700 ? 3 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: .66),
      ),
    );
  }
}

class BarakahAuctionScreen extends StatefulWidget {
  const BarakahAuctionScreen({super.key});

  @override
  State<BarakahAuctionScreen> createState() => _BarakahAuctionScreenState();
}

class _BarakahAuctionScreenState extends State<BarakahAuctionScreen> {
  static const String _auctionUploadEndpoint =
      'https://barakah-90-production-384c.up.railway.app/upload';

  Future<String> _uploadAuctionImage(XFile image) async {
    final bytes = await image.readAsBytes();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(_auctionUploadEndpoint),
    );

    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: image.name,
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'تعذر رفع الصورة. رمز الخادم: ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('استجابة خادم الصور غير صالحة.');
    }

    final url = decoded['url']?.toString().trim() ?? '';

    if (url.isEmpty || Uri.tryParse(url)?.hasScheme != true) {
      throw Exception('لم يرجع خادم الصور رابطاً صالحاً.');
    }

    return url;
  }

  Future<void> _buyAuctionItem(
    String requestId,
    Map<String, dynamic> data,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      final shouldLogin = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('شراء عبر بركة'),
          content: const Text(
            'يجب تسجيل الدخول لإتمام عملية الشراء عبر بركة.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('تسجيل الدخول'),
            ),
          ],
        ),
      );

      if (shouldLogin == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AuthenticationScreen(),
          ),
        );
      }
      return;
    }

    final sellerId = data['userId']?.toString().trim() ?? '';

    if (sellerId == user.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكنك شراء إعلانك الخاص.'),
        ),
      );
      return;
    }

    final rawPrice = data['startingPrice'];

    final price = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice?.toString() ?? '') ?? 0;

    const commissionRate = 10.0;
    final commissionAmount = price * commissionRate / 100;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الشراء عبر بركة'),
        content: Text(
          'سيتم حجز السلعة داخل بركة ولن يتم إكمال التوصيل قبل تأكيد استلام عمولة بركة.\n\n'
          'السعر: ${price.toStringAsFixed(2)} ₪\n'
          'عمولة بركة: ${commissionAmount.toStringAsFixed(2)} ₪',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.shopping_bag_rounded),
            label: const Text('تأكيد الشراء'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final firestore = FirebaseFirestore.instance;

      final requestRef =
          firestore.collection('auction_requests').doc(requestId);

      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(requestRef);
        final freshData = snapshot.data();

        if (!snapshot.exists || freshData == null) {
          throw Exception('الإعلان غير موجود.');
        }

        if (freshData['status']?.toString() != 'approved') {
          throw Exception('هذه السلعة غير متاحة للشراء حالياً.');
        }

        final currentBuyer = freshData['buyerId']?.toString().trim() ?? '';

        if (currentBuyer.isNotEmpty) {
          throw Exception('تم حجز هذه السلعة بالفعل.');
        }

        transaction.update(requestRef, {
          'buyerId': user.uid,
          'buyerEmail': user.email ?? '',
          'saleStatus': 'pending_commission',
          'salePrice': price,
          'commissionRate': commissionRate,
          'commissionAmount': commissionAmount,
          'commissionPaid': false,
          'reservedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final saleRef = firestore.collection('auction_sales').doc(requestId);

        transaction.set(saleRef, {
          'auctionRequestId': requestId,
          'sellerId': freshData['userId'] ?? '',
          'buyerId': user.uid,
          'buyerEmail': user.email ?? '',
          'itemName': freshData['itemName'] ?? '',
          'image': freshData['image'] ?? '',
          'salePrice': price,
          'commissionRate': commissionRate,
          'commissionAmount': commissionAmount,
          'commissionPaid': false,
          'status': 'pending_commission',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم حجز السلعة عبر بركة. بانتظار تأكيد استلام العمولة قبل التوصيل.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إتمام الشراء: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitAuctionRequest() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      final login = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('إضافة إعلان للمزاد'),
          content: const Text(
            'إضافة إعلان للمزاد متاحة للحسابات المسجلة فقط.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('تسجيل الدخول'),
            ),
          ],
        ),
      );

      if (login == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AuthenticationScreen(),
          ),
        );
      }
      return;
    }

    final itemName = TextEditingController();
    final description = TextEditingController();
    final startingPrice = TextEditingController();
    final area = TextEditingController();
    final phone = TextEditingController();

    final picker = ImagePicker();
    final selectedImages = <XFile>[];

    String condition = 'مستعملة - جيدة';
    bool sending = false;

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              18,
              18,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'إرسال طلب إعلان للمزاد',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'سيتم نشر الإعلان فقط بعد موافقة إدارة بركة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: itemName,
                    decoration: const InputDecoration(
                      labelText: 'اسم السلعة',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: description,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'وصف السلعة',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: startingPrice,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'سعر البداية',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: area,
                    decoration: const InputDecoration(
                      labelText: 'المنطقة',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم التواصل',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: condition,
                    decoration: const InputDecoration(
                      labelText: 'حالة السلعة',
                    ),
                    items: const [
                      'جديدة',
                      'مستعملة - ممتازة',
                      'مستعملة - جيدة',
                      'تحتاج صيانة',
                    ]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: sending
                        ? null
                        : (value) {
                            if (value != null) {
                              setSheetState(() => condition = value);
                            }
                          },
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: sending
                          ? null
                          : () async {
                              final picked = await picker.pickMultiImage(
                                imageQuality: 82,
                              );

                              if (picked.isEmpty) return;

                              final combined = [
                                ...selectedImages,
                                ...picked,
                              ];

                              setSheetState(() {
                                selectedImages
                                  ..clear()
                                  ..addAll(combined.take(5));
                              });

                              if (combined.length > 5 && sheetContext.mounted) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'الحد الأقصى 5 صور للإعلان.',
                                    ),
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.add_photo_alternate_rounded),
                      label: Text(
                        selectedImages.isEmpty
                            ? 'إضافة صور السلعة'
                            : 'الصور المختارة: ${selectedImages.length}/5',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (selectedImages.isEmpty)
                    const Text(
                      'يجب إضافة صورة واحدة على الأقل للسلعة.',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  else
                    SizedBox(
                      height: 92,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: selectedImages.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final image = selectedImages[index];

                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  width: 92,
                                  height: 92,
                                  child: FutureBuilder<List<int>>(
                                    future: image.readAsBytes(),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return const ColoredBox(
                                          color: Color(0xFFE5EAF2),
                                          child: Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        );
                                      }

                                      return Image.memory(
                                        Uint8List.fromList(
                                          snapshot.data!,
                                        ),
                                        fit: BoxFit.cover,
                                      );
                                    },
                                  ),
                                ),
                              ),
                              PositionedDirectional(
                                top: 3,
                                end: 3,
                                child: InkWell(
                                  onTap: sending
                                      ? null
                                      : () {
                                          setSheetState(
                                            () =>
                                                selectedImages.removeAt(index),
                                          );
                                        },
                                  child: const CircleAvatar(
                                    radius: 13,
                                    backgroundColor: Colors.black87,
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: sending
                          ? null
                          : () async {
                              final price =
                                  num.tryParse(startingPrice.text.trim());

                              if (itemName.text.trim().isEmpty ||
                                  description.text.trim().isEmpty ||
                                  price == null ||
                                  price < 0 ||
                                  area.text.trim().isEmpty ||
                                  phone.text.trim().isEmpty) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'أكمل جميع بيانات الإعلان بشكل صحيح.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              if (selectedImages.isEmpty) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'أضف صورة واحدة على الأقل للسلعة.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              setSheetState(() => sending = true);

                              try {
                                final imageUrls = <String>[];

                                for (final image in selectedImages) {
                                  imageUrls.add(
                                    await _uploadAuctionImage(image),
                                  );
                                }

                                await FirebaseFirestore.instance
                                    .collection('auction_requests')
                                    .add({
                                  'userId': user.uid,
                                  'userEmail': user.email ?? '',
                                  'itemName': itemName.text.trim(),
                                  'description': description.text.trim(),
                                  'startingPrice': price,
                                  'area': area.text.trim(),
                                  'contactPhone': phone.text.trim(),
                                  'condition': condition,

                                  // صور الإعلان
                                  'image': imageUrls.first,
                                  'imageUrls': imageUrls,

                                  'status': 'pending',
                                  'createdAt': FieldValue.serverTimestamp(),
                                  'updatedAt': FieldValue.serverTimestamp(),
                                });

                                if (sheetContext.mounted) {
                                  Navigator.pop(
                                    sheetContext,
                                    true,
                                  );
                                }
                              } catch (error) {
                                if (sheetContext.mounted) {
                                  setSheetState(() => sending = false);

                                  ScaffoldMessenger.of(sheetContext)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'تعذر إرسال طلب المزاد: $error',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                      icon: sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        sending
                            ? 'جاري رفع الصور وإرسال الطلب...'
                            : 'إرسال الطلب للأدمن',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    itemName.dispose();
    description.dispose();
    startingPrice.dispose();
    area.dispose();
    phone.dispose();

    if (submitted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إرسال طلب إعلان المزاد للأدمن للمراجعة ✅',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('مزاد بركة'),
        centerTitle: true,
      ),
      body: BarakahBrandBackdrop(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submitAuctionRequest,
                  icon: const Icon(Icons.add_circle_rounded),
                  label: const Text('أضف إعلان للمزاد'),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('auction_requests')
                    .where('status', isEqualTo: 'approved')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final docs = snapshot.data?.docs ?? const [];

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'لا توجد إعلانات مزاد منشورة حالياً.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final data = docs[index].data();

                      final image = data['image']?.toString().trim() ?? '';

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.navy.withOpacity(.92),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: AppTheme.coolYellow.withOpacity(.65),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (image.isNotEmpty) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  image,
                                  height: 210,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            Text(
                              data['itemName']?.toString() ?? '',
                              style: const TextStyle(
                                color: AppTheme.coolYellow,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              data['description']?.toString() ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'سعر البداية: ${data['startingPrice'] ?? 0} ₪',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'المنطقة: ${data['area'] ?? ''}',
                              style: const TextStyle(
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              'الحالة: ${data['condition'] ?? ''}',
                              style: const TextStyle(
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: (data['buyerId']
                                            ?.toString()
                                            .trim()
                                            .isNotEmpty ??
                                        false)
                                    ? null
                                    : () =>
                                        _buyAuctionItem(docs[index].id, data),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.coolYellow,
                                  foregroundColor: AppTheme.navy,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: Icon(
                                  (data['buyerId']
                                              ?.toString()
                                              .trim()
                                              .isNotEmpty ??
                                          false)
                                      ? Icons.lock_rounded
                                      : Icons.shopping_bag_rounded,
                                ),
                                label: Text(
                                  (data['buyerId']
                                              ?.toString()
                                              .trim()
                                              .isNotEmpty ??
                                          false)
                                      ? 'تم حجز السلعة'
                                      : 'شراء عبر بركة',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
