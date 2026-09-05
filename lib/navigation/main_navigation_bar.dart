import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

import '../screens/restaurants_screen.dart';
import '../screens/market_screen.dart';
import '../screens/cart_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/customer_support_chat_screen.dart';
import '../widgets/barakah_waiting_screen.dart';
import '../services/app_hours_service.dart';
import '../services/firebase_state.dart';
import 'package:url_launcher/url_launcher.dart';

class MainNavBar extends StatefulWidget {
  const MainNavBar({super.key});

  @override
  State<MainNavBar> createState() => _MainNavBarState();
}

class _MainNavBarState extends State<MainNavBar> {
  int currentIndex = 0;

  bool _switchingTab = false;
  bool _startupHoursChecked = false;

  late final List<Widget> screens;

  int get _safeCurrentIndex {
    if (screens.isEmpty) return 0;
    return currentIndex.clamp(0, screens.length - 1);
  }

  Future<void> _changeTab(int index) async {
    if (index < 0 || index >= screens.length) return;
    if (index == currentIndex || _switchingTab) return;

    setState(() => _switchingTab = true);

    await Future<void>.delayed(
      const Duration(milliseconds: 420),
    );

    if (!mounted) return;

    setState(() {
      currentIndex = index;
      _switchingTab = false;
    });
  }

