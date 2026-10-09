import 'package:flutter/foundation.dart';

/// RailRadar monthly credits ke hisaab se routing.
///
/// Logic:
///   • Credits available  → RailRadar use karo
///   • 429 aaya           → rate-limit cooldown, Retry-After ka respect
///   • 402 aaya           → credits khatam, MNTES pe switch, reset tak rukо
///   • 401 / 403 aaya     → auth problem, longer pause
///   • Probe interval     → har 6 ghante ek baar try karo (manual recharge detect)
///   • Reset date reached → auto back to RailRadar
class ApiRouter {
  // ── RailRadar ka monthly reset day (usually 1st of month) ──────
  static const int resetDayOfMonth = 1;
  static const int resetHourIst = 0; // 00:00 IST

  // ── Probes: exhausted hone par bhi kabhi-kabhi try karo ────────
  static const Duration _probeInterval = Duration(hours: 6);

  // ── Auth failure pe zyada lamba pause ──────────────────────────
  static const Duration _authPauseDuration = Duration(hours: 12);
  static const Duration _defaultRateLimitPause = Duration(minutes: 1);
  static const Duration _maxRateLimitPause = Duration(hours: 1);

  // ── Credits low hone ka threshold (percentage) ─────────────────
  static const int lowCreditsThreshold = 10;

  // ── State ─────────────────────────────────────────────────────
  static DateTime? _railRadarPausedUntil;
  static DateTime? _nextProbeAt;
  static String _pauseReason = '';
  static int? _lastSeenRemaining;
  static int? _lastSeenLimit;

  // ═══════════════════════════════════════════════════════════════
  // PUBLIC — decision
  // ═══════════════════════════════════════════════════════════════

  /// True → RailRadar use karo. False → MNTES pe jao.
  static bool get useRailRadar {
    // Kabhi pause nahi hua → seedha RailRadar
    if (_railRadarPausedUntil == null) return true;

    final now = DateTime.now();

    // 1) Monthly reset ho gaya → unpause
    if (now.isAfter(_railRadarPausedUntil!)) {
      debugPrint('[Router] Reset time reached — trying RailRadar again');
      _clearPause();
      return true;
    }

    // 2) Probe window aa gaya → ek baar try karo
    if (_nextProbeAt != null && now.isAfter(_nextProbeAt!)) {
      debugPrint('[Router] Probe window — trying RailRadar once');
      _nextProbeAt = now.add(_probeInterval);
      return true;
    }

    return false;
  }

  // ═══════════════════════════════════════════════════════════════
  // PUBLIC — events
  // ═══════════════════════════════════════════════════════════════

  /// Credits exhausted (402) — agle monthly reset tak pause.
  static void pauseForMonthlyExhaustion({String? reason}) {
    final resumeAt = _nextMonthlyReset();
    _railRadarPausedUntil = resumeAt;
    _nextProbeAt = DateTime.now().add(_probeInterval);
    _pauseReason = reason ?? 'monthly quota exhausted';

    debugPrint(
      '[Router] RailRadar EXHAUSTED — paused until '
      '${resumeAt.toIso8601String()} '
      '(${_daysUntil(resumeAt)}d, probes every ${_probeInterval.inHours}h)',
    );
  }

  /// Auth problem (401/403) — 12h pause.
  static void pauseForAuth({String? reason}) {
    _railRadarPausedUntil = DateTime.now().add(_authPauseDuration);
    _nextProbeAt = DateTime.now().add(_probeInterval);
    _pauseReason = reason ?? 'auth failure';

    debugPrint(
      '[Router] RailRadar AUTH FAILED — paused '
      '${_authPauseDuration.inHours}h — $_pauseReason',
    );
  }

  /// HTTP 429 means request throttling unless the server reports quota exhaustion.
  static void pauseForRateLimit({Duration? retryAfter}) {
    final requestedPause = retryAfter ?? _defaultRateLimitPause;
    final pause = requestedPause <= Duration.zero
        ? _defaultRateLimitPause
        : requestedPause > _maxRateLimitPause
        ? _maxRateLimitPause
        : requestedPause;
    final resumeAt = DateTime.now().add(pause);
    _railRadarPausedUntil = resumeAt;
    _nextProbeAt = resumeAt;
    _pauseReason = 'rate limited';
    debugPrint(
      '[Router] RailRadar rate limited — paused for ${pause.inSeconds}s',
    );
  }

  /// RailRadar successful → unpause + healthy mark.
  static void markRailRadarHealthy() {
    if (_railRadarPausedUntil != null) {
      debugPrint('[Router] RailRadar back ONLINE');
    }
    _clearPause();
  }

  /// Response headers / meta se credits track karo.
  ///
  /// Agar RailRadar `X-Credits-Remaining` ya meta me
  /// remaining credits bhejta hai, to yahan feed karo.
  static void reportCredits({int? remaining, int? limit}) {
    _lastSeenRemaining = remaining;
    _lastSeenLimit = limit;

    if (remaining != null && limit != null && limit > 0) {
      final pct = (remaining / limit * 100).round();
      debugPrint('[Router] RailRadar credits: $remaining/$limit ($pct%)');

      if (pct <= lowCreditsThreshold && remaining > 0) {
        debugPrint('[Router] Credits LOW — MNTES warm rakho');
      }
    }
  }

  /// Har API call ke baad status inspect karo.
  static void inspectRailRadarResult(
    int? status, {
    Duration? retryAfter,
    String? responseBody,
  }) {
    if (status == null) return;

    if (status == 200) {
      markRailRadarHealthy();
    } else if (status == 402) {
      pauseForMonthlyExhaustion(
        reason: 'monthly quota exhausted (HTTP $status)',
      );
    } else if (status == 429) {
      final body = responseBody?.toLowerCase() ?? '';
      final quotaExhausted =
          body.contains('quota') ||
          body.contains('monthly') ||
          body.contains('exhaust') ||
          body.contains('credit limit') ||
          body.contains('credits depleted');
      if (quotaExhausted) {
        pauseForMonthlyExhaustion(
          reason: 'monthly quota exhausted (HTTP $status)',
        );
      } else {
        pauseForRateLimit(retryAfter: retryAfter);
      }
    } else if (status == 401 || status == 403) {
      pauseForAuth(reason: 'auth failure (HTTP $status)');
    }
    // 404, 5xx — pause nahi karo, transient hai
  }

  // ═══════════════════════════════════════════════════════════════
  // INTROSPECTION
  // ═══════════════════════════════════════════════════════════════
  static bool get isRailRadarPaused => _railRadarPausedUntil != null;
  static Duration? get railRadarRetryDelay {
    final until = _railRadarPausedUntil;
    if (until == null) return null;
    final delay = until.difference(DateTime.now());
    return delay.isNegative ? null : delay;
  }

  static String? get railRadarPauseReason =>
      railRadarRetryDelay == null ? null : _pauseReason;

  static bool get creditsLow {
    final r = _lastSeenRemaining;
    final l = _lastSeenLimit;
    if (r == null || l == null || l == 0) return false;
    return (r / l * 100) <= lowCreditsThreshold;
  }

  static Map<String, dynamic> get state => {
    'railRadarPaused': isRailRadarPaused,
    'reason': _pauseReason,
    'resumeAt': _railRadarPausedUntil?.toIso8601String(),
    'nextProbeAt': _nextProbeAt?.toIso8601String(),
    'creditsRemaining': _lastSeenRemaining,
    'creditsLimit': _lastSeenLimit,
    'creditsLow': creditsLow,
  };

  // ═══════════════════════════════════════════════════════════════
  // INTERNAL
  // ═══════════════════════════════════════════════════════════════
  static void _clearPause() {
    _railRadarPausedUntil = null;
    _nextProbeAt = null;
    _pauseReason = '';
  }

  /// Agla monthly reset date (IST) — 1st of next month, 00:00 IST.
  ///
  /// Agar aaj 1st hai aur abhi reset time nahi aaya, to aaj ka reset.
  /// Warna next month ka 1st.
  static DateTime _nextMonthlyReset() {
    final nowUtc = DateTime.now().toUtc();
    final nowIst = nowUtc.add(const Duration(hours: 5, minutes: 30));

    var targetIst = DateTime.utc(
      nowIst.year,
      nowIst.month,
      resetDayOfMonth,
      resetHourIst,
    );

    if (!targetIst.isAfter(nowIst)) {
      targetIst = DateTime.utc(
        nowIst.year,
        nowIst.month + 1,
        resetDayOfMonth,
        resetHourIst,
      );
    }

    // Wapas UTC me convert
    return targetIst.subtract(const Duration(hours: 5, minutes: 30));
  }

  static int _daysUntil(DateTime d) => d.difference(DateTime.now()).inDays;
}
