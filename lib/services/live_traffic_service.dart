import '../core/cache/offline_cache.dart';
import '../data/models/station_traffic.dart';
import '../data/sources/live_stream_source.dart';
import '../data/sources/ntes_source.dart';

class LiveTrafficService {
  // ── One-shot fetch ───────────────────────────────────────────
  static Future<StationTraffic?> fetch(
      String stationCode, {
        int hours = 8,
      }) async {
    final code = stationCode.trim().toUpperCase();
    if (code.isEmpty) return null;

    final cacheKey = 'traffic_${code}_$hours';
    final d = await NtesSource.stationTraffic(code, hours);

    dynamic src = d;
    if (src == null || (src is Map && src['__html__'] is String)) {
      final cached = await OfflineCache.get(cacheKey);
      if (cached != null) src = cached;
    }
    if (src == null) return null;

    try {
      if (d != null && !(d is Map && d['__html__'] is String)) {
        await OfflineCache.put(cacheKey, src,
            ttl: const Duration(minutes: 3));
      }
    } catch (_) {}

    return StationTraffic.parse(
      Map<String, dynamic>.from(src),
      code,
      hours,
    );
  }

  // ── Stream ──────────────────────────────────────────────────
  static Stream<StationTraffic> stream(
      String stationCode, {
        int hours = 8,
        Duration interval = const Duration(seconds: 30),
      }) {
    final code = stationCode.trim().toUpperCase();
    return LiveStreamSource
        .stationLive(code, hours: hours, interval: interval)
        .map((raw) => StationTraffic.parse(raw, code, hours));
  }
}