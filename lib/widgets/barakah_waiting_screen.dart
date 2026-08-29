import 'package:flutter/material.dart';

class BarakahWaitingScreen extends StatelessWidget {
  const BarakahWaitingScreen({
    super.key,
    this.message = 'استنا شوي، بنجهزلك الصفحة',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFCFCFB),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFFEFEFC),
              Color(0xFFF8F5ED),
              Color(0xFFFFFFFF),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 240,
                      maxHeight: 240,
                    ),
                    child: Image.asset(
                      'assets/images/bunny_stickers/loading.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.shopping_bag_rounded,
                        color: Color(0xFFE8C64A),
                        size: 92,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: const SizedBox(
                      width: 170,
                      child: LinearProgressIndicator(
                        minHeight: 5,
                        backgroundColor: Color(0x14000000),
                        color: Color(0xFFE8C64A),
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
  }
}

class BarakahRouteLoadingObserver extends NavigatorObserver {
  OverlayEntry? entry;
  int token = 0;

  void showUntilNextFrame() {
    final overlay = navigator?.overlay;
    if (overlay == null) return;

    entry?.remove();
    entry = null;

    final currentToken = ++token;

    final newEntry = OverlayEntry(
      builder: (_) => const BarakahWaitingScreen(),
    );

    entry = newEntry;
    overlay.insert(newEntry);

    Future<void>(() async {
      final minVisible =
          Future<void>.delayed(const Duration(milliseconds: 520));
      final nextFrame = WidgetsBinding.instance.endOfFrame;

      await Future.wait([minVisible, nextFrame]);

      if (currentToken != token) return;

      entry?.remove();
      entry = null;
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);

    if (previousRoute != null) {
      showUntilNextFrame();
    }
  }

  @override
  void didReplace({
    Route<dynamic>? newRoute,
    Route<dynamic>? oldRoute,
  }) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    showUntilNextFrame();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    showUntilNextFrame();
  }
}
