import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class MntesClient {
  static String get _base =>
      dotenv.env['MNTES_BASE_URL'] ?? 'https://enquiry.indianrail.gov.in/mntes';
  static const Duration _timeout = Duration(seconds: 15);

  static final http.Client _http = http.Client();
  static final Map<String, String> _cookies = {};
  static DateTime? _lastRequestAt;
  static DateTime? _sessionBootedAt;
  static Future<void> _postQueue = Future<void>.value();
  static bool _booted = false;
  static int _consecutiveFailures = 0;
  static DateTime? _blockedUntil;

  // Rate limit: min gap between requests
  static const Duration _minGap = Duration(seconds: 3);

  static const List<String> _userAgents = [
    'Mozilla/5.0 (Linux; Android 13; SM-S911B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 12; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
  ];

  static String get _ua => _userAgents[Random().nextInt(_userAgents.length)];

  // Bootstrap session
  static Future<void> _bootstrap() async {
    if (_booted && _sessionBootedAt != null &&
        DateTime.now().difference(_sessionBootedAt!) < const Duration(minutes: 25)) {
      return;
    }

    try {
      final res = await _http.get(
        Uri.parse('$_base/'),
        headers: {
          'User-Agent': _ua,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-IN,en;q=0.9',
        },
      ).timeout(_timeout);

      _storeCookies(res);
      _booted = true;
      _sessionBootedAt = DateTime.now();
      debugPrint('[MNTES] session booted, cookies=${_cookies.length}');
    } catch (e) {
      debugPrint('[MNTES] bootstrap failed: $e');
    }
  }

  static void _storeCookies(http.Response res) {
    final setCookies = res.headers['set-cookie'];
    if (setCookies == null) return;
    // set-cookie may be a single comma-joined string or list
    final parts = setCookies.split(',');
    for (final p in parts) {
      final kv = p.split(';').first.trim();
      final idx = kv.indexOf('=');
      if (idx > 0) {
        final key = kv.substring(0, idx).trim();
        final val = kv.substring(idx + 1).trim();
        if (key.isNotEmpty && val.isNotEmpty) _cookies[key] = val;
      }
    }
  }

  static String _cookieHeader() =>
      _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  static Map<String, String> _headers({bool ajax = true}) => {
    'User-Agent': _ua,
    'Accept': ajax ? 'application/json, text/javascript, */*; q=0.01'
        : 'text/html,application/xhtml+xml,*/*;q=0.8',
    'Accept-Language': 'en-IN,en;q=0.9',
    'Referer': '$_base/',
    'Origin': 'https://enquiry.indianrail.gov.in',
    'X-Requested-With': ajax ? 'XMLHttpRequest' : '',
    'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
    if (_cookies.isNotEmpty) 'Cookie': _cookieHeader(),
  }..removeWhere((k, v) => v.isEmpty);

  // Rate limiter
  static Future<void> _respectRateLimit() async {
    if (_lastRequestAt != null) {
      final elapsed = DateTime.now().difference(_lastRequestAt!);
      if (elapsed < _minGap) {
        await Future.delayed(_minGap - elapsed);
      }
    }
  }

  static bool get isBlocked =>
      _blockedUntil != null && DateTime.now().isBefore(_blockedUntil!);

  static Future<dynamic> post(
    String cat,
    String sub, {
    Map<String, String>? query,
  }) async {
    final previousPost = _postQueue;
    final releasePost = Completer<void>();
    _postQueue = releasePost.future;
    await previousPost;
    try {
      return await _postUnlocked(cat, sub, query: query);
    } finally {
      releasePost.complete();
    }
  }

  static Future<dynamic> _postUnlocked(
    String cat,
    String sub, {
    Map<String, String>? query,
  }) async {
    if (isBlocked) return null;

    await _bootstrap();
    await _respectRateLimit();

    final uri = Uri.parse('$_base/q?opt=$cat&subOpt=$sub');
    final body = query ?? {};

    try {
      _lastRequestAt = DateTime.now();
      final res = await _http.post(
        uri,
        headers: _headers(),
        body: body,
      ).timeout(_timeout);

      _storeCookies(res);

      if (res.statusCode == 429 || res.statusCode == 503) {
        _recordFailure();
        return null;
      }

      if (res.statusCode != 200) {
        _recordFailure();
        return null;
      }

      // Detect block page
      final text = res.body.trim();
      if (text.isEmpty ||
          text.toLowerCase().contains('blocked') ||
          text.toLowerCase().contains('captcha') ||
          text.startsWith('<')) {
        // HTML or empty = likely blocked
        _recordFailure();
        // Re-bootstrap on next call
        _booted = false;
        return null;
      }

      final decoded = json.decode(text);

      // MNTES wraps in { "data": ..., "status": ... } sometimes
      if (decoded is Map && decoded['data'] != null) {
        _recordSuccess();
        return decoded['data'];
      }
      _recordSuccess();
      return decoded;
    } catch (e) {
      _recordFailure();
      debugPrint('[MNTES] post $cat/$sub failed: $e');
      return null;
    }
  }

  static void _recordFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= 3) {
      _blockedUntil = DateTime.now().add(const Duration(minutes: 10));
      _booted = false; // force re-bootstrap
      _consecutiveFailures = 0;
      debugPrint('[MNTES] circuit open for 10 minutes');
    }
  }

  static void _recordSuccess() {
    _consecutiveFailures = 0;
    _blockedUntil = null;
  }
}
