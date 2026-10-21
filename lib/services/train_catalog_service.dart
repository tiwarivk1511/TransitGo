import 'dart:async';
import 'package:flutter/foundation.dart';

import '../core/cache/offline_cache.dart';
import '../data/sources/railradar_source.dart';

/// Manages pre-fetching, storing, and background enrichment of Indian Railways
/// train numbers and names for sub-millisecond local autocomplete search.
class TrainCatalogService {
  static bool _initializing = false;
  static bool _bulkEnriching = false;

  /// App startup entry point. Fetches official NTES trains lookup Map and live map catalog into SQLite.
  static Future<void> initCatalog() async {
    if (_initializing) return;
    _initializing = true;

    try {
      debugPrint('[TrainCatalogService] Starting catalog initialization...');

      // 1. Fetch official RailRadar NTES trains lookup Map (5,000+ Trains)
      try {
        final ntesMap = await RailRadarSource.fetchNtesTrainLookup();
        if (ntesMap != null && ntesMap.isNotEmpty) {
          final ntesList = <Map<String, dynamic>>[];
          ntesMap.forEach((number, name) {
            if (number.isNotEmpty && name.isNotEmpty) {
              ntesList.add({
                'number': number,
                'name': name,
                'source': '',
                'destination': '',
              });
            }
          });
          if (ntesList.isNotEmpty) {
            await OfflineCache.saveTrainCatalog(ntesList);
            debugPrint(
              '✅ [TrainCatalogService] Loaded ${ntesList.length} NTES lookup trains into SQLite',
            );
          }
        }
      } catch (e) {
        debugPrint('[TrainCatalogService] NTES lookup error: $e');
      }

      // 3. Fetch live map catalog for dynamic updates
      try {
        final liveMapList = await RailRadarSource.liveMap(
          timeout: const Duration(seconds: 4),
        );

        if (liveMapList != null && liveMapList.isNotEmpty) {
          final parsedTrains = <Map<String, dynamic>>[];

          for (final item in liveMapList) {
            String no = '';
            String name = '';
            String src = '';
            String dst = '';

            if (item is List && item.isNotEmpty) {
              no = item[0]?.toString().trim() ?? '';
              if (item.length > 1) {
                final rawName = item[1]?.toString().trim() ?? '';
                if (!RegExp(r'^\d+$').hasMatch(rawName) && rawName.length >= 3) {
                  name = rawName;
                }
              }
            } else if (item is Map) {
              no = (item['train_number'] ?? item['number'] ?? item['trainNo'] ?? '')
                  .toString()
                  .trim();
              final rawName = (item['train_name'] ?? item['name'] ?? '').toString().trim();
              if (!RegExp(r'^\d+$').hasMatch(rawName) && rawName.length >= 3) {
                name = rawName;
              }
              src = (item['source'] ?? item['from'] ?? '').toString().trim();
              dst = (item['destination'] ?? item['to'] ?? '').toString().trim();
            }

            if (no.isNotEmpty) {
              parsedTrains.add({
                'number': no,
                'name': name.isNotEmpty ? name : 'Train $no',
                'source': src,
                'destination': dst,
              });
            }
          }

          if (parsedTrains.isNotEmpty) {
            await OfflineCache.saveTrainCatalog(parsedTrains);
            debugPrint(
              '✅ [TrainCatalogService] Cached ${parsedTrains.length} live map trains in SQLite',
            );
          }
        }
      } catch (_) {}

      // Trigger non-blocking background enrichment
      unawaited(enrichCatalogInBackground());
      unawaited(bulkEnrichCatalog());
    } catch (e) {
      debugPrint('[TrainCatalogService] Catalog init failed: $e');
    } finally {
      _initializing = false;
    }
  }

  /// Small background worker that resolves unresolved train names in chunks
  static Future<void> enrichCatalogInBackground() async {
    try {
      final unresolved = await OfflineCache.getUnresolvedCatalogTrainNumbers(
        limit: 15,
      );
      if (unresolved.isEmpty) return;

      final updatedTrains = <Map<String, dynamic>>[];
      for (final no in unresolved) {
        try {
          final info = await RailRadarSource.fetchSingleTrainName(no);
          final realName = info['name']?.toString().trim() ?? '';
          if (realName.isNotEmpty && !realName.startsWith('Train ') && !RegExp(r'^\d+$').hasMatch(realName)) {
            updatedTrains.add({
              'number': no,
              'name': realName,
              'source': info['source'] ?? '',
              'destination': info['destination'] ?? '',
            });
          }
        } catch (_) {}
      }

      if (updatedTrains.isNotEmpty) {
        await OfflineCache.saveTrainCatalog(updatedTrains);
        debugPrint(
          '✅ [TrainCatalogService] Enriched ${updatedTrains.length} train names',
        );
      }
    } catch (e) {
      debugPrint('[TrainCatalogService] Background enrichment error: $e');
    }
  }

  /// Dedicated separate method for bulk enrichment of larger catalog datasets.
  /// Throttled to prevent server overload while ensuring catalog completeness.
  static Future<void> bulkEnrichCatalog() async {
    if (_bulkEnriching) return;
    _bulkEnriching = true;

    try {
      int totalEnriched = 0;
      while (true) {
        final unresolvedBatch =
            await OfflineCache.getUnresolvedCatalogTrainNumbers(limit: 10);
        if (unresolvedBatch.isEmpty) break;

        final updated = <Map<String, dynamic>>[];

        // Process batch with inter-request delay to keep server load minimal
        for (final no in unresolvedBatch) {
          try {
            final info = await RailRadarSource.fetchSingleTrainName(no);
            final realName = info['name']?.toString().trim() ?? '';
            if (realName.isNotEmpty && !realName.startsWith('Train ') && !RegExp(r'^\d+$').hasMatch(realName)) {
              updated.add({
                'number': no,
                'name': realName,
                'source': info['source'] ?? '',
                'destination': info['destination'] ?? '',
              });
            }
          } catch (_) {}
          await Future.delayed(const Duration(milliseconds: 150));
        }

        if (updated.isNotEmpty) {
          await OfflineCache.saveTrainCatalog(updated);
          totalEnriched += updated.length;
        }

        // Delay between bulk batches to protect server and keep app lightweight
        await Future.delayed(const Duration(milliseconds: 500));

        // Stop if max bulk cycle reached per session to conserve bandwidth
        if (totalEnriched >= 100) break;
      }
      if (totalEnriched > 0) {
        debugPrint(
          '✅ [TrainCatalogService] Bulk enriched $totalEnriched train names',
        );
      }
    } catch (e) {
      debugPrint('[TrainCatalogService] Bulk enrichment error: $e');
    } finally {
      _bulkEnriching = false;
    }
  }
}
