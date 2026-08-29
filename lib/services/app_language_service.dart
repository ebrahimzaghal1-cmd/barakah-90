import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// يحتفظ بلغة الواجهة محلياً حتى تبقى بعد إغلاق التطبيق.
class AppLanguageService {
  AppLanguageService._();

  static final AppLanguageService instance = AppLanguageService._();
  static const _key = 'app_language';

  final ValueNotifier<Locale> locale = ValueNotifier(const Locale('ar'));
  late SharedPreferences _preferences;

  void initialize(SharedPreferences preferences) {
    _preferences = preferences;
    final saved = preferences.getString(_key) ?? 'ar';
    locale.value = Locale(_supported(saved) ? saved : 'ar');
  }

  Future<void> setLanguage(String code) async {
    final language = _supported(code) ? code : 'ar';
    locale.value = Locale(language);
    await _preferences.setString(_key, language);
  }

  bool _supported(String code) => const ['ar', 'en', 'fr'].contains(code);
}
