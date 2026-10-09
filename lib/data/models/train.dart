import 'package:latlong2/latlong.dart';

import '../sources/station_source.dart';
import 'coach.dart';

class TrainJourneyInfo {
  final String trainType;
  final String fromCode;
  final String fromName;
  final String toCode;
  final String toName;
  final String departure;
  final String arrival;
  final int distanceKm;
  final int? durationMin;
  final int? halts;
  final List<String> runDays;

  const TrainJourneyInfo({
    required this.trainType,
    required this.fromCode,
    required this.fromName,
    required this.toCode,
    required this.toName,
    required this.departure,
    required this.arrival,
    required this.distanceKm,
    this.durationMin,
    this.halts,
    this.runDays = const [],
  });
}

// ═════════════════════════════════════════════════════════════════════
// TRAIN TRACKING — top-level live status
// ═════════════════════════════════════════════════════════════════════
class TrainTracking {
  final String trainNumber;
  final String trainName;
  final String trainType; // "Superfast Express"
  final String category; // "Express"
  final List<String> runDays; // ['mon','tue',...]

  final TrainStopRef? source;
  final TrainStopRef? destination;

  final double? distance; // total route km
  final int? durationMin;
  final double? avgSpeed;
  final double? maxSpeed;
  final int? totalHalts;
  final String? returnTrain;
  final List<CoachInfo> coachComposition;
  final String? rawCoachPosition;

  final bool isLive;
  final String trackingMode; // "real-time" | "predicted"
  final String status; // "not-started" | "running" | "reached"
  final int delayMinutes;
  final DateTime? lastUpdatedAt;
  final DateTime? startDate;

  final TrainStopRef? nextHalt;
  final LiveLocation currentLocation;
  final List<TrainRouteStop> route;

  /// Ordered polyline of the route (from `geometry.geojson`).
  final List<LatLng> routeGeometry;

  /// Station stops with lat/lng (from `stops=true`).
  final List<TrainStopRef> geoStops;

  TrainTracking({
    required this.trainNumber,
    required this.trainName,
    this.trainType = '',
    this.category = '',
    this.runDays = const [],
    this.source,
    this.destination,
    this.distance,
    this.durationMin,
    this.avgSpeed,
    this.maxSpeed,
    this.totalHalts,
    this.returnTrain,
    this.coachComposition = const [],
    this.rawCoachPosition,
    this.isLive = false,
    this.trackingMode = 'unknown',
    this.status = '',
    this.delayMinutes = 0,
    this.lastUpdatedAt,
    this.startDate,
    this.nextHalt,
    this.currentLocation = const LiveLocation(),
    this.route = const [],
    this.routeGeometry = const [],
    this.geoStops = const [],
  });

  // ── Factories ──────────────────────────────────────────────────
  factory TrainTracking.fromNtes(
    Map<String, dynamic> data,
    String trainNumber,
  ) {
    final routeRaw = (data['stationList'] ?? data['route'] ?? []) as List?;
    final route = <TrainRouteStop>[];
    if (routeRaw != null) {
      for (var i = 0; i < routeRaw.length; i++) {
        if (routeRaw[i] is! Map) continue;
        route.add(
          TrainRouteStop.fromNtes(
            Map<String, dynamic>.from(routeRaw[i] as Map),
            i + 1,
          ),
        );
      }
    }
    final current =
        data['currentStationCode']?.toString() ??
        data['curStn']?.toString() ??
        (route.isNotEmpty ? route.first.stationCode : '');

    return TrainTracking(
      trainNumber: trainNumber,
      trainName: data['trainName']?.toString() ?? '',
      status: data['status']?.toString() ?? 'running',
      delayMinutes: _int(data['delay']),
      route: route,
      currentLocation: LiveLocation(
        stationCode: current,
        status: 'running',
        speedKmh: _dbl(data['speed']),
        delayMinutes: _int(data['delay']),
      ),
    );
  }

  factory TrainTracking.fromRailRadar(
    Map<String, dynamic> data,
    String trainNumber,
  ) {
    final trainMap = data['train'] is Map
        ? Map<String, dynamic>.from(data['train'] as Map)
        : const <String, dynamic>{};

    // ── Route ─────────────────────────────────────────────────────
    final routeRaw = (data['route'] ?? []) as List?;
    final route = <TrainRouteStop>[];
    if (routeRaw != null) {
      for (var i = 0; i < routeRaw.length; i++) {
        if (routeRaw[i] is! Map) continue;
        route.add(
          TrainRouteStop.fromRailRadar(
            Map<String, dynamic>.from(routeRaw[i] as Map),
            i + 1,
          ),
        );
      }
    }

    // ── Source / destination ──────────────────────────────────────
    final srcMap = trainMap['source'] is Map
        ? Map<String, dynamic>.from(trainMap['source'] as Map)
        : const <String, dynamic>{};
    final dstMap = trainMap['destination'] is Map
        ? Map<String, dynamic>.from(trainMap['destination'] as Map)
        : const <String, dynamic>{};

    // ── Run days ──────────────────────────────────────────────────
    final runDays = (trainMap['runDays'] is List)
        ? (trainMap['runDays'] as List).map((e) => e.toString()).toList()
        : <String>[];

    // ── Coach composition ────────────────────────────────────────
    final rawCoach =
        trainMap['coachPosition']?.toString() ??
        data['coachPosition']?.toString();
    final coaches = <CoachInfo>[];
    if (rawCoach != null && rawCoach.isNotEmpty) {
      final parts = rawCoach.split('-');
      for (var i = 0; i < parts.length; i++) {
        final c = parts[i].trim();
        if (c.isEmpty) continue;
        coaches.add(CoachInfo.fromCode(c, i + 1));
      }
    }

    // ── nextHalt ─────────────────────────────────────────────────
    TrainStopRef? nextHalt;
    if (data['nextHalt'] is Map) {
      final nh = Map<String, dynamic>.from(data['nextHalt'] as Map);
      nextHalt = TrainStopRef(
        code: nh['stationCode']?.toString() ?? '',
        name: nh['stationName']?.toString() ?? '',
        sequence: _int(nh['sequence']),
        distance: _dbl(nh['distance']),
      );
    }

    // ═══════════════════════════════════════════════════════════════
    // GEO STOPS — station coordinates (from stops=true or route)
    // ═══════════════════════════════════════════════════════════════
    final stops = <TrainStopRef>[];
    final rawStops = data['stops'] ?? data['route'];
    if (rawStops is List) {
      for (final s in rawStops) {
        if (s is! Map) continue;
        final sm = Map<String, dynamic>.from(s);
        final stn = sm['station'] is Map
            ? Map<String, dynamic>.from(sm['station'] as Map)
            : null;
        final code = stn != null
            ? (stn['code'] ?? stn['stationCode'] ?? '').toString()
            : (sm['code'] ?? sm['stationCode'] ?? '').toString();
        final name = stn != null
            ? (stn['name'] ?? sm['stationName'] ?? '').toString()
            : (sm['name'] ?? sm['stationName'] ?? '').toString();

        final lat = _dbl(stn?['lat'] ?? sm['lat'] ?? sm['latitude']);
        final lng = _dbl(
          stn?['lng'] ??
              stn?['lon'] ??
              sm['lng'] ??
              sm['lon'] ??
              sm['longitude'],
        );

        LatLng? stnLatLng;
        if (lat != null && lng != null) {
          stnLatLng = LatLng(lat, lng);
        } else if (code.isNotEmpty) {
          final sObj = StationSource.byCode(code);
          if (sObj != null && sObj.hasCoordinates) {
            stnLatLng = LatLng(sObj.latitude!, sObj.longitude!);
          }
        }

        if (stnLatLng == null) continue;
        stops.add(
          TrainStopRef(
            code: code,
            name: name.isNotEmpty
                ? name
                : (StationSource.byCode(code)?.name ?? code),
            sequence: _int(sm['sequence']),
            distance: _dbl(sm['distance']),
            latLng: stnLatLng,
          ),
        );
      }
    }

    // Fallback: if `stops` wasn't present, try to build geoStops by matching route coords.
    if (stops.isEmpty &&
        srcMap.isNotEmpty &&
        dstMap.isNotEmpty &&
        srcMap['lat'] != null &&
        dstMap['lat'] != null) {
      final srcLat = _dbl(srcMap['lat']);
      final srcLng = _dbl(srcMap['lng']);
      final dstLat = _dbl(dstMap['lat']);
      final dstLng = _dbl(dstMap['lng']);
      if (srcLat != null && srcLng != null) {
        stops.add(
          TrainStopRef(
            code: srcMap['code']?.toString() ?? '',
            name: srcMap['name']?.toString() ?? '',
            sequence: 1,
            latLng: LatLng(srcLat, srcLng),
          ),
        );
      }
      if (dstLat != null && dstLng != null) {
        stops.add(
          TrainStopRef(
            code: dstMap['code']?.toString() ?? '',
            name: dstMap['name']?.toString() ?? '',
            sequence: route.length,
            latLng: LatLng(dstLat, dstLng),
          ),
        );
      }
    }

    // ── currentLocation ─────────────────────────────────────────
    final locMap = data['currentLocation'] is Map
        ? Map<String, dynamic>.from(data['currentLocation'] as Map)
        : const <String, dynamic>{};

    final apiLocLatLng =
        _parseLatLng(locMap) ??
        _parseLatLng(locMap['location']) ??
        _parseLatLng(locMap['position']) ??
        _parseLatLng(data['location']) ??
        _parseLatLng(data['position']);
    var locLatLng = apiLocLatLng;
    if (locLatLng == null) {
      final seq = _int(locMap['sequence']);
      final code = locMap['stationCode']?.toString() ?? '';
      for (final stp in stops) {
        if ((seq > 0 && stp.sequence == seq) ||
            (code.isNotEmpty && stp.code.toUpperCase() == code.toUpperCase())) {
          locLatLng = stp.latLng;
          break;
        }
      }
    }

    // ═══════════════════════════════════════════════════════════════
    // GEOMETRY — polyline of the entire route
    // ═══════════════════════════════════════════════════════════════
    final geoList = <LatLng>[];

    String encPoly = (data['encodedPolyline'] ?? data['polyline'] ?? '').toString().trim();
    final geo = data['geometry'];
    if (encPoly.isEmpty && geo is Map) {
      encPoly = (geo['encodedPolyline'] ?? geo['polyline'] ?? '').toString().trim();
    }
    if (encPoly.isNotEmpty) {
      geoList.addAll(_decodePolyline(encPoly));
    }

    if (geoList.isEmpty) {
      if (geo is Map) {
        final gj = geo['geojson'];
        if (gj is Map) {
          final g = gj['geometry'];
          if (g is Map && g['coordinates'] is List) {
            for (final c in (g['coordinates'] as List)) {
              final point = _parseLatLng(c);
              if (point != null) geoList.add(point);
            }
          }
        }
      } else if (data['routeGeometry'] is List) {
        for (final c in (data['routeGeometry'] as List)) {
          final point = _parseLatLng(c);
          if (point != null) geoList.add(point);
        }
      } else if (data['routeGeometry'] is String) {
        geoList.addAll(_decodePolyline(data['routeGeometry'].toString()));
      }
    }

    return TrainTracking(
      trainNumber: trainMap['number']?.toString() ?? trainNumber,
      trainName:
          trainMap['name']?.toString() ?? data['trainName']?.toString() ?? '',
      trainType: trainMap['type']?.toString() ?? '',
      category: trainMap['category']?.toString() ?? '',
      runDays: runDays,
      source: srcMap.isEmpty
          ? null
          : TrainStopRef(
              code: srcMap['code']?.toString() ?? '',
              name: srcMap['name']?.toString() ?? '',
              latLng: (srcMap['lat'] != null && srcMap['lng'] != null)
                  ? LatLng(_dbl(srcMap['lat'])!, _dbl(srcMap['lng'])!)
                  : null,
            ),
      destination: dstMap.isEmpty
          ? null
          : TrainStopRef(
              code: dstMap['code']?.toString() ?? '',
              name: dstMap['name']?.toString() ?? '',
              latLng: (dstMap['lat'] != null && dstMap['lng'] != null)
                  ? LatLng(_dbl(dstMap['lat'])!, _dbl(dstMap['lng'])!)
                  : null,
            ),
      distance: _dbl(trainMap['distance']),
      durationMin: _int(trainMap['duration']),
      avgSpeed: _dbl(trainMap['avgSpeed']),
      maxSpeed: _dbl(trainMap['maxSpeed']),
      totalHalts: _int(trainMap['totalHalts']),
      returnTrain: trainMap['returnTrain']?.toString(),
      coachComposition: coaches,
      rawCoachPosition: rawCoach,
      isLive: data['isLive'] == true,
      trackingMode: data['trackingMode']?.toString() ?? 'unknown',
      status: data['status']?.toString() ?? 'unknown',
      delayMinutes: _int(data['delayMinutes']),
      lastUpdatedAt: _dt(data['lastUpdatedAt']),
      startDate: _dt(data['startDate']),
      nextHalt: nextHalt,
      currentLocation: LiveLocation(
        stationCode: locMap['stationCode']?.toString() ?? '',
        stationName: locMap['stationName']?.toString() ?? '',
        sequence: _int(locMap['sequence']),
        status: locMap['status']?.toString() ?? '',
        isHalt: locMap['isHalt'] == true,
        distanceFromOriginKm: _dbl(locMap['distanceFromOriginKm']),
        distanceFromLastStationKm: _dbl(locMap['distanceFromLastStationKm']),
        segmentProgress: _dbl(locMap['segmentProgress']),
        speedKmh: _dbl(
          locMap['speedKmh'] ??
              locMap['speedKmph'] ??
              locMap['currentSpeedKmh'] ??
              locMap['currentSpeed'] ??
              locMap['speed'] ??
              data['speedKmh'] ??
              data['speedKmph'] ??
              data['currentSpeedKmh'] ??
              data['currentSpeed'] ??
              data['speed'],
        ),
        delayMinutes: _int(locMap['delayMinutes']),
        latLng: locLatLng,
        hasGpsCoordinates: apiLocLatLng != null,
      ),
      route: route,
      routeGeometry: geoList,
      geoStops: stops,
    );
  }

  factory TrainTracking.parse(Map<String, dynamic> data, String trainNumber) {
    if (data['train'] is Map || data['currentLocation'] is Map) {
      return TrainTracking.fromRailRadar(data, trainNumber);
    }
    return TrainTracking.fromNtes(data, trainNumber);
  }

  // ── Derived helpers ────────────────────────────────────────────
  int get currentIndex {
    if (currentLocation.stationCode.isEmpty) return -1;
    return route.indexWhere(
      (s) => s.stationCode == currentLocation.stationCode,
    );
  }

  /// 0.0 … 1.0
  double get progressFraction {
    final total = distance ?? 0;
    if (total <= 0) return 0;
    final covered = currentLocation.distanceFromOriginKm ?? 0;
    return (covered / total).clamp(0.0, 1.0);
  }

  TrainRouteStop? get nextStop {
    final idx = currentIndex;
    if (idx < 0 || idx >= route.length - 1) return null;
    return route[idx + 1];
  }

  /// Human-friendly running status.
  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'not-started':
        return 'Not Started';
      case 'running':
        return 'Running';
      case 'at-station':
        return 'At Station';
      case 'reached':
      case 'completed':
        return 'Journey Complete';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.isEmpty ? 'Unknown' : status;
    }
  }

  // ── LEGACY GETTERS (backward compat) ──────────────────────────
  /// Alias for [statusLabel] — kept so old UI code compiles.
  String get statusMessage => statusLabel;

  /// Current speed in km/h — aliased from [currentLocation].
  double? get speed => currentLocation.speedKmh;

  /// Current station code — aliased from [currentLocation].
  String get currentStationCode => currentLocation.stationCode;

  /// True if we have enough data to render the map.
  bool get hasMapData => routeGeometry.isNotEmpty || geoStops.isNotEmpty;

  static int _int(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  static double? _dbl(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  static List<LatLng> _decodePolyline(String encoded) {
    final poly = <LatLng>[];
    if (encoded.isEmpty) return poly;
    int index = 0;
    final len = encoded.length;
    int lat = 0;
    int lng = 0;

    try {
      while (index < len) {
        int b;
        int shift = 0;
        int result = 0;
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        final dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lat += dlat;

        shift = 0;
        result = 0;
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        final dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lng += dlng;

        final pLat = lat / 1E5;
        final pLng = lng / 1E5;
        if (pLat.isFinite &&
            pLng.isFinite &&
            pLat >= -90 &&
            pLat <= 90 &&
            pLng >= -180 &&
            pLng <= 180) {
          poly.add(LatLng(pLat, pLng));
        }
      }
    } catch (_) {}
    return poly;
  }

  static LatLng? _parseLatLng(dynamic value) {
    double? lat;
    double? lng;
    if (value is Map) {
      lat = _dbl(value['lat'] ?? value['latitude']);
      lng = _dbl(value['lng'] ?? value['lon'] ?? value['longitude']);
      if (lat == null || lng == null) {
        final coordinates = value['coordinates'];
        if (coordinates is List && coordinates.length >= 2) {
          lng = _dbl(coordinates[0]);
          lat = _dbl(coordinates[1]);
        }
      }
    } else if (value is List && value.length >= 2) {
      lng = _dbl(value[0]);
      lat = _dbl(value[1]);
    }

    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180) {
      return null;
    }
    return LatLng(lat, lng);
  }
}

// ═════════════════════════════════════════════════════════════════════
// SOURCE / DESTINATION / NEXT-HALT / GEO-STOP REFERENCE
// ═════════════════════════════════════════════════════════════════════
class TrainStopRef {
  final String code;
  final String name;
  final int? sequence;
  final double? distance;
  final LatLng? latLng;
  final String? departureTime;
  final String? arrivalTime;

  const TrainStopRef({
    required this.code,
    required this.name,
    this.sequence,
    this.distance,
    this.latLng,
    this.departureTime,
    this.arrivalTime,
  });

  bool get hasCoords => latLng != null;
}

// ═════════════════════════════════════════════════════════════════════
// LIVE LOCATION (from currentLocation block)
// ═════════════════════════════════════════════════════════════════════
class LiveLocation {
  final String stationCode;
  final String stationName;
  final int sequence;
  final String status; // "at-station" | "running" | "upcoming"
  final bool isHalt;
  final double? distanceFromOriginKm;
  final double? distanceFromLastStationKm;
  final double? segmentProgress;
  final double? speedKmh;
  final int delayMinutes;
  final LatLng? latLng;
  final bool hasGpsCoordinates;

  const LiveLocation({
    this.stationCode = '',
    this.stationName = '',
    this.sequence = 0,
    this.status = '',
    this.isHalt = false,
    this.distanceFromOriginKm,
    this.distanceFromLastStationKm,
    this.segmentProgress,
    this.speedKmh,
    this.delayMinutes = 0,
    this.latLng,
    this.hasGpsCoordinates = false,
  });
}

