import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_translations.dart';

/// Single source of truth for Application Multilingual Locale & First-Time Onboarding State.
class LanguageController extends ChangeNotifier {
  static final LanguageController instance = LanguageController._internal();
  LanguageController._internal();

  static const String _langPrefKey = 'user_language_code';
  static const String _setupCompletedKey = 'has_completed_language_setup';

  String _currentLanguageCode = 'en';
  bool _hasCompletedSetup = false;

  String get currentLanguageCode => _currentLanguageCode;
  bool get hasCompletedSetup => _hasCompletedSetup;

  Locale get currentLocale => Locale(_currentLanguageCode);

  void notify() => notifyListeners();

  /// Translate a string key or raw text.
  String translate(String keyOrText) =>
      AppTranslations.translate(keyOrText, _currentLanguageCode);

  /// Initializes language preference & onboarding state from SharedPreferences.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentLanguageCode = prefs.getString(_langPrefKey) ?? 'en';
      _hasCompletedSetup = prefs.getBool(_setupCompletedKey) ?? false;
      notifyListeners();
    } catch (_) {}
  }

  /// Sets user language preference and marks initial onboarding setup as completed.
  Future<void> setLanguage(String langCode, {bool completeSetup = true}) async {
    _currentLanguageCode = langCode;
    if (completeSetup) {
      _hasCompletedSetup = true;
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_langPrefKey, langCode);
      if (completeSetup) {
        await prefs.setBool(_setupCompletedKey, true);
      }
    } catch (_) {}
  }
}
