import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../data/models/train.dart';
import 'train_service.dart';

class WakeMeUpService {
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
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        if (response.actionId == 'cancel_alarm') {
          cancel();
        }
      },
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
    _showOngoingNotification(
      title: '🔔 Station Alarm Active: $targetStationName ($targetStationCode)',
      bigText: '🚆 Train: $trainNumber${_trainName != null ? " • $_trainName" : ""}\n'
          '📍 Target Station: $targetStationName ($targetStationCode)\n'
          '⏱️ Trigger Lead Time: $minutesAhead min before arrival\n'
          '📡 Tracking live status in background...',
      summaryText: '$targetStationName ($targetStationCode)',
    );

    _poll = Timer.periodic(const Duration(seconds: 45), (_) => _check());
    _check();
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

    // Destination Reached
    if (idxCurrent >= idxTarget) {
      if (!_fired) {
        _fired = true;
        await _showAlertNotification(
          title: '🚨 DESTINATION REACHED: ${_targetName ?? target.stationName}',
          bigText: '🚨 DEBOARDING ALERT!\n'
              'Train ${_trainNo!} has arrived at ${_targetName ?? target.stationName} (${_targetCode!}).\n'
              '🎫 Platform: ${target.platform ?? "1"}\n'
              '🎒 Please gather all luggage and deboard safely.',
          summaryText: 'Destination Reached',
        );
      }
      cancel();
      return;
    }

    // Update Ultra-Modern Persistent Ongoing Notification
    final currentText = currentStop != null ? currentStop.stationName : data.currentLocation.stationName;

    _showOngoingNotification(
      title: '🔔 Destination Alarm: ${_targetName ?? target.stationName} ($_targetCode)',
      bigText: '🚆 Train: ${_trainNo!} • ${_trainName ?? "Express"}\n'
          '📍 Target: ${_targetName ?? target.stationName} ($_targetCode)\n'
          '⏱️ Remaining: $remainingStops Stops${leftMinutes < 900 ? " (~$leftMinutes min left)" : ""}\n'
          '🚉 Current Location: $currentText\n'
          '🕒 Scheduled Arrival: $etaStr${data.delayMinutes > 0 ? " (+${data.delayMinutes}m late)" : ""}',
      summaryText: 'Remaining: $remainingStops Stops (~${leftMinutes < 900 ? leftMinutes : "--"}m)',
    );

    // High-Priority Loud Alert Trigger when within Lead Time
    if (leftMinutes <= _aheadMinutes && leftMinutes >= -2 && !_fired) {
      _fired = true;
      await _showAlertNotification(
        title: '🚨 WAKE UP! Approaching ${_targetName ?? target.stationName}',
        bigText: '🚨 WAKE UP ALARM!\n'
            'Train ${_trainNo!} is approaching ${_targetName ?? target.stationName} ($_targetCode) in ~$leftMinutes minutes!\n\n'
            '📍 Current Position: $currentText\n'
            '🎫 Target Platform: ${target.platform ?? "1"}\n'
            '🎒 Prepare your bags and get ready to deboard.',
        summaryText: 'Approaching Station in ~$leftMinutes min',
      );
    }
  }

  static DateTime? _parseHm(String? s) {
    if (s == null || s.isEmpty) return null;
    final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(s);
    if (m == null) return null;
    return DateTime(2000, 1, 1, int.parse(m.group(1)!), int.parse(m.group(2)!));
  }

  static Future<void> _showOngoingNotification({
    required String title,
    required String bigText,
    required String summaryText,
  }) async {
    final bigTextStyle = BigTextStyleInformation(
      bigText,
      htmlFormatBigText: false,
      contentTitle: title,
      htmlFormatContentTitle: false,
      summaryText: summaryText,
      htmlFormatSummaryText: false,
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
      subText: 'TransitGo • Live Station Alarm',
      styleInformation: bigTextStyle,
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
      bigText,
      NotificationDetails(
        android: android,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: false,
        ),
      ),
    );
  }

  static Future<void> _showAlertNotification({
    required String title,
    required String bigText,
    required String summaryText,
  }) async {
    final vibrationPattern = Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1000]);

    final bigTextStyle = BigTextStyleInformation(
      bigText,
      htmlFormatBigText: false,
      contentTitle: title,
      htmlFormatContentTitle: false,
      summaryText: summaryText,
      htmlFormatSummaryText: false,
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
      styleInformation: bigTextStyle,
    );

    await _plugin.show(
      _alertNotificationId,
      title,
      bigText,
      NotificationDetails(
        android: android,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: true,
        ),
      ),
    );
  }
}
