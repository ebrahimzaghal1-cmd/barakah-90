import 'package:flutter/material.dart';
import 'admin_manage_partner_applications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_manage_categories.dart';
import 'admin_manage_products.dart';
import 'admin_manage_restaurants.dart';
import 'admin_operations_screen.dart';
import 'admin_add_item_screen.dart';
import 'admin_manage_ads.dart';
import 'admin_manage_drivers.dart';
import 'admin_account_deletion_requests.dart';
import 'admin_loyalty_settings.dart';
import 'admin_app_hours.dart';
import 'admin_manage_trends.dart';
import 'admin_manage_users.dart';
import 'admin_manage_home_strips.dart';
import 'admin_customer_service.dart';

import '../theme/app_theme.dart';
import '../services/user_profile_service.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return FutureBuilder<bool>(
      future: user == null
          ? Future.value(false)
          : UserProfileService().isAdmin(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.data != true) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('صلاحيات الأدمن'),
            ),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'هذه اللوحة متاحة لحساب الأدمن فقط.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        }

        return _buildDashboard(context);
      },
    );
  }

  Widget _buildDashboard(BuildContext context) {
    final items = [
      _AdminItem(
        title: 'إدارة المطاعم',
        icon: Icons.storefront,
        page: const AdminManageRestaurants(),
      ),
      _AdminItem(
        title: 'إدارة الماركت',
        icon: Icons.local_grocery_store,
        page: const AdminManageRestaurants(
          itemType: 'market',
          singularLabel: 'ماركت',
          pluralLabel: 'الماركت',
        ),
      ),
      _AdminItem(
        title: 'أشرطة المطاعم',
        icon: Icons.restaurant_menu_rounded,
        page: const AdminManageHomeStrips(surface: 'restaurants'),
      ),
      _AdminItem(
        title: 'أشرطة الماركت',
        icon: Icons.view_carousel_rounded,
        page: const AdminManageHomeStrips(surface: 'market'),
      ),
      _AdminItem(
        title: 'أقسام المطاعم',
        icon: Icons.category,
        page: const AdminManageCategories(
          collectionName: 'restaurant_categories',
          title: 'إدارة أقسام المطاعم',
          seedItems: [
            {
              'title': 'مشاوي',
              'image': 'assets/images/categories/restaurant.jpg',
              'desc': 'مطاعم المشاوي واللحوم',
            },
            {
              'title': 'برغر',
              'image': 'assets/images/categories/meat.jpg',
              'desc': 'برغر ووجبات سريعة',
            },
            {
              'title': 'دجاج',
              'image': 'assets/images/categories/chicken.jpg',
              'desc': 'دجاج مقلي ومشوي',
            },
            {
              'title': 'بيتزا',
              'image': 'assets/images/categories/bakery.jpg',
              'desc': 'بيتزا ومعجنات طازجة',
            },
            {
              'title': 'شاورما',
              'image': 'assets/images/categories/meat.jpg',
              'desc': 'شاورما ووجبات عربية',
            },
            {
              'title': 'قهوة وحلويات',
              'image': 'assets/images/categories/restaurant.jpg',
              'desc': 'قهوة وحلويات ومشروبات',
            },
          ],
        ),
      ),
      _AdminItem(
        title: 'سوق بركة',
        icon: Icons.grid_view_rounded,
        page: const AdminManageCategories(
          collectionName: 'market_categories',
          title: 'إدارة سوق بركة',
          seedItems: [
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
          ],
        ),
      ),
      _AdminItem(
        title: 'إدارة المنتجات',
        icon: Icons.fastfood,
        page: const AdminManageProducts(),
      ),
      _AdminItem(
        title: 'إدارة الإعلانات',
        icon: Icons.campaign_rounded,
        page: const AdminManageAds(),
      ),
      _AdminItem(
        title: 'سائقو التوصيل',
        icon: Icons.delivery_dining_rounded,
        page: const AdminManageDrivers(),
      ),
      _AdminItem(
        title: 'طلبات التوظيف وخدمة العملاء',
        icon: Icons.support_agent_rounded,
        page: const AdminCustomerService(),
      ),
      _AdminItem(
        title: 'نقاط بركة',
        icon: Icons.card_giftcard_rounded,
        page: const AdminLoyaltySettings(),
      ),
      _AdminItem(
        title: 'أوقات عمل بركة',
        icon: Icons.schedule_rounded,
        page: const AdminAppHours(),
      ),
      _AdminItem(
        title: 'إحصائيات بركة',
        icon: Icons.analytics_rounded,
        page: const _AdminAnalyticsScreen(),
      ),
      _AdminItem(
        title: 'إدارة الترندات',
        icon: Icons.local_fire_department_rounded,
        page: const AdminManageTrends(),
      ),
      _AdminItem(
        title: 'طلبات انضمام الشركاء',
        icon: Icons.handshake_rounded,
        page: const AdminManagePartnerApplications(),
      ),
      _AdminItem(
        title: 'طلبات المزاد',
        icon: Icons.gavel_rounded,
        page: const _AdminAuctionRequestsScreen(),
      ),
      _AdminItem(
        title: 'المشتركون والحسابات',
        icon: Icons.manage_accounts_rounded,
        page: const AdminManageUsers(),
      ),
      _AdminItem(
        title: 'إضافة مطعم / متجر',
        icon: Icons.add_business,
        page: const AdminAddItemScreen(),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF3D4147),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text(
          'لوحة تحكم الأدمن',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _TechBackground()),
          PositionedDirectional(
            end: -120,
            top: 120,
            width: 430,
            height: 390,
            child: Opacity(
              opacity: .075,
              child: Image.asset(
                'assets/images/barakah_header_bunny.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 34),
            children: [
              const _AdminHero(),
              const SizedBox(height: 14),
              _OperationsShortcut(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminOperationsScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ===== BARAKAH ADMIN REQUEST STRIP =====
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _AdminRequestShortcut(
                      title: 'طلبات المزاد',
                      icon: Icons.shopping_bag_rounded,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const _AdminAuctionRequestsScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _AdminRequestShortcut(
                      title: 'لوحة المزاد',
                      icon: Icons.gavel_rounded,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const _AdminAuctionRequestsScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _AdminRequestShortcut(
                      title: 'طلبات الشركاء',
                      icon: Icons.handshake_rounded,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const AdminManagePartnerApplications(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _AdminRequestShortcut(
                      title: 'طلبات السائقين',
                      icon: Icons.delivery_dining_rounded,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminManageDrivers(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _AdminRequestShortcut(
                      title: 'طلبات حذف الحساب',
                      icon: Icons.person_remove_rounded,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminAccountDeletionRequests(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              FutureBuilder<int>(
                future: UserProfileService().customerCount(),
                builder: (context, snapshot) => Card(
                  color: Colors.white.withOpacity(.10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.coolYellow,
                      child:
                          Icon(Icons.groups_2_outlined, color: AppTheme.navy),
                    ),
                    title: const Text(
                      'عدد المشتركين',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    trailing: Text(
                      '${snapshot.data ?? 0}',
                      style: const TextStyle(
                        color: AppTheme.coolYellow,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    subtitle: const Text(
                      'اضغط لفتح إدارة الحسابات',
                      style: TextStyle(color: Colors.white60),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminManageUsers(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const _AdminBusinessStats(),
              const SizedBox(height: 22),
              const Text(
                'أدوات الإدارة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 11),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900
                      ? 4
                      : constraints.maxWidth >= 600
                          ? 3
                          : 2;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.12,
                    ),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _AdminCard(
                        title: item.title,
                        icon: item.icon,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => item.page),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminBusinessStats extends StatelessWidget {
  const _AdminBusinessStats();

  bool _isToday(Timestamp? value) {
    if (value == null) return false;

    final date = value.toDate().toLocal();
    final now = DateTime.now();

    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('items').snapshots(),
      builder: (context, itemSnapshot) {
        final businesses = (itemSnapshot.data?.docs ?? [])
            .where(
              (doc) => doc.data()['kind']?.toString() != 'product',
            )
            .toList();

        final subscribed = businesses
            .where(
              (doc) =>
                  doc.data()['ownerId']?.toString().trim().isNotEmpty == true,
            )
            .length;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('orders').snapshots(),
          builder: (context, orderSnapshot) {
            final orders = orderSnapshot.data?.docs ?? [];

            final todayOrders = orders
                .where(
                  (doc) => _isToday(doc.data()['createdAt'] as Timestamp?),
                )
                .length;

            final totals = <String, int>{};

            for (final order in orders) {
              final seen = <String>{};

              for (final raw in (order.data()['items'] as List? ?? const [])) {
                if (raw is! Map) continue;

                final id = raw['businessId']?.toString().trim() ?? '';

                final title = raw['businessTitle']?.toString().trim() ?? '';

                final key = id.isNotEmpty ? id : title;

                if (key.isNotEmpty) {
                  seen.add(key);
                }
              }

              for (final key in seen) {
                totals[key] = (totals[key] ?? 0) + 1;
              }
            }

            final rows = businesses.map((business) {
              final title =
                  business.data()['title']?.toString() ?? 'محل بدون اسم';

              return (
                title,
                totals[business.id] ?? totals[title] ?? 0,
              );
            }).toList()
              ..sort(
                (a, b) => b.$2.compareTo(a.$2),
              );

            return Card(
              color: Colors.white.withOpacity(.10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatBox(
                            icon: Icons.storefront_rounded,
                            label: 'المحلات المشتركة',
                            value: '$subscribed',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatBox(
                            icon: Icons.today_rounded,
                            label: 'طلبات اليوم',
                            value: '$todayOrders',
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    ExpansionTile(
                      iconColor: AppTheme.coolYellow,
                      collapsedIconColor: AppTheme.coolYellow,
                      tilePadding: EdgeInsets.zero,
                      title: const Text(
                        'إجمالي الطلبات لكل محل',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      subtitle: const Text(
                        'هذه الإحصائية تظهر للأدمن فقط',
                        style: TextStyle(color: Colors.white60),
                      ),
                      children: rows.isEmpty
                          ? const [
                              ListTile(
                                title: Text(
                                  'لا توجد محلات حالياً',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            ]
                          : rows
                              .map(
                                (row) => ListTile(
                                  dense: true,
                                  leading: const Icon(
                                    Icons.store_outlined,
                                    color: AppTheme.coolYellow,
                                  ),
                                  title: Text(
                                    row.$1,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  trailing: Text(
                                    '${row.$2}',
                                    style: const TextStyle(
                                      color: AppTheme.coolYellow,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF071A38).withOpacity(.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: AppTheme.deepYellow,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminItem {
  final String title;
  final IconData icon;
  final Widget page;

  _AdminItem({
    required this.title,
    required this.icon,
    required this.page,
  });
}

class _AdminCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _AdminCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [
              Colors.white.withOpacity(.14),
              Colors.white.withOpacity(.075),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(.14)),
        ),
        child: Stack(
          children: [
            PositionedDirectional(
              end: -18,
              bottom: -22,
              child: Icon(
                icon,
                size: 94,
                color: Colors.white.withOpacity(.035),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.coolYellow,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x44E8C64A),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: Icon(icon, color: AppTheme.navy, size: 26),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Text(
                        'فتح الأداة',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_back_rounded,
                        size: 15,
                        color: AppTheme.coolYellow,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminHero extends StatelessWidget {
  const _AdminHero();

  @override
  Widget build(BuildContext context) => Container(
        height: 190,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [Color(0xFF1D477E), Color(0xFF0A1B38)],
          ),
          border: Border.all(color: Colors.white12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55040D20),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            PositionedDirectional(
              end: -32,
              top: -34,
              bottom: -40,
              width: 265,
              child: Opacity(
                opacity: .34,
                child: Image.asset(
                  'assets/images/barakah_header_bunny.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                ),
              ),
            ),
            PositionedDirectional(
              start: -40,
              top: -60,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.coolYellow.withOpacity(.08),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0x22FFFFFF),
                      borderRadius: BorderRadius.all(Radius.circular(99)),
                    ),
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      child: Text(
                        'BARAKAH CONTROL',
                        style: TextStyle(
                          color: AppTheme.coolYellow,
                          fontSize: 11,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: 235,
                    child: Text(
                      'إدارة أذكى، أسرع، وأوضح',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(height: 7),
                  SizedBox(
                    width: 225,
                    child: Text(
                      'كل ما تحتاجينه لإدارة بركة من شاشة واحدة.',
                      style: TextStyle(
                        color: Colors.white70,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _AdminRequestShortcut extends StatelessWidget {
  const _AdminRequestShortcut({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 155,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(.20),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppTheme.coolYellow,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: AppTheme.navy,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OperationsShortcut extends StatelessWidget {
  const _OperationsShortcut({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: AppTheme.coolYellow,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x44E8C64A),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: const Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.navy,
                    borderRadius: BorderRadius.all(Radius.circular(17)),
                  ),
                  child: SizedBox(
                    width: 58,
                    height: 58,
                    child: Icon(
                      Icons.space_dashboard_rounded,
                      color: AppTheme.coolYellow,
                      size: 31,
                    ),
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الطلبات والمحاسبة',
                        style: TextStyle(
                          color: AppTheme.navy,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'مركز التشغيل اليومي • افتحيه أولًا',
                        style: TextStyle(
                          color: Color(0xB3122447),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.navy),
              ],
            ),
          ),
        ),
      );
}

class _TechBackground extends StatelessWidget {
  const _TechBackground();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF5B6068), Color(0xFF30343A)],
          ),
        ),
        child: CustomPaint(painter: _TechGridPainter()),
      );
}

class _TechGridPainter extends CustomPainter {
  const _TechGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(.025)
      ..strokeWidth = 1;
    const gap = 34.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AdminAnalyticsScreen extends StatelessWidget {
  const _AdminAnalyticsScreen();

  bool _isToday(Timestamp? value) {
    if (value == null) return false;

    final date = value.toDate().toLocal();
    final now = DateTime.now();

    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إحصائيات بركة'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, userSnapshot) {
          final subscribers = (userSnapshot.data?.docs ?? [])
              .where(
                (doc) =>
                    (doc.data()['role']?.toString() ?? 'customer') ==
                    'customer',
              )
              .length;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('analytics_events')
                .snapshots(),
            builder: (context, analyticsSnapshot) {
              final events = analyticsSnapshot.data?.docs ?? [];

              final allVisitors = <String>{};
              final todayVisitors = <String>{};
              final categoryTotals = <String, int>{};

              for (final event in events) {
                final data = event.data();
                final type = data['eventType']?.toString() ?? '';
                final sessionId = data['sessionId']?.toString().trim() ?? '';
                final createdAt = data['createdAt'] as Timestamp?;

                if (type == 'app_visit' && sessionId.isNotEmpty) {
                  allVisitors.add(sessionId);

                  if (_isToday(createdAt)) {
                    todayVisitors.add(sessionId);
                  }
                }

                if (type == 'category_view') {
                  final category = data['category']?.toString().trim() ?? '';

                  if (category.isNotEmpty) {
                    categoryTotals[category] =
                        (categoryTotals[category] ?? 0) + 1;
                  }
                }
              }

              final topCategories = categoryTotals.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream:
                    FirebaseFirestore.instance.collection('orders').snapshots(),
                builder: (context, orderSnapshot) {
                  final productTotals = <String, int>{};

                  for (final order in orderSnapshot.data?.docs ?? []) {
                    final items = order.data()['items'] as List? ?? const [];

                    for (final raw in items) {
                      if (raw is! Map) continue;

                      final item = Map<String, dynamic>.from(raw);

                      final title = item['title']?.toString().trim() ?? 'صنف';

                      final quantity = item['quantity'];

                      final count = quantity is num
                          ? quantity.toInt()
                          : int.tryParse(
                                quantity?.toString() ?? '',
                              ) ??
                              1;

                      if (title.isNotEmpty) {
                        productTotals[title] = (productTotals[title] ?? 0) +
                            (count <= 0 ? 1 : count);
                      }
                    }
                  }

                  final topProducts = productTotals.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));

                  return ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _AnalyticsSummaryCard(
                              icon: Icons.people_alt_rounded,
                              label: 'المشتركين',
                              value: '$subscribers',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _AnalyticsSummaryCard(
                              icon: Icons.visibility_rounded,
                              label: 'زوار اليوم',
                              value: '${todayVisitors.length}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _AnalyticsSummaryCard(
                        icon: Icons.groups_rounded,
                        label: 'إجمالي الزوار',
                        value: '${allVisitors.length}',
                        fullWidth: true,
                      ),
                      const SizedBox(height: 18),
                      _AnalyticsRankingCard(
                        title: 'أكثر الأصناف طلبًا',
                        icon: Icons.shopping_bag_rounded,
                        rows: topProducts
                            .take(10)
                            .map(
                              (entry) => (
                                entry.key,
                                entry.value,
                              ),
                            )
                            .toList(),
                        emptyText: 'لا توجد طلبات كافية بعد.',
                      ),
                      const SizedBox(height: 14),
                      _AnalyticsRankingCard(
                        title: 'أكثر الأقسام زيارة',
                        icon: Icons.category_rounded,
                        rows: topCategories
                            .take(10)
                            .map(
                              (entry) => (
                                entry.key,
                                entry.value,
                              ),
                            )
                            .toList(),
                        emptyText: 'ستظهر الزيارات هنا بعد استخدام الأقسام.',
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'إحصائيات الزوار والأقسام تبدأ من وقت تفعيل نظام التتبع.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _AnalyticsSummaryCard extends StatelessWidget {
  const _AnalyticsSummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    this.fullWidth = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        child: Row(
          mainAxisAlignment:
              fullWidth ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: AppTheme.deepYellow,
              size: 30,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsRankingCard extends StatelessWidget {
  const _AnalyticsRankingCard({
    required this.title,
    required this.icon,
    required this.rows,
    required this.emptyText,
  });

  final String title;
  final IconData icon;
  final List<(String, int)> rows;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: AppTheme.deepYellow,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: Text(
                    emptyText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black54,
                    ),
                  ),
                ),
              )
            else
              for (var i = 0; i < rows.length; i++)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.coolYellow,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  title: Text(
                    rows[i].$1,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  trailing: Text(
                    '${rows[i].$2}',
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _AdminAuctionRequestsScreen extends StatelessWidget {
  const _AdminAuctionRequestsScreen();

  Future<void> _confirmCommission(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> sale,
  ) async {
    final data = sale.data();
    final auctionRequestId =
        data['auctionRequestId']?.toString().trim() ?? sale.id;

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      batch.update(sale.reference, {
        'commissionPaid': true,
        'status': 'commission_paid',
        'commissionPaidAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.update(
        firestore.collection('auction_requests').doc(auctionRequestId),
        {
          'commissionPaid': true,
          'saleStatus': 'commission_paid',
          'commissionPaidAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تأكيد استلام عمولة بركة ✅'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تأكيد العمولة: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _completeSale(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> sale,
  ) async {
    final data = sale.data();
    final auctionRequestId =
        data['auctionRequestId']?.toString().trim() ?? sale.id;

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      batch.update(sale.reference, {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.update(
        firestore.collection('auction_requests').doc(auctionRequestId),
        {
          'saleStatus': 'completed',
          'status': 'sold',
          'soldAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إتمام بيع السلعة ✅'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إتمام البيع: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _requestsTab(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('auction_requests').snapshots(),
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
            child: Text('لا توجد طلبات مزاد حالياً.'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();

            final status = data['status']?.toString() ?? 'pending';
            final image = data['image']?.toString().trim() ?? '';

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (image.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          image,
                          height: 190,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      data['itemName']?.toString() ?? 'سلعة',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(data['description']?.toString() ?? ''),
                    const SizedBox(height: 8),
                    Text('السعر: ${data['startingPrice'] ?? 0} ₪'),
                    Text('المنطقة: ${data['area'] ?? ''}'),
                    Text('الهاتف: ${data['contactPhone'] ?? ''}'),
                    Text('الحالة: ${data['condition'] ?? ''}'),
                    Text('صاحب الطلب: ${data['userEmail'] ?? ''}'),
                    Text('حالة الطلب: $status'),
                    if (status == 'pending') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                await doc.reference.update({
                                  'status': 'approved',
                                  'approvedAt': FieldValue.serverTimestamp(),
                                  'approvedBy':
                                      FirebaseAuth.instance.currentUser?.uid,
                                  'updatedAt': FieldValue.serverTimestamp(),
                                });

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'تم قبول ونشر إعلان المزاد ✅',
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: const Text('قبول ونشر'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await doc.reference.update({
                                  'status': 'rejected',
                                  'updatedAt': FieldValue.serverTimestamp(),
                                });

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'تم رفض طلب المزاد.',
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: const Text('رفض'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _salesTab(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('auction_sales').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = (snapshot.data?.docs ?? const []).toList()
          ..sort((a, b) {
            final aTime =
                (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                    0;

            final bTime =
                (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                    0;

            return bTime.compareTo(aTime);
          });

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'لا توجد عمليات بيع في المزاد حالياً.',
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final sale = docs[index];
            final data = sale.data();

            final status = data['status']?.toString() ?? 'pending_commission';

            String statusLabel;

            switch (status) {
              case 'commission_paid':
                statusLabel = 'تم استلام العمولة';
                break;

              case 'completed':
                statusLabel = 'تم البيع';
                break;

              default:
                statusLabel = 'بانتظار العمولة';
            }

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      data['itemName']?.toString() ?? 'سلعة مزاد',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'سعر البيع: ${data['salePrice'] ?? 0} ₪',
                    ),
                    Text(
                      'عمولة بركة: ${data['commissionAmount'] ?? 0} ₪',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'البائع: ${data['sellerId'] ?? ''}',
                    ),
                    Text(
                      'المشتري: ${data['buyerId'] ?? ''}',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'الحالة: $statusLabel',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (status == 'pending_commission') ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => _confirmCommission(context, sale),
                        icon: const Icon(
                          Icons.payments_rounded,
                        ),
                        label: const Text(
                          'تأكيد استلام عمولة بركة',
                        ),
                      ),
                    ],
                    if (status == 'commission_paid') ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => _completeSale(context, sale),
                        icon: const Icon(
                          Icons.check_circle_rounded,
                        ),
                        label: const Text(
                          'تأكيد إتمام البيع',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة المزاد'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(
                text: 'طلبات الإعلانات',
              ),
              Tab(
                text: 'عمليات البيع',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _requestsTab(context),
            _salesTab(context),
          ],
        ),
      ),
    );
  }
}
