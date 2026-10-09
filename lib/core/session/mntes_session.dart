import 'dart:async';
import 'package:http/http.dart' as http;

class MntesSession {
  static String? _cookie;
  static DateTime? _expiry;
  static bool _refreshing = false;

  static String? get cookie => _cookie;

  static bool get isValid =>
      _cookie != null &&
          _cookie!.isNotEmpty &&
          _expiry != null &&
          DateTime.now().isBefore(_expiry!);

  static Future<void> refresh(http.Client client) async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final res = await client.get(
        Uri.parse('https://enquiry.indianrail.gov.in/mntes/'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
              'AppleWebKit/537.36 (KHTML, like Gecko) '
              'Chrome/122.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-IN,en;q=0.9',
        },
      ).timeout(const Duration(seconds: 10));

      final setCookies = <String>[];
      res.headers.forEach((k, v) {
        if (k.toLowerCase() == 'set-cookie') setCookies.add(v);
      });

      String? raw;
      for (final sc in setCookies) {
        final m = RegExp(r'JSESSIONID=("?)([^";,\s]+)\1').firstMatch(sc);
        if (m != null) {
          raw = m.group(2);
          break;
        }
      }

      if (raw == null) return;
      final cleaned = raw.replaceAll('"', '').trim();
      _cookie = 'JSESSIONID=$cleaned';
      _expiry = DateTime.now().add(const Duration(minutes: 25));
    } catch (_) {} finally {
      _refreshing = false;
    }
  }

  static void clear() {
    _cookie = null;
    _expiry = null;
  }
}

// import 'dart:async';
// import 'package:http/http.dart' as http;
//
// /// Manages MNTES session cookie with proper quote stripping.
// class MntesSession {
//   static String? _cookie;
//   static DateTime? _expiry;
//   static bool _refreshing = false;
//
//   static bool get isValid =>
//       _cookie != null &&
//           _cookie!.isNotEmpty &&
//           _expiry != null &&
//           DateTime.now().isBefore(_expiry!);
//
//   static Map<String, String> get headers => {
//     if (_cookie != null && _cookie!.isNotEmpty) 'Cookie': _cookie!,
//     'User-Agent':
//     'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
//         '(KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
//     'Accept': 'application/json, text/javascript, */*; q=0.01',
//     'X-Requested-With': 'XMLHttpRequest',
//     'Referer': 'https://enquiry.indianrail.gov.in/mntes/',
//   };
//
//   static Future<void> refresh(http.Client client) async {
//     if (_refreshing) return;
//     _refreshing = true;
//     try {
//       final res = await client
//           .get(
//         Uri.parse('https://enquiry.indianrail.gov.in/mntes/'),
//         headers: {
//           'User-Agent':
//           'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
//               '(KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
//           'Accept':
//           'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
//         },
//       )
//           .timeout(const Duration(seconds: 10));
//
//       final setCookies = <String>[];
//       res.headers.forEach((k, v) {
//         if (k.toLowerCase() == 'set-cookie') setCookies.add(v);
//       });
//
//       String? raw;
//       for (final sc in setCookies) {
//         final m = RegExp(r'JSESSIONID=("?)([^";,\s]+)\1').firstMatch(sc);
//         if (m != null) {
//           raw = m.group(2);
//           break;
//         }
//       }
//
//       if (raw == null) return;
//
//       final cleaned = raw.replaceAll('"', '').trim();
//       _cookie = 'JSESSIONID=$cleaned';
//       _expiry = DateTime.now().add(const Duration(minutes: 25));
//     } catch (_) {} finally {
//       _refreshing = false;
//     }
//   }
//
//   static void clear() {
//     _cookie = null;
//     _expiry = null;
//   }
// }