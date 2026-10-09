import 'package:flutter_test/flutter_test.dart';
import 'package:transit_go/data/models/fare.dart';

void main() {
  group('TrainFareData.fromNtes', () {
    test('parses formatted amounts and preserves real zero charges', () {
      final fare = TrainFareData.fromNtes(
        {
          'totalFare': '₹ 1,234',
          'baseFare': '₹ 980',
          'reservationCharge': '₹ 0',
          'source': 'mntes',
        },
        '12919',
        'INDB',
        'SVDK',
        '02-10-2026',
        '3A',
        requestedQuota: 'TQ',
      );

      expect(fare.totalFare, 1234);
      expect(fare.baseFare, 980);
      expect(fare.reservationCharge, 0);
      expect(fare.serviceTax, isNull);
      expect(fare.quota, 'TQ');
      expect(fare.hasBreakdown, isTrue);
    });

    test('keeps missing charge categories unavailable, not zero', () {
      final fare = TrainFareData.fromNtes(
        {'totalFare': 800, 'baseFare': 800},
        '12919',
        'INDB',
        'SVDK',
        '02-10-2026',
        'SL',
      );

      expect(fare.totalFare, 800);
      expect(fare.reservationCharge, isNull);
      expect(fare.superfastCharge, isNull);
      expect(fare.serviceTax, isNull);
      expect(fare.hasBreakdown, isFalse);
    });
  });
}
