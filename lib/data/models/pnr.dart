class PnrData {
  final String pnrNumber;
  final String trainNumber;
  final String trainName;
  final String journeyDate;
  final String source;
  final String destination;
  final String journeyClass;
  final String chartingStatus;
  final List<PnrPassenger> passengers;

  /// Optional metadata.
  final String? boardingStation;
  final String? reservationUpto;
  final String? fromCode;
  final String? toCode;
  final String? trainType;
  final DateTime? expectedDeparture;

  PnrData({
    required this.pnrNumber,
    required this.trainNumber,
    required this.trainName,
    required this.journeyDate,
    required this.source,
    required this.destination,
    required this.journeyClass,
    required this.chartingStatus,
    required this.passengers,
    this.boardingStation,
    this.reservationUpto,
    this.fromCode,
    this.toCode,
    this.trainType,
    this.expectedDeparture,
  });

  // ═══════════════════════════════════════════════════════════════════
  // NTES PARSER (legacy)
  // ═══════════════════════════════════════════════════════════════════
  factory PnrData.fromNtes(Map<String, dynamic> data, String pnr) {
    final raw =
    (data['passengerStatus'] ?? data['passengers'] ?? []) as List?;
    final list = <PnrPassenger>[];
    for (var i = 0; i < (raw?.length ?? 0); i++) {
      if (raw![i] is! Map) continue;
      list.add(PnrPassenger.fromJson(
        Map<String, dynamic>.from(raw[i] as Map),
        i + 1,
      ));
    }

    return PnrData(
      pnrNumber: pnr,
      trainNumber: data['trainNumber']?.toString() ?? '',
      trainName: data['trainName']?.toString() ?? '',
      journeyDate: data['doj']?.toString() ?? '',
      source: data['boardingStation']?.toString() ?? '',
      destination: data['reservationUpto']?.toString() ?? '',
      journeyClass: data['journeyClass']?.toString() ?? '',
      chartingStatus: data['chartStatus']?.toString() ?? '',
      passengers: list,
      boardingStation: data['boardingStation']?.toString(),
      reservationUpto: data['reservationUpto']?.toString(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // RAILRADAR PARSER
  //
  // Handles shapes like:
  //   {
  //     "train":      { number, name, type },
  //     "journey":    { date, class },
  //     "from":       { code, name },
  //     "to":         { code, name },
  //     "boarding":   { code, name, time },
  //     "chartStatus": "Chart Prepared",
  //     "passengers": [ ... ]
  //   }
  // ═══════════════════════════════════════════════════════════════════
  factory PnrData.fromRailRadar(Map<String, dynamic> data, String pnr) {
    final trainMap =
    data['train'] is Map ? Map<String, dynamic>.from(data['train'] as Map) : const {};
    final journeyMap = data['journey'] is Map
        ? Map<String, dynamic>.from(data['journey'] as Map)
        : const {};
    final fromMap =
    data['from'] is Map ? Map<String, dynamic>.from(data['from'] as Map) : const {};
    final toMap =
    data['to'] is Map ? Map<String, dynamic>.from(data['to'] as Map) : const {};
    final boardMap = data['boarding'] is Map
        ? Map<String, dynamic>.from(data['boarding'] as Map)
        : const {};

    final raw =
    (data['passengers'] ?? data['passengerStatus'] ?? []) as List?;
    final list = <PnrPassenger>[];
    for (var i = 0; i < (raw?.length ?? 0); i++) {
      if (raw![i] is! Map) continue;
      list.add(PnrPassenger.fromJson(
        Map<String, dynamic>.from(raw[i] as Map),
        i + 1,
      ));
    }

    return PnrData(
      pnrNumber: data['pnr']?.toString() ?? pnr,
      trainNumber:
      (trainMap['number'] ?? data['trainNumber'] ?? '').toString(),
      trainName:
      (trainMap['name'] ?? data['trainName'] ?? '').toString(),
      journeyDate:
      (journeyMap['date'] ?? data['journeyDate'] ?? '').toString(),
      source: (fromMap['code'] ?? data['source'] ?? '').toString(),
      destination: (toMap['code'] ?? data['destination'] ?? '').toString(),
      journeyClass:
      (journeyMap['class'] ?? data['class'] ?? '').toString(),
      chartingStatus: (data['chartStatus'] ??
          data['chartingStatus'] ??
          data['chart'] ??
          '')
          .toString(),
      passengers: list,
      boardingStation: boardMap['code']?.toString() ??
          data['boardingStation']?.toString(),
      reservationUpto: data['reservationUpto']?.toString(),
      fromCode: fromMap['code']?.toString(),
      toCode: toMap['code']?.toString(),
      trainType: trainMap['type']?.toString(),
    );
  }

  /// Auto-detect.
  factory PnrData.parse(Map<String, dynamic> data, String pnr) {
    if (data['train'] is Map ||
        data['journey'] is Map ||
        data['from'] is Map ||
        data['to'] is Map) {
      return PnrData.fromRailRadar(data, pnr);
    }
    return PnrData.fromNtes(data, pnr);
  }

  /// True if any passenger is still waitlisted / RAC.
  bool get hasPending =>
      passengers.any((p) => !p.isConfirmed && !p.isCancelled);

  int get confirmedCount =>
      passengers.where((p) => p.isConfirmed).length;

  @override
  String toString() => 'PnrData($pnrNumber, $trainNumber)';
}

class PnrPassenger {
  final int serialNumber;
  final String bookingStatus;
  final String currentStatus;
  final bool isConfirmed;
  final bool isWaitlisted;
  final bool isCancelled;
  final bool isRac;
  final String? coach;
  final String? berthNo;
  final String? berthType; // LB / MB / UB / SL / SU / …

  PnrPassenger({
    required this.serialNumber,
    required this.bookingStatus,
    required this.currentStatus,
    required this.isConfirmed,
    required this.isWaitlisted,
    this.isCancelled = false,
    this.isRac = false,
    this.coach,
    this.berthNo,
    this.berthType,
  });

  factory PnrPassenger.fromJson(Map<String, dynamic> json, int serial) {
    final booking = (json['bookingStatus'] ??
        json['booking'] ??
        json['status'] ??
        '')
        .toString();
    final current = (json['currentStatus'] ??
        json['current'] ??
        json['status'] ??
        booking)
        .toString();

    final up = current.toUpperCase();
    final bookingUp = booking.toUpperCase();

    return PnrPassenger(
      serialNumber: serial,
      bookingStatus: booking,
      currentStatus: current,
      isConfirmed: up.contains('CNF') || up.contains('CONFIRM'),
      isWaitlisted: up.contains('WL') || up.contains('WAIT'),
      isCancelled: up.contains('CAN') || up.contains('CANCEL'),
      isRac: up.contains('RAC'),
      coach: json['coach']?.toString() ??
          json['coachNumber']?.toString(),
      berthNo: json['berth']?.toString() ??
          json['berthNo']?.toString() ??
          json['berthNumber']?.toString(),
      berthType: json['berthType']?.toString() ??
          json['berthCode']?.toString(),
    );
  }

  String get display => currentStatus.isEmpty ? bookingStatus : currentStatus;

  @override
  String toString() => 'PnrPassenger($serialNumber, $currentStatus)';
}