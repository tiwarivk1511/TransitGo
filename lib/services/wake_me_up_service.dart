import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../data/models/train.dart';
import '../screens/train_details/train_details_screen.dart';
import 'train_service.dart';

class WakeMeUpService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final _plugin = FlutterLocalNotificationsPlugin();
  static Timer? _poll;
  static String? _trainNo;
  static String? _trainName;
  static String? _targetCode;
  static String? _targetName;
  static int _aheadMinutes = 15;
  static bool _fired = false;

  static const int _ongoingNotificationId = 8881;
  static const int _alertNotificationId = 8882;

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        if (response.actionId == 'cancel_alarm') {
          cancel();
        } else if (response.payload != null && response.payload!.isNotEmpty) {
          _handleNotificationTap(response.payload!);
        } else if (_trainNo != null) {
          _handleNotificationTap('$_trainNo|${_trainName ?? ""}');
        }
      },
    );
  }

  static void _handleNotificationTap(String payload) {
    final parts = payload.split('|');
    if (parts.isEmpty || parts[0].trim().isEmpty) return;
    final trainNo = parts[0].trim();
    final trainName = parts.length > 1 ? parts[1].trim() : '';

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => TrainDetailsScreen(
          trainNumber: trainNo,
          trainName: trainName,
        ),
      ),
    );
  }

  static void arm({
    required String trainNumber,
    required String targetStationCode,
    required String targetStationName,
    String? trainName,
    int minutesAhead = 15,
  }) {
    _trainNo = trainNumber;
    _trainName = trainName;
    _targetCode = targetStationCode;
    _targetName = targetStationName;
    _aheadMinutes = minutesAhead;
    _fired = false;

    _poll?.cancel();
    _check();

    _poll = Timer.periodic(const Duration(seconds: 40), (_) => _check());
  }

  static void cancel() {
    _poll?.cancel();
    _poll = null;
    _trainNo = null;
    _trainName = null;
    _targetCode = null;
    _targetName = null;
    _fired = false;
    _plugin.cancelAll();
  }

  static bool get isArmed => _trainNo != null && _targetCode != null;
  static String? get trainNumber => _trainNo;
  static String? get targetStationCode => _targetCode;
  static String? get targetStationName => _targetName;
  static int get minutesAhead => _aheadMinutes;

  static Future<void> _check() async {
    if (_trainNo == null || _targetCode == null) return;
    final data = await TrainService.liveTracking(_trainNo!);
    if (data == null) return;

    if (data.trainName.isNotEmpty) _trainName = data.trainName;

    final idxTarget = data.route.indexWhere((s) => s.stationCode == _targetCode);
    final idxCurrent = data.currentIndex;

    if (idxTarget < 0) return;

    final target = data.route[idxTarget];
    final currentStop = (idxCurrent >= 0 && idxCurrent < data.route.length)
        ? data.route[idxCurrent]
        : null;

    final remainingStops = (idxTarget - idxCurrent).clamp(0, 999);

    final etaStr = TrainRouteStop.formatHm(target.effectiveArrival) ?? target.arrival ?? '--';
    final eta = _parseHm(etaStr);

    final now = DateTime.now();
    int leftMinutes = 999;

    if (eta != null) {
      final etaToday = DateTime(now.year, now.month, now.day, eta.hour, eta.minute)
          .add(Duration(minutes: data.delayMinutes));
      leftMinutes = etaToday.difference(now).inMinutes;
    }

    final currentText = currentStop != null ? currentStop.stationName : data.currentLocation.stationName;

    // Destination Reached
    if (idxCurrent >= idxTarget) {
      if (!_fired) {
        _fired = true;
        final cardBytes = await _createAlarmCardImage(
          trainNo: _trainNo!,
          trainName: _trainName ?? 'Express',
          currentStation: currentText,
          targetStationCode: _targetCode!,
          targetStationName: _targetName ?? target.stationName,
          remainingStops: 0,
          leftMinutes: 0,
          etaStr: etaStr,
          isAlert: true,
        );

        await _showAlertNotification(
          title: '🚨 DESTINATION REACHED: ${_targetName ?? target.stationName}',
          summaryText: 'Destination Reached',
          imageBytes: cardBytes,
        );
      }
      cancel();
      return;
    }

    // Generate Ultra-Modern Card Graphic
    final cardBytes = await _createAlarmCardImage(
      trainNo: _trainNo!,
      trainName: _trainName ?? 'Express',
      currentStation: currentText,
      targetStationCode: _targetCode!,
      targetStationName: _targetName ?? target.stationName,
      remainingStops: remainingStops,
      leftMinutes: leftMinutes,
      etaStr: etaStr,
      isAlert: false,
    );

    _showOngoingNotification(
      title: '🔔 Destination Alarm: ${_targetName ?? target.stationName} ($_targetCode)',
      summaryText: '$remainingStops Stops (~${leftMinutes < 900 ? leftMinutes : "--"}m)',
      imageBytes: cardBytes,
    );

    // High-Priority Loud Alert Trigger
    if (leftMinutes <= _aheadMinutes && leftMinutes >= -2 && !_fired) {
      _fired = true;
      final alertBytes = await _createAlarmCardImage(
        trainNo: _trainNo!,
        trainName: _trainName ?? 'Express',
        currentStation: currentText,
        targetStationCode: _targetCode!,
        targetStationName: _targetName ?? target.stationName,
        remainingStops: remainingStops,
        leftMinutes: leftMinutes,
        etaStr: etaStr,
        isAlert: true,
      );

      await _showAlertNotification(
        title: '🚨 WAKE UP! Approaching ${_targetName ?? target.stationName}',
        summaryText: 'Approaching Station in ~$leftMinutes min',
        imageBytes: alertBytes,
      );
    }
  }

  static DateTime? _parseHm(String? s) {
    if (s == null || s.isEmpty) return null;
    final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(s);
    if (m == null) return null;
    return DateTime(2000, 1, 1, int.parse(m.group(1)!), int.parse(m.group(2)!));
  }

  static Future<Uint8List> _createAlarmCardImage({
    required String trainNo,
    required String trainName,
    required String currentStation,
    required String targetStationCode,
    required String targetStationName,
    required int remainingStops,
    required int leftMinutes,
    required String etaStr,
    required bool isAlert,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 800, 380));

    // 1. Dark Glassmorphism Background Gradient
    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(800, 380),
        isAlert
            ? [const Color(0xFF2C0B14), const Color(0xFF160308)]
            : [const Color(0xFF0B132B), const Color(0xFF1C2541)],
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 800, 380), const Radius.circular(24)),
      bgPaint,
    );

    // 2. Neon Border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = isAlert ? const Color(0xFFFF375F) : const Color(0xFF0A84FF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(2, 2, 796, 376), const Radius.circular(22)),
      borderPaint,
    );

    // 3. Header Badge
    final pillPaint = Paint()
      ..color = (isAlert ? const Color(0xFFFF375F) : const Color(0xFF0A84FF)).withValues(alpha: 0.25);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(28, 24, 340, 42), const Radius.circular(12)),
      pillPaint,
    );

    final tpHeader = TextPainter(
      text: TextSpan(
        text: isAlert ? '🚨 WAKE UP! ALARM TRIGGERED' : '🔔 LIVE STATION ALARM ACTIVE',
        style: TextStyle(
          color: isAlert ? const Color(0xFFFF375F) : const Color(0xFF64D2FF),
          fontSize: 15,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tpHeader.layout();
    tpHeader.paint(canvas, const Offset(42, 35));

    // 4. Train Info
    final tpTrain = TextPainter(
      text: TextSpan(
        text: 'Train $trainNo • $trainName',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 25,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tpTrain.layout();
    tpTrain.paint(canvas, const Offset(28, 88));

    // 5. Route Flow Text
    final tpRoute = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Current: ${currentStation.isNotEmpty ? currentStation : "En Route"}  ',
            style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 19),
          ),
          TextSpan(
            text: '➔  ',
            style: TextStyle(
              color: isAlert ? const Color(0xFFFF375F) : const Color(0xFF0A84FF),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: '$targetStationName ($targetStationCode)',
            style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    );
    tpRoute.layout();
    tpRoute.paint(canvas, const Offset(28, 132));

    // 6. Visual Progress Bar
    final lineBgPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(28, 205), const Offset(772, 205), lineBgPaint);

    final lineProgressPaint = Paint()
      ..color = isAlert ? const Color(0xFFFF375F) : const Color(0xFF30D158)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final progressX = remainingStops <= 0
        ? 772.0
        : (772.0 - (remainingStops * 38.0)).clamp(80.0, 750.0);
    canvas.drawLine(const Offset(28, 205), Offset(progressX, 205), lineProgressPaint);

    // Train Node Circle
    final trainNodePaint = Paint()
      ..color = isAlert ? const Color(0xFFFF375F) : const Color(0xFF0A84FF);
    canvas.drawCircle(Offset(progressX, 205), 15, trainNodePaint);
    final trainNodeInner = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(progressX, 205), 7, trainNodeInner);

    // 7. Bottom Stats
    final tpBottom = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Remaining: $remainingStops Stops   |   ETA: $etaStr',
            style: const TextStyle(
              color: Color(0xFF30D158),
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (leftMinutes < 900)
            TextSpan(
              text: '   (~${leftMinutes}m left)',
              style: TextStyle(
                color: isAlert ? const Color(0xFFFF375F) : const Color(0xFFFF9F0A),
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
      textDirection: TextDirection.ltr,
    );
    tpBottom.layout();
    tpBottom.paint(canvas, const Offset(28, 248));

    // 8. Footer Branding
    final tpFooter = TextPainter(
      text: const TextSpan(
        text: 'TRANSITGO LIVE WAKE-UP ALARM SERVICE',
        style: TextStyle(
          color: Color(0xFF5E5CE6),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tpFooter.layout();
    tpFooter.paint(canvas, const Offset(28, 332));

    final picture = recorder.endRecording();
    final img = await picture.toImage(800, 380);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static Future<void> _showOngoingNotification({
    required String title,
    required String summaryText,
    required Uint8List imageBytes,
  }) async {
    final bigPictureStyle = BigPictureStyleInformation(
      ByteArrayAndroidBitmap(imageBytes),
      contentTitle: title,
      htmlFormatContentTitle: false,
      summaryText: summaryText,
      htmlFormatSummaryText: false,
      largeIcon: ByteArrayAndroidBitmap(imageBytes),
    );

    final android = AndroidNotificationDetails(
      'wake_me_up_ongoing',
      'Active Station Alarm (Ongoing)',
      channelDescription: 'Persistent live status notification for station wake-up alarm',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      color: const Color(0xFF0A84FF),
      colorized: true,
      showWhen: true,
      subText: 'TransitGo • Live Station Alarm 📍',
      styleInformation: bigPictureStyle,
      actions: const [
        AndroidNotificationAction(
          'cancel_alarm',
          '🔕 Cancel Alarm',
          showsUserInterface: false,
        ),
      ],
    );

    await _plugin.show(
      _ongoingNotificationId,
      title,
      'Live Station Alarm',
      NotificationDetails(
        android: android,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: false,
        ),
      ),
      payload: '$_trainNo|${_trainName ?? ""}',
    );
  }

  static Future<void> _showAlertNotification({
    required String title,
    required String summaryText,
    required Uint8List imageBytes,
  }) async {
    final vibrationPattern = Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1000]);

    final bigPictureStyle = BigPictureStyleInformation(
      ByteArrayAndroidBitmap(imageBytes),
      contentTitle: title,
      htmlFormatContentTitle: false,
      summaryText: summaryText,
      htmlFormatSummaryText: false,
      largeIcon: ByteArrayAndroidBitmap(imageBytes),
    );

    final android = AndroidNotificationDetails(
      'wake_me_up_alert',
      'Station Arrival Alarm (Loud)',
      channelDescription: 'High-priority loud alarm sound and vibration for station arrival',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      color: const Color(0xFFFF375F),
      colorized: true,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      subText: 'TransitGo • WAKE UP ALARM 🚨',
      ticker: '🚨 WAKE UP! Train is approaching station!',
      styleInformation: bigPictureStyle,
    );

    await _plugin.show(
      _alertNotificationId,
      title,
      '🚨 WAKE UP! Approaching Station',
      NotificationDetails(
        android: android,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: true,
        ),
      ),
      payload: '$_trainNo|${_trainName ?? ""}',
    );
  }
}
