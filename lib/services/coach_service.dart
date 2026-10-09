import '../core/cache/offline_cache.dart';
import '../data/models/coach.dart';
import '../data/sources/railradar_source.dart';

/// Coach Position service.
///
/// Live-API first. Falls back to a cached copy of a *real* API response.
/// No static templates — every rake you see is data returned by the API.
class CoachService {
  /// Fetch a formation. If [stationCode] is omitted, the API returns the
  /// full `stationVariations.stops` block, which we use to build the
  /// dynamic station selector on the UI.
  static Future<TrainFormation?> fetch(
      String trainNumber, {
        String? stationCode,
      }) async {
    final cleanNo = trainNumber.trim().split(' - ').first;
    if (cleanNo.isEmpty) return null;

    final cacheKey =
        'coach_v3_${cleanNo}_${(stationCode ?? 'auto').toUpperCase()}';

    // 1. Live Coach Position API
    final rr = await RailRadarSource.coachPosition(cleanNo, stationCode);
    if (rr != null) {
      try {
        await OfflineCache.put(cacheKey, rr, ttl: const Duration(hours: 6));
      } catch (_) {}
      return TrainFormation.fromRailRadar(rr, cleanNo);
    }

    // 2. Live Tracking API (contains coachPosition at train & route level)
    final liveData = await RailRadarSource.liveTracking(cleanNo);
    if (liveData != null) {
      try {
        await OfflineCache.put(cacheKey, liveData, ttl: const Duration(hours: 6));
      } catch (_) {}
      return TrainFormation.fromRailRadar(liveData, cleanNo);
    }

    // 3. Cached copy
    final cached = await OfflineCache.get(cacheKey);
    if (cached is Map) {
      return TrainFormation.fromRailRadar(
          Map<String, dynamic>.from(cached), cleanNo);
    }

    // 3. Nothing usable — UI shows an error box instead of fake data.
    return null;
  }
}