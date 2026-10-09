import '../core/cache/offline_cache.dart';
import '../data/models/train.dart';
import '../data/sources/api_router.dart';
import '../data/sources/live_stream_source.dart';
import '../data/sources/ntes_source.dart';
import '../data/sources/railradar_source.dart';

class TrainService {
  // ═══════════════════════════════════════════════════════════════════
  // LIVE TRACKING (one-shot)
  // ═══════════════════════════════════════════════════════════════════
  static Future<TrainTracking?> liveTracking(String trainNumber) async {
    final cleanNo = trainNumber.trim().split(' - ').first;
    final cacheKey = 'live_$cleanNo';

    dynamic d = await NtesSource.liveTracking(cleanNo);
    Map<String, dynamic>? rawMap;

    if (d is Map && (d['__html__'] is! String)) {
      rawMap = Map<String, dynamic>.from(d);
    } else {
      final liveData = await RailRadarSource.liveTracking(
        cleanNo,
        includeGeometry: true,
      );
      if (liveData is Map) {
        rawMap = Map<String, dynamic>.from(liveData!);
      }
    }

    if (rawMap != null &&
        (rawMap['geometry'] == null || rawMap['geometry'] is! Map)) {
      final routeGeo = await RailRadarSource.trainRouteGeometry(cleanNo);
      if (routeGeo != null) {
        rawMap['geometry'] = routeGeo;
      }
    }

    if (rawMap != null) {
      try {
        await OfflineCache.put(
          cacheKey,
          rawMap,
          ttl: const Duration(minutes: 10),
        );
      } catch (_) {}

      return TrainTracking.parse(rawMap, cleanNo);
    }

    final cached = await OfflineCache.get(cacheKey);
    if (cached is Map) {
      return TrainTracking.parse(Map<String, dynamic>.from(cached), cleanNo);
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // LIVE TRACKING STREAM (WebSocket-shaped)
  // ═══════════════════════════════════════════════════════════════════
  static Stream<TrainTracking> stream(
    String trainNumber, {
    Duration interval = const Duration(seconds: 30),
    bool includeGeometry = true,
  }) {
    return LiveStreamSource.liveTrain(
      trainNumber,
      interval: interval,
      includeGeometry: includeGeometry,
    ).map((raw) => TrainTracking.parse(raw, trainNumber));
  }

  // ═══════════════════════════════════════════════════════════════════
  // TRAINS BETWEEN STATIONS
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> trainsBetween(
    String from,
    String to, [
    String? date,
  ]) async {
    final cacheKey = 'btwn_${from}_${to}_${date ?? 'all'}';
    final d = await NtesSource.trainsBetween(from, to, date);

    dynamic src = d;
    if (src == null || (src is Map && src['__html__'] is String)) {
      final cached = await OfflineCache.get(cacheKey);
      if (cached is Map) src = cached;
    }

    // ── Real failure: no data from network AND no cache ────────
    if (src == null) return null;

    final map = Map<String, dynamic>.from(src);

    final raw =
        (map['trains'] ?? map['trainBtwnStnsList'] ?? map['trainList'] ?? [])
            as List?;

    // ── Empty is a VALID result — never return null for it ─────
    final rawList = raw ?? const <dynamic>[];

    final topFrom = map['from'] is Map
        ? Map<String, dynamic>.from(map['from'] as Map)
        : const <String, dynamic>{};
    final topTo = map['to'] is Map
        ? Map<String, dynamic>.from(map['to'] as Map)
        : const <String, dynamic>{};

    final trains = <Map<String, dynamic>>[];
    for (final item in rawList) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);

      final hasNested = m['train'] is Map || m['from'] is Map || m['to'] is Map;

      if (hasNested) {
        final trainMap = m['train'] is Map
            ? Map<String, dynamic>.from(m['train'] as Map)
            : const <String, dynamic>{};
        final fromMap = m['from'] is Map
            ? Map<String, dynamic>.from(m['from'] as Map)
            : const <String, dynamic>{};
        final toMap = m['to'] is Map
            ? Map<String, dynamic>.from(m['to'] as Map)
            : const <String, dynamic>{};

        trains.add({
          'train': {
            'number': (trainMap['number'] ?? '').toString(),
            'name': (trainMap['name'] ?? '').toString(),
            'type': (trainMap['type'] ?? '').toString(),
            'runDays': trainMap['runDays'],
          },
          'from': {
            'code': (fromMap['code'] ?? topFrom['code'] ?? from).toString(),
            'name': (fromMap['name'] ?? topFrom['name'] ?? from).toString(),
            'departure': (fromMap['departure'] ?? '--').toString(),
            'day': fromMap['day'],
            'sequence': fromMap['sequence'],
          },
          'to': {
            'code': (toMap['code'] ?? topTo['code'] ?? to).toString(),
            'name': (toMap['name'] ?? topTo['name'] ?? to).toString(),
            'arrival': (toMap['arrival'] ?? '--').toString(),
            'day': toMap['day'],
            'sequence': toMap['sequence'],
          },
          'distance': _num(m['distance']) ?? 0,
          'duration': _num(m['duration']),
          'halts': _num(m['totalHaltsBetween']),
        });
      } else {
        trains.add({
          'train': {
            'number': (m['trainNumber'] ?? '').toString(),
            'name': (m['trainName'] ?? '').toString(),
            'type': (m['trainType'] ?? '').toString(),
          },
          'from': {
            'code': (m['fromStnCode'] ?? from).toString(),
            'name': (m['fromStnName'] ?? from).toString(),
            'departure': (m['departureTime'] ?? '--').toString(),
            'day': m['fromDay'],
          },
          'to': {
            'code': (m['toStnCode'] ?? to).toString(),
            'name': (m['toStnName'] ?? to).toString(),
            'arrival': (m['arrivalTime'] ?? '--').toString(),
            'day': m['toDay'],
          },
          'distance': _num(m['distance']) ?? 0,
          'duration': _num(m['duration']),
          'halts': _num(m['totalHaltsBetween']),
        });
      }
    }

    final result = <String, dynamic>{
      'fromStation': topFrom['name']?.toString() ?? from,
      'toStation': topTo['name']?.toString() ?? to,
      'trains': trains,
      'count': trains.length,
    };
    if (date != null) result['journeyDate'] = date;

    // Cache ONLY network successes (including empty), 6h TTL
    if (d is Map && ((d as Map)['__html__'] as String?) == null) {
      try {
        await OfflineCache.put(cacheKey, result, ttl: const Duration(hours: 6));
      } catch (_) {}
    }

    return result;
  }

