import 'dart:async';
import 'package:flutter/foundation.dart';
import 'ntes_source.dart';
import 'railradar_source.dart';

/// ---------------------------------------------------------------------
/// LiveStreamSource — WebSocket-shaped live data stream
/// ---------------------------------------------------------------------
///
/// Wraps REST polling & MNTES Web Fallbacks in a `Stream` API.
/// From the caller's point of view it behaves exactly like a WebSocket:
///
///   final sub = LiveStreamSource.liveTrain('12919').listen((data) {
///     print('delay: ${data['delayMinutes']}m');
///   });
///   ...
///   await sub.cancel();
///
/// Features:
///   • Stream API identical to a WebSocket channel
///   • Hybrid RailRadar + MNTES Web Scraper Failover
///   • Auto-reconnect with exponential backoff
///   • Auto-dedup — identical payloads don't trigger rebuilds
///   • Shared pollers — 2 widgets on same key → 1 network call
///   • 5-second grace period on unsubscribe (avoids churn)
/// ---------------------------------------------------------------------
class LiveStreamSource {
  // ═══════════════════════════════════════════════════════════════════
  // 1. LIVE TRAIN STREAM (Hybrid RailRadar + MNTES Web Scraper)
  // ═══════════════════════════════════════════════════════════════════
  static Stream<Map<String, dynamic>> liveTrain(
      String trainNumber, {
        Duration interval = const Duration(seconds: 30),
        bool fastFirstTick = true,
        bool includeGeometry = true,
      }) {
    return _pollStream<Map<String, dynamic>>(
      key: 'live:$trainNumber:geo:$includeGeometry',
      interval: interval,
      fastFirstTick: fastFirstTick,
      fetch: () async {
        final live = await NtesSource.liveTracking(trainNumber);
        if (live != null) {
          final m = Map<String, dynamic>.from(live);
          if (m['geometry'] == null || m['geometry'] is! Map) {
            final geo = await RailRadarSource.trainRouteGeometry(trainNumber);
            if (geo != null) {
              m['geometry'] = geo;
            }
          }
          return m;
        }
        return null;
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 2. STATION LIVE BOARD STREAM
  // ═══════════════════════════════════════════════════════════════════
  static Stream<Map<String, dynamic>> stationLive(
      String stationCode, {
        int hours = 4,
        Duration interval = const Duration(seconds: 30),
        bool fastFirstTick = true,
      }) {
    return _pollStream<Map<String, dynamic>>(
      key: 'station:$stationCode:$hours',
      interval: interval,
      fastFirstTick: fastFirstTick,
      fetch: () => NtesSource.stationTraffic(stationCode, hours),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 3. PNR STREAM (changes rarely; poll slowly)
  // ═══════════════════════════════════════════════════════════════════
  static Stream<Map<String, dynamic>> pnr(
      String pnr, {
        Duration interval = const Duration(minutes: 5),
        bool fastFirstTick = true,
      }) {
    return _pollStream<Map<String, dynamic>>(
      key: 'pnr:$pnr',
      interval: interval,
      fastFirstTick: fastFirstTick,
      fetch: () => NtesSource.pnr(pnr),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // CORE POLLING ENGINE
  // ═══════════════════════════════════════════════════════════════════
  static final Map<String, dynamic> _active = {};

  static Stream<T> _pollStream<T>({
    required String key,
    required Duration interval,
    required bool fastFirstTick,
    required Future<T?> Function() fetch,
  }) {
    final existing = _active[key];
    if (existing is _PollController<T>) {
      return existing.stream;
    }

    final ctrl = _PollController<T>(
      key: key,
      interval: interval,
      fastFirstTick: fastFirstTick,
      fetch: fetch,
      onDispose: () => _active.remove(key),
    );
    _active[key] = ctrl;
    return ctrl.stream;
  }

  /// Kill every active stream (call on logout / app dispose).
  static void disposeAll() {
    for (final c in _active.values) {
      if (c is _PollController) c.dispose();
    }
    _active.clear();
  }
}

// ═════════════════════════════════════════════════════════════════════
// INTERNAL — one poll controller per active stream
// ═════════════════════════════════════════════════════════════════════
class _PollController<T> {
  final String key;
  final Duration interval;
  final bool fastFirstTick;
  final Future<T?> Function() fetch;
  final VoidCallback onDispose;

  late final StreamController<T> _out;
  Timer? _timer;
  Timer? _disposeTimer;
  bool _disposed = false;
  int _failures = 0;
  String? _lastHash;
  bool _inFlight = false;

  _PollController({
    required this.key,
    required this.interval,
    required this.fastFirstTick,
    required this.fetch,
    required this.onDispose,
  }) {
    _out = StreamController<T>.broadcast(
      onListen: _start,
      onCancel: () {
        _disposeTimer?.cancel();
        _disposeTimer = Timer(const Duration(seconds: 5), () {
          if (!_out.hasListener) dispose();
        });
      },
    );

    if (fastFirstTick) {
      scheduleMicrotask(_tick);
    }
  }

  Stream<T> get stream => _out.stream;

  void _start() {
    _disposeTimer?.cancel();
    _timer ??= Timer.periodic(interval, (_) => _tick());
  }

  Future<void> _tick() async {
    if (_disposed || _inFlight) return;
    _inFlight = true;

    try {
      final data = await fetch();
      if (_disposed) return;

      if (data == null) {
        _failures++;
        final backoff = Duration(
          seconds: (30 * _failures).clamp(30, 300),
        );
        if (kDebugMode) {
          debugPrint('[LiveStream] $key failure #$_failures, '
              'retry in ${backoff.inSeconds}s');
        }
        _timer?.cancel();
        _timer = Timer(backoff, () {
          _start();
          _tick();
        });
        return;
      }

      // Dedup: skip identical payloads
      final hash = data.toString();
      if (hash == _lastHash) {
        _failures = 0;
        return;
      }
      _lastHash = hash;
      _failures = 0;

      if (!_out.isClosed) _out.add(data);
    } catch (e) {
      _failures++;
      if (kDebugMode) debugPrint('[LiveStream] $key tick error: $e');
    } finally {
      _inFlight = false;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _disposeTimer?.cancel();
    _timer?.cancel();
    _timer = null;
    _out.close();
    onDispose();
  }
}
