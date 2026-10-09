class TrainFareData {
  final String trainNumber;
  final String trainName;
  final String source;
  final String destination;
  final String journeyDate;
  final String classCode;
  final int totalFare;
  final int baseFare;
  final int? distanceKm;
  final String? fareSource;

  /// Itemized charges breakdown fields
  final int? reservationCharge;
  final int? superfastCharge;
  final int? cateringCharge;
  final int? serviceTax;
  final int? tatkalCharge;
  final int? otherCharges;
  final int? dynamicFare;
  final int? fuelAmount;
  final int? totalConcession;
  final int? wpServiceTax;
  final String? quota;
  final String? generatedAt;

  TrainFareData({
    required this.trainNumber,
    this.trainName = '',
    required this.source,
    required this.destination,
    required this.journeyDate,
    required this.classCode,
    required this.totalFare,
    required this.baseFare,
    this.distanceKm,
    this.fareSource,
    this.reservationCharge,
    this.superfastCharge,
    this.cateringCharge,
    this.serviceTax,
    this.tatkalCharge,
    this.otherCharges,
    this.dynamicFare,
    this.fuelAmount,
    this.totalConcession,
    this.wpServiceTax,
    this.quota,
    this.generatedAt,
  });

  static int _int(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is num) return v.toInt();
    final normalized = v.toString().replaceAll(RegExp(r'[^\d.-]'), '');
    return num.tryParse(normalized)?.round() ?? fallback;
  }

  static int? _intOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    final text = v.toString().trim();
    if (text.isEmpty || text == '--') return null;
    final normalized = text.replaceAll(RegExp(r'[^\d.-]'), '');
    return num.tryParse(normalized)?.round();
  }

  // ═══════════════════════════════════════════════════════════════════
  // NTES PARSER (legacy)
  // ═══════════════════════════════════════════════════════════════════
  factory TrainFareData.fromNtes(
    Map<String, dynamic> data,
    String train,
    String src,
    String dst,
    String date,
    String cls, {
    String? requestedQuota,
  }) {
    final total = _int(data['totalFare']) != 0
        ? _int(data['totalFare'])
        : _int(data['fare']);

    return TrainFareData(
      trainNumber: train,
      trainName: (data['trainName'] ?? '').toString(),
      source: src,
      destination: dst,
      journeyDate: date,
      classCode: cls,
      totalFare: total,
      baseFare: _int(data['baseFare'], total),
      distanceKm: _intOrNull(data['distance']),
      reservationCharge: _intOrNull(
        data['reservationCharge'] ?? data['reservation'],
      ),
      superfastCharge: _intOrNull(
        data['superfastCharge'] ?? data['superFastCharge'],
      ),
      cateringCharge: _intOrNull(data['cateringCharge'] ?? data['catering']),
      serviceTax: _intOrNull(data['serviceTax'] ?? data['goodsServiceTax'] ?? data['gst'] ?? data['tax']),
      tatkalCharge: _intOrNull(data['tatkalFare'] ?? data['tatkalCharge'] ?? data['tatkalSurcharge']),
      otherCharges: _intOrNull(
        data['otherCharge'] ?? data['otherCharges'] ?? data['miscellaneousCharges'],
      ),
      dynamicFare: _intOrNull(data['dynamicFare']),
      quota: data['quota']?.toString() ?? requestedQuota,
      fareSource: data['fareSource']?.toString() ?? data['source']?.toString(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // RAILRADAR PARSER
  // ═══════════════════════════════════════════════════════════════════
  factory TrainFareData.fromRailRadar(
    Map<String, dynamic> data, {
    required String train,
    required String from,
    required String to,
    required String date,
    required String classCode,
  }) {
    final bd = data['breakdown'] is Map
        ? Map<String, dynamic>.from(data['breakdown'] as Map)
        : (data['fare'] is Map
            ? Map<String, dynamic>.from(data['fare'] as Map)
            : data);

    final fromMap = data['from'] is Map
        ? Map<String, dynamic>.from(data['from'] as Map)
        : const {};
    final toMap = data['to'] is Map
        ? Map<String, dynamic>.from(data['to'] as Map)
        : const {};

    final total = _int(bd['totalFare']) != 0
        ? _int(bd['totalFare'])
        : (_int(bd['total']) != 0
            ? _int(bd['total'])
            : _int(bd['amount']));

    final base = _int(bd['baseFare']) != 0
        ? _int(bd['baseFare'])
        : (_int(bd['base']) != 0 ? _int(bd['base']) : total);

    return TrainFareData(
      trainNumber: (data['trainNumber'] ?? train).toString(),
      trainName: (data['trainName'] ?? '').toString(),
      source: fromMap['code']?.toString() ?? from,
      destination: toMap['code']?.toString() ?? to,
      journeyDate: data['journeyDate']?.toString() ?? date,
      classCode: (data['classCode'] ?? data['class'] ?? classCode).toString().toUpperCase(),
      totalFare: total,
      baseFare: base,
      distanceKm: _intOrNull(data['distance']),
      reservationCharge: _intOrNull(bd['reservationCharge'] ?? bd['reservation']),
      superfastCharge: _intOrNull(bd['superfastCharge'] ?? bd['superFastCharge']),
      cateringCharge: _intOrNull(bd['cateringCharge'] ?? bd['catering']),
      serviceTax: _intOrNull(bd['goodsServiceTax'] ?? bd['serviceTax'] ?? bd['gst'] ?? bd['tax']),
      tatkalCharge: _intOrNull(bd['tatkalFare'] ?? bd['tatkalCharge'] ?? bd['tatkalSurcharge']),
      otherCharges: _intOrNull(bd['otherCharge'] ?? bd['otherCharges'] ?? bd['miscellaneousCharges']),
      dynamicFare: _intOrNull(bd['dynamicFare']),
      fuelAmount: _intOrNull(bd['fuelAmount']),
      totalConcession: _intOrNull(bd['totalConcession']),
      wpServiceTax: _intOrNull(bd['wpServiceTax']),
      quota: data['quotaCode']?.toString() ?? data['quota']?.toString(),
      fareSource: data['fareSource']?.toString() ?? data['source']?.toString(),
      generatedAt: data['generatedAt']?.toString(),
    );
  }

  /// Auto-detect
  factory TrainFareData.parse(
    Map<String, dynamic> data, {
    required String train,
    required String from,
    required String to,
    required String date,
    required String classCode,
  }) {
    if (data['breakdown'] is Map ||
        data['fare'] is Map ||
        data['from'] is Map ||
        data['totalFare'] != null) {
      return TrainFareData.fromRailRadar(
        data,
        train: train,
        from: from,
        to: to,
        date: date,
        classCode: classCode,
      );
    }
    return TrainFareData.fromNtes(data, train, from, to, date, classCode);
  }

  bool get hasBreakdown =>
      reservationCharge != null ||
      superfastCharge != null ||
      cateringCharge != null ||
      serviceTax != null ||
      tatkalCharge != null ||
      otherCharges != null ||
      dynamicFare != null ||
      fuelAmount != null ||
      totalConcession != null;

  @override
  String toString() => 'TrainFareData($trainNumber, $classCode, ₹$totalFare)';
}