// ═════════════════════════════════════════════════════════════════════
// ROUTE STOP
// ═════════════════════════════════════════════════════════════════════
class TrainRouteStop {
  final int sequence;
  final String stationCode;
  final String stationName;
  final bool isHalt;
  final String status; // "at-station" | "upcoming" | "departed"
  final String? coachPosition;

  final DateTime? scheduledArrival;
  final DateTime? scheduledDeparture;
  final DateTime? actualArrival;
  final DateTime? actualDeparture;

  final int arrivalDay;
  final int departureDay;
  final int delayArrival;
  final int delayDeparture;

  final String? platform;
  final double distance;
  final double? speedToNextStationKmph;
  final String? provenance; // "predicted" | "actual"

  int get delayArrivalMinutes => delayArrival;

  const TrainRouteStop({
    required this.sequence,
    required this.stationCode,
    required this.stationName,
    required this.isHalt,
    this.status = 'upcoming',
    this.coachPosition,
    this.scheduledArrival,
    this.scheduledDeparture,
    this.actualArrival,
    this.actualDeparture,
    this.arrivalDay = 1,
    this.departureDay = 1,
    this.delayArrival = 0,
    this.delayDeparture = 0,
    this.platform,
    this.distance = 0,
    this.speedToNextStationKmph,
    this.provenance,
  });

  // ── NTES factory ──────────────────────────────────────────────
  factory TrainRouteStop.fromNtes(Map<String, dynamic> j, int fallbackSeq) {
    return TrainRouteStop(
      sequence: _int(j['seq'] ?? j['sequence'], fallbackSeq),
      stationCode: (j['stationCode'] ?? j['code'] ?? '').toString(),
      stationName: (j['stationName'] ?? j['name'] ?? '').toString(),
      isHalt: (j['halt'] ?? j['isHalt']) == true,
      scheduledArrival: _dt(j['scheduledArrival'] ?? j['arrivalTime'] ?? j['sta']),
      scheduledDeparture: _dt(j['scheduledDeparture'] ?? j['departureTime'] ?? j['std']),
      actualArrival: _dt(j['actualArrival'] ?? j['actArr']),
      actualDeparture: _dt(j['actualDeparture'] ?? j['actDep']),
      distance: _dbl(j['distance']) ?? 0,
      arrivalDay: _int(j['dayCount'] ?? j['day'], 1),
      departureDay: _int(j['departureDay'] ?? j['day'], 1),
      platform: j['platform']?.toString(),
      delayArrival: _int(j['delayArrival'] ?? j['delay']),
      delayDeparture: _int(j['delayDeparture'] ?? j['delay']),
    );
  }

