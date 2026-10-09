import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app.dart';
import 'core/cache/offline_cache.dart';
import 'core/theme/theme_controller.dart';
import 'core/utils/permission_helper.dart';
import 'data/sources/station_source.dart';
import 'firebase_options.dart';
import 'services/analytics_service.dart';
import 'services/crashlytics_service.dart';
import 'services/remote_config_service.dart';
import 'services/wake_me_up_service.dart';

/// Populated during startup if the API key couldn't be resolved.
/// A null value means the app is safe to run normally.
String? _startupError;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = true;

  // ─────────────────────────────────────────────────────────────
  // 1. .env.local — base URL only. API key does NOT come from here.
  // ─────────────────────────────────────────────────────────────
  try {
    await dotenv.load(fileName: '.env.local');
  } catch (e) {
    debugPrint('[startup] dotenv load failed (non-fatal): $e');
  }

  // ─────────────────────────────────────────────────────────────
  // 2. Firebase, Crashlytics & Analytics initialization
  // ─────────────────────────────────────────────────────────────
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await CrashlyticsService.initialize();
    await AnalyticsService.initialize();
    debugPrint('[startup] Firebase, Crashlytics & Analytics OK');
  } catch (e, st) {
    debugPrint('[startup] Firebase init failed: $e\n$st');
    _startupError ??= 'Firebase failed to initialise: $e';
  }

  // ─────────────────────────────────────────────────────────────
  // 3. Remote Config — block until the API key is in memory.
  // ─────────────────────────────────────────────────────────────
  if (_startupError == null) {
    try {
      await RemoteConfigService.initialize();

      final key = await RemoteConfigService.ensureApiKey();
      debugPrint('[startup] Remote Config OK — '
          'apiKey len=${key.length} '
          'prefix=${key.isEmpty ? "<empty>" : key.substring(0, key.length < 10 ? key.length : 10)}');
    } catch (e, st) {
      debugPrint('[startup] Remote Config failed: $e\n$st');
      _startupError ??=
          'API key unavailable. Check Firebase Remote Config param '
          '"railradar_api_key" is set and published.';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 4. SQLite FFI for desktop.
  // ─────────────────────────────────────────────────────────────
  if (!kIsWeb) {
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
    } catch (e) {
      debugPrint('[startup] sqflite FFI init failed (non-fatal): $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 5. Parallel init — each is independently wrapped.
  // ─────────────────────────────────────────────────────────────
  await Future.wait([
    ThemeController.instance.init().catchError((e) {
      debugPrint('[startup] ThemeController init failed: $e');
    }),
    StationSource.load().catchError((e) {
      debugPrint('[startup] StationSource.load failed: $e');
    }),
    if (!kIsWeb)
      () async {
        try {
          await OfflineCache.instance;
        } catch (e) {
          debugPrint('[startup] OfflineCache init failed: $e');
        }
      }()
    else
      Future<void>.value(),
    () async {
      await WakeMeUpService.init();
      final granted = await PermissionHelper.requestAllPermissions();
      debugPrint(
        '[startup] Notification and location permissions '
        '${granted ? "granted" : "not fully granted"}',
      );
    }().catchError((e) {
      debugPrint('[startup] Notification/location permission setup failed: $e');
    }),
  ]);

  // ─────────────────────────────────────────────────────────────
  // 6. System UI.
  // ─────────────────────────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // ─────────────────────────────────────────────────────────────
  // 7. Launch.
  // ─────────────────────────────────────────────────────────────
  runApp(TransitGoApp(startupError: _startupError));
}
