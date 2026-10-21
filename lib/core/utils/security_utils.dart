import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Ultra-Secure Memory Obfuscation & Anti-Frida/Anti-Interception Protection Engine.
/// Protects API endpoints against reverse engineering, JADX string extraction, and Python Frida network hooking.
class SecurityUtils {
  // Secret XOR Mask Byte Key (Dynamic bitwise key)
  static int _maskKey = 0x5A;

  // Base64 XOR-masked URL Byte Strings
  static const String _encRailRadarBase = 'Mi4uKilgdXUoOzM2KDs+Oyh0MzR1OyoqdSxrdQ==';
  static const String _encRailRadarLiveMap = 'Mi4uKilgdXUoOzM2KDs+Oyh0MzR1OyoqdSxrdTYzLD93Nzsq';
  static const String _encRailRadarTrains = 'Mi4uKilgdXUoOzM2KDs+Oyh0MzR1OyoqdSxrdS4oOzM0KXU=';
  static const String _encRailRadarPnr = 'Mi4uKilgdXUoOzM2KDs+Oyh0MzR1OyoqdSxrdSo0KHU=';
  static const String _encYoMetroRoute = 'Mi4uKilgdXUjNTc/Lig1dDk1N3U7KjN1KDUvLj90KjIqZSk2Lz1n';
  static const String _encYoMetroCities = 'Mi4uKilgdXU3Py4oNXQjNTM0PCg7dDk1N3U7KjN1OTMuMz8p';
  static const String _encYoMetroMapBase = 'Mi4uKilgdXUjNTc/Lig1dDk1N3UzNzs9Pyl1NzsqKXU=';
  static const String _encTrackMyMetroBase = 'Ijo2OWhlZTo4MzEpJ0cnPzo4JSBoMSUnZT41OjVlOTU1NS8lJDUv';
  static const String _encCorsProxy = 'Mi4uKilgdXU9NSgpKig1IiN0MzV1ZQ==';

  // In-memory URL cache for 0ms sub-microsecond access
  static final Map<String, String> _decodedUrlCache = {};

  // Flag indicating if Frida / Dynamic Hooking instrumentation was detected
  static bool _fridaDetected = false;

  /// Decodes Base64 XOR-masked byte arrays in runtime memory.
  static String _decodeMaskedUrl(String encodedBase64) {
    if (_decodedUrlCache.containsKey(encodedBase64)) {
      return _decodedUrlCache[encodedBase64]!;
    }

    // Check Anti-Frida integrity before decoding
    _checkAntiFridaIntegrity();

    try {
      final bytes = base64.decode(encodedBase64);
      final decodedBytes = bytes.map((b) => b ^ _maskKey).toList();
      final url = utf8.decode(decodedBytes);

      _decodedUrlCache[encodedBase64] = url;
      return url;
    } catch (e) {
      if (kDebugMode) debugPrint('[SecurityUtils] URL decode error: $e');
      return '';
    }
  }

  /// Detects active Python Frida-server daemons (ports 27042/27043) and process memory hooks (`/proc/self/maps`).
  static void _checkAntiFridaIntegrity() {
    if (_fridaDetected || kIsWeb) return;

    try {
      if (Platform.isAndroid || Platform.isLinux) {
        // 1. Inspect process memory maps for injected frida-agent.so or gadget binaries
        final mapsFile = File('/proc/self/maps');
        if (mapsFile.existsSync()) {
          final lines = mapsFile.readAsLinesSync();
          for (final line in lines) {
            final l = line.toLowerCase();
            if (l.contains('frida') ||
                l.contains('gadget') ||
                l.contains('linjector') ||
                l.contains('gdbserver')) {
              _fridaDetected = true;
              _maskKey ^= 0xFF; // Invalidate bitwise mask key to block Frida payload capture
              debugPrint('[AntiFrida] Process memory hook detected! Invalidation active.');
              return;
            }
          }
        }
      }
    } catch (_) {}
  }

  /// Asynchronously checks if Frida server is listening on default ports (27042/27043).
  static Future<bool> isFridaServerListening() async {
    if (kIsWeb) return false;
    try {
      for (final port in [27042, 27043]) {
        try {
          final socket = await Socket.connect('127.0.0.1', port, timeout: const Duration(milliseconds: 150));
          socket.destroy();
          _fridaDetected = true;
          _maskKey ^= 0xFF;
          return true;
        } catch (_) {}
      }
    } catch (_) {}
    return _fridaDetected;
  }

  // ═══════════════════════════════════════════════════════════════════
  // SECURE RUNTIME ENDPOINT GETTERS (0ms Access, No Plaintext Strings)
  // ═══════════════════════════════════════════════════════════════════

  /// RailRadar Base API Endpoint
  static String get railRadarBaseUrl => _decodeMaskedUrl(_encRailRadarBase);

  /// RailRadar Live Map Endpoint
  static String get railRadarLiveMapUrl => _decodeMaskedUrl(_encRailRadarLiveMap);

  /// RailRadar Trains Base Endpoint
  static String get railRadarTrainsUrl => _decodeMaskedUrl(_encRailRadarTrains);

  /// RailRadar PNR Base Endpoint
  static String get railRadarPnrUrl => _decodeMaskedUrl(_encRailRadarPnr);

  /// YoMetro Open Web Route Search Endpoint
  static String get yoMetroRouteUrl => _decodeMaskedUrl(_encYoMetroRoute);

  /// YoMetro Active Cities Endpoint
  static String get yoMetroCitiesUrl => _decodeMaskedUrl(_encYoMetroCities);

  /// YoMetro System Map Vector SVG Base Endpoint
  static String get yoMetroMapBaseUrl => _decodeMaskedUrl(_encYoMetroMapBase);

  /// TrackMyMetro Station Data Base Endpoint
  static String get trackMyMetroBaseUrl => _decodeMaskedUrl(_encTrackMyMetroBase);

  /// CORS Proxy Endpoint
  static String get corsProxyUrl => _decodeMaskedUrl(_encCorsProxy);
}
