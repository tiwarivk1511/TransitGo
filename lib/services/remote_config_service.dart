// remote_config_service.dart
import 'dart:io' show Platform;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Single source of truth for RailRadar API key & Metro Network Remote Config parameters.
/// Bypasses Windows platform channel null-cast bugs gracefully while fully supporting Remote Config on Android/iOS/Web.
class RemoteConfigService {
  static FirebaseRemoteConfig? _rc;
  static bool _initialized = false;
  static String _apiKey = 'rg_6bbd3e8a36884bc9ac93a446e7494983';
  static Future<void>? _initFuture;

  /// Must match the Firebase Console parameter name exactly.
  static const String _keyApiKey = 'railradar_api_key';

  /// Call from `main()` after `Firebase.initializeApp()`.
  static Future<void> initialize() {
    _initFuture ??= _doInitialize();
    return _initFuture!;
  }

  static Future<void> _doInitialize() async {
    // On Windows, firebase_remote_config plugin has a known platform channel null-cast bug.
    // We gracefully bypass it on Windows and use cached/default keys.
    if (!kIsWeb && Platform.isWindows) {
      debugPrint('[RemoteConfig] Windows platform detected — bypassing FirebaseRemoteConfig plugin.');
      _initialized = true;
      return;
    }

    try {
      final rc = FirebaseRemoteConfig.instance;

      try {
        await rc.setConfigSettings(RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: Duration.zero,
        ));
      } catch (e) {
        debugPrint('[RemoteConfig] setConfigSettings failed: $e');
      }

      try {
        await rc.setDefaults(const {_keyApiKey: ''});
      } catch (_) {}

      try {
        final activated = await rc.fetchAndActivate();
        debugPrint('[RemoteConfig] fetchAndActivate OK (activated=$activated)');
      } catch (e) {
        debugPrint('[RemoteConfig] fetchAndActivate failed: $e');
        try {
          await rc.activate();
        } catch (_) {}
      }

      _rc = rc;
      final fetched = rc.getString(_keyApiKey).trim();
      if (fetched.isNotEmpty) {
        _apiKey = fetched;
      }
    } catch (e) {
      debugPrint('[RemoteConfig] Initialization error (non-fatal): $e');
    }

    _initialized = true;

    debugPrint('[RemoteConfig] initialized → '
        'apiKey len=${_apiKey.length} '
        'prefix=${_apiKey.isEmpty ? "<empty>" : _apiKey.substring(0, _apiKey.length < 10 ? _apiKey.length : 10)}');
  }

  /// Guarantees a non-empty key.
  static Future<String> ensureApiKey() async {
    if (!_initialized) {
      await initialize();
    }
    if (!kIsWeb && Platform.isWindows) {
      return _apiKey;
    }

    await refresh();

    if (_apiKey.isEmpty) {
      try {
        _apiKey = FirebaseRemoteConfig.instance.getString(_keyApiKey).trim();
      } catch (_) {}
    }

    if (_apiKey.isEmpty) {
      throw StateError(
        'Firebase Remote Config parameter "$_keyApiKey" is empty. '
            'Open Firebase Console → Remote Config, add/enable the '
            'parameter, and hit "Publish changes".',
      );
    }
    return _apiKey;
  }

  /// Fetches network-wise metro stations JSON string from Firebase Remote Config.
  /// Parameter key formats in Firebase Console: `stations-del`, `stations-noi`, `stations-mum`, etc.
  static String getMetroStationsJson(String cityCode) {
    if (!kIsWeb && Platform.isWindows) return '';
    final rc = _rc ?? FirebaseRemoteConfig.instance;
    final cleanCode = cityCode.trim().toLowerCase();

    // Check key formats: `stations-del`, `stations-noi`, `stations-del.json`, etc.
    final keysToTry = [
      'stations_$cleanCode',
      'stations_$cleanCode.json',
      'stations_$cleanCode',
      'metro_stations_$cleanCode',
    ];

    for (final key in keysToTry) {
      try {
        final str = rc.getString(key).trim();
        if (str.isNotEmpty) return str;
      } catch (_) {}
    }

    return '';
  }

  /// Synchronous accessor — returns whatever's currently cached.
  static String get apiKey => _apiKey;

  /// Force refresh from Firebase servers.
  static Future<void> refresh() async {
    if (!kIsWeb && Platform.isWindows) return;
    final rc = _rc ?? FirebaseRemoteConfig.instance;
    try {
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: Duration.zero,
      ));
      await rc.fetchAndActivate();
      final fetched = rc.getString(_keyApiKey).trim();
      if (fetched.isNotEmpty) {
        _apiKey = fetched;
      }
      debugPrint('[RemoteConfig] refresh → apiKey len=${_apiKey.length}');
    } catch (e) {
      debugPrint('[RemoteConfig] refresh failed: $e');
    }
  }

  /// DEBUG ONLY — bypasses Firebase to isolate problems.
  static void debugInjectKey(String key) {
    _apiKey = key.trim();
    _initialized = true;
    debugPrint('[RemoteConfig] ⚠ debug-injected key (len=${_apiKey.length})');
  }
}
