import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart'; // المكتبة الأساسية للربط
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'navigation/main_navigation_bar.dart';
import 'firebase_options.dart'; // الملف الذي يتم إنشاؤه تلقائياً بواسطة FlutterFire CLI
import 'screens/splash_screen.dart';
import 'screens/partner_registration_screen.dart';
import 'screens/driver_registration_screen.dart';
import 'screens/customer_service_join_screen.dart';
import 'screens/customer_service_portal.dart';
import 'screens/customer_support_chat_screen.dart';
import 'services/auth_service.dart';
import 'services/firebase_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'games/gold_worm_game.dart';
import 'services/app_language_service.dart';
import 'services/user_profile_service.dart';
import 'services/admin_notification_service.dart';

import 'widgets/barakah_waiting_screen.dart';

void main() async {
  // 1. التأكد من تهيئة أدوات فلاتر
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 2. تهيئة Firebase - الخطوة التي كانت مفقودة في لقطة الشاشة 2.21.14 ص
    await Firebase.initializeApp(
      options: !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? null
          : DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseState.isReady = true;
    await AdminNotificationService.instance.initialize();

    if (kIsWeb) {
      try {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      } catch (e) {
        debugPrint('تعذر حفظ جلسة Firebase على الويب: $e');
      }
    }

    // 3. رفع البيانات (يفضل تشغيلها مرة واحدة فقط ثم إغلاقها)
    // await uploadRestaurants();
  } catch (e) {
    print("خطأ في تهيئة Firebase: $e");
  }

  final preferences = await SharedPreferences.getInstance();
  AppLanguageService.instance.initialize(preferences);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: AppLanguageService.instance.locale,
      builder: (context, locale, _) => MaterialApp(
        navigatorObservers: [BarakahRouteLoadingObserver()],
        debugShowCheckedModeBanner: false,
        title: 'Barakah App',
        theme: AppTheme.lightTheme,
        locale: locale,
        supportedLocales: const [Locale('ar'), Locale('en'), Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => Directionality(
          textDirection: locale.languageCode == 'ar'
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/profile_gold_background.jpg',
                fit: BoxFit.cover,
              ),
              const ColoredBox(color: Color(0xD9FFFCF5)),
              child ?? const SizedBox.shrink(),
            ],
          ),
        ),
        home: kIsWeb
            ? switch (Uri.base.path) {
                '/partner' => const PartnerRegistrationScreen(),
                '/driver' => const DriverRegistrationScreen(),
                '/customer-service' => const CustomerServiceJoinScreen(),
                '/jobs' => const CustomerServiceJoinScreen(),
                '/support' => const CustomerSupportChatScreen(),
                '/support-agent' => const CustomerServicePortal(),
                _ => const SplashScreen(),
              }
            : const SplashScreen(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!FirebaseState.isReady) return const MainNavBar();
    return StreamBuilder(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final user = snapshot.data;
        if (user is User) {
          return FutureBuilder<void>(
            future: UserProfileService().ensureCustomerProfile(user),
            builder: (context, profileSnapshot) {
              // لا نمنع فتح التطبيق عند ضعف الإنترنت؛ المزامنة ستُعاد في
              // الفتح القادم، بينما تبقى الجلسة محفوظة محلياً.
              return const MainNavBar();
            },
          );
        }
        return const MainNavBar();
      },
    );
  }
}
