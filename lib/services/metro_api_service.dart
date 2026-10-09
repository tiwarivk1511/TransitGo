import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as latlong show LatLng;

import '../data/models/metro_network.dart';
import 'remote_config_service.dart';

class MetroApiService {
  static final http.Client _client = http.Client();

  // Cache for fetched web metro networks & cities
  static final Map<String, MetroNetwork> _liveNetworkCache = {};
  static List<String>? MetroActiveCitiesCache;
  static final Map<int, List<Map<String, dynamic>>> MetroStationsCache = {};
  static final Map<String, List<Map<String, dynamic>>> _trackMyMetroStationsCache = {};

  /// Map of city/network IDs to TrackMyMetro city codes
  static const Map<String, String> trackMyMetroCityCodes = {
    'delhi': 'del',
    'noida': 'noi',
    'patna': 'pat',
    'indore': 'ind',
    'bhopal': 'bho',
    'bengaluru': 'blr',
    'nagpur': 'nag',
    'mumbai': 'mum',
    'hyderabad': 'hyd',
    'kanpur': 'kan',
    'ahmedabad': 'ahm',
    'gurugram': 'gur',
    'kolkata': 'kol',
    'chennai': 'chn',
    'kochi': 'koc',
    'jaipur': 'jai',
    'lucknow': 'luc',
    'agra': 'agr',
    'navi_mumbai': 'nav',
    'gandhinagar': 'gan',
    'meerut': 'mee',
    'mumbai_mono': 'mmo',
  };

  /// Exact Postman / Curl headers for TrackMyMetro REST API
  static const Map<String, String> _trackMyMetroHeaders = {
    'accept': '*/*',
    'accept-language': 'en-US,en;q=0.9,en-IN;q=0.8,hi;q=0.7,hi-IN;q=0.6',
    'dnt': '1',
    'priority': 'u=1, i',
    'referer': 'https://trackmymetro.com/',
    'sec-ch-ua': '"Chromium";v="154", "Microsoft Edge";v="154", "Not A(Brand";v="99"',
    'sec-ch-ua-mobile': '?1',
    'sec-ch-ua-platform': '"Android"',
    'sec-fetch-dest': 'empty',
    'sec-fetch-mode': 'cors',
    'sec-fetch-site': 'same-origin',
    'user-agent':
        'Mozilla/5.0 (Linux; Android 16; Pixel 10) AppleWebKit/537.36 (KHTML, like Gecko) Edg/154.0.0.0 Mobile Safari/537.36',
  };

  static const Map<String, String> MetroHeaders = {
    'accept': '*/*',
    'accept-language': 'en-US,en;q=0.9,hi;q=0.7',
    'referer': 'https://yometro.com/app/',
    'user-agent':
        'Mozilla/5.0 (Linux; Android 16; Pixel 10) AppleWebKit/537.36 (KHTML, like Gecko) Edg/154.0.0.0 Mobile Safari/537.36',
  };

  /// Map of city/network IDs to YoMetro Zone IDs
  static const Map<String, int> yoMetroZoneIds = {
    'delhi': 11,
    'jaipur': 13,
    'mumbai': 14,
    'bengaluru': 15,
    'hyderabad': 16,
    'chennai': 17,
    'kochi': 18,
    'kolkata': 19,
    'lucknow': 20,
    'nagpur': 22,
    'ahmedabad': 23,
    'pune': 24,
  };

  /// Center coordinates for Indian Metro networks
  static final Map<String, latlong.LatLng> cityCenters = {
    'delhi': const latlong.LatLng(28.6139, 77.2090),
    'mumbai': const latlong.LatLng(19.0760, 72.8777),
    'kolkata': const latlong.LatLng(22.5726, 88.3639),
    'bengaluru': const latlong.LatLng(12.9716, 77.5946),
    'chennai': const latlong.LatLng(13.0827, 80.2707),
    'hyderabad': const latlong.LatLng(17.3850, 78.4867),
    'pune': const latlong.LatLng(18.5204, 73.8567),
    'ahmedabad': const latlong.LatLng(23.0225, 72.5714),
    'kochi': const latlong.LatLng(9.9312, 76.2673),
    'lucknow': const latlong.LatLng(26.8467, 80.9462),
    'jaipur': const latlong.LatLng(26.9124, 75.7873),
    'kanpur': const latlong.LatLng(26.4499, 80.3319),
    'agra': const latlong.LatLng(27.1767, 78.0081),
    'nagpur': const latlong.LatLng(21.1458, 79.0882),
    'indore': const latlong.LatLng(22.7196, 75.8577),
    'patna': const latlong.LatLng(25.5941, 85.1376),
    'bhopal': const latlong.LatLng(23.2599, 77.4126),
  };

  static Color? _parseColorHex(String? hex) {
    if (hex == null || hex.trim().isEmpty) return null;
    var clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final val = int.tryParse('FF$clean', radix: 16);
      if (val != null) return Color(val);
    } else if (clean.length == 8) {
      final val = int.tryParse(clean, radix: 16);
      if (val != null) return Color(val);
    }
    return null;
  }

  static Color _getLineColorFromCode(String lineCode) {
    final code = lineCode.toLowerCase();
    if (code.contains('red')) return const Color(0xFFE53935);
    if (code.contains('yellow')) return const Color(0xFFFDD835);
    if (code.contains('blue')) return const Color(0xFF1E88E5);
    if (code.contains('green')) return const Color(0xFF43A047);
    if (code.contains('violet') || code.contains('purple')) return const Color(0xFF8E24AA);
    if (code.contains('pink')) return const Color(0xFFEC407A);
    if (code.contains('magenta') || code.contains('rrts')) return const Color(0xFFD81B60);
    if (code.contains('orange') || code.contains('airport')) return const Color(0xFFFB8C00);
    if (code.contains('aqua') || code.contains('mono') || code.contains('cyan')) return const Color(0xFF00ACC1);
    if (code.contains('rapid')) return const Color(0xFF3949AB);
    if (code.contains('grey')) return const Color(0xFF757575);
    return const Color(0xFF0A84FF);
  }

  static String _formatLineTitle(String lineCode) {
    final parts = lineCode.split('-');
    if (parts.isEmpty) return 'Metro Line';
    final colorName = parts[0][0].toUpperCase() + parts[0].substring(1);
    return '$colorName Line';
  }

  /// Clean slug_for_route into a human-friendly Metro Station Name
  static String cleanSlugToStationName(String slug) {
    if (slug.isEmpty) return '';
    var s = slug.split('-metro-station-').first;
    s = s.replaceAll('-station-', '-').replaceAll('-railway-', '-');
    final parts = s.split('-').where((p) => p.isNotEmpty).map((p) {
      final low = p.toLowerCase();
      if (low == 'isbt') return 'ISBT';
      if (low == 'igi') return 'IGI';
      if (low == 'csmt') return 'CSMT';
      if (low == 'mg') return 'MG';
      if (low == 'gtb') return 'GTB';
      if (low == 'sec') return 'Sector';
      if (low == 'dr') return 'Dr.';
      return p[0].toUpperCase() + p.substring(1).toLowerCase();
    }).toList();
    return parts.join(' ');
  }

  /// Formats station name into a clean YoMetro API slug
  static String formatYoMetroStationSlug(String stationName, String cityName) {
    var s = stationName
        .toLowerCase()
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll('.', '')
        .replaceAll('isbt', '')
        .replaceAll(' - ', '-')
        .replaceAll(' ', '-')
        .replaceAll(RegExp(r'-+'), '-')
        .trim();

    if (s.startsWith('-')) s = s.substring(1);
    if (s.endsWith('-')) s = s.substring(0, s.length - 1);

    var c = cityName.toLowerCase().replaceAll(' ', '').replaceAll('ncr', '');
    if (c.isEmpty || c == 'delhincr' || c == 'delhi') {
      c = 'delhi';
    }

    return '$s-metro-station-$c';
  }

  /// Fetches exact 100% live routes directly from YoMetro Open Web Route API: https://yometro.com/api/route.php?slug=...
  static Future<List<MetroRoute>> fetchYoMetroApiRoutes({
    required MetroNetwork network,
    required String sourceStation,
    required String destinationStation,
  }) async {
    final srcSlug = formatYoMetroStationSlug(sourceStation, network.cityName);
    final dstSlug = formatYoMetroStationSlug(destinationStation, network.cityName);
    final slug = 'from-$srcSlug-to-$dstSlug';
    final url = 'https://yometro.com/api/route.php?slug=$slug';

    try {
      final response = await _client.get(
        Uri.parse(url),
        headers: MetroHeaders,
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body is Map && body['route_algo'] is Map) {
          final results = <MetroRoute>[];

          final algoRoute = _parseYoMetroRouteData(
            network: network,
            sourceStation: sourceStation,
            destinationStation: destinationStation,
            data: Map<String, dynamic>.from(body['route_algo'] as Map),
            tag: 'Fastest Route ⚡',
          );
          if (algoRoute != null) results.add(algoRoute);

          if (body['route_custom'] is Map) {
            final customRoute = _parseYoMetroRouteData(
              network: network,
              sourceStation: sourceStation,
              destinationStation: destinationStation,
              data: Map<String, dynamic>.from(body['route_custom'] as Map),
              tag: 'Alternate Route 🚇',
            );
            if (customRoute != null) results.add(customRoute);
          }

          if (results.isNotEmpty) return results;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[YoMetroRouteApi] fetchRoutes error: $e');
    }

    return const [];
  }

  static MetroRoute? _parseYoMetroRouteData({
    required MetroNetwork network,
    required String sourceStation,
    required String destinationStation,
    required Map<String, dynamic> data,
    required String tag,
  }) {
    final fare = (data['normal_fare'] as num?)?.toInt() ?? 10;
    final timeStr = (data['total_time'] ?? '').toString();
    final distStr = (data['total_distance'] ?? '').toString().replaceAll('km', '').trim();
    final distanceKm = double.tryParse(distStr) ?? 10.0;

    int durationMins = 0;
    final hrsMatch = RegExp(r'(\d+)\s*hrs?').firstMatch(timeStr);
    final minsMatch = RegExp(r'(\d+)\s*mins?').firstMatch(timeStr);
    if (hrsMatch != null) durationMins += (int.tryParse(hrsMatch.group(1)!) ?? 0) * 60;
    if (minsMatch != null) durationMins += (int.tryParse(minsMatch.group(1)!) ?? 0);
    if (durationMins == 0) durationMins = (data['station_count'] as num?)?.toInt() ?? 20;

    final rawStations = data['stations'] as List<dynamic>? ?? [];
    if (rawStations.isEmpty) return null;

    final segments = <MetroRouteSegment>[];
    final interchanges = <MetroInterchange>[];

    String currentLine = (rawStations.first['line_name_en'] ?? 'Metro Line').toString();
    Color currentColor = _parseColorHex((rawStations.first['line_color'] ?? '').toString()) ?? const Color(0xFF0A84FF);
    List<String> currentSegmentStations = [(rawStations.first['station_name_en'] ?? sourceStation).toString()];

    for (int i = 1; i < rawStations.length; i++) {
      final item = rawStations[i] as Map;
      final stName = (item['station_name_en'] ?? '').toString();
      final lineName = (item['line_name_en'] ?? currentLine).toString();
      final lineColorHex = (item['line_color'] ?? '').toString();
      final lineColor = _parseColorHex(lineColorHex) ?? currentColor;

      if (lineName == currentLine) {
        if (currentSegmentStations.isEmpty || currentSegmentStations.last != stName) {
          currentSegmentStations.add(stName);
        }
      } else {
        if (currentSegmentStations.length > 1) {
          segments.add(MetroRouteSegment(
            lineName: currentLine,
            lineColor: currentColor,
            fromStation: currentSegmentStations.first,
            toStation: currentSegmentStations.last,
            stations: List.from(currentSegmentStations),
            distanceKm: double.parse(((currentSegmentStations.length - 1) * 1.3).toStringAsFixed(1)),
            durationMinutes: (currentSegmentStations.length - 1) * 2,
          ));
        }

        interchanges.add(MetroInterchange(
          stationName: currentSegmentStations.isNotEmpty ? currentSegmentStations.last : stName,
          fromLine: currentLine,
          toLine: lineName,
          toLineColor: lineColor,
        ));

        currentLine = lineName;
        currentColor = lineColor;
        currentSegmentStations = [stName];
      }
    }

    if (currentSegmentStations.length > 1) {
      segments.add(MetroRouteSegment(
        lineName: currentLine,
        lineColor: currentColor,
        fromStation: currentSegmentStations.first,
        toStation: currentSegmentStations.last,
        stations: List.from(currentSegmentStations),
        distanceKm: double.parse(((currentSegmentStations.length - 1) * 1.3).toStringAsFixed(1)),
        durationMinutes: (currentSegmentStations.length - 1) * 2,
      ));
    }

    return MetroRoute(
      cityName: network.cityName,
      sourceStation: sourceStation,
      destinationStation: destinationStation,
      segments: segments,
      interchanges: interchanges,
      totalStations: (data['station_count'] as num?)?.toInt() ?? rawStations.length,
      totalDurationMinutes: durationMins,
      totalDistanceKm: distanceKm,
      estimatedFare: fare,
    );
  }

  /// Fetches dynamic active stations for a city from TrackMyMetro REST API (stations-{code}.json)
  static Future<List<Map<String, dynamic>>> fetchTrackMyMetroStations(String cityCode) async {
    final code = cityCode.trim().toLowerCase();
    if (_trackMyMetroStationsCache.containsKey(code)) {
      return _trackMyMetroStationsCache[code]!;
    }

    // 1. Try Firebase Remote Config first (parameter key: metro_stations_{code})
    try {
      final remoteConfigJson = RemoteConfigService.getMetroStationsJson(code);
      if (remoteConfigJson.isNotEmpty) {
        final decoded = json.decode(remoteConfigJson);
        List<dynamic> rawList = [];
        if (decoded is List) {
          rawList = decoded;
        } else if (decoded is Map && decoded['stations'] is List) {
          rawList = decoded['stations'] as List;
        }

        final results = <Map<String, dynamic>>[];
        for (final item in rawList) {
          if (item is Map) {
            final m = Map<String, dynamic>.from(item);
            final name = (m['name'] ?? '').toString().trim();
            if (name.isNotEmpty) {
              results.add(m);
            }
          }
        }

        if (results.isNotEmpty) {
          _trackMyMetroStationsCache[code] = results;
          return results;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[RemoteConfig] fetchMetroStations error for $code: $e');
    }

    // 2. TrackMyMetro REST API call
    final url = 'https://trackmymetro.com/data/stations-$code.json?v=1.6';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: _trackMyMetroHeaders,
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        List<dynamic> rawList = [];
        if (body is List) {
          rawList = body;
        } else if (body is Map && body['stations'] is List) {
          rawList = body['stations'] as List;
        }

        final results = <Map<String, dynamic>>[];
        for (final item in rawList) {
          if (item is Map) {
            final m = Map<String, dynamic>.from(item);
            final name = (m['name'] ?? '').toString().trim();
            if (name.isNotEmpty) {
              results.add(m);
            }
          }
        }

        if (results.isNotEmpty) {
          _trackMyMetroStationsCache[code] = results;
          return results;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[TrackMyMetroApi] fetchTrackMyMetroStations error for $code: $e');
    }

    // 3. Fallback: YoMetro Open Web REST API
    final zoneId = yoMetroZoneIds[code];
    if (zoneId != null) {
      final yoStns = await fetchYoMetroStations(zoneId);
      if (yoStns.isNotEmpty) {
        _trackMyMetroStationsCache[code] = yoStns;
        return yoStns;
      }
    }

    return const [];
  }

  /// Backward compatible alias for fetchDynamicTrackMyMetroNetwork
  static Future<MetroNetwork> fetchLiveNetwork(MetroNetwork baseNetwork) async {
    return fetchDynamicTrackMyMetroNetwork(baseNetwork);
  }

  /// Builds a 100% dynamic MetroNetwork directly from TrackMyMetro REST API (stations-{code}.json)
  static Future<MetroNetwork> fetchDynamicTrackMyMetroNetwork(MetroNetwork baseNetwork) async {
    final cityCode = trackMyMetroCityCodes[baseNetwork.id.toLowerCase()] ?? 'del';

    if (_liveNetworkCache.containsKey(baseNetwork.id)) {
      return _liveNetworkCache[baseNetwork.id]!;
    }

    final rawStations = await fetchTrackMyMetroStations(cityCode);

    if (rawStations.isEmpty) {
      return baseNetwork;
    }

    final linesMap = <String, List<String>>{};
    final lineInterchangesMap = <String, List<String>>{};

    for (final st in rawStations) {
      final stName = (st['name'] ?? '').toString().trim();
      if (stName.isEmpty) continue;

      final isInterchange = st['isInterchange'] == true;
      final stLines = st['lines'] as List<dynamic>? ?? [];

      for (final lCodeRaw in stLines) {
        final lCode = lCodeRaw.toString().trim();
        if (lCode.isEmpty) continue;

        linesMap.putIfAbsent(lCode, () => []).add(stName);
        if (isInterchange) {
          lineInterchangesMap.putIfAbsent(lCode, () => []).add(stName);
        }
      }
    }

    if (linesMap.isEmpty) {
      return baseNetwork;
    }

    final dynamicLines = <MetroLine>[];

    for (final entry in linesMap.entries) {
      final lineCode = entry.key;
      final stationList = entry.value;
      if (stationList.isEmpty) continue;

      final lineColor = _getLineColorFromCode(lineCode);
      final lineTitle = _formatLineTitle(lineCode);
      final interchanges = lineInterchangesMap[lineCode] ?? [];

      final routeString = stationList.length >= 2
          ? '${stationList.first} ↔ ${stationList.last}'
          : stationList.first;

      dynamicLines.add(MetroLine(
        name: lineTitle,
        color: lineColor,
        route: routeString,
        stationsCount: stationList.length,
        distanceKm: (stationList.length * 1.3),
        interchangeStations: interchanges,
        stations: stationList,
      ));
    }

    if (dynamicLines.isEmpty) {
      return baseNetwork;
    }

    int totalStnsCount = rawStations.length;
    double totalKm = 0;
    for (final line in dynamicLines) {
      totalKm += line.distanceKm;
    }

    final dynamicNetwork = MetroNetwork(
      id: baseNetwork.id,
      cityName: baseNetwork.cityName,
      stateName: baseNetwork.stateName,
      operatorName: baseNetwork.operatorName,
      fareRange: baseNetwork.fareRange,
      timings: baseNetwork.timings,
      totalStations: totalStnsCount,
      totalNetworkKm: double.parse(totalKm.toStringAsFixed(1)),
      ticketingOptions: baseNetwork.ticketingOptions,
      lines: dynamicLines,
      highlights: baseNetwork.highlights,
      websiteUrl: baseNetwork.websiteUrl,
      mapUrl: baseNetwork.mapUrl,
    );

    _liveNetworkCache[baseNetwork.id] = dynamicNetwork;
    return dynamicNetwork;
  }

  /// Fetches active metro network cities directly from YoMetro REST API
  static Future<List<String>> fetchYoMetroActiveCities() async {
    if (MetroActiveCitiesCache != null && MetroActiveCitiesCache!.isNotEmpty) {
      return MetroActiveCitiesCache!;
    }

    final uri = Uri.parse(
      'https://metro.yoinfra.com/api/cities?fields[0]=name&filters[metro_networks][network_status][\$eq]=active&sort=name:asc&pagination[pageSize]=30',
    );

    try {
      final response = await _client.get(uri, headers: MetroHeaders).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = data['data'] as List<dynamic>? ?? [];
        final cities = <String>[];
        for (final item in list) {
          if (item is Map && item['name'] != null) {
            final name = item['name'].toString().trim();
            if (name.isNotEmpty) cities.add(name);
          }
        }
        if (cities.isNotEmpty) {
          MetroActiveCitiesCache = cities;
          return cities;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[YoMetroApi] fetchYoMetroActiveCities failed: $e');
    }

    return [
      'Agra', 'Ahmedabad', 'Bengaluru', 'Bhopal', 'Chennai', 'Delhi',
      'Gurugram', 'Hyderabad', 'Indore', 'Jaipur', 'Kanpur', 'Kochi',
      'Kolkata', 'Lucknow', 'Meerut', 'Mumbai', 'Nagpur', 'Navi Mumbai',
      'Noida', 'Patna', 'Pune'
    ];
  }

  /// Fetches all active station list for a metro network zone from YoMetro API
  static Future<List<Map<String, dynamic>>> fetchYoMetroStations(int zoneId) async {
    if (MetroStationsCache.containsKey(zoneId)) {
      return MetroStationsCache[zoneId]!;
    }

    final results = <Map<String, dynamic>>[];
    final seen = <String>{};
    int page = 1;
    int pageCount = 1;

    try {
      while (page <= pageCount && page <= 8) {
        final uri = Uri.parse(
          'https://metro.yoinfra.com/api/line-routes?fields[0]=station_status'
          '&populate[station][fields][0]=slug_for_route'
          '&populate[station][fields][1]=unique_id'
          '&pagination[pageSize]=100&pagination[page]=$page'
          '&filters[station][metro_network][zone_id][\$eq]=$zoneId',
        );

        final response = await _client.get(uri, headers: MetroHeaders).timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) {
          final body = json.decode(response.body);
          if (body is Map) {
            final meta = body['meta'] as Map?;
            final pagination = meta?['pagination'] as Map?;
            pageCount = (pagination?['pageCount'] as num?)?.toInt() ?? 1;

            final list = body['data'] as List<dynamic>? ?? [];
            for (final item in list) {
              if (item is Map) {
                final status = (item['station_status'] ?? 'active').toString().toLowerCase();
                final st = item['station'] is Map ? Map<String, dynamic>.from(item['station'] as Map) : null;
                if (st != null && status == 'active') {
                  final slug = (st['slug_for_route'] ?? '').toString();
                  final uid = (st['unique_id'] ?? '').toString();
                  final cleanName = cleanSlugToStationName(slug);

                  if (cleanName.isNotEmpty && seen.add(cleanName.toLowerCase())) {
                    results.add({
                      'unique_id': uid,
                      'slug': slug,
                      'name': cleanName,
                      'status': status,
                    });
                  }
                }
              }
            }
          }
        }
        page++;
      }
      if (results.isNotEmpty) {
        MetroStationsCache[zoneId] = results;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[YoMetroApi] fetchYoMetroStations zone $zoneId failed: $e');
    }

    return results;
  }
}
