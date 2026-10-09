class StationTraffic {
  final String stationCode;
  final String stationName;
  final int hoursAhead;
  final List<TrainMovement> movements;
  final DateTime? generatedAt;

  /// Live board window (RailRadar provides this).
  final String? windowFrom; // "07:54"
  final String? windowTo; // "15:54"
  final int? hoursBack; // 4
  final int? serverCount; // total count reported by API

  StationTraffic({
    required this.stationCode,
    required this.stationName,
    required this.hoursAhead,
    required this.movements,
    this.generatedAt,
    this.windowFrom,
    this.windowTo,
    this.hoursBack,
    this.serverCount,
  });

  // ── Shared key-picking helper ──────────────────────────────────
  static dynamic pick(Map m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      if (v is String && v.trim().isEmpty) continue;
      return v;
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // NTES PARSER (legacy)
  // ═══════════════════════════════════════════════════════════════════
  factory StationTraffic.fromNtes(
    Map<String, dynamic> data,
    String code,
    int hours,
  ) {
    final raw =
        (data['trainList'] ??
                data['trains'] ??
                data['movements'] ??
                data['data'] ??
                [])
            as List?;

    final list = <TrainMovement>[];
    if (raw != null) {
      for (final item in raw) {
        if (item is! Map) continue;
        list.add(TrainMovement.parse(Map<String, dynamic>.from(item)));
      }
    }

    return StationTraffic(
      stationCode: (pick(data, ['stationCode', 'code', 'stnCode']) ?? code)
          .toString(),
      stationName: (pick(data, ['stationName', 'name', 'stnName']) ?? code)
          .toString(),
      hoursAhead: _int(pick(data, ['hours', 'hoursAhead'])) ?? hours,
      movements: list,
      generatedAt: _dt(pick(data, ['generatedAt', 'updatedAt', 'timestamp'])),
      serverCount: _intOrNull(pick(data, ['count'])),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // RAILRADAR PARSER
  // Handles both /stations/{code}/live and /stations/{code}/trains
  // ═══════════════════════════════════════════════════════════════════
  factory StationTraffic.fromRailRadar(
    Map<String, dynamic> data,
    String code,
    int hours,
  ) {
    final stationMap = data['station'] is Map
        ? Map<String, dynamic>.from(data['station'] as Map)
        : (data['stationInfo'] is Map
              ? Map<String, dynamic>.from(data['stationInfo'] as Map)
              : const <String, dynamic>{});

    final windowMap = data['window'] is Map
        ? Map<String, dynamic>.from(data['window'] as Map)
        : const <String, dynamic>{};

    final raw =
        (data['trains'] ??
                data['trainList'] ??
                data['movements'] ??
                data['departures'] ??
                data['arrivals'] ??
                data['data'] ??
                [])
            as List?;

    final list = <TrainMovement>[];
    if (raw != null) {
      for (final item in raw) {
        if (item is! Map) continue;
        list.add(TrainMovement.parse(Map<String, dynamic>.from(item)));
      }
    }

    return StationTraffic(
      stationCode:
          (pick(stationMap, ['code', 'stationCode', 'stnCode']) ??
                  pick(data, ['stationCode', 'code']) ??
                  code)
              .toString(),
      stationName:
          (pick(stationMap, ['name', 'stationName', 'stnName']) ??
                  pick(data, ['stationName', 'name']) ??
                  code)
              .toString(),
      hoursAhead:
          _int(pick(windowMap, ['hoursAhead'])) ??
          _int(pick(data, ['hours', 'hoursAhead'])) ??
          hours,
      movements: list,
      generatedAt: _dt(
        pick(data, ['generatedAt', 'updatedAt', 'timestamp', 'lastUpdated']),
      ),
      windowFrom: windowMap['from']?.toString(),
      windowTo: windowMap['to']?.toString(),
      hoursBack: _intOrNull(windowMap['hoursBack']),
      serverCount: _intOrNull(data['count']),
    );
  }

  /// Auto-detect.
  factory StationTraffic.parse(
    Map<String, dynamic> data,
    String code,
    int hours,
  ) {
    if (data['station'] is Map ||
        data['stationInfo'] is Map ||
        data['window'] is Map ||
        data['generatedAt'] != null ||
        data['departures'] != null ||
        data['arrivals'] != null) {
      return StationTraffic.fromRailRadar(data, code, hours);
    }
    return StationTraffic.fromNtes(data, code, hours);
  }

  static int? _int(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static int? _intOrNull(dynamic v) => _int(v);

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    return DateTime.tryParse(v.toString());
  }

  List<TrainMovement> get delayed =>
      movements.where((m) => m.delayMinutes > 0).toList();
  List<TrainMovement> get onTime =>
      movements.where((m) => m.delayMinutes <= 0).toList();

  /// Live arrivals (from the server's perspective) — trains arriving.
  List<TrainMovement> get arrivals =>
      movements.where((m) => m.arrival != null && m.arrival != '--').toList();

  /// Live departures — trains departing.
  List<TrainMovement> get departures => movements
      .where((m) => m.departure != null && m.departure != '--')
      .toList();

  int get totalCount => serverCount ?? movements.length;

  @override
  String toString() =>
      'StationTraffic($stationCode, ${movements.length} trains)';
}

// ═════════════════════════════════════════════════════════════════════
// TRAIN MOVEMENT — defensive parser
// ═════════════════════════════════════════════════════════════════════
class TrainMovement {
  final String trainNumber;
  final String trainName;
  final String source;
  final String destination;
  final String? arrival;
  final String? departure;
  final String? platform;
  final int delayMinutes;
  final String? trainType;
  final String? status; // "at-station" | "running" | "upcoming"
  final String? expectedArrival; // ISO or HH:mm
  final String? expectedDeparture;
  final int? day;

  // ── NEW fields from RailRadar's /trains + /live ─────────────────
  final List<String> runDays; // ['mon','tue',...]
  final String? stopType; // "origin" | "destination" | "intermediate"
  final int? sequence;
  final double? distance;
  final int? arrivalDay;
  final int? departureDay;

  String get origin => source;
  String get number => trainNumber;
  String get name => trainName;

  TrainMovement({
    required this.trainNumber,
    required this.trainName,
    required this.source,
    required this.destination,
    this.arrival,
    this.departure,
    this.platform,
    required this.delayMinutes,
    this.trainType,
    this.status,
    this.expectedArrival,
    this.expectedDeparture,
    this.day,
    this.runDays = const [],
    this.stopType,
    this.sequence,
    this.distance,
    this.arrivalDay,
    this.departureDay,
  });

  static int _int(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  static int? _intOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double? _dbl(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  // ═══════════════════════════════════════════════════════════════════
  // THE ONLY PUBLIC PARSER — auto-detects and handles nulls
  // ═══════════════════════════════════════════════════════════════════
  factory TrainMovement.parse(Map<String, dynamic> json) {
    final trainMap = json['train'] is Map
        ? Map<String, dynamic>.from(json['train'] as Map)
        : const <String, dynamic>{};

    final stopMap = json['stop'] is Map
        ? Map<String, dynamic>.from(json['stop'] as Map)
        : (json['radar'] is Map
              ? Map<String, dynamic>.from(json['radar'] as Map)
              : (json['timing'] is Map
                    ? Map<String, dynamic>.from(json['timing'] as Map)
                    : const <String, dynamic>{}));

    final liveMap = json['live'] is Map
        ? Map<String, dynamic>.from(json['live'] as Map)
        : (json['realtime'] is Map
              ? Map<String, dynamic>.from(json['realtime'] as Map)
              : (json['realTime'] is Map
                    ? Map<String, dynamic>.from(json['realTime'] as Map)
                    : const <String, dynamic>{}));

    final srcMap = json['source'] is Map
        ? Map<String, dynamic>.from(json['source'] as Map)
        : (trainMap['source'] is Map
              ? Map<String, dynamic>.from(trainMap['source'] as Map)
              : const <String, dynamic>{});

    final dstMap = json['destination'] is Map
        ? Map<String, dynamic>.from(json['destination'] as Map)
        : (trainMap['destination'] is Map
              ? Map<String, dynamic>.from(trainMap['destination'] as Map)
              : const <String, dynamic>{});

    dynamic find(List<String> keys) {
      for (final layer in [json, trainMap, stopMap, liveMap]) {
        final v = StationTraffic.pick(layer, keys);
        if (v != null) return v;
      }
      return null;
    }

    // ── Train number / name ───────────────────────────────────────
    final number =
        (find([
                  'trainNumber',
                  'number',
                  'trainNo',
                  'train_no',
                  'no',
                  'trainNumberCode',
                ]) ??
                '')
            .toString();

    final name =
        (find(['trainName', 'name', 'train_name', 'trainFullName']) ?? '')
            .toString();

    // ── Source / destination ──────────────────────────────────────
    String src;
    if (srcMap.isNotEmpty) {
      src = (StationTraffic.pick(srcMap, ['name', 'stationName', 'code']) ?? '')
          .toString();
    } else {
      src =
          (find([
                    'source',
                    'from',
                    'fromStation',
                    'fromStationName',
                    'sourceStation',
                    'sourceName',
                    'origin',
                  ]) ??
                  '')
              .toString();
    }

    String dst;
    if (dstMap.isNotEmpty) {
      dst = (StationTraffic.pick(dstMap, ['name', 'stationName', 'code']) ?? '')
          .toString();
    } else {
      dst =
          (find([
                    'destination',
                    'to',
                    'toStation',
                    'toStationName',
                    'destinationStation',
                    'destinationName',
                    'dest',
                  ]) ??
                  '')
              .toString();
    }

    // ── Arrival / departure (can be null for origin/destination) ──
    final arrRaw = find([
      'arrival',
      'arrivalTime',
      'sta',
      'scheduledArrival',
      'schArrival',
      'eta',
      'scheduled_arrival',
    ]);
    final depRaw = find([
      'departure',
      'departureTime',
      'std',
      'scheduledDeparture',
      'schDeparture',
      'etd',
      'scheduled_departure',
    ]);

    // ── Platform ──────────────────────────────────────────────────
    final pf = find([
      'platform',
      'pf',
      'platformNumber',
      'platformNo',
    ])?.toString();

    // ── Delay ────────────────────────────────────────────────────
    final delay = _int(
      find(['delayMinutes', 'delay', 'delayMin', 'lateBy', 'late']),
    );

    // ── Run days ─────────────────────────────────────────────────
    final rawDays = trainMap['runDays'];
    final runDays = rawDays is List
        ? rawDays.map((e) => e.toString()).toList()
        : <String>[];

    // ── Live type ────────────────────────────────────────────────
    final liveStatus =
        liveMap['type']?.toString() ??
        find(['status', 'runningStatus'])?.toString();

    // ── Expected times (parse out HH:mm from ISO) ─────────────────
    final expDep = _extractHm(liveMap['expectedDepartureTime']);
    final expArr = _extractHm(liveMap['expectedArrivalTime']);

    return TrainMovement(
      trainNumber: number,
      trainName: name,
      source: src,
      destination: dst,
      arrival: _hm(arrRaw),
      departure: _hm(depRaw),
      platform: pf,
      delayMinutes: delay,
      trainType:
          trainMap['type']?.toString() ??
          find(['trainType', 'type'])?.toString(),
      status: liveStatus,
      expectedArrival: expArr,
      expectedDeparture: expDep,
      day: _intOrNull(find(['day', 'dayCount', 'dayNo'])),
      runDays: runDays,
      stopType: stopMap['stopType']?.toString(),
      sequence: _intOrNull(stopMap['sequence']),
      distance: _dbl(stopMap['distance']),
      arrivalDay: _intOrNull(stopMap['arrivalDay']),
      departureDay: _intOrNull(stopMap['departureDay']),
    );
  }

  /// Extract HH:mm from ISO-8601 or "HH:mm:ss" strings, normalizing
  /// timestamps to IST before returning the time.
  static String? _extractHm(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString();
    if (s.isEmpty) return null;
    final timestamp = DateTime.tryParse(s);
    if (timestamp != null && s.contains('T')) {
      final ist = timestamp.toUtc().add(const Duration(hours: 5, minutes: 30));
      return '${ist.hour.toString().padLeft(2, '0')}:'
          '${ist.minute.toString().padLeft(2, '0')}';
    }
    final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(s);
    if (m == null) return null;
    return '${m.group(1)!.padLeft(2, '0')}:${m.group(2)}';
  }

  /// "14:35", "14:35:00", "2026-06-22T23:55:00+05:30" → "23:55"
  /// Returns null if raw is null/empty/"--" so the UI can show "—".
  static String? _hm(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString();
    if (s.isEmpty || s == '--') return null;
    return _extractHm(raw) ?? s;
  }

  bool get isDelayed => delayMinutes > 0;
  bool get isOrigin => stopType == 'origin' || sequence == 1;
  bool get isDestination => stopType == 'destination';
  bool get hasArrival => arrival != null;
  bool get hasDeparture => departure != null;

  /// Live at-station / running / upcoming
  bool get isAtStation => status == 'at-station';
  bool get isRunning => status == 'running';

  @override
  String toString() =>
      'TrainMovement($trainNumber, ${arrival ?? '--'}→${departure ?? '--'}, +${delayMinutes}m)';
}