  static num? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    return num.tryParse(v.toString());
  }

  // ═══════════════════════════════════════════════════════════════════
  // TRAIN CROSSINGS & ENCOUNTERS
  // ═══════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> trainCrossings(String trainNumber, {String? date}) async {
    final cleanNo = trainNumber.trim().split(' - ').first;
    final cacheKey = 'crossings_$cleanNo';

    final cached = await OfflineCache.get(cacheKey);
    if (cached is List) {
      return cached.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }

    final list = await NtesSource.trainCrossings(cleanNo, date: date);
    if (list.isNotEmpty) {
      try {
        await OfflineCache.put(cacheKey, list, ttl: const Duration(hours: 2));
      } catch (_) {}
    }
    return list;
  }

  // ═══════════════════════════════════════════════════════════════════
  // DIAGNOSTICS — UI can call this for better error messages
  // ═══════════════════════════════════════════════════════════════════
  /// Human-readable description of the last RailRadar failure, or
  /// `null` if the last call succeeded.
  static String? lastErrorDescription() {
    final pause = ApiRouter.railRadarRetryDelay;
    if (pause != null &&
        ApiRouter.railRadarPauseReason?.contains('quota') == true) {
      return 'RailRadar monthly quota is exhausted and the backup train-data '
          'service did not respond.';
    }
    if (pause != null &&
        ApiRouter.railRadarPauseReason?.contains('auth failure') == true) {
      return 'RailRadar rejected its API credentials. Please contact support '
          'or try again later.';
    }

    final code = RailRadarSource.lastStatusCode;
    final msg = RailRadarSource.lastErrorMessage;

    if (code == 429) {
      return null;
    }
    if (code == 401 || code == 403) {
      return 'API key rejected. Please contact support.';
    }
    if (code == 404) {
      return 'Route not found on RailRadar.';
    }
    if (code != null && code >= 500) {
      return 'RailRadar is temporarily unavailable. Try again in a moment.';
    }
    if (msg != null && msg.isNotEmpty && msg != 'Request timed out') {
      return msg;
    }
    return null;
  }
}
