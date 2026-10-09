import '../data/models/station.dart';
import '../data/sources/station_source.dart';

class StationService {
  static Future<List<Station>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    // Offline only — instant, works without network.
    return StationSource.search(q);
  }

  static Station? byCode(String code) => StationSource.byCode(code);
}

// import '../data/models/station.dart';
// import '../data/sources/ntes_source.dart';
// import '../data/sources/station_source.dart';
//
// class StationService {
//   static Future<List<Station>> search(String query) async {
//     final q = query.trim();
//     if (q.isEmpty) return [];
//
//     // Offline first — instant
//     final local = StationSource.search(q);
//     if (local.isNotEmpty) return local;
//
//     // Fallback: NTES (if bundled list misses something)
//     final d = await NtesSource.liveTracking(''); // no-op fallback
//     return [];
//   }
//
//   static Station? byCode(String code) => StationSource.byCode(code);
// }