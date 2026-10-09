import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SQLite-backed persistent cache for TransitGo (with SharedPreferences fallback for Web).
class OfflineCache {
  static Database? _db;
  static Future<Database>? _opening;
  static SharedPreferences? _prefs;
  static const String _dbName = 'transitgo_v2.db';
  static const int _dbVersion = 3;

  static Future<void> _initWeb() async {
    if (_prefs == null && kIsWeb) {
      _prefs = await SharedPreferences.getInstance();
    }
  }

  // ───────────────────────────────────────────────────────────────────
  // SINGLETON / INSTANCE
  // ───────────────────────────────────────────────────────────────────
  static Future<Database> get instance async {
    if (kIsWeb) {
      throw UnsupportedError(
        'SQLite is not supported on web. Use web SharedPreferences methods.',
      );
    }
    if (_db != null) return _db!;

    final opening = _opening;
    if (opening != null) return opening;

    final future = _openDatabase();
    _opening = future;
    try {
      return _db = await future;
    } finally {
      _opening = null;
    }
  }

  static Future<Database> _openDatabase() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // SCHEMA (Mobile / Desktop SQLite)
  // ───────────────────────────────────────────────────────────────────
  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE cache(
        key       TEXT PRIMARY KEY,
        json      TEXT NOT NULL,
        expires   INTEGER NOT NULL,
        created   INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_cache_expires ON cache(expires)');
    await db.execute('CREATE INDEX idx_cache_created ON cache(created)');

    await db.execute('''
      CREATE TABLE search_history(
        id      INTEGER PRIMARY KEY AUTOINCREMENT,
        kind    TEXT NOT NULL,
        query   TEXT NOT NULL,
        label   TEXT,
        data    TEXT,
        created INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_history_kind ON search_history(kind, created DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_history_query ON search_history(kind, query)',
    );

    await db.execute('''
      CREATE TABLE tracked_trains(
        train_number  TEXT PRIMARY KEY,
        train_name    TEXT NOT NULL,
        route_json    TEXT,
        last_seen     INTEGER NOT NULL,
        track_count   INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_tracked_last_seen ON tracked_trains(last_seen DESC)',
    );

    await db.execute('''
      CREATE TABLE favourite_stations(
        code      TEXT PRIMARY KEY,
        name      TEXT NOT NULL,
        city      TEXT,
        state     TEXT,
        added     INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_fav_added ON favourite_stations(added DESC)',
    );
    await db.execute('''
      CREATE TABLE station_metadata(
        code TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        updated INTEGER NOT NULL
      )
    ''');
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE station_metadata(
          code TEXT PRIMARY KEY,
          data TEXT NOT NULL,
          updated INTEGER NOT NULL
        )
      ''');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 1. RESPONSE CACHE
  // ═══════════════════════════════════════════════════════════════════
  static Future<void> put(
    String key,
    dynamic value, {
    Duration ttl = const Duration(hours: 1),
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final expires = now + ttl.inMilliseconds;
      if (kIsWeb) {
        await _initWeb();
        await _prefs?.setString('cache_val_$key', jsonEncode(value));
        await _prefs?.setInt('cache_exp_$key', expires);
        await _prefs?.setInt('cache_crt_$key', now);
        return;
      }
      final db = await instance;
      await db.insert('cache', {
        'key': key,
        'json': jsonEncode(value),
        'expires': expires,
        'created': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  static Future<dynamic> get(String key) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (kIsWeb) {
        await _initWeb();
        final expires = _prefs?.getInt('cache_exp_$key') ?? 0;
        if (now > expires) {
          await remove(key);
          return null;
        }
        final valStr = _prefs?.getString('cache_val_$key');
        if (valStr == null) return null;
        return jsonDecode(valStr);
      }
      final db = await instance;
      final rows = await db.query(
        'cache',
        columns: ['json', 'expires'],
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final expires = rows.first['expires'] as int;
      if (now > expires) {
        await db.delete('cache', where: 'key = ?', whereArgs: [key]);
        return null;
      }
      return jsonDecode(rows.first['json'] as String);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> has(String key) async => (await get(key)) != null;

  static Future<void> remove(String key) async {
    try {
      if (kIsWeb) {
        await _initWeb();
        _prefs?.remove('cache_val_$key');
        _prefs?.remove('cache_exp_$key');
        _prefs?.remove('cache_crt_$key');
        return;
      }
      final db = await instance;
      await db.delete('cache', where: 'key = ?', whereArgs: [key]);
    } catch (_) {}
  }

  static Future<void> removeByPrefix(String prefix) async {
    try {
      if (kIsWeb) {
        await _initWeb();
        final keys = _prefs?.getKeys() ?? {};
        for (final k in keys) {
          if (k.startsWith('cache_val_$prefix')) {
            final rawKey = k.replaceFirst('cache_val_', '');
            await remove(rawKey);
          }
        }
        return;
      }
      final db = await instance;
      await db.delete('cache', where: 'key LIKE ?', whereArgs: ['$prefix%']);
    } catch (_) {}
  }

  static Future<void> clearExpired() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (kIsWeb) {
        await _initWeb();
        final keys = _prefs?.getKeys() ?? {};
        for (final k in keys) {
          if (k.startsWith('cache_exp_')) {
            final expires = _prefs?.getInt(k) ?? 0;
            if (now > expires) {
              final rawKey = k.replaceFirst('cache_exp_', '');
              await remove(rawKey);
            }
          }
        }
        return;
      }
      final db = await instance;
      await db.delete('cache', where: 'expires < ?', whereArgs: [now]);
    } catch (_) {}
  }

  static Future<void> clearAllCache() async {
    try {
      if (kIsWeb) {
        await _initWeb();
        final keys = _prefs?.getKeys() ?? {};
        for (final k in keys.toList()) {
          if (k.startsWith('cache_val_') ||
              k.startsWith('cache_exp_') ||
              k.startsWith('cache_crt_')) {
            _prefs?.remove(k);
          }
        }
        return;
      }
      final db = await instance;
      await db.delete('cache');
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════
  // 2. SEARCH HISTORY
  // ═══════════════════════════════════════════════════════════════════
  static Future<void> addHistory(
    String kind,
    String query, {
    String? label,
    Map<String, dynamic>? data,
  }) async {
    if (query.trim().isEmpty) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (kIsWeb) {
        await _initWeb();
        final list = await getHistory(kind, limit: 100);
        list.removeWhere((item) => item['query'] == query);
        list.insert(0, {
          'kind': kind,
          'query': query,
          'label': label,
          'data': data,
          'created': now,
        });
        if (list.length > 50) list.removeRange(50, list.length);
        _prefs?.setString('history_$kind', jsonEncode(list));
        return;
      }
      final db = await instance;
      await db.delete(
        'search_history',
        where: 'kind = ? AND query = ?',
        whereArgs: [kind, query],
      );
      await db.insert('search_history', {
        'kind': kind,
        'query': query,
        'label': label,
        'data': data == null ? null : jsonEncode(data),
        'created': now,
      });
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> getHistory(
    String kind, {
    int limit = 30,
  }) async {
    try {
      if (kIsWeb) {
        await _initWeb();
        final str = _prefs?.getString('history_$kind');
        if (str == null) return [];
        final decoded = jsonDecode(str) as List;
        return decoded
            .map((e) => Map<String, dynamic>.from(e))
            .take(limit)
            .toList();
      }
      final db = await instance;
      final rows = await db.query(
        'search_history',
        where: 'kind = ?',
        whereArgs: [kind],
        orderBy: 'created DESC',
        limit: limit,
      );
      return rows.map((r) {
        final m = Map<String, dynamic>.from(r);
        if (m['data'] is String) {
          try {
            m['data'] = jsonDecode(m['data'] as String);
          } catch (_) {}
        }
        return m;
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> clearHistory(String s, {String? kind}) async {
    try {
      if (kIsWeb) {
        await _initWeb();
        if (kind == null) {
          final keys = _prefs?.getKeys() ?? {};
          for (final k in keys.toList()) {
            if (k.startsWith('history_')) _prefs?.remove(k);
          }
        } else {
          _prefs?.remove('history_$kind');
        }
        return;
      }
      final db = await instance;
      if (kind == null) {
        await db.delete('search_history');
      } else {
        await db.delete('search_history', where: 'kind = ?', whereArgs: [kind]);
      }
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════
  // 3. TRACKED TRAINS
  // ═══════════════════════════════════════════════════════════════════
  static Future<void> rememberTrain(
    String number,
    String name, {
    Map<String, dynamic>? route,
  }) async {
    if (number.trim().isEmpty) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (kIsWeb) {
        await _initWeb();
        final list = await getRecentTrains(limit: 100);
        list.removeWhere((t) => t['train_number'] == number);
        list.insert(0, {
          'train_number': number,
          'train_name': name,
          'route': route,
          'last_seen': now,
          'track_count': 1,
        });
        if (list.length > 50) list.removeRange(50, list.length);
        _prefs?.setString('tracked_trains', jsonEncode(list));
        return;
      }
      final db = await instance;
      await db.insert('tracked_trains', {
        'train_number': number,
        'train_name': name,
        'route_json': route == null ? null : jsonEncode(route),
        'last_seen': now,
        'track_count': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> getRecentTrains({
    int limit = 20,
  }) async {
    try {
      if (kIsWeb) {
        await _initWeb();
        final str = _prefs?.getString('tracked_trains');
        if (str == null) return [];
        final decoded = jsonDecode(str) as List;
        return decoded
            .map((e) => Map<String, dynamic>.from(e))
            .take(limit)
            .toList();
      }
      final db = await instance;
      final rows = await db.query(
        'tracked_trains',
        orderBy: 'last_seen DESC',
        limit: limit,
      );
      return rows.map((r) {
        final m = Map<String, dynamic>.from(r);
        if (m['route_json'] is String) {
          try {
            m['route'] = jsonDecode(m['route_json'] as String);
          } catch (_) {}
        }
        return m;
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> removeTrackedTrain(String number) async {
    try {
      if (kIsWeb) {
        await _initWeb();
        final list = await getRecentTrains(limit: 100);
        list.removeWhere((t) => t['train_number'] == number);
        _prefs?.setString('tracked_trains', jsonEncode(list));
        return;
      }
      final db = await instance;
      await db.delete(
        'tracked_trains',
        where: 'train_number = ?',
        whereArgs: [number],
      );
    } catch (_) {}
  }

  static Future<void> clearTrackedTrains() async {
    try {
      if (kIsWeb) {
        await _initWeb();
        _prefs?.remove('tracked_trains');
        return;
      }
      final db = await instance;
      await db.delete('tracked_trains');
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════
  // 4. FAVOURITE STATIONS
  // ═══════════════════════════════════════════════════════════════════
  static Future<void> addFavouriteStation({
    required String code,
    required String name,
    String? city,
    String? state,
  }) async {
    if (code.trim().isEmpty) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (kIsWeb) {
        await _initWeb();
        final list = await getFavouriteStations();
        list.removeWhere((s) => s['code'] == code);
        list.insert(0, {
          'code': code,
          'name': name,
          'city': city,
          'state': state,
          'added': now,
        });
        _prefs?.setString('fav_stations', jsonEncode(list));
        return;
      }
      final db = await instance;
      await db.insert('favourite_stations', {
        'code': code,
        'name': name,
        'city': city,
        'state': state,
        'added': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  static Future<void> removeFavouriteStation(String code) async {
    try {
      if (kIsWeb) {
        await _initWeb();
        final list = await getFavouriteStations();
        list.removeWhere((s) => s['code'] == code);
        _prefs?.setString('fav_stations', jsonEncode(list));
        return;
      }
      final db = await instance;
      await db.delete(
        'favourite_stations',
        where: 'code = ?',
        whereArgs: [code],
      );
    } catch (_) {}
  }

  static Future<bool> isFavouriteStation(String code) async {
    try {
      final list = await getFavouriteStations();
      return list.any((s) => s['code'] == code);
    } catch (_) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getFavouriteStations() async {
    try {
      if (kIsWeb) {
        await _initWeb();
        final str = _prefs?.getString('fav_stations');
        if (str == null) return [];
        final decoded = jsonDecode(str) as List;
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      final db = await instance;
      return await db.query('favourite_stations', orderBy: 'added DESC');
    } catch (_) {
      return const [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 5. PERSISTENT STATION METADATA
  // ═══════════════════════════════════════════════════════════════════
  static Future<void> saveStationMetadata(
    Iterable<Map<String, dynamic>> stations,
  ) async {
    final normalized = <String, Map<String, dynamic>>{};
    for (final station in stations) {
      final code =
          (station['code'] ??
                  station['stationCode'] ??
                  station['stnCode'] ??
                  '')
              .toString()
              .trim()
              .toUpperCase();
      if (code.isEmpty) continue;
      normalized[code] = {...station, 'code': code};
    }
    if (normalized.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (kIsWeb) {
      await _initWeb();
      for (final entry in normalized.entries) {
        final key = 'station_metadata_${entry.key}';
        final raw = _prefs?.getString(key);
        final existing = raw == null
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(jsonDecode(raw) as Map);
        final merged = {...existing, ...entry.value, 'code': entry.key};
        await _prefs?.setString(key, jsonEncode(merged));
      }
      return;
    }

    final db = await instance;
    await db.transaction((txn) async {
      for (final entry in normalized.entries) {
        final rows = await txn.query(
          'station_metadata',
          columns: ['data'],
          where: 'code = ?',
          whereArgs: [entry.key],
          limit: 1,
        );
        final existing = rows.isEmpty
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(
                jsonDecode(rows.first['data']! as String) as Map,
              );
        final merged = {...existing, ...entry.value, 'code': entry.key};
        await txn.insert('station_metadata', {
          'code': entry.key,
          'data': jsonEncode(merged),
          'updated': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  static Future<List<Map<String, dynamic>>> getStationMetadata() async {
    if (kIsWeb) {
      await _initWeb();
      final metadata = <Map<String, dynamic>>[];
      for (final key in _prefs?.getKeys() ?? <String>{}) {
        if (!key.startsWith('station_metadata_')) continue;
        final raw = _prefs?.getString(key);
        if (raw == null) continue;
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          metadata.add(Map<String, dynamic>.from(decoded));
        }
      }
      return metadata;
    }

    final db = await instance;
    final rows = await db.query('station_metadata', columns: ['data']);
    return rows
        .map(
          (row) => Map<String, dynamic>.from(
            jsonDecode(row['data']! as String) as Map,
          ),
        )
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 6. MAINTENANCE
  // ═══════════════════════════════════════════════════════════════════
  static Future<void> wipeAll() async {
    try {
      if (kIsWeb) {
        await _initWeb();
        final keys = _prefs?.getKeys() ?? {};
        for (final k in keys.toList()) {
          _prefs?.remove(k);
        }
        return;
      }
      final db = await instance;
      await db.delete('cache');
      await db.delete('search_history');
      await db.delete('tracked_trains');
      await db.delete('favourite_stations');
      await db.delete('station_metadata');
      await db.execute('VACUUM');
    } catch (_) {}
  }

  static Future<void> vacuum() async {}

  static Future<void> dispose() async {
    await _db?.close();
    _db = null;
  }
}
