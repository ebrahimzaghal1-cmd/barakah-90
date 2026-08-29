import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../games/play_hub_screen.dart';
import '../services/firebase_state.dart';
import '../services/order_service.dart';
import '../theme/app_theme.dart';
import '../widgets/barakah_brand.dart';
import 'authentication_screen.dart';
import '../widgets/barakah_reactions.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!FirebaseState.isReady) {
      return const _OrdersPreviewScreen();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;

        if (user == null) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text(
                'طلباتي',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              centerTitle: true,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
            ),
            body: BarakahBrandBackdrop(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xEFFFFFFF),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: AppTheme.coolYellow.withOpacity(.38),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 22,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              color: AppTheme.coolYellow.withOpacity(.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: AppTheme.coolYellow,
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'سجّل الدخول لعرض طلباتك',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'بعد تسجيل الدخول ستظهر طلباتك الحالية والسابقة هنا.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black45,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AuthenticationScreen(),
                                ),
                              ),
                              icon: const Icon(Icons.login_rounded),
                              label: const Text('تسجيل الدخول'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text(
              'طلباتي',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
          ),
          body: BarakahBrandBackdrop(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: OrderService().customerOrders(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'تعذر تحميل الطلبات.',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final orders = snapshot.data!.docs.toList()
                  ..sort((a, b) {
                    final right = b.data()['createdAt'] as Timestamp?;
                    final left = a.data()['createdAt'] as Timestamp?;
                    return (right?.millisecondsSinceEpoch ?? 0)
                        .compareTo(left?.millisecondsSinceEpoch ?? 0);
                  });

                final currentOrders = orders
                    .where((order) => !_isPrevious(order.data()['status']))
                    .toList();

                final previousOrders = orders
                    .where((order) => _isPrevious(order.data()['status']))
                    .toList();

                return _OrdersSplitView(
                  currentOrders: currentOrders,
                  previousOrders: previousOrders,
                  statusLabel: _status,
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _status(Object? value) => switch (value) {
        'scheduled' => 'مجدول',
        'accepted' => 'تم قبول الطلب',
        'preparing' => 'قيد التحضير',
        'ready' => 'جاهز',
        'awaiting_driver' => 'بانتظار سائق',
        'driver_assigned' => 'تم تعيين سائق',
        'picked_up' => 'مع السائق',
        'rejected' => 'اعتذر المحل عن الطلب',
        'delivered' => 'تم التسليم',
        'cancelled' => 'ملغي',
        'canceled' => 'ملغي',
        _ => 'طلب جديد',
      };

  bool _isPrevious(Object? status) =>
      const {'delivered', 'rejected', 'cancelled', 'canceled'}.contains(status);
}

class _OrdersSplitView extends StatefulWidget {
  const _OrdersSplitView({
    required this.currentOrders,
    required this.previousOrders,
    required this.statusLabel,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> currentOrders;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> previousOrders;
  final String Function(Object?) statusLabel;

  @override
  State<_OrdersSplitView> createState() => _OrdersSplitViewState();
}

class _OrdersSplitViewState extends State<_OrdersSplitView> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        final showingCurrent = _selectedTab == 0;
        final selectedOrders =
            showingCurrent ? widget.currentOrders : widget.previousOrders;

        return Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFFCFCFB),
                Color(0xFFF8F6F0),
              ],
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                wide ? 28 : 12,
                16,
                wide ? 28 : 12,
                28,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: _OrdersSummaryPanel(
                      currentCount: widget.currentOrders.length,
                      previousCount: widget.previousOrders.length,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: _OrdersTabs(
                      selectedIndex: _selectedTab,
                      onChanged: (index) => setState(
                        () => _selectedTab = index,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: wide ? 760 : double.infinity,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      child: _OrderSection(
                        key: ValueKey(_selectedTab),
                        title:
                            showingCurrent ? 'قيد التنفيذ' : 'الطلبات المكتملة',
                        icon: showingCurrent
                            ? Icons.local_shipping_rounded
                            : Icons.check_circle_outline_rounded,
                        orders: selectedOrders,
                        emptyTitle: showingCurrent
                            ? 'لا توجد طلبات قيد التنفيذ'
                            : 'لا توجد طلبات مكتملة',
                        emptySubtitle: showingCurrent
                            ? 'عندما تطلب من بركة ستتابع طلبك هنا خطوة بخطوة.'
                            : 'بعد اكتمال طلباتك ستجدها هنا للرجوع إليها.',
                        emptyIcon: showingCurrent
                            ? Icons.shopping_bag_outlined
                            : Icons.inventory_2_outlined,
                        statusLabel: widget.statusLabel,
                        current: showingCurrent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OrdersGlassSurface extends StatelessWidget {
  const _OrdersGlassSurface({
    required this.child,
    this.padding,
    this.decoration,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Decoration? decoration;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 18,
          sigmaY: 18,
        ),
        child: Container(
          padding: padding,
          decoration: decoration ??
              BoxDecoration(
                color: const Color(0xAFFFFFFF),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: Colors.white.withOpacity(.15),
                ),
              ),
          child: child,
        ),
      ),
    );
  }
}

class _OrdersSummaryPanel extends StatelessWidget {
  const _OrdersSummaryPanel({
    required this.currentCount,
    required this.previousCount,
  });

  final int currentCount;
  final int previousCount;

  @override
  Widget build(BuildContext context) {
    final total = currentCount + previousCount;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.deepYellow.withOpacity(.22),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _OrdersCounter(
              label: 'إجمالي الطلبات',
              count: total,
              icon: Icons.shopping_bag_outlined,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _OrdersCounter(
              label: 'قيد التنفيذ',
              count: currentCount,
              icon: Icons.schedule_rounded,
              highlighted: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _OrdersCounter(
              label: 'مكتملة',
              count: previousCount,
              icon: Icons.check_circle_outline_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersCounter extends StatelessWidget {
  const _OrdersCounter({
    required this.label,
    required this.count,
    required this.icon,
    this.highlighted = false,
  });

  final String label;
  final int count;
  final IconData icon;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
      decoration: BoxDecoration(
        color: highlighted
            ? AppTheme.coolYellow.withOpacity(.92)
            : const Color(0xFFF8F8F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted
              ? AppTheme.deepYellow.withOpacity(.40)
              : Colors.black.withOpacity(.08),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: highlighted ? AppTheme.navy : Colors.black38,
            size: 19,
          ),
          const SizedBox(height: 3),
          Text(
            '$count',
            style: TextStyle(
              color: highlighted ? AppTheme.navy : AppTheme.navy,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: highlighted ? AppTheme.navy : Colors.black54,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersTabs extends StatelessWidget {
  const _OrdersTabs({
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _OrdersTabButton(
            label: 'قيد التنفيذ',
            selected: selectedIndex == 0,
            onTap: () => onChanged(0),
          ),
          _OrdersTabButton(
            label: 'مكتملة',
            selected: selectedIndex == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _OrdersTabButton extends StatelessWidget {
  const _OrdersTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? AppTheme.deepYellow.withOpacity(.48)
                      : Colors.transparent,
                ),
                boxShadow: selected
                    ? const [
                        BoxShadow(
                          color: Color(0x10000000),
                          blurRadius: 9,
                          offset: Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? AppTheme.navy : Colors.black45,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      );
}

class _OrdersGameBanner extends StatelessWidget {
  const _OrdersGameBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withOpacity(.38),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF617CFF).withOpacity(.34),
                blurRadius: 30,
                spreadRadius: 1,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(.32),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              children: [
                Image.asset(
                  'assets/images/barakah_games_banner.jpeg',
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(.22),
                            Colors.transparent,
                            const Color(0xFF645CFF).withOpacity(.12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 30,
                  right: 30,
                  child: IgnorePointer(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(.05),
                            Colors.white.withOpacity(.62),
                            Colors.white.withOpacity(.05),
                          ],
                        ),
                      ),
                    ),
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

class _OrderSection extends StatelessWidget {
  const _OrderSection({
    super.key,
    required this.title,
    required this.icon,
    required this.orders,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyIcon,
    required this.statusLabel,
    required this.current,
  });

  final String title;
  final IconData icon;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> orders;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData emptyIcon;
  final String Function(Object?) statusLabel;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return _OrdersGlassSurface(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x9FFFFFFF),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: current
              ? AppTheme.coolYellow.withOpacity(.30)
              : Colors.white.withOpacity(.70),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OrderSectionHeader(
            title: title,
            icon: icon,
            count: orders.length,
            current: current,
          ),
          const SizedBox(height: 12),
          if (orders.isEmpty)
            _EmptyOrderState(
              title: emptyTitle,
              subtitle: emptySubtitle,
              icon: emptyIcon,
            )
          else
            ...List.generate(
              orders.length,
              (index) => Padding(
                padding: EdgeInsets.only(
                  bottom: index == orders.length - 1 ? 0 : 10,
                ),
                child: _OrderCard(
                  order: orders[index],
                  statusLabel: statusLabel,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderSectionHeader extends StatelessWidget {
  const _OrderSectionHeader({
    required this.title,
    required this.icon,
    required this.count,
    required this.current,
  });

  final String title;
  final IconData icon;
  final int count;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return _OrdersGlassSurface(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
        gradient: LinearGradient(
          colors: current
              ? [
                  AppTheme.coolYellow.withOpacity(.20),
                  Colors.white.withOpacity(.66),
                ]
              : [
                  Colors.white.withOpacity(.68),
                  Colors.white.withOpacity(.04),
                ],
        ),
        border: Border.all(
          color: current
              ? AppTheme.coolYellow.withOpacity(.35)
              : Colors.white.withOpacity(.70),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  current ? AppTheme.coolYellow : Colors.white.withOpacity(.70),
            ),
            child: Icon(
              icon,
              size: 21,
              color: current ? AppTheme.navy : Colors.black54,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 32),
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: AppTheme.coolYellow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyOrderState extends StatelessWidget {
  const _EmptyOrderState({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isCurrentOrdersEmpty = title.contains('حالية');

    return _OrdersGlassSurface(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: BoxDecoration(
        color: const Color(0x9AFFFFFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(.68),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: isCurrentOrdersEmpty ? 150 : 122,
            child: Image.asset(
              isCurrentOrdersEmpty
                  ? 'assets/images/bunny_stickers/empty_cart.png'
                  : 'assets/images/barakah_cart_bunny.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                icon,
                size: 58,
                color: AppTheme.coolYellow,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black45,
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _firstImageUrl(
  Map<String, dynamic> data,
  List<String> keys,
) {
  for (final key in keys) {
    final rawValue = data[key];
    if (rawValue is String && rawValue.trim().isNotEmpty) {
      return rawValue.trim();
    }
    if (rawValue is List) {
      for (final entry in rawValue) {
        final value = entry?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
    }
    if (rawValue is Map) {
      for (final nestedKey in const ['url', 'image', 'imageUrl', 'src']) {
        final value = rawValue[nestedKey]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
    }
  }
  return '';
}

String _orderItemImage(Map<String, dynamic> item) => _firstImageUrl(
      item,
      const [
        'image',
        'imageUrl',
        'productImage',
        'thumbnail',
        'photo',
        'coverImage',
        'images',
      ],
    );

String _orderItemDocumentId(Map<String, dynamic> item) {
  for (final key in const ['productId', 'itemId', 'id']) {
    final value = item[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

class _OrderDocumentImage extends StatefulWidget {
  const _OrderDocumentImage({
    required this.directUrl,
    required this.documentId,
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.fallbackIcon,
  });

  final String directUrl;
  final String documentId;
  final double width;
  final double height;
  final double borderRadius;
  final IconData fallbackIcon;

  @override
  State<_OrderDocumentImage> createState() => _OrderDocumentImageState();
}

class _OrderDocumentImageState extends State<_OrderDocumentImage> {
  late Future<String> _imageUrl;

  @override
  void initState() {
    super.initState();
    _imageUrl = _resolveImage();
  }

  @override
  void didUpdateWidget(covariant _OrderDocumentImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.directUrl != widget.directUrl ||
        oldWidget.documentId != widget.documentId) {
      _imageUrl = _resolveImage();
    }
  }

  Future<String> _resolveImage() async {
    final direct = widget.directUrl.trim();
    if (direct.isNotEmpty) return direct;

    final documentId = widget.documentId.trim();
    if (documentId.isEmpty || !FirebaseState.isReady) return '';

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('items')
          .doc(documentId)
          .get();
      final data = snapshot.data();
      if (data == null) return '';
      return _firstImageUrl(
        data,
        const [
          'image',
          'imageUrl',
          'photo',
          'coverImage',
          'thumbnail',
          'images'
        ],
      );
    } catch (_) {
      return '';
    }
  }

  Widget _placeholder() => ColoredBox(
        color: AppTheme.coolYellow.withOpacity(.12),
        child: Center(
          child: Icon(
            widget.fallbackIcon,
            color: AppTheme.deepYellow,
            size: widget.width * .42,
          ),
        ),
      );

  Widget _image(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    return Image.asset(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: AppTheme.deepYellow.withOpacity(.48),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<String>(
        future: _imageUrl,
        builder: (context, snapshot) {
          final url = snapshot.data?.trim() ?? '';
          if (url.isEmpty) return _placeholder();
          return _image(url);
        },
      ),
    );
  }
}

class _OrderItemsPreview extends StatelessWidget {
  const _OrderItemsPreview({required this.lines});

  final List<dynamic> lines;

  @override
  Widget build(BuildContext context) {
    final items = lines
        .whereType<Map>()
        .map((line) => Map<String, dynamic>.from(line))
        .take(5)
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final item = items[index];
          return Tooltip(
            message: item['title']?.toString() ?? 'صنف',
            child: _OrderDocumentImage(
              directUrl: _orderItemImage(item),
              documentId: _orderItemDocumentId(item),
              width: 48,
              height: 48,
              borderRadius: 12,
              fallbackIcon: Icons.fastfood_rounded,
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.statusLabel,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> order;
  final String Function(Object?) statusLabel;

  @override
  Widget build(BuildContext context) {
    final data = order.data();

    final lines = (data['items'] as List?) ?? const [];
    final number =
        data['orderNumber'] ?? order.id.substring(0, 6).toUpperCase();
    final firstLine = lines.isNotEmpty && lines.first is Map
        ? Map<String, dynamic>.from(lines.first as Map)
        : <String, dynamic>{};
    final businessTitle =
        data['businessTitle']?.toString().trim().isNotEmpty == true
            ? data['businessTitle'].toString().trim()
            : firstLine['businessTitle']?.toString().trim().isNotEmpty == true
                ? firstLine['businessTitle'].toString().trim()
                : 'بركة';
    final businessId = data['businessId']?.toString().trim().isNotEmpty == true
        ? data['businessId'].toString().trim()
        : firstLine['businessId']?.toString().trim() ?? '';
    final directBusinessImage = _firstImageUrl(
      data,
      const ['businessImage', 'restaurantImage', 'businessImageUrl'],
    );
    final businessImage = directBusinessImage.isNotEmpty
        ? directBusinessImage
        : _firstImageUrl(
            firstLine,
            const ['businessImage', 'restaurantImage', 'businessImageUrl'],
          );
    final status = data['status']?.toString() ?? 'new';

    final isDelivered = data['status'] == 'delivered';
    final savedReaction = data['customerReaction']?.toString();

    return _OrdersGlassSurface(
      decoration: BoxDecoration(
        color: const Color(0xDFFFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.coolYellow.withOpacity(.34),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        childrenPadding: const EdgeInsets.only(bottom: 7),
        title: Row(
          children: [
            _OrderDocumentImage(
              directUrl: businessImage,
              documentId: businessId,
              width: 58,
              height: 58,
              borderRadius: 14,
              fallbackIcon: Icons.storefront_rounded,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'طلب #$number',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    businessTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.coolYellow.withOpacity(.16),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: AppTheme.deepYellow.withOpacity(.45),
                      ),
                    ),
                    child: Text(
                      statusLabel(status),
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${data['total'] ?? 0} ₪',
                    style: const TextStyle(
                      color: AppTheme.navy,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _OrderCompactProgress(status: status),
              const SizedBox(height: 10),
              _OrderItemsPreview(lines: lines),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 4, 9, 10),
            child: _OrderStatusTimeline(
              status: status,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 0, 9, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _OrderInvoiceScreen(
                          orderId: order.id,
                          data: data,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: const Text('عرض التفاصيل'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      builder: (_) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          child: _OrderStatusTimeline(status: status),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.location_on_outlined, size: 18),
                    label: const Text('تتبع الطلب'),
                  ),
                ),
              ],
            ),
          ),
          ...lines.map((line) {
            final item = line is Map
                ? Map<String, dynamic>.from(line)
                : <String, dynamic>{};

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              child: Row(
                children: [
                  _OrderDocumentImage(
                    directUrl: _orderItemImage(item),
                    documentId: _orderItemDocumentId(item),
                    width: 46,
                    height: 46,
                    borderRadius: 11,
                    fallbackIcon: Icons.fastfood_rounded,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title']?.toString() ?? 'صنف',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'الكمية: ${item['quantity'] ?? 1}',
                          style: const TextStyle(
                            color: Colors.black45,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          if (const {'new', 'scheduled'}.contains(data['status'])) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                  ),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text(
                    'إلغاء الطلب',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('إلغاء الطلب'),
                        content: const Text(
                          'هل تريد إلغاء هذا الطلب؟ إذا كنت استخدمت نقاط بركة فسيتم إرجاعها تلقائيًا.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('تراجع'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('تأكيد الإلغاء'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed != true) return;

                    try {
                      await OrderService().cancelOrder(order.id);

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'تم إلغاء الطلب وإرجاع نقاط بركة المستخدمة إن وجدت ✅',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (error) {
                      if (!context.mounted) return;

                      final message = error is StateError
                          ? error.message.toString()
                          : 'تعذر إلغاء الطلب الآن.';

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
          ],
          if (const {'cancelled', 'canceled'}.contains(data['status']) &&
              ((data['barakahPointsUsed'] as num?)?.toInt() ?? 0) > 0 &&
              data['barakahPointsRefunded'] != true) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.coolYellow,
                  ),
                  onPressed: () async {
                    try {
                      await OrderService().cancelOrder(order.id);

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'تم استرداد ${((data['barakahPointsUsed'] as num?)?.toInt() ?? 0)} نقطة إلى بطاقة بركة ✅',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (error) {
                      if (!context.mounted) return;

                      final message = error is StateError
                          ? error.message.toString()
                          : 'تعذر استرداد النقاط الآن.';

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.restore_rounded),
                  label: Text(
                    'استرداد ${((data['barakahPointsUsed'] as num?)?.toInt() ?? 0)} نقطة',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (isDelivered) ...[
            const SizedBox(height: 8),
            Divider(
              color: Colors.white.withOpacity(.94),
              indent: 12,
              endIndent: 12,
            ),
            const SizedBox(height: 4),
            const Text(
              'كيف كان طلبك؟ 🐰',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            BarakahReactions(
              selectedId: savedReaction,
              onChanged: (reaction) async {
                try {
                  await order.reference.update({
                    'customerReaction': reaction.id,
                    'reactionUpdatedAt': FieldValue.serverTimestamp(),
                  });

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'شكراً لتقييمك: ${reaction.label} 🐰',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تعذر حفظ التقييم، حاولي مرة أخرى.'),
                      ),
                    );
                  }
                  rethrow;
                }
              },
            ),
            const SizedBox(height: 5),
          ],
        ],
      ),
    );
  }
}

class _OrderCompactProgress extends StatelessWidget {
  const _OrderCompactProgress({required this.status});

  final String status;

  static const _labels = <String>[
    'قبول الطلب',
    'قيد التحضير',
    'في الطريق',
    'تم التوصيل',
  ];

  int get _reachedIndex => switch (status) {
        'delivered' => 3,
        'picked_up' => 2,
        'preparing' || 'ready' || 'awaiting_driver' || 'driver_assigned' => 1,
        'new' || 'scheduled' || 'accepted' => 0,
        _ => -1,
      };

  @override
  Widget build(BuildContext context) {
    final cancelled = const {
      'rejected',
      'cancelled',
      'canceled',
    }.contains(status);
    final reachedIndex = cancelled ? -1 : _reachedIndex;

    return Row(
      children: List.generate(_labels.length * 2 - 1, (index) {
        if (index.isOdd) {
          final stepIndex = index ~/ 2;
          final reached = stepIndex < reachedIndex;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              height: 3,
              color: reached ? AppTheme.deepYellow : const Color(0xFFD9DDE3),
            ),
          );
        }

        final stepIndex = index ~/ 2;
        final reached = stepIndex <= reachedIndex;

        return SizedBox(
          width: 58,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: reached ? AppTheme.deepYellow : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        reached ? AppTheme.deepYellow : const Color(0xFFBFC5CE),
                    width: 2,
                  ),
                ),
                child: reached
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 13,
                      )
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                _labels[stepIndex],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: reached ? AppTheme.navy : Colors.black38,
                  fontSize: 8,
                  fontWeight: reached ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _OrderInvoiceScreen extends StatelessWidget {
  const _OrderInvoiceScreen({
    required this.orderId,
    required this.data,
  });

  final String orderId;
  final Map<String, dynamic> data;

  num _number(Object? value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(Object? value) {
    final amount = _number(value);
    return amount == amount.roundToDouble()
        ? '${amount.toInt()} ₪'
        : '${amount.toStringAsFixed(2)} ₪';
  }

  String _date(Object? value) {
    final date = switch (value) {
      Timestamp timestamp => timestamp.toDate(),
      DateTime dateTime => dateTime,
      int milliseconds => DateTime.fromMillisecondsSinceEpoch(milliseconds),
      _ => null,
    };
    if (date == null) return 'غير متوفر';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}/${two(date.month)}/${two(date.day)}  '
        '${two(date.hour)}:${two(date.minute)}';
  }

  String _paymentLabel(Object? value) => switch (value?.toString()) {
        'cash' => 'الدفع عند الاستلام',
        'card' => 'بطاقة',
        'online' => 'دفع إلكتروني',
        final String value when value.isNotEmpty => value,
        _ => 'غير محدد',
      };

  String _deliveryLabel(Object? value) => switch (value?.toString()) {
        'delivery' => 'توصيل',
        'pickup' => 'استلام من المحل',
        final String value when value.isNotEmpty => value,
        _ => 'غير محدد',
      };

  @override
  Widget build(BuildContext context) {
    final rawItems = data['items'] as List? ?? const [];
    final items = rawItems
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final orderNumber = data['orderNumber']?.toString() ??
        orderId.substring(0, 6).toUpperCase();
    final subtotal = _number(data['subtotal']);
    final deliveryFee = _number(data['deliveryFee']);
    final discount = _number(
      data['discount'] ?? data['barakahPointsDiscount'],
    );
    final total = _number(data['payableTotal'] ?? data['total']);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F6EE),
        appBar: AppBar(
          title: const Text(
            'فاتورة الطلب',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppTheme.deepYellow.withOpacity(.42),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 18,
                      offset: Offset(0, 7),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.receipt_long_rounded,
                      color: AppTheme.deepYellow,
                      size: 46,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'فاتورة #$orderNumber',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _date(data['createdAt']),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.ink.withOpacity(.55),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Divider(),
                    ...items.map((item) {
                      final quantity = _number(item['quantity']);
                      final unitPrice = _number(
                        item['price'] ?? item['unitPrice'],
                      );
                      final lineTotal = _number(
                        item['subtotal'] ??
                            item['lineTotal'] ??
                            unitPrice * (quantity == 0 ? 1 : quantity),
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFEFA),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: AppTheme.coolYellow.withOpacity(.28),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _OrderDocumentImage(
                                directUrl: _orderItemImage(item),
                                documentId: _orderItemDocumentId(item),
                                width: 64,
                                height: 64,
                                borderRadius: 13,
                                fallbackIcon: Icons.fastfood_rounded,
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['title']?.toString() ??
                                          item['name']?.toString() ??
                                          'صنف',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      'الكمية: ${quantity == 0 ? 1 : quantity}',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _money(lineTotal),
                                style: const TextStyle(
                                  color: AppTheme.navy,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'تفاصيل الأصناف غير متوفرة لهذا الطلب.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.ink.withOpacity(.55),
                          ),
                        ),
                      ),
                    const Divider(height: 28),
                    if (subtotal > 0)
                      _InvoiceRow(
                          label: 'المجموع الفرعي', value: _money(subtotal)),
                    if (deliveryFee > 0)
                      _InvoiceRow(
                          label: 'رسوم التوصيل', value: _money(deliveryFee)),
                    if (discount > 0)
                      _InvoiceRow(
                        label: 'الخصم',
                        value: '- ${_money(discount)}',
                        valueColor: Colors.green.shade700,
                      ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.coolYellow.withOpacity(.24),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'الإجمالي',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            _money(total),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _InvoiceRow(
                      label: 'طريقة الدفع',
                      value: _paymentLabel(data['paymentMethod']),
                    ),
                    _InvoiceRow(
                      label: 'طريقة الاستلام',
                      value: _deliveryLabel(data['deliveryMethod']),
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

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.ink.withOpacity(.62),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppTheme.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderStatusTimeline extends StatelessWidget {
  const _OrderStatusTimeline({required this.status});

  final String status;

  static const _steps = <({String id, String label})>[
    (id: 'new', label: 'طلب جديد'),
    (id: 'accepted', label: 'تم قبول الطلب'),
    (id: 'preparing', label: 'قيد التحضير'),
    (id: 'ready', label: 'جاهز'),
    (id: 'driver_assigned', label: 'تم تعيين سائق'),
    (id: 'picked_up', label: 'مع السائق'),
    (id: 'delivered', label: 'تم التسليم'),
  ];

  @override
  Widget build(BuildContext context) {
    if (const {'rejected', 'cancelled', 'canceled'}.contains(status)) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEEEE),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFE85D5D)),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 15,
              backgroundColor: Color(0xFFE85D5D),
              child: Icon(Icons.close_rounded, color: Colors.black, size: 19),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                status == 'rejected'
                    ? 'اعتذر المحل عن الطلب'
                    : 'تم إلغاء الطلب',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final effectiveStatus = status == 'scheduled' ? 'new' : status;
    final currentIndex =
        _steps.indexWhere((step) => step.id == effectiveStatus);
    final reachedIndex = currentIndex < 0 ? 0 : currentIndex;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 13, 12, 9),
      decoration: BoxDecoration(
        color: AppTheme.coolYellow.withOpacity(.10),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.black.withOpacity(.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'متابعة حالة الطلب',
            style: TextStyle(
              color: Colors.black,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(_steps.length, (index) {
            final reached = index <= reachedIndex;
            final step = _steps[index];
            final label = status == 'scheduled' && index == 0
                ? 'الطلب مجدول'
                : step.label;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: reached ? AppTheme.navy : AppTheme.coolYellow,
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: reached
                            ? const [
                                BoxShadow(
                                  color: Color(0x33202B52),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: reached
                          ? const Icon(
                              Icons.check_rounded,
                              color: AppTheme.coolYellow,
                              size: 21,
                            )
                          : null,
                    ),
                    if (index < _steps.length - 1)
                      Container(
                        width: 3,
                        height: 24,
                        color: index < reachedIndex
                            ? AppTheme.navy
                            : AppTheme.coolYellow,
                      ),
                  ],
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: reached ? FontWeight.w900 : FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _OrdersPreviewScreen extends StatelessWidget {
  const _OrdersPreviewScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'طلباتي',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: BarakahBrandBackdrop(
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFFCFCFB),
                Color(0xFFF8F6F0),
              ],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              const _OrdersSummaryPanel(
                currentCount: 0,
                previousCount: 0,
              ),
              const SizedBox(height: 18),
              const _PreviewOrderSection(
                title: 'الطلبات الحالية',
                icon: Icons.receipt_long_rounded,
                emptyTitle: 'لا توجد طلبات حالية',
                emptySubtitle:
                    'عندما تطلب من بركة سيظهر طلبك هنا وتقدر تتابعه خطوة بخطوة.',
                current: true,
              ),
              const SizedBox(height: 16),
              _OrdersGameBanner(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PlayHubScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const _PreviewOrderSection(
                title: 'الطلبات السابقة',
                icon: Icons.history_rounded,
                emptyTitle: 'لا توجد طلبات سابقة',
                emptySubtitle:
                    'بعد اكتمال طلباتك ستجدها هنا للرجوع إليها في أي وقت.',
                current: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewOrderSection extends StatelessWidget {
  const _PreviewOrderSection({
    required this.title,
    required this.icon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.current,
  });

  final String title;
  final IconData icon;
  final String emptyTitle;
  final String emptySubtitle;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return _OrdersGlassSurface(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x9FFFFFFF),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: current
              ? AppTheme.coolYellow.withOpacity(.30)
              : Colors.white.withOpacity(.70),
        ),
      ),
      child: Column(
        children: [
          _OrderSectionHeader(
            title: title,
            icon: icon,
            count: 0,
            current: current,
          ),
          const SizedBox(height: 12),
          _EmptyOrderState(
            title: emptyTitle,
            subtitle: emptySubtitle,
            icon: Icons.inventory_2_outlined,
          ),
        ],
      ),
    );
  }
}
