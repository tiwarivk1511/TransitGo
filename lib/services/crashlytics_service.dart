import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class CrashlyticsService {
  static final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  /// Initializes Crashlytics error collection and hooks Flutter/Platform error handlers.
  static Future<void> initialize() async {
    try {
      // In debug mode, enable collection or keep enabled for testing
      await _crashlytics.setCrashlyticsCollectionEnabled(true);

      // Hook Flutter framework error handler
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        _crashlytics.recordFlutterFatalError(details);
      };

      // Hook asynchronous Dart platform errors
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        _crashlytics.recordError(error, stack, fatal: true);
        return true;
      };

      debugPrint('[CrashlyticsService] Firebase Crashlytics initialized successfully.');
    } catch (e, st) {
      debugPrint('[CrashlyticsService] Failed to initialize Crashlytics: $e\n$st');
    }
  }

  /// Records a non-fatal or fatal error with optional reason and custom attributes.
  static Future<void> recordError(
    dynamic error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('[CrashlyticsLog] ${fatal ? "FATAL" : "NON-FATAL"} ERROR: $error');
        if (reason != null) debugPrint('[CrashlyticsLog] Reason: $reason');
      }

      await _crashlytics.recordError(
        error,
        stack,
        reason: reason,
        fatal: fatal,
      );
    } catch (e) {
      debugPrint('[CrashlyticsService] Exception recording error: $e');
    }
  }

  /// Logs a custom message to Crashlytics timeline log.
  static Future<void> log(String message) async {
    try {
      if (kDebugMode) debugPrint('[CrashlyticsLog] $message');
      await _crashlytics.log(message);
    } catch (_) {}
  }

  /// Sets custom key-value pairs for Crashlytics reports.
  static Future<void> setCustomKey(String key, Object value) async {
    try {
      await _crashlytics.setCustomKey(key, value);
    } catch (_) {}
  }

  /// Sets user identifier for tracking user sessions.
  static Future<void> setUserIdentifier(String identifier) async {
    try {
      await _crashlytics.setUserIdentifier(identifier);
    } catch (_) {}
  }

  /// Forces a test crash to verify Crashlytics integration.
  static void testCrash() {
    _crashlytics.crash();
  }
}
