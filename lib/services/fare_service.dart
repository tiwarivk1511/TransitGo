import 'package:intl/intl.dart';
import '../core/cache/offline_cache.dart';
import '../data/models/fare.dart';
import '../data/sources/ntes_source.dart';
import 'crashlytics_service.dart';

class FareService {
  static Future<TrainFareData?> fetch({
    required String trainNumber,
    required String from,
    required String to,
    String? date,
    String classCode = 'SL',
    String quota = 'GN',
  }) async {
    final jDate = (date != null && date.trim().isNotEmpty)
        ? date.trim()
        : DateFormat('yyyy-MM-dd').format(DateTime.now());

    final cacheKey =
        'fare_v2_${trainNumber}_${from}_${to}_${jDate}_${classCode}_$quota';

    try {
      final d = await NtesSource.fare(
        trainNumber: trainNumber,
        from: from,
        to: to,
        date: jDate,
        classCode: classCode,
        quota: quota,
      );
      if (d == null) {
        final cached = await OfflineCache.get(cacheKey);
        if (cached is Map) {
          final fare = TrainFareData.parse(
            Map<String, dynamic>.from(cached),
            train: trainNumber,
            from: from,
            to: to,
            date: jDate,
            classCode: classCode,
          );
          return fare.totalFare > 0 ? fare : null;
        }
        return null;
      }
      try {
        await OfflineCache.put(cacheKey, d, ttl: const Duration(hours: 24));
      } catch (_) {}
      final fare = TrainFareData.parse(
        Map<String, dynamic>.from(d),
        train: trainNumber,
        from: from,
        to: to,
        date: jDate,
        classCode: classCode,
      );
      return fare.totalFare > 0 ? fare : null;
    } catch (e, st) {
      CrashlyticsService.recordError(e, st, reason: 'Fare fetch failed for train $trainNumber');
      return null;
    }
  }
}
