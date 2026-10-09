import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../core/cache/offline_cache.dart';
import '../models/station.dart';

/// Reads legacy station names and enriched station metadata from stations.json.
/// District/state details can be embedded per station or stored in
/// a top-level "stationMetadata" map keyed by station code.
class StationSource {
  static List<Station> _all = [];
  static bool _loaded = false;

  static bool get isLoaded => _loaded;
  static int get count => _all.length;
  static List<Station> get all => List.unmodifiable(_all);

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/data/stations.json');
      final decoded = json.decode(raw);

      if (decoded is! Map) {
        print('StationSource: unexpected JSON root');
        return;
      }

      final stationsRaw = decoded['stations'];
      if (stationsRaw == null) {
        print('StationSource: no "stations" key');
        return;
      }

      final loaded = <Station>[];
      final metadataRaw = decoded['stationMetadata'];
      final metadataByCode = metadataRaw is Map
          ? {
              for (final entry in metadataRaw.entries)
                entry.key.toString().trim().toUpperCase(): entry.value,
            }
          : const <String, dynamic>{};

      if (stationsRaw is Map) {
        // Format 1: { "NDLS": "New Delhi", ... }
        stationsRaw.forEach((code, value) {
          final c = code.toString().trim().toUpperCase();
          final stationData = value is Map
              ? Map<String, dynamic>.from(value)
              : <String, dynamic>{'name': value};
          final metadata = metadataByCode[c];
          final combinedData = metadata is Map
              ? {...Map<String, dynamic>.from(metadata), ...stationData}
              : stationData;
          final n =
              (combinedData['name'] ??
                      combinedData['stationName'] ??
                      combinedData['stnName'] ??
                      '')
                  .toString()
                  .trim();
          if (c.isEmpty || n.isEmpty) return;
          if (c.contains('-')) return; // skip technical codes
          loaded.add(Station.fromJson({...combinedData, 'code': c, 'name': n}));
        });
      } else if (stationsRaw is List) {
        // Format 2: [ { "code": "...", "name": "..." } ]
        for (final item in stationsRaw) {
          if (item is! Map) continue;
          final m = Map<String, dynamic>.from(item);
          final code = (m['code'] ?? m['stnCode'] ?? '')
              .toString()
              .trim()
              .toUpperCase();
          final name = (m['name'] ?? m['stnName'] ?? '').toString().trim();
          if (code.isEmpty || name.isEmpty) continue;
          final metadata = metadataByCode[code];
          final combinedData = metadata is Map
              ? {...Map<String, dynamic>.from(metadata), ...m}
              : m;
          loaded.add(
            Station.fromJson({...combinedData, 'code': code, 'name': name}),
          );
        }
      }

      try {
        final cachedMetadata = await OfflineCache.getStationMetadata();
        final metadataByCode = {
          for (final station in cachedMetadata)
            (station['code'] ?? '').toString().trim().toUpperCase(): station,
        };
        for (var i = 0; i < loaded.length; i++) {
          final station = loaded[i];
          final metadata = metadataByCode[station.code.toUpperCase()];
          if (metadata == null) continue;
          loaded[i] = Station.fromJson({
            ...station.toJson(),
            ...metadata,
            'code': station.code,
            'name': station.name,
          });
        }
      } catch (error) {
        debugPrint('[StationSource] Could not load cached metadata: $error');
      }

      final seen = <String>{};
      _all = loaded.where((s) => seen.add(s.code)).toList();
      _all.sort((a, b) => a.name.compareTo(b.name));
      _loaded = true;
      print('✅ StationSource loaded ${_all.length} stations');
    } catch (e) {
      print('❌ StationSource load failed: $e');
    }
  }

  static List<Station> search(String query, {int limit = 20}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty || _all.isEmpty) return [];

    final exactCode = <Station>[];
    final codeStarts = <Station>[];
    final nameStarts = <Station>[];
    final nameContains = <Station>[];

    for (final s in _all) {
      final c = s.code.toLowerCase();
      final n = s.name.toLowerCase();
      if (c == q) {
        exactCode.add(s);
      } else if (c.startsWith(q)) {
        codeStarts.add(s);
      } else if (n.startsWith(q)) {
        nameStarts.add(s);
      } else if (n.contains(q)) {
        nameContains.add(s);
      }
      if (exactCode.length +
              codeStarts.length +
              nameStarts.length +
              nameContains.length >=
          limit * 3) {
        break;
      }
    }

    return [
      ...exactCode,
      ...codeStarts,
      ...nameStarts,
      ...nameContains,
    ].take(limit).toList();
  }

  static Station? byCode(String code) {
    final c = code.trim().toUpperCase();
    for (final s in _all) {
      if (s.code == c) return s;
    }
    return null;
  }

  static void registerStations(Iterable<Station> stations) {
    final byCode = {for (final station in _all) station.code: station};
    for (final station in stations) {
      final code = station.code.trim().toUpperCase();
      if (code.isEmpty || station.name.trim().isEmpty) continue;
      final existing = byCode[code];
      byCode[code] = existing == null
          ? station
          : Station.fromJson({
              ...existing.toJson(),
              ...station.toJson(),
              'code': code,
              'name': station.name,
            });
    }
    _all = byCode.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  static Future<void> cacheStations(Iterable<Station> stations) async {
    final values = stations.toList();
    registerStations(values);
    try {
      await OfflineCache.saveStationMetadata(
        values.map((station) => station.toJson()),
      );
    } catch (error) {
      debugPrint('[StationSource] Could not save station metadata: $error');
    }
  }

  static Future<List<Station>> inSameArea(Station selected) async {
    if (!_loaded) await load();
    registerStations([selected]);

    final district = _normalizeArea(selected.district);
    final city = _normalizeArea(selected.city);
    final state = _normalizeArea(selected.state);
    final hasDistrict = district.isNotEmpty;
    final area = hasDistrict ? district : city;
    if (area.isEmpty) return [selected];

    final matches = _all.where((station) {
      if (station.code.toUpperCase() == selected.code.toUpperCase()) {
        return true;
      }
      final stationArea = _normalizeArea(
        hasDistrict ? station.district : station.city,
      );
      if (stationArea != area) return false;

      final stationState = _normalizeArea(station.state);
      return state.isEmpty || stationState.isEmpty || stationState == state;
    }).toList();

    return matches;
  }

  static String _normalizeArea(String? value) => (value ?? '')
      .toLowerCase()
      .replaceAll('district', '')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
}
