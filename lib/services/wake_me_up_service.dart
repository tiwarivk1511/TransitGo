import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../data/models/train.dart';
import 'train_service.dart';

class WakeMeUpService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static Timer? _poll;
  static String? _trainNo;
  static String? _targetCode;
  static String? _targetName;
  static int _aheadMinutes = 20;
  static bool _fired = false;

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  static void arm({
    required String trainNumber,
    required String targetStationCode,
    required String targetStationName,
    int minutesAhead = 20,
  }) {
    _trainNo = trainNumber;
    _targetCode = targetStationCode;
    _targetName = targetStationName;
    _aheadMinutes = minutesAhead;
    _fired = false;
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 90), (_) => _check());
    _check();
  }

  static void cancel() {
    _poll?.cancel();
    _poll = null;
    _trainNo = null;
    _fired = false;
  }

  static bool get isArmed => _trainNo != null;

  static Future<void> _check() async {
    if (_fired || _trainNo == null || _targetCode == null) return;
    final data = await TrainService.liveTracking(_trainNo!);
    if (data == null) return;

    final idxTarget =
        data.route.indexWhere((s) => s.stationCode == _targetCode);
    final idxCurrent = data.currentIndex;
    if (idxTarget < 0 || idxCurrent < 0 || idxCurrent >= idxTarget) return;

    final target = data.route[idxTarget];

    // Prefer the actual time when available, else scheduled.
    final etaStr = TrainRouteStop.formatHm(target.effectiveArrival) ??
        target.arrival;
    final eta = _parseHm(etaStr);
    if (eta == null) return;

    final now = DateTime.now();
    final etaToday =
        DateTime(now.year, now.month, now.day, eta.hour, eta.minute)
            .add(Duration(minutes: data.delayMinutes));
    final left = etaToday.difference(now).inMinutes;

    if (left <= _aheadMinutes && left >= -2) {
      _fired = true;
      await _notify(_targetName ?? target.stationName, left);
    }
  }

  /// Accepts nullable input now — returns null on empty / unparseable.
  static DateTime? _parseHm(String? s) {
    if (s == null || s.isEmpty) return null;
    final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(s);
    if (m == null) return null;
    return DateTime(
        2000, 1, 1, int.parse(m.group(1)!), int.parse(m.group(2)!));
  }

  static Future<void> _notify(String station, int minutes) async {
    const android = AndroidNotificationDetails(
      'wake_me_up',
      'Wake Me Up',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    await _plugin.show(
      0,
      '🚆 Wake up! $station is approaching',
      'Train reaches $station in ~$minutes minutes.',
      const NotificationDetails(
          android: android, iOS: DarwinNotificationDetails()),
    );
  }
}