  @override
  void initState() {
    super.initState();

    screens = [
      const RestaurantsScreen(),
      const MarketScreen(),
      const CartScreen(),
      const OrdersScreen(),
      const ProfileScreen(),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showClosedHoursNotice();
    });
  }

  Future<void> _showClosedHoursNotice() async {
    if (_startupHoursChecked || !FirebaseState.isReady) return;
    _startupHoursChecked = true;

    try {
      final status = await AppHoursService.fetch();
      if (!mounted || status == null || status.isOpen) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.schedule_rounded,
            color: Color(0xFFA52626),
            size: 42,
          ),
          title: const Text(
            'أوقات عمل بركة',
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                status.detail,
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.5),
              ),
              const SizedBox(height: 12),
              Text(
                'ساعات العمل: ${status.openingTime} - ${status.closingTime}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('حسنًا'),
            ),
          ],
        ),
      );
    } catch (_) {
      // لا نمنع فتح التطبيق إذا تعذر جلب أوقات العمل مؤقتًا.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: screens[_safeCurrentIndex],
          ),
          const Positioned(
            right: -7,
            bottom: 116,
            child: _BarakahContactButton(),
          ),
          if (_switchingTab)
            const Positioned.fill(
              child: BarakahWaitingScreen(),
            ),
        ],
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(.96),
                  const Color(0xF7F7FCFA),
                  const Color(0xF2FFF9EE),
                ],
              ),
              border: Border(
                top: BorderSide(
                  color: const Color(0xFFD7A928).withOpacity(.40),
                  width: .9,
                ),
              ),
            ),
            child: Directionality(
              // ترتيب ثابت من اليسار إلى اليمين: المطاعم ثم الماركت وصولاً للملف الشخصي.
              textDirection: TextDirection.ltr,
              child: BottomNavigationBar(
                currentIndex: _safeCurrentIndex,
                onTap: _changeTab,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: const Color(0xFFD7A928),
                unselectedItemColor: AppTheme.navy.withOpacity(.62),
                selectedLabelStyle:
                    const TextStyle(fontWeight: FontWeight.w800),
                unselectedLabelStyle:
                    const TextStyle(fontWeight: FontWeight.w600),
                backgroundColor: Colors.transparent,
                elevation: 0,
                items: [
                  const BottomNavigationBarItem(
                      icon: Icon(Icons.restaurant_rounded, size: 24),
                      activeIcon: Icon(Icons.restaurant_rounded, size: 30),
                      label: 'مطاعم'),
                  const BottomNavigationBarItem(
                      icon: Icon(Icons.storefront_outlined, size: 24),
                      activeIcon: Icon(Icons.storefront_rounded, size: 30),
                      label: 'ماركت'),
                  const BottomNavigationBarItem(
                      icon: Icon(
                        Icons.shopping_cart_outlined,
                        size: 29,
                      ),
                      activeIcon: Icon(
                        Icons.shopping_cart_rounded,
                        size: 36,
                      ),
                      label: 'سلتي'),
                  const BottomNavigationBarItem(
                      icon: Icon(Icons.receipt_long_outlined, size: 24),
                      activeIcon: Icon(Icons.receipt_long_rounded, size: 30),
                      label: 'طلباتي'),
                  BottomNavigationBarItem(
                      icon: SizedBox(
                        width: 48,
                        height: 44,
                        child: OverflowBox(
                          maxWidth: 64,
                          maxHeight: 64,
                          child: Image.asset(
                            'assets/images/profile_favorites_sticker_v2.png',
                            width: 64,
                            height: 64,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      activeIcon: SizedBox(
                        width: 52,
                        height: 48,
                        child: OverflowBox(
                          maxWidth: 72,
                          maxHeight: 72,
                          child: Image.asset(
                            'assets/images/profile_favorites_sticker_v2.png',
                            width: 72,
                            height: 72,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      label: 'صفحتي'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BarakahContactButton extends StatefulWidget {
  const _BarakahContactButton();

  @override
  State<_BarakahContactButton> createState() => _BarakahContactButtonState();
}

class _BarakahContactButtonState extends State<_BarakahContactButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: .94, end: 1.06).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _openUri(Uri uri, String failureMessage) async {
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage)),
      );
    }
  }

  Future<void> _showContactOptions() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('app_settings')
        .doc('support_contact')
        .get();
    if (!mounted) return;
    final data = snapshot.data() ?? const <String, dynamic>{};
    final phone = data['phone']?.toString().trim() ?? '';
    final whatsApp = data['whatsapp']?.toString().trim() ?? '';
    final whatsAppDigits = whatsApp.replaceAll(RegExp(r'\D'), '');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.56),
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 13, 22, 30),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'تواصل مع بركة',
                  style: TextStyle(
                    color: AppTheme.navy,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'نحن جاهزون لمساعدتك',
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (whatsAppDigits.isNotEmpty) ...[
                      Expanded(
                        child: _ContactActionCard(
                          title: 'واتساب',
                          icon: Icons.chat_rounded,
                          color: const Color(0xFF24C863),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            const message = 'مرحباً بركة، أريد التواصل معكم.';
                            _openUri(
                              Uri.parse(
                                'https://wa.me/$whatsAppDigits?text=${Uri.encodeComponent(message)}',
                              ),
                              'تعذر فتح واتساب.',
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (phone.isNotEmpty) ...[
                      Expanded(
                        child: _ContactActionCard(
                          title: 'مكالمة هاتفية',
                          icon: Icons.phone_in_talk_rounded,
                          color: AppTheme.navy,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _openUri(
                              Uri.parse('tel:$phone'),
                              'تعذر فتح المكالمة.',
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: _ContactActionCard(
                        title: 'محادثة داخلية',
                        icon: Icons.forum_rounded,
                        color: AppTheme.deepYellow,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CustomerSupportChatScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _animationController,
            builder: (_, __) => Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.navy.withOpacity(
                  .10 + (_animationController.value * .08),
                ),
              ),
            ),
          ),
          Material(
            color: AppTheme.navy,
            shape: const CircleBorder(),
            elevation: 10,
            shadowColor: AppTheme.navy,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _showContactOptions,
              child: Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.coolYellow,
                    width: 1.4,
                  ),
                ),
                child: const Icon(
                  Icons.phone_in_talk_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactActionCard extends StatelessWidget {
  const _ContactActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            constraints: const BoxConstraints(minHeight: 142),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: color.withOpacity(.22)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0C000000),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: color.withOpacity(.11),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 37),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
