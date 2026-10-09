import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/cache/offline_cache.dart';
import 'station_source.dart';

/// RailRadar Open Web API Client — 100% Free Open Web Endpoints (Zero API Key Required)
/// Base: https://railradar.in/app/v1/
class RailRadarSource {
  static const Map<String, String> _openWebHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13; SM-S911B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
  };

  static const Duration _timeout = Duration(seconds: 15);

  static void _debug(String msg) {
    if (kDebugMode) debugPrint(msg);
  }

  // Diagnostics & Status Getters
  static int? _lastStatus;
  static String? _lastError;

  static int? get lastStatusCode => _lastStatus;
  static String? get lastErrorMessage => _lastError;

  static void clearError() {
    _lastStatus = null;
    _lastError = null;
  }

  static Future<Map<String, dynamic>> fetchSingleTrainName(String no) async {
    return _fetchSingleTrainName(no);
  }

  static Future<Map<String, dynamic>> fetchTrainName(String no) async {
    return _fetchSingleTrainName(no);
  }

  // ═══════════════════════════════════════════════════════════════════
  // 1. TRAIN AUTOCOMPLETE SEARCH (Open Web - No Key Needed)
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> _fetchSingleTrainName(String no) async {
    try {
      final uri = Uri.parse('https://railradar.in/app/v1/trains/$no/live');
      final res = await http.get(uri, headers: _openWebHeaders).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body is Map && body['success'] == true && body['data'] is Map) {
          final d = Map<String, dynamic>.from(body['data'] as Map);
          final trainObj = d['train'] is Map
              ? Map<String, dynamic>.from(d['train'] as Map)
              : <String, dynamic>{};
          final name =
          (d['trainName'] ?? trainObj['name'] ?? 'Train $no').toString().trim();
          final src = (trainObj['source'] is Map
              ? trainObj['source']['name'] ?? trainObj['source']['code']
              : '')
              .toString();
          final dst = (trainObj['destination'] is Map
              ? trainObj['destination']['name'] ?? trainObj['destination']['code']
              : '')
              .toString();

          return {
            'number': no,
            'name': name.isNotEmpty ? name : 'Train $no',
            'source': src,
            'destination': dst,
          };
        }
      }
    } catch (_) {}
    return {'number': no, 'name': 'Train $no', 'source': '', 'destination': ''};
  }

  static Future<List<Map<String, dynamic>>> searchTrains(
      String query, {
        int limit = 10,
      }) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final results = <Map<String, dynamic>>[];
    final seen = <String>{};

    // 1. Open Web Direct Digits Lookup
    final digits = q.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 3) {
      final single = await _fetchSingleTrainName(digits);
      if (single['name'] != null && single['name'] != 'Train $digits') {
        final no = single['number']?.toString() ?? digits;
        if (seen.add(no)) {
          results.add(single);
        }
      }
    }

    // 2. Open Web Live Radar Map Candidate Lookup
    try {
      final liveMapList = await liveMap();
      if (liveMapList != null) {
        final qLow = q.toLowerCase();
        final candidateNumbers = <String>[];

        for (final item in liveMapList) {
          if (item is List && item.isNotEmpty) {
            final no = item[0]?.toString().trim() ?? '';
            if (no.isNotEmpty && !seen.contains(no) && no.toLowerCase().contains(qLow)) {
              seen.add(no);
              candidateNumbers.add(no);
              if (candidateNumbers.length >= (limit - results.length)) break;
            }
          }
        }

        if (candidateNumbers.isNotEmpty) {
          final resolvedList = await Future.wait(
            candidateNumbers.map((no) => _fetchSingleTrainName(no)),
          );
          results.addAll(resolvedList);
        }
      }
    } catch (_) {}

    return results;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 2. STATION AUTOCOMPLETE SEARCH (Offline Station Database Catalog)
  // ═══════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> searchStations(
      String query, {
        int limit = 10,
        int offset = 0,
      }) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final stations = StationSource.search(q, limit: limit);
    return stations.map((s) => {
      'code': s.code,
      'name': s.name,
      'city': s.city,
      'district': s.district,
      'state': s.state,
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 3. LIVE TRAIN RUNNING STATUS (Open Web - No Key Needed)
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> liveTracking(
    String trainNumber, {
    bool includeGeometry = true,
  }) async {
    final cleanNo = trainNumber.trim().split(' - ').first;
    if (cleanNo.isEmpty) return null;

    final uri = Uri.parse(
      'https://railradar.in/app/v1/trains/$cleanNo/live'
      '?geometry=${includeGeometry ? "true" : "false"}'
      '&format=polyline'
      '&includeCoordinates=true'
      '&haltsOnly=false',
    );

    try {
      final res = await http.get(uri, headers: _openWebHeaders).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body is Map && body['success'] == true && body['data'] is Map) {
          final map = Map<String, dynamic>.from(body['data'] as Map);
          unawaited(OfflineCache.put('live_$cleanNo', map, ttl: const Duration(minutes: 10)));
          return map;
        }
      }
    } catch (e) {
      _debug('[RailRadarLive] Open web call failed: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 4. TRAINS BETWEEN STATIONS (Open Web - No Key Needed)
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> trainsBetween(
    String from,
    String to, {
    String? date,
  }) async {
    final f = from.trim().toUpperCase();
    final t = to.trim().toUpperCase();
    if (f.isEmpty || t.isEmpty) return null;

    final uri = Uri.parse(
      'https://railradar.in/app/v1/trains/between/$f/$t?byCity=true'
      '${date != null && date.isNotEmpty ? "&date=$date" : ""}',
    );

    try {
      final res = await http.get(uri, headers: _openWebHeaders).timeout(_timeout);
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body is Map && body['success'] == true && body['data'] is Map) {
          return Map<String, dynamic>.from(body['data'] as Map);
        }
      }
    } catch (e) {
      _debug('[RailRadarBetween] Open web call failed: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 5. STATION LIVE TRAFFIC BOARD (Open Web - No Key Needed)
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> stationLive(
    String stationCode, {
    int hours = 8,
  }) async {
    final code = stationCode.trim().toUpperCase();
    if (code.isEmpty) return null;

    final uri = Uri.parse(
      'https://railradar.in/app/v1/stations/$code/live?hours=$hours&includeIntermediate=true',
    );

    try {
      final res = await http.get(uri, headers: _openWebHeaders).timeout(_timeout);
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body is Map && body['success'] == true && body['data'] is Map) {
          return Map<String, dynamic>.from(body['data'] as Map);
        }
        if (body is Map && body['data'] is Map) {
          return Map<String, dynamic>.from(body['data'] as Map);
        }
      }
    } catch (e) {
      _debug('[RailRadarStationLive] Open web call failed: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 6. NATIONAL LIVE MAP RADAR (2,000+ Active Trains - Open Web)
  // ═══════════════════════════════════════════════════════════════════
  static Future<List<dynamic>?> liveMap() async {
    final uri = Uri.parse('https://railradar.in/app/v1/live-map');
    try {
      final res = await http.get(uri, headers: _openWebHeaders).timeout(_timeout);
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body is Map && body['success'] == true && body['data'] is List) {
          return body['data'] as List;
        }
        if (body is Map && body['data'] is List) {
          return body['data'] as List;
        }
        if (body is List) {
          return body;
        }
      }
    } catch (e) {
      _debug('[RailRadarLiveMap] Open web live-map call failed: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 7. STATION SCHEDULE & DEPARTURES BOARD (Open Web)
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> stationSchedule(String stationCode) async {
    return stationLive(stationCode, hours: 24);
  }

  // ═══════════════════════════════════════════════════════════════════
  // 8. PNR STATUS ENQUIRY (Open Web - No Key Needed)
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> pnr(String pnr) async {
    final cleanPnr = pnr.replaceAll(RegExp(r'\D'), '').trim();
    if (cleanPnr.length != 10) return null;

    final uri = Uri.parse('https://railradar.in/app/v1/pnr/$cleanPnr');

    try {
      final res = await http.get(uri, headers: _openWebHeaders).timeout(_timeout);
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body is Map && body['success'] == true && body['data'] is Map) {
          return Map<String, dynamic>.from(body['data'] as Map);
        }
      }
    } catch (e) {
      _debug('[RailRadarPnr] Open web PNR call failed: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 9. NATIONAL SERVICE DISRUPTIONS & EXCEPTIONS (Open Web)
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> trainExceptions() async {
    final uri = Uri.parse('https://railradar.in/app/v1/trains/exceptions');

    try {
      final res = await http.get(uri, headers: _openWebHeaders).timeout(_timeout);
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body is Map) {
          if (body['success'] == true && body['data'] is Map) {
            return Map<String, dynamic>.from(body['data'] as Map);
          }
          if (body['data'] is Map) {
            return Map<String, dynamic>.from(body['data'] as Map);
          }
          if (body.containsKey('summary') || body.containsKey('trains')) {
            return Map<String, dynamic>.from(body);
          }
        }
      }
    } catch (e) {
      _debug('[RailRadarExceptions] Open web call failed: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 10. CORRIDOR TRAIN CROSSINGS & ENCOUNTERS (Open Web)
  // ═══════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> trainCrossings(
    String trainNumber, {
    String? date,
    String? from,
    String? to,
  }) async {
    final n = trainNumber.trim().split(' - ').first;
    if (n.isEmpty) return const [];

    final fromCode = (from ?? '').trim().toUpperCase();
    final toCode = (to ?? '').trim().toUpperCase();

    final uri = Uri.parse(
      'https://railradar.in/app/v1/trains/$n/crossings'
      '${fromCode.isNotEmpty && toCode.isNotEmpty ? "?from=$fromCode&to=$toCode" : ""}',
    );

    try {
      final res = await http.get(uri, headers: _openWebHeaders).timeout(_timeout);
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body is Map && body['success'] == true) {
          final raw = body['data'];
          if (raw is List) {
            return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          }
          if (raw is Map && raw['crossings'] is List) {
            return (raw['crossings'] as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
        }
      }
    } catch (e) {
      _debug('[RailRadarCrossings] Open web call failed: $e');
    }
    return const [];
  }

  // ═══════════════════════════════════════════════════════════════════
  // 11. ITEMIZE TICKET FARE ENQUIRY (Open Web)
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> trainFare({
    required String trainNumber,
    required String from,
    required String to,
    required String date,
    String classCode = '3A',
    String quotaCode = 'GN',
  }) async {
    final n = trainNumber.trim().split(' - ').first;
    if (n.isEmpty || from.isEmpty || to.isEmpty) return null;

    final uri = Uri.parse(
      'https://railradar.in/app/v1/trains/$n/fare'
      '?source=${from.toUpperCase()}'
      '&destination=${to.toUpperCase()}'
      '&journeyDate=$date'
      '&classCode=${classCode.toUpperCase()}'
      '&quotaCode=${quotaCode.toUpperCase()}',
    );

    try {
      final res = await http.get(uri, headers: _openWebHeaders).timeout(_timeout);
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body is Map && body['success'] == true && body['data'] is Map) {
          return Map<String, dynamic>.from(body['data'] as Map);
        }
      }
    } catch (e) {
      _debug('[RailRadarFare] Open web call failed: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 12. COACH POSITION & RAKE FORMATION (Open Web)
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> coachPosition(
    String trainNumber, [
    String? stationCode,
  ]) async {
    final n = trainNumber.trim().split(' - ').first;
    if (n.isEmpty) return null;

    final urlStr = (stationCode != null && stationCode.trim().isNotEmpty)
        ? 'https://railradar.in/app/v1/trains/$n/coaches/${stationCode.trim().toUpperCase()}'
        : 'https://railradar.in/app/v1/trains/$n/coaches';

    try {
      final uri = Uri.parse(urlStr);
      final res = await http.get(uri, headers: _openWebHeaders).timeout(_timeout);
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body is Map && body['success'] == true && body['data'] is Map) {
          return Map<String, dynamic>.from(body['data'] as Map);
        }
      }
    } catch (e) {
      _debug('[RailRadarCoaches] Open web call failed: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> trainCoaches(String trainNumber) async {
    return coachPosition(trainNumber);
  }

  // ═══════════════════════════════════════════════════════════════════
  // 13. TRAIN SCHEDULE & ROUTE GEOMETRY (Open Web)
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> trainSchedule(String trainNumber) async {
    return liveTracking(trainNumber, includeGeometry: true);
  }

  static Future<Map<String, dynamic>?> trainRouteGeometry(String trainNumber) async {
    return liveTracking(trainNumber, includeGeometry: true);
  }
}
