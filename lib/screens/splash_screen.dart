import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../navigation/main_navigation_bar.dart';
import 'authentication_screen.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _giftController;
  late final AnimationController _logoController;

  bool _loading = true;
  bool _showGift = false;
  bool _showReward = false;
  bool _openingGift = false;
  bool _showWelcome = false;
  bool _navigated = false;

  Timer? _welcomeTimer;

  static const String _giftIntroSeenKey = 'barakahGiftIntroSeenV2';

  @override
  void initState() {
    super.initState();

    _giftController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    _prepareStartup();
  }

  Future<void> _prepareStartup() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final giftSeen = prefs.getBool(_giftIntroSeenKey) ?? false;

    if (!mounted) return;

    if (!giftSeen) {
      await prefs.setBool(_giftIntroSeenKey, true);

      if (!mounted) return;

      setState(() {
        _loading = false;
        _showGift = true;
        _showReward = false;
        _showWelcome = false;
      });
      return;
    }

    setState(() {
      _loading = false;
      _showGift = false;
      _showReward = false;
      _showWelcome = true;
    });

    _startWelcome();
  }

  Future<void> _openGift() async {
    if (_openingGift) return;

    setState(() {
      _openingGift = true;
      _showGift = false;
      _showReward = true;
      _showWelcome = false;
    });
  }

  Future<void> _openRegistrationFromReward() async {
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AuthenticationScreen(),
      ),
    );

    if (!mounted) return;

    if (FirebaseAuth.instance.currentUser != null) {
      setState(() {
        _showGift = false;
        _showReward = false;
        _showWelcome = true;
        _openingGift = false;
      });

      _startWelcome();
      return;
    }

    setState(() => _openingGift = false);
  }

  void _startWelcome() {
    _logoController.forward(from: 0);
    _welcomeTimer?.cancel();
  }

  void _enterApp() {
    if (!mounted || _navigated) return;

    _navigated = true;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const MainNavBar(),
      ),
    );
  }

  @override
  void dispose() {
    _welcomeTimer?.cancel();
    _giftController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.navy,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: _showGift
          ? _FullGiftIntro(
              key: const ValueKey('gift'),
              onTap: _openingGift ? null : _openGift,
            )
          : _showReward
              ? _SignupRewardIntro(
                  key: const ValueKey('reward'),
                  onTap: _openRegistrationFromReward,
                )
              : _showWelcome
                  ? _PremiumWelcomeIntro(
                      key: const ValueKey('welcome'),
                      onTap: _enterApp,
                    )
                  : const SizedBox.shrink(),
    );
  }
}

class _FullGiftIntro extends StatelessWidget {
  const _FullGiftIntro({super.key, required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.navy,
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Center(
              child: Image.asset(
                'assets/images/splash/barakah_gift_box_v2.png',
                fit: BoxFit.contain,
                alignment: Alignment.center,
              ),
            ),
          ),
        ),
      );
}

class _SignupRewardIntro extends StatelessWidget {
  const _SignupRewardIntro({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF020B19),
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Center(
              child: Image.asset(
                'assets/images/splash/barakah_signup_gift.jpeg',
                fit: BoxFit.contain,
                alignment: Alignment.center,
              ),
            ),
          ),
        ),
      );
}

