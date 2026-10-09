import 'dart:convert';

class HtmlParser {
  static dynamic extract(String html) {
    if (html.trim().isEmpty) return null;
    final jsonInScript = _extractJsonFromScriptTag(html);
    if (jsonInScript != null) return jsonInScript;
    final jsonBlock = _extractJsonBlock(html);
    if (jsonBlock != null) return jsonBlock;
    final stations = parseStationList(html);
    if (stations.isNotEmpty) return stations;
    final trains = parseTrainList(html);
    if (trains.isNotEmpty) return trains;
    return null;
  }

  static List<Map<String, String>> parseStationList(String html) {
    final out = <Map<String, String>>[];
    final seen = <String>{};

    void add(String code, String name) {
      final c = code.trim().toUpperCase();
      final n = name.trim();
      if (c.isEmpty || n.isEmpty) return;
      if (!RegExp(r'^[A-Z0-9]{2,10}$').hasMatch(c)) return;
      if (!seen.add(c)) return;
      out.add({'stnCode': c, 'stnName': n});
    }

    // Pattern 1: onclick="...('CODE','NAME')..."
    final onclickRe = RegExp(r'''\(["']([A-Z0-9]{2,10})["']\s*,\s*["']([^"']+)["']''');
    for (final m in onclickRe.allMatches(html)) {
      add(m.group(1) ?? '', m.group(2) ?? '');
      if (out.length >= 50) break;
    }

    // Pattern 2: data-code="XX" data-name="Name"
    if (out.isEmpty) {
      final dataRe = RegExp(
        r'''data-(?:stn)?code=["']([A-Z0-9]{2,10})["'][^>]*?data-(?:stn)?name=["']([^"']+)["']''',
        caseSensitive: false,
      );
      for (final m in dataRe.allMatches(html)) {
        add(m.group(1) ?? '', m.group(2) ?? '');
        if (out.length >= 50) break;
      }
    }

    // Pattern 3: <option value="XX">Name</option>
    if (out.isEmpty) {
      final optionRe = RegExp(
        r'''<option[^>]*value=["']([A-Z0-9]{2,10})["'][^>]*>([^<]+)</option>''',
        caseSensitive: false,
      );
      for (final m in optionRe.allMatches(html)) {
        add(m.group(1) ?? '', m.group(2) ?? '');
        if (out.length >= 50) break;
      }
    }

    // Pattern 4: <li>CODE - Name</li>
    if (out.isEmpty) {
      final liRe = RegExp(
        r'<li[^>]*>\s*([A-Z0-9]{2,10})\s*[-–:]\s*([^<]{3,80}?)\s*</li>',
        caseSensitive: false,
      );
      for (final m in liRe.allMatches(html)) {
        add(m.group(1) ?? '', m.group(2) ?? '');
        if (out.length >= 50) break;
      }
    }

    return out;
  }

  static List<Map<String, String>> parseTrainList(String html) {
    final out = <Map<String, String>>[];
    final seen = <String>{};

    void add(String number, String name) {
      final n = number.trim();
      final nm = name.trim();
      if (n.isEmpty || nm.isEmpty) return;
      if (!RegExp(r'^\d{4,6}$').hasMatch(n)) return;
      if (!seen.add(n)) return;
      out.add({'trainNumber': n, 'trainName': nm});
    }

    final onclickRe = RegExp(r'''\(["'](\d{4,6})["']\s*,\s*["']([^"']+)["']''');
    for (final m in onclickRe.allMatches(html)) {
      add(m.group(1) ?? '', m.group(2) ?? '');
      if (out.length >= 50) break;
    }

    if (out.isEmpty) {
      final trRe = RegExp(
        r'<tr[^>]*>\s*<td[^>]*>\s*(\d{4,6})\s*</td>\s*<td[^>]*>([^<]+)</td>',
        caseSensitive: false,
      );
      for (final m in trRe.allMatches(html)) {
        add(m.group(1) ?? '', m.group(2) ?? '');
        if (out.length >= 50) break;
      }
    }

    return out;
  }

  static dynamic _extractJsonFromScriptTag(String html) {
    final re = RegExp(
      r'''<script[^>]*type=["']application/json["'][^>]*>(.*?)</script>''',
      dotAll: true,
      caseSensitive: false,
    );
    for (final m in re.allMatches(html)) {
      final body = m.group(1)?.trim();
      if (body == null || body.isEmpty) continue;
      try {
        return json.decode(body);
      } catch (_) {}
    }
    return null;
  }

  static dynamic _extractJsonBlock(String html) {
    final objRe = RegExp(r'\{[\s\S]{20,}?\}');
    for (final m in objRe.allMatches(html)) {
      final body = m.group(0)?.trim();
      if (body == null || body.isEmpty) continue;
      if (body.contains('function') || body.contains('var ') || body.contains('window.')) continue;
      try {
        final decoded = json.decode(body);
        if (decoded is Map || decoded is List) return decoded;
      } catch (_) {}
    }

    final arrRe = RegExp(r'\[[\s\S]{20,}?\]');
    for (final m in arrRe.allMatches(html)) {
      final body = m.group(0)?.trim();
      if (body == null || body.isEmpty) continue;
      try {
        final decoded = json.decode(body);
        if (decoded is List && decoded.isNotEmpty) return decoded;
      } catch (_) {}
    }

    return null;
  }

  static String stripTags(String html) {
    var text = html;
    text = text.replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), ' ');
    text = text.replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), ' ');
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#x2F;', '/');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  static bool looksLikeLoginPage(String html) {
    final lower = html.toLowerCase();
    return lower.contains('<title>indian railways') &&
        lower.contains('login') &&
        !lower.contains('stationlist') &&
        !lower.contains('trainbtwnstnslist');
  }

  static bool isTrivial(String html) {
    final stripped = stripTags(html).trim();
    return stripped.isEmpty || stripped.length < 20;
  }

  static String? extractValue(String html, String pattern) {
    try {
      final match = RegExp(pattern, caseSensitive: false).firstMatch(html);
      return match?.group(1)?.trim();
    } catch (_) {
      return null;
    }
  }

  static List<String> extractAll(String html, String pattern) {
    try {
      return RegExp(pattern, caseSensitive: false)
          .allMatches(html)
          .map((m) => m.group(1)?.trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}