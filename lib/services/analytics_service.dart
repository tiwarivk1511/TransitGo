import 'dart:io' show Platform;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Single source of truth for Firebase Analytics tracking across TransitGo.
/// Safely bypasses platform channel limits on desktop while providing full telemetry on Android, iOS, and Web.
class AnalyticsService {
  static FirebaseAnalytics? _analytics;
  static FirebaseAnalyticsObserver? _observer;
  static bool _initialized = false;

  static FirebaseAnalytics? get analytics => _analytics;
  static FirebaseAnalyticsObserver? get observer => _observer;

  /// Initializes Firebase Analytics and configures auto collection.
  static Future<void> initialize() async {
    if (_initialized) return;

    if (!kIsWeb && Platform.isWindows) {
      debugPrint('[AnalyticsService] Windows platform detected — bypassing Firebase Analytics plugin.');
      _initialized = true;
      return;
    }

    try {
      _analytics = FirebaseAnalytics.instance;
      _observer = FirebaseAnalyticsObserver(analytics: _analytics!);

      await _analytics!.setAnalyticsCollectionEnabled(true);
      _initialized = true;
      debugPrint('[AnalyticsService] Firebase Analytics initialized successfully.');
    } catch (e) {
      debugPrint('[AnalyticsService] Firebase Analytics init error: $e');
    }
  }

  /// Logs a screen view navigation event.
  static Future<void> logScreenView(String screenName) async {
    if (!_initialized || _analytics == null) return;
    try {
      await _analytics!.logScreenView(screenName: screenName);
      debugPrint('[Analytics] ScreenView: $screenName');
    } catch (_) {}
  }

  /// Logs a search term event (station or train search).
  static Future<void> logSearch({required String searchTerm, String? category}) async {
    if (!_initialized || _analytics == null) return;
    try {
      await _analytics!.logSearch(
        searchTerm: searchTerm,
        numberOfNights: category != null ? 1 : null,
      );
      await _analytics!.logEvent(
        name: 'transit_search',
        parameters: {
          'search_term': searchTerm,
          'category': category ?? 'general',
        },
      );
      debugPrint('[Analytics] Search: $searchTerm ($category)');
    } catch (_) {}
  }

  /// Logs a train detail view event.
  static Future<void> logTrainView({
    required String trainNumber,
    required String trainName,
  }) async {
    if (!_initialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'view_train_details',
        parameters: {
          'train_number': trainNumber,
          'train_name': trainName,
        },
      );
      debugPrint('[Analytics] TrainView: $trainNumber ($trainName)');
    } catch (_) {}
  }

  /// Logs a station info view event.
  static Future<void> logStationView({
    required String stationCode,
    required String stationName,
  }) async {
    if (!_initialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'view_station_info',
        parameters: {
          'station_code': stationCode,
          'station_name': stationName,
        },
      );
      debugPrint('[Analytics] StationView: $stationCode ($stationName)');
    } catch (_) {}
  }

  /// Logs a metro route planner search event.
  static Future<void> logMetroSearch({
    required String cityName,
    required String source,
    required String destination,
  }) async {
    if (!_initialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'metro_route_search',
        parameters: {
          'city_name': cityName,
          'source_station': source,
          'destination_station': destination,
        },
      );
      debugPrint('[Analytics] MetroSearch: $source -> $destination ($cityName)');
    } catch (_) {}
  }

  /// Logs a PNR enquiry search event.
  static Future<void> logPnrSearch({required String pnrNumber}) async {
    if (!_initialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'pnr_enquiry_search',
        parameters: {
          'pnr_length': pnrNumber.length,
        },
      );
      debugPrint('[Analytics] PNR Search triggered');
    } catch (_) {}
  }

  /// Logs a theme mode toggle event.
  static Future<void> logThemeToggle({required bool isDarkMode}) async {
    if (!_initialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'toggle_theme',
        parameters: {
          'theme_mode': isDarkMode ? 'dark_oled' : 'light_apple',
        },
      );
    } catch (_) {}
  }
}
