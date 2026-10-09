import 'package:flutter_test/flutter_test.dart';
import 'package:transit_go/data/sources/api_router.dart';

void main() {
  group('ApiRouter rate limits', () {
    test('treats HTTP 429 as a short rate-limit cooldown', () {
      ApiRouter.inspectRailRadarResult(429);

      expect(ApiRouter.railRadarPauseReason, 'rate limited');
      expect(ApiRouter.railRadarRetryDelay, isNotNull);
      expect(ApiRouter.railRadarRetryDelay!.inSeconds, inInclusiveRange(1, 60));

      ApiRouter.inspectRailRadarResult(200);
      expect(ApiRouter.railRadarRetryDelay, isNull);
    });

    test('honors Retry-After while capping excessive cooldowns', () {
      ApiRouter.inspectRailRadarResult(
        429,
        retryAfter: const Duration(minutes: 5),
      );

      expect(ApiRouter.railRadarRetryDelay!.inMinutes, inInclusiveRange(4, 5));
      expect(ApiRouter.railRadarPauseReason, 'rate limited');

      ApiRouter.inspectRailRadarResult(
        429,
        retryAfter: const Duration(days: 2),
      );
      expect(ApiRouter.railRadarRetryDelay!.inHours, lessThanOrEqualTo(1));

      ApiRouter.inspectRailRadarResult(200);
    });

    test('only treats 429 as monthly exhaustion when the body says quota', () {
      ApiRouter.inspectRailRadarResult(
        429,
        responseBody: 'Monthly credits exhausted',
      );

      expect(ApiRouter.railRadarPauseReason, contains('quota'));
      expect(ApiRouter.railRadarRetryDelay!.inDays, greaterThan(1));

      ApiRouter.inspectRailRadarResult(200);
    });
  });
}