  // ── RailRadar factory ─────────────────────────────────────────
  factory TrainRouteStop.fromRailRadar(
    Map<String, dynamic> j,
    int fallbackSeq,
  ) {
    final stn = j['station'] is Map
        ? Map<String, dynamic>.from(j['station'] as Map)
        : null;
    final code = stn != null
        ? (stn['code'] ?? stn['stationCode'] ?? '').toString()
        : (j['stationCode'] ?? j['code'] ?? '').toString();
    final name = stn != null
        ? (stn['name'] ?? stn['stationName'] ?? '').toString()
        : (j['stationName'] ?? j['name'] ?? '').toString();

    return TrainRouteStop(
      sequence: _int(j['sequence'], fallbackSeq),
      stationCode: code,
      stationName: name,
      isHalt: j['isHalt'] == true,
      status: j['status']?.toString() ?? 'upcoming',
      coachPosition: j['coachPosition']?.toString(),
      scheduledArrival: _dt(j['scheduledArrival'] ?? j['arrivalTime'] ?? j['arrival'] ?? j['sta']),
      scheduledDeparture: _dt(j['scheduledDeparture'] ?? j['departureTime'] ?? j['departure'] ?? j['std']),
      actualArrival: _dt(j['actualArrival'] ?? j['actArr']),
      actualDeparture: _dt(j['actualDeparture'] ?? j['actDep']),
      arrivalDay: _int(j['arrivalDay'], 1),
      departureDay: _int(j['departureDay'], 1),
      delayArrival: _int(j['delayArrival'] ?? j['delay']),
      delayDeparture: _int(j['delayDeparture'] ?? j['delay']),
      platform: j['platform']?.toString(),
      distance: _dbl(j['distance']) ?? 0,
      speedToNextStationKmph: _dbl(j['speedToNextStationKmph']),
      provenance: j['provenance']?.toString(),
    );
  }

  // ── Legacy getters (kept for backward compatibility) ──────────
  /// Scheduled arrival in 12-hour IST format or null.
  String? get arrival => _fmtTime(scheduledArrival);

  /// Scheduled departure in 12-hour IST format or null.
  String? get departure => _fmtTime(scheduledDeparture);

  /// Actual arrival in 12-hour IST format or null.
  String? get actualArrivalTime => _fmtTime(actualArrival);

  /// Actual departure in 12-hour IST format or null.
  String? get actualDepartureTime => _fmtTime(actualDeparture);

  /// Convenience alias for arrivalDay.
  int get day => arrivalDay;

  /// Convenience alias — non-null only when the stop is delayed.
  int? get delayMinutes => (delayArrival > 0 || delayDeparture > 0)
      ? (delayArrival > delayDeparture ? delayArrival : delayDeparture)
      : null;

  bool get isDeparted => status == 'departed';
  bool get isCurrent => status == 'at-station';
  bool get isUpcoming => status == 'upcoming';

  bool get isDelayed => delayArrival > 0 || delayDeparture > 0;

  /// Which time to show — actual if available, else scheduled.
  DateTime? get effectiveArrival => actualArrival ?? scheduledArrival;
  DateTime? get effectiveDeparture => actualDeparture ?? scheduledDeparture;

  // ── Helpers ───────────────────────────────────────────────────
  static String? formatHm(DateTime? d) => _fmtTime(d);

  /// Format a DateTime to 12-hour time in IST.
  static String? _fmtTime(DateTime? d) {
    if (d == null) return null;
    // Normalise to UTC then shift to IST (+5:30)
    final ist = d.toUtc().add(const Duration(hours: 5, minutes: 30));
    final hour = ist.hour % 12 == 0 ? 12 : ist.hour % 12;
    final period = ist.hour < 12 ? 'AM' : 'PM';
    return '$hour:${ist.minute.toString().padLeft(2, '0')} $period';
  }

  static int _int(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  static double? _dbl(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}