class _PremiumWelcomeIntro extends StatelessWidget {
  const _PremiumWelcomeIntro({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _AnimatedBarakahEntrance(onDone: onTap);
}

class _AnimatedBarakahEntrance extends StatefulWidget {
  const _AnimatedBarakahEntrance({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_AnimatedBarakahEntrance> createState() =>
      _AnimatedBarakahEntranceState();
}

class _AnimatedBarakahEntranceState extends State<_AnimatedBarakahEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6500),
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finish();
      })
      ..forward();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onDone();
  }

  double _phase(double start, double end) {
    final value = (_controller.value - start) / (end - start);
    return value.clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFFC928),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final ride = Curves.easeInOutCubic.transform(_phase(0.02, 0.66));
            final bikeOpacity = Curves.easeIn.transform(_phase(0.0, 0.10));
            final brake = math.sin(_phase(0.59, 0.71) * math.pi) * 7;
            final logoReveal =
                Curves.easeOutCubic.transform(_phase(0.65, 0.88));
            final subtitle = Curves.easeOut.transform(_phase(0.82, 0.96));

            final bikeWidth = math.min(size.width * 0.88, 520.0);
            final route = _barakahEntranceRoute(size);
            final routeMetric = route.computeMetrics().first;
            final tangent = routeMetric.getTangentForOffset(
              routeMetric.length * ride.clamp(0.0, 1.0),
            )!;
            final bikeLeft = tangent.position.dx - bikeWidth / 2;
            final bikeTop = tangent.position.dy - (bikeWidth / 1.155) / 2;
            final bikeScale = 0.16 + (0.84 * ride).clamp(0.0, 0.84);
            final bikeAngle = tangent.angle.clamp(-0.16, 0.16).toDouble();

            return Stack(
              fit: StackFit.expand,
              children: [
                _EntranceBackground(progress: ride),
                Positioned(
                  left: bikeLeft,
                  top: bikeTop - brake,
                  width: bikeWidth,
                  child: Opacity(
                    opacity: bikeOpacity,
                    child: Transform.scale(
                      scale: bikeScale,
                      alignment: Alignment.center,
                      child: Transform.rotate(
                        angle: bikeAngle - 0.018 * math.sin(ride * math.pi * 5),
                        child: Image.asset(
                          'assets/images/splash/barakah_delivery_splash.png',
                          width: bikeWidth,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  top: size.height * 0.12,
                  child: Column(
                    children: [
                      Opacity(
                        opacity: logoReveal,
                        child: Transform.scale(
                          scale: 0.90 + logoReveal * 0.10,
                          child: ClipRect(
                            child: Align(
                              alignment: Alignment.centerRight,
                              widthFactor: logoReveal,
                              child: const _BarakahSplashWordmark(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Opacity(
                        opacity: subtitle,
                        child: Transform.translate(
                          offset: Offset(0, 10 * (1 - subtitle)),
                          child: const Text(
                            'وصلنا… ويومك صار أبرك',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.navy,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Opacity(
                        opacity: subtitle,
                        child: const Text(
                          'اضغط للدخول',
                          style: TextStyle(
                            color: AppTheme.navy,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BarakahSplashWordmark extends StatelessWidget {
  const _BarakahSplashWordmark();

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'بركة',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: AppTheme.navy,
                    fontSize: 66,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -3,
                    shadows: [
                      Shadow(
                        color: Color(0x33C99A22),
                        blurRadius: 18,
                        offset: Offset(0, 7),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 14),
                SizedBox(
                  height: 42,
                  child: VerticalDivider(
                    color: Color(0xFFD29D1E),
                    thickness: 2,
                  ),
                ),
                SizedBox(width: 14),
                Text(
                  'BARAKAH',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    color: AppTheme.navy,
                    fontSize: 27,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: 116,
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: const LinearGradient(
                colors: [
                  Color(0x00D7A72A),
                  Color(0xFFD7A72A),
                  Color(0x00D7A72A)
                ],
              ),
            ),
          ),
        ],
      );
}

class _EntranceBackground extends StatelessWidget {
  const _EntranceBackground({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _EntranceBackgroundPainter(progress),
        child: const SizedBox.expand(),
      );
}

class _EntranceBackgroundPainter extends CustomPainter {
  const _EntranceBackgroundPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final wash = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFE16A), Color(0xFFFFBE18)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wash);

    final halo = Paint()..color = const Color(0x14042147);
    canvas.drawCircle(
        Offset(size.width * .82, size.height * .18), size.width * .42, halo);
    canvas.drawCircle(
        Offset(size.width * .12, size.height * .76), size.width * .30, halo);

    final routePath = _barakahEntranceRoute(size);
    final metric = routePath.computeMetrics().first;
    final baseRoute = Paint()
      ..color = const Color(0x40042147)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    double distance = 0;
    while (distance < metric.length) {
      canvas.drawPath(
        metric.extractPath(distance, math.min(distance + 7, metric.length)),
        baseRoute,
      );
      distance += 17;
    }

    final travelled = metric.length * progress.clamp(0.0, 1.0);
    final activeRoute = Paint()
      ..color = const Color(0xFF08264F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(metric.extractPath(0, travelled), activeRoute);

    final destination = metric.getTangentForOffset(metric.length)?.position;
    if (destination != null) {
      canvas.drawCircle(destination, 10, Paint()..color = Colors.white);
      canvas.drawCircle(
          destination, 6, Paint()..color = const Color(0xFF08264F));
    }
  }

  @override
  bool shouldRepaint(covariant _EntranceBackgroundPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

Path _barakahEntranceRoute(Size size) => Path()
  ..moveTo(size.width * .07, size.height * .11)
  ..cubicTo(
    size.width * .42,
    size.height * .15,
    size.width * .06,
    size.height * .31,
    size.width * .34,
    size.height * .39,
  )
  ..cubicTo(
    size.width * .69,
    size.height * .49,
    size.width * .28,
    size.height * .59,
    size.width * .50,
    size.height * .70,
  );

class _WelcomeBubble extends StatelessWidget {
  const _WelcomeBubble({
    required this.text,
    required this.fontSize,
    required this.angle,
    this.gold = false,
  });

  final String text;
  final double fontSize;
  final double angle;
  final bool gold;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: angle,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: fontSize * .72,
            vertical: fontSize * .38,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gold
                  ? const [Color(0xFFFFE891), Color(0xFFE5AD25)]
                  : const [Color(0xE62A4D78), Color(0xED0A1930)],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: gold
                  ? const Color(0xFFFFF1B0)
                  : AppTheme.coolYellow.withOpacity(.72),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x70000000),
                blurRadius: 12,
                offset: Offset(0, 7),
              ),
              BoxShadow(
                color: Color(0x3DFFFFFF),
                blurRadius: 2,
                offset: Offset(0, -1),
              ),
            ],
          ),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: gold ? AppTheme.navy : Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
}

class _GlassGiftIntro extends StatelessWidget {
  const _GlassGiftIntro({super.key, required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.navy,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF173762), AppTheme.navy, Color(0xFF07152D)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(34),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0x3DFFFFFF), Color(0x16040D1D)],
                          ),
                          borderRadius: BorderRadius.circular(34),
                          border: Border.all(
                            color: AppTheme.coolYellow.withOpacity(.58),
                            width: 1.4,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x78000000),
                              blurRadius: 30,
                              offset: Offset(0, 16),
                            ),
                            BoxShadow(
                              color: Color(0x44FFFFFF),
                              blurRadius: 3,
                              offset: Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'هدية من بركة',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 29,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'لأن وجودك معنا بركة',
                              style: TextStyle(
                                color: AppTheme.coolYellow,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Image.asset(
                              'assets/images/splash/barakah_gift_box_v2.png',
                              height: 330,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: onTap,
                              child: Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFFFFE891),
                                      Color(0xFFE5AD25)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: const Color(0xFFFFF1B0),
                                    width: 1.7,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x8A000000),
                                      blurRadius: 14,
                                      offset: Offset(0, 9),
                                    ),
                                    BoxShadow(
                                      color: Color(0x66FFFFFF),
                                      blurRadius: 3,
                                      offset: Offset(0, -2),
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'افتح هديتك',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppTheme.navy,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _ReferenceIntro extends StatelessWidget {
  const _ReferenceIntro({
    super.key,
    required this.imageAsset,
    required this.onTap,
    this.glassTitle,
  });

  final String imageAsset;
  final VoidCallback? onTap;
  final String? glassTitle;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF020B19),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                imageAsset,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
              if (glassTitle != null)
                SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.only(top: 14),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xB82A4D78), Color(0xB80A1930)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppTheme.coolYellow.withOpacity(.75),
                          width: 1.2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 14,
                            offset: Offset(0, 7),
                          ),
                          BoxShadow(
                            color: Color(0x44FFFFFF),
                            blurRadius: 2,
                            offset: Offset(0, -1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            color: AppTheme.coolYellow,
                            size: 17,
                          ),
                          const SizedBox(width: 9),
                          Container(
                            width: 20,
                            height: 1,
                            color: AppTheme.coolYellow.withOpacity(.75),
                          ),
                          const SizedBox(width: 11),
                          Text(
                            glassTitle!,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              color: Color(0xFFFFDC62),
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                              height: 1.25,
                              shadows: [
                                Shadow(
                                  color: Color(0xB3000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 11),
                          Container(
                            width: 20,
                            height: 1,
                            color: AppTheme.coolYellow.withOpacity(.75),
                          ),
                          const SizedBox(width: 9),
                          const Icon(
                            Icons.auto_awesome_rounded,
                            color: AppTheme.coolYellow,
                            size: 17,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _GiftIntro extends StatelessWidget {
  const _GiftIntro({
    super.key,
    required this.controller,
    required this.opening,
    required this.onOpen,
  });

  final AnimationController controller;
  final bool opening;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Color(0xFF183A68),
                      Color(0xFF07162E),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned(
              top: 80,
              left: 28,
              child: Icon(
                Icons.add_rounded,
                color: AppTheme.coolYellow,
                size: 34,
              ),
            ),
            const Positioned(
              top: 170,
              right: 34,
              child: Icon(
                Icons.add_rounded,
                color: AppTheme.coolYellow,
                size: 21,
              ),
            ),
            const Positioned(
              bottom: 160,
              left: 40,
              child: Icon(
                Icons.add_rounded,
                color: AppTheme.coolYellow,
                size: 24,
              ),
            ),
            const Positioned(
              bottom: 90,
              right: 38,
              child: Icon(
                Icons.add_rounded,
                color: AppTheme.coolYellow,
                size: 32,
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 34),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'هدية صغيرة من بركة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'جاهز تبدأ رحلة التسوق معنا؟',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 30),
                    GestureDetector(
                      onTap: opening ? null : onOpen,
                      child: AnimatedBuilder(
                        animation: controller,
                        builder: (context, _) {
                          final t = controller.value;

                          final lidProgress = Curves.easeOutBack.transform(
                            (t / .70).clamp(0.0, 1.0),
                          );

                          final glowProgress = Curves.easeOut.transform(
                            ((t - .20) / .80).clamp(0.0, 1.0),
                          );

                          return SizedBox(
                            width: 310,
                            height: 320,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Opacity(
                                  opacity: glowProgress * .75,
                                  child: Transform.scale(
                                    scale: .6 + glowProgress * .8,
                                    child: Container(
                                      width: 250,
                                      height: 250,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            Color(0xFFFFE86B),
                                            Color(0x66FFD02E),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (glowProgress > 0)
                                  ...List.generate(14, (index) {
                                    final angle = index * math.pi * 2 / 14;

                                    final radius = 72 + (85 * glowProgress);

                                    return Transform.translate(
                                      offset: Offset(
                                        math.cos(angle) * radius,
                                        math.sin(angle) * radius,
                                      ),
                                      child: Transform.rotate(
                                        angle: angle + t,
                                        child: Icon(
                                          index.isEven
                                              ? Icons.star_rounded
                                              : Icons.add_rounded,
                                          color: index % 3 == 0
                                              ? Colors.white
                                              : AppTheme.coolYellow,
                                          size: index.isEven ? 18 : 15,
                                        ),
                                      ),
                                    );
                                  }),
                                Transform.translate(
                                  offset: const Offset(0, 45),
                                  child: const _GiftBody(),
                                ),
                                Transform.translate(
                                  offset: Offset(
                                    0,
                                    4 - (95 * lidProgress),
                                  ),
                                  child: Transform.rotate(
                                    angle: -.08 * lidProgress,
                                    child: const _GiftLid(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedOpacity(
                      opacity: opening ? .45 : 1,
                      duration: const Duration(milliseconds: 250),
                      child: const Text(
                        'اضغط لفتح الهدية',
                        style: TextStyle(
                          color: AppTheme.coolYellow,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftBody extends StatelessWidget {
  const _GiftBody();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 215,
      height: 158,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF315786),
            Color(0xFF0A1C39),
          ],
        ),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: Colors.white24,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x77000000),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Container(
              width: 48,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFFE66D),
                    Color(0xFFFFB800),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              height: 40,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFFE66D),
                    Color(0xFFFFB800),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftLid extends StatelessWidget {
  const _GiftLid();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      height: 120,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: 240,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF3A6294),
                  Color(0xFF112A50),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white24,
              ),
            ),
            child: Center(
              child: Container(
                width: 50,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFFE66D),
                      Color(0xFFFFB800),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.rotate(
                  angle: -.45,
                  child: Container(
                    width: 70,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.coolYellow,
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
                Container(
                  width: 29,
                  height: 29,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFB800),
                    shape: BoxShape.circle,
                  ),
                ),
                Transform.rotate(
                  angle: .45,
                  child: Container(
                    width: 70,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.coolYellow,
                      borderRadius: BorderRadius.circular(30),
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
}

class _YellowWelcome extends StatelessWidget {
  const _YellowWelcome({
    super.key,
    required this.logoController,
    required this.onContinue,
  });

  final AnimationController logoController;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final scale = Tween<double>(
      begin: .15,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: logoController,
        curve: Curves.easeOutBack,
      ),
    );

    return Scaffold(
      backgroundColor: AppTheme.navy,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onContinue,
        child: SafeArea(
          child: Stack(
            children: [
              const Positioned.fill(
                child: _YellowBackgroundPattern(),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    26,
                    28,
                    26,
                    34,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'أهلًا بكم في بركة',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 24),
                      AnimatedBuilder(
                        animation: scale,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(44),
                            border: Border.all(
                              color: AppTheme.coolYellow,
                              width: 3,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 28,
                                offset: Offset(0, 14),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(38),
                            child: Image.asset(
                              'assets/images/barakah_app_icon.png',
                              width: 220,
                              height: 220,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        builder: (context, child) {
                          return Transform.scale(
                            scale: scale.value,
                            child: child,
                          );
                        },
                      ),
                      const SizedBox(height: 30),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xCC0B1B31),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppTheme.coolYellow.withOpacity(.45),
                          ),
                        ),
                        child: const Text(
                          'كل ما تتمنوه تحت سقف واحد',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'نتمنى لكم رحلة تسوق ممتعة في بركة',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          height: 1.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YellowBackgroundPattern extends StatelessWidget {
  const _YellowBackgroundPattern();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _YellowPatternPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _YellowPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.coolYellow.withOpacity(.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const step = 78.0;

    for (double y = 10; y < size.height + step; y += step) {
      for (double x = 10; x < size.width + step; x += step) {
        final shifted = ((y / step).round().isEven) ? 0.0 : step / 2;

        final center = Offset(
          x + shifted,
          y,
        );

        canvas.drawCircle(
          center,
          14,
          paint,
        );

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: center.translate(23, 18),
              width: 25,
              height: 21,
            ),
            const Radius.circular(6),
          ),
          paint,
        );

        canvas.drawLine(
          center.translate(-13, 23),
          center.translate(13, 23),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
