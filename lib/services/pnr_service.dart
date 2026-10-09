import '../core/cache/offline_cache.dart';
import '../data/models/pnr.dart';
import '../data/sources/ntes_source.dart';
import 'crashlytics_service.dart';

class PnrService {
  static Future<PnrData?> fetch(String pnr) async {
    if (!RegExp(r'^\d{10}$').hasMatch(pnr)) return null;
    final cacheKey = 'pnr_$pnr';
    try {
      final d = await NtesSource.pnr(pnr);
      if (d == null) {
        final cached = await OfflineCache.get(cacheKey);
        if (cached is Map) {
          return PnrData.fromNtes(Map<String, dynamic>.from(cached), pnr);
        }
        return null;
      }
      try {
        await OfflineCache.put(cacheKey, d, ttl: const Duration(hours: 3));
      } catch (_) {}
      return PnrData.fromNtes(Map<String, dynamic>.from(d), pnr);
    } catch (e, st) {
      CrashlyticsService.recordError(e, st, reason: 'PNR fetch failed for $pnr');
      return null;
    }
  }
}