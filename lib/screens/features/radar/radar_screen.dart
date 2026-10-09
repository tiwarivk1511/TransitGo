import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../components/common/apple_glass_card.dart';
import '../../../components/common/error_box.dart';
import '../../../components/common/loading_indicator.dart';
import '../../../components/train/TrainNumberAutocomplete.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../data/models/train.dart';
import '../../../data/sources/railradar_source.dart';
import '../../train_details/train_details_screen.dart';

/// Active train model parsed from RailRadar /app/v1/live-map array format:
/// ["14003", 3, 1, 26.11104, 81.85174, 312.6, 0, 1, 1, "SHJP", 786, "MFL", 789.1, 76.4]
class LiveMapTrain {
  final String number;
  final int typeCode;
  final int direction;
  final double lat;
  final double lng;
  final double bearing;
  final int delayMinutes;
  final bool isHalt;
  final String prevStation;
  final double prevDist;
  final String nextStation;
  final double nextDist;
  final double speed;

  const LiveMapTrain({
    required this.number,
    required this.typeCode,
    required this.direction,
    required this.lat,
    required this.lng,
    required this.bearing,
    required this.delayMinutes,
    required this.isHalt,
    required this.prevStation,
    required this.prevDist,
    required this.nextStation,
    required this.nextDist,
    required this.speed,
  });

  static LiveMapTrain? fromArray(List<dynamic> raw) {
    if (raw.length < 5) return null;
    final lat = _dbl(raw[3]);
    final lng = _dbl(raw[4]);
    if (lat == null || lng == null) return null;

    final numStr = raw[0]?.toString().trim() ?? '';
    if (numStr.isEmpty) return null;

    final typeCode = _int(raw[1]);
    final dir = _int(raw[2]);
    final bearing = _dbl(raw[5]) ?? 0.0;
    final delay = _int(raw[6]);
    final haltFlag = _int(raw[7]);
    final prevSt = raw.length > 9 ? (raw[9]?.toString() ?? '') : '';
    final prevD = raw.length > 10 ? (_dbl(raw[10]) ?? 0.0) : 0.0;
    final nextSt = raw.length > 11 ? (raw[11]?.toString() ?? '') : '';
    final nextD = raw.length > 12 ? (_dbl(raw[12]) ?? 0.0) : 0.0;
    final spd = raw.length > 13 ? (_dbl(raw[13]) ?? 0.0) : 0.0;

    return LiveMapTrain(
      number: numStr,
      typeCode: typeCode,
      direction: dir,
      lat: lat,
      lng: lng,
      bearing: bearing,
      delayMinutes: delay,
      isHalt: haltFlag == 1,
      prevStation: prevSt,
      prevDist: prevD,
      nextStation: nextSt,
      nextDist: nextD,
      speed: spd,
    );
  }

  static double? _dbl(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int _int(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  bool get isDelayed => delayMinutes > 0;

  String get typeCategory {
    switch (typeCode) {
      case 1:
        return 'Vande Bharat / Rajdhani';
      case 2:
        return 'Superfast / Shatabdi';
      case 3:
        return 'Express / Mail';
      case 4:
        return 'Duronto Express';
      case 6:
        return 'Suburban / MEMU';
      case 7:
        return 'Passenger';
      case 8:
        return 'Special Train';
      default:
        return 'Express';
    }
  }

  Color get statusColor {
    if (delayMinutes > 30) return const Color(0xFFFF375F);
    if (delayMinutes > 0) return const Color(0xFFFF9F0A);
    return const Color(0xFF30D158);
  }
}

enum _MapFilter { all, onTime, delayed, majorLate, halt }

class ScheduleScreen extends StatefulWidget {
  final String? initialStationCode;

  const ScheduleScreen({super.key, this.initialStationCode});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with WidgetsBindingObserver {
  final _mapController = MapController();
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  List<LiveMapTrain> _allTrains = [];
  LiveMapTrain? _selectedTrain;

  // Single train live tracking data fetched on tap:
  // https://railradar.in/app/v1/trains/{train_number}/live?geometry=true&format=polyline&includeCoordinates=true
  Map<String, dynamic>? _selectedTrainDetails;
  List<LatLng> _selectedPolyline = [];
  bool _fetchingDetails = false;

  // Map Tile Mode:
  // 0 = Google Hybrid Satellite + Transit (https://mt1.google.com/vt/lyrs=y,transit&x={x}&y={y}&z={z})
  // 1 = Google Standard Roadmap + Transit (https://mt1.google.com/vt/lyrs=m,transit&x={x}&y={y}&z={z})
  // 2 = CartoDB Dark Matter
  int _mapLayerMode = 0;

  bool _loading = true;
  bool _refreshing = false;
  bool _mapReady = false;
  String? _error;
  DateTime? _lastFetch;
  Timer? _autoRefreshTimer;

  TrainTracking? _selectedTrainTracking;

  _MapFilter _filter = _MapFilter.all;

  static const _indiaCenter = LatLng(22.5937, 78.9629);
  static const _defaultZoom = 5.2;

  double get _currentZoom {
    if (!_mapReady) return _defaultZoom;
    try {
      return _mapController.camera.zoom;
    } catch (_) {
      return _defaultZoom;
    }
  }

  LatLng get _currentCenter {
    if (!_mapReady) return _indiaCenter;
    try {
      return _mapController.camera.center;
    } catch (_) {
      return _indiaCenter;
    }
  }

  String get _tileUrl {
    switch (_mapLayerMode) {
      case 0:
        return 'https://mt{s}.google.com/vt/lyrs=y,transit&x={x}&y={y}&z={z}';
      case 1:
        return 'https://mt{s}.google.com/vt/lyrs=m,transit&x={x}&y={y}&z={z}';
      case 2:
      default:
        return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
    }
  }

  List<String> get _tileSubdomains {
    if (_mapLayerMode == 2) return const ['a', 'b', 'c', 'd'];
    return const ['0', '1', '2', '3'];
  }

  String get _mapLayerLabel {
    switch (_mapLayerMode) {
      case 0:
        return 'Google Satellite Transit';
      case 1:
        return 'Google Standard Transit';
      case 2:
      default:
        return 'CartoDB Dark Vector';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchLiveMap();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _fetchLiveMap(isBackground: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _fetchLiveMap(isBackground: true);
    }
  }

  Future<void> _fetchLiveMap({bool isBackground = false}) async {
    if (_refreshing) return;
    if (!isBackground && mounted) {
      setState(() {
        _loading = _allTrains.isEmpty;
        _refreshing = _allTrains.isNotEmpty;
        _error = null;
      });
    }

    try {
      final rawList = await RailRadarSource.liveMap();
      if (!mounted) return;

      if (rawList != null) {
        final parsed = <LiveMapTrain>[];
        for (final item in rawList) {
          if (item is List) {
            final t = LiveMapTrain.fromArray(item);
            if (t != null) parsed.add(t);
          }
        }

        setState(() {
          _allTrains = parsed;
          _loading = false;
          _refreshing = false;
          _lastFetch = DateTime.now();
          _error = null;
        });

        if (_selectedTrain != null) {
          final match = _allTrains.firstWhere(
            (t) => t.number == _selectedTrain!.number,
            orElse: () => _selectedTrain!,
          );
          _selectedTrain = match;
        }
      } else {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _refreshing = false;
          if (_allTrains.isEmpty) {
            _error = 'Failed to load national live map data.';
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        if (_allTrains.isEmpty) {
          _error = 'Error connecting to live radar feed.';
        }
      });
    }
  }

  List<LiveMapTrain> get _filteredTrains {
    switch (_filter) {
      case _MapFilter.onTime:
        return _allTrains.where((t) => t.delayMinutes <= 0).toList();
      case _MapFilter.delayed:
        return _allTrains.where((t) => t.delayMinutes > 0).toList();
      case _MapFilter.majorLate:
        return _allTrains.where((t) => t.delayMinutes > 30).toList();
      case _MapFilter.halt:
        return _allTrains.where((t) => t.isHalt).toList();
      case _MapFilter.all:
        return _allTrains;
    }
  }

  /// Tapping a train marker or search item triggers live train details fetch:
  /// https://railradar.in/app/v1/trains/{train_number}/live?geometry=true&format=polyline&includeCoordinates=true
  void _onTrainTapped(LiveMapTrain train) async {
    setState(() {
      _selectedTrain = train;
      _fetchingDetails = true;
      _selectedTrainDetails = null;
      _selectedTrainTracking = null;
      _selectedPolyline = [];
    });

    if (_mapReady) {
      try {
        _mapController.move(LatLng(train.lat, train.lng), 9.0);
      } catch (_) {}
    }

    try {
      final details = await RailRadarSource.liveTracking(
        train.number,
        includeGeometry: true,
      );

      if (!mounted) return;
      if (_selectedTrain?.number == train.number) {
        TrainTracking? tracking;
        List<LatLng> polylinePoints = [];

        if (details != null) {
          tracking = TrainTracking.parse(details, train.number);
          polylinePoints = _getRoutePoints(tracking);
        }

        setState(() {
          _selectedTrainDetails = details;
          _selectedTrainTracking = tracking;
          _selectedPolyline = polylinePoints;
          _fetchingDetails = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _fetchingDetails = false);
      }
    }
  }

  LatLng? _positionForStop(TrainTracking data, TrainRouteStop stop) {
    for (final geoStop in data.geoStops) {
      if (geoStop.latLng == null) continue;
      if ((stop.sequence > 0 && geoStop.sequence == stop.sequence) ||
          (stop.stationCode.isNotEmpty &&
              geoStop.code.toUpperCase() == stop.stationCode.toUpperCase())) {
        return geoStop.latLng;
      }
    }
    return null;
  }

  List<LatLng> _snapStationAnchorsToTrack(List<LatLng> polyline, TrainTracking d) {
    if (polyline.length < 2) return polyline;

    final snapped = List<LatLng>.from(polyline);
    const distance = Distance();

    final stationPoints = <LatLng>[];
    for (final stop in d.route) {
      final pos = _positionForStop(d, stop);
      if (pos != null && pos.latitude.isFinite && pos.longitude.isFinite) {
        stationPoints.add(pos);
      }
    }

    for (final stnPos in stationPoints) {
      double minMeters = double.infinity;
      int minIndex = 0;

      for (int i = 0; i < snapped.length - 1; i++) {
        final a = snapped[i];
        final b = snapped[i + 1];
        final proj = _projectOnSegment(stnPos, a, b);
        final distMeters = distance.as(LengthUnit.Meter, stnPos, proj);

        if (distMeters < minMeters) {
          minMeters = distMeters;
          minIndex = i;
        }
      }

      if (minMeters <= 350.0) {
        snapped[minIndex] = stnPos;
      }
    }

    return snapped;
  }

  List<LatLng> _getRoutePoints(TrainTracking d) {
    // 1. High-resolution decoded railway track polyline geometry
    if (d.routeGeometry.length >= 2) {
      return _snapStationAnchorsToTrack(d.routeGeometry, d);
    }

    // 2. Sequential station coordinates connecting official journey stops with smooth Catmull-Rom railway curvature
    final rawPoints = <LatLng>[];
    final seenKeys = <String>{};

    for (final stop in d.route) {
      final pos = _positionForStop(d, stop);
      if (pos != null &&
          pos.latitude.isFinite &&
          pos.longitude.isFinite &&
          pos.latitude >= -90.0 &&
          pos.latitude <= 90.0 &&
          pos.longitude >= -180.0 &&
          pos.longitude <= 180.0) {
        final key = '${pos.latitude.toStringAsFixed(4)},${pos.longitude.toStringAsFixed(4)}';
        if (seenKeys.add(key)) {
          rawPoints.add(pos);
        }
      }
    }

    if (rawPoints.length < 2 && d.geoStops.isNotEmpty) {
      for (final stop in d.geoStops) {
        final pos = stop.latLng;
        if (pos != null &&
            pos.latitude.isFinite &&
            pos.longitude.isFinite &&
            pos.latitude >= -90.0 &&
            pos.latitude <= 90.0 &&
            pos.longitude >= -180.0 &&
            pos.longitude <= 180.0) {
          final key = '${pos.latitude.toStringAsFixed(4)},${pos.longitude.toStringAsFixed(4)}';
          if (seenKeys.add(key)) {
            rawPoints.add(pos);
          }
        }
      }
    }

    if (rawPoints.length < 2) return const [];

    return _smoothCurvedPolyline(rawPoints, samplesPerSegment: 8);
  }

  LatLng _projectOnSegment(LatLng p, LatLng a, LatLng b) {
    final ax = a.latitude;
    final ay = a.longitude;
    final bx = b.latitude;
    final by = b.longitude;
    final px = p.latitude;
    final py = p.longitude;

    final dx = bx - ax;
    final dy = by - ay;

    if (dx == 0 && dy == 0) return a;

    final t = (((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)).clamp(0.0, 1.0);
    return LatLng(ax + t * dx, ay + t * dy);
  }

  List<LatLng> _coveredSlice(TrainTracking d, LatLng trainPos, List<LatLng> routePoints) {
    if (routePoints.length < 2) return const [];

    int bestIndex = 0;
    LatLng bestProj = routePoints.first;
    double minSqDist = double.infinity;

    for (int i = 0; i < routePoints.length - 1; i++) {
      final a = routePoints[i];
      final b = routePoints[i + 1];
      final proj = _projectOnSegment(trainPos, a, b);

      final dLat = trainPos.latitude - proj.latitude;
      final dLng = trainPos.longitude - proj.longitude;
      final sqDist = dLat * dLat + dLng * dLng;

      if (sqDist < minSqDist) {
        minSqDist = sqDist;
        bestIndex = i;
        bestProj = proj;
      }
    }

    final slice = routePoints.sublist(0, bestIndex + 1).toList();
    slice.add(bestProj);
    return slice.length >= 2 ? slice : const [];
  }

  List<LatLng> _smoothCurvedPolyline(List<LatLng> points, {int samplesPerSegment = 8}) {
    if (points.length < 3) return points;

    final smoothed = <LatLng>[];
    final count = points.length;

    for (var i = 0; i < count - 1; i++) {
      final p0 = points[i == 0 ? 0 : i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = points[i + 2 >= count ? count - 1 : i + 2];

      for (var step = 0; step < samplesPerSegment; step++) {
        final t = step / samplesPerSegment;
        final t2 = t * t;
        final t3 = t2 * t;

        final f0 = -0.5 * t3 + t2 - 0.5 * t;
        final f1 = 1.5 * t3 - 2.5 * t2 + 1.0;
        final f2 = -1.5 * t3 + 2.0 * t2 + 0.5 * t;
        final f3 = 0.5 * t3 - 0.5 * t2;

        final lat = p0.latitude * f0 + p1.latitude * f1 + p2.latitude * f2 + p3.latitude * f3;
        final lng = p0.longitude * f0 + p1.longitude * f1 + p2.longitude * f2 + p3.longitude * f3;

        if (lat.isFinite &&
            lng.isFinite &&
            lat >= -90.0 &&
            lat <= 90.0 &&
            lng >= -180.0 &&
            lng <= 180.0) {
          smoothed.add(LatLng(lat, lng));
        }
      }
    }
    smoothed.add(points.last);
    return smoothed;
  }

  /// Decodes Google/OSM encodedPolyline string to List of LatLng points
  List<LatLng> _decodePolyline(String encoded) {
    if (encoded.isEmpty) return const [];
    final List<LatLng> points = [];
    int index = 0;
    final int len = encoded.length;
    int lat = 0;
    int lng = 0;

    try {
      while (index < len) {
        int b;
        int shift = 0;
        int result = 0;
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        final int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lat += dlat;

        shift = 0;
        result = 0;
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        final int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lng += dlng;

        final pLat = lat / 1E5;
        final pLng = lng / 1E5;
        if (pLat.isFinite &&
            pLng.isFinite &&
            pLat >= -90.0 &&
            pLat <= 90.0 &&
            pLng >= -180.0 &&
            pLng <= 180.0) {
          points.add(LatLng(pLat, pLng));
        }
      }
    } catch (_) {}
    return points;
  }

  void _recenterMap() {
    if (_mapReady) {
      try {
        _mapController.move(_indiaCenter, _defaultZoom);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDarkMode;
    final bgColor = isDark ? const Color(0xFF09090C) : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF16161C) : const Color(0xFFFFFFFF);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? Colors.white54 : const Color(0xFF8E8E93);
    final borderCol = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE5E5EA);

    final filtered = _filteredTrains;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // ── 1. Interactive Vector/Raster Live Google Map Layer ───────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _indiaCenter,
              initialZoom: _defaultZoom,
              minZoom: 3.5,
              maxZoom: 18.0,
              onMapReady: () {
                if (mounted) {
                  setState(() => _mapReady = true);
                }
              },
              onTap: (_, _) {
                if (_selectedTrain != null) {
                  setState(() {
                    _selectedTrain = null;
                    _selectedTrainDetails = null;
                    _selectedPolyline = [];
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _tileUrl,
                fallbackUrl: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: _tileSubdomains,
                userAgentPackageName: 'com.transitgo.app',
                tileProvider: NetworkTileProvider(
                  headers: {
                    'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
                  },
                ),
                errorTileCallback: (tile, error, stackTrace) {
                  if (kDebugMode) debugPrint('[ScheduleTileError] Handshake / Network tile error for ${tile.coordinates}: $error');
                },
              ),
              if (_selectedPolyline.length >= 2) ...[
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _selectedPolyline,
                      strokeWidth: 8.5,
                      color: const Color(0xFFFF375F).withValues(alpha: 0.28),
                    ),
                    Polyline(
                      points: _selectedPolyline,
                      strokeWidth: 4.0,
                      color: const Color(0xFFFF375F),
                    ),
                  ],
                ),
                if (_selectedTrainTracking != null && _selectedTrain != null) ...[
                  () {
                    final trainPos = LatLng(_selectedTrain!.lat, _selectedTrain!.lng);
                    final covered = _coveredSlice(_selectedTrainTracking!, trainPos, _selectedPolyline);
                    if (covered.length < 2) return const SizedBox.shrink();
                    return PolylineLayer(
                      polylines: [
                        Polyline(
                          points: covered,
                          color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1C1C1E),
                          strokeWidth: 3.5,
                        ),
                      ],
                    );
                  }(),
                ],
              ],
              MarkerLayer(
                markers: _buildMarkers(filtered, isDark),
              ),
            ],
          ),

          // ── 2. Top Header & Search Bar ──────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _topBar(isDark, cardBg, textPrimary, textSecondary, borderCol),
                  const SizedBox(height: 8),
                  _categoryFilterRow(cardBg, textPrimary, textSecondary, borderCol),
                ],
              ),
            ),
          ),

          // ── 3. Loading / Error Indicators ────────────────────────────
          if (_loading)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: borderCol),
                ),
                child: const LoadingIndicator(
                  color: Color(0xFFFF375F),
                  label: 'Fetching national live radar map…',
                ),
              ),
            )
          else if (_error != null && _allTrains.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ErrorBox(
                  message: _error!,
                  onRetry: () => _fetchLiveMap(isBackground: false),
                ),
              ),
            ),

          // ── 4. Right Side Floating Map Controls ──────────────────────
          Positioned(
            right: 16,
            bottom: _selectedTrain != null ? 310 : 32,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _mapControlButton(
                  icon: CupertinoIcons.layers_fill,
                  onPressed: () {
                    setState(() {
                      _mapLayerMode = (_mapLayerMode + 1) % 3;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Map Style: $_mapLayerLabel', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: cardBg,
                      ),
                    );
                  },
                  cardBg: cardBg,
                  borderCol: borderCol,
                  iconColor: const Color(0xFF0A84FF),
                ),
                const SizedBox(height: 8),
                _mapControlButton(
                  icon: CupertinoIcons.location_fill,
                  onPressed: _recenterMap,
                  cardBg: cardBg,
                  borderCol: borderCol,
                  iconColor: const Color(0xFFFF375F),
                ),
                const SizedBox(height: 8),
                _mapControlButton(
                  icon: CupertinoIcons.plus,
                  onPressed: () {
                    if (_mapReady) {
                      try {
                        _mapController.move(_currentCenter, _currentZoom + 1);
                      } catch (_) {}
                    }
                  },
                  cardBg: cardBg,
                  borderCol: borderCol,
                  iconColor: textPrimary,
                ),
                const SizedBox(height: 8),
                _mapControlButton(
                  icon: CupertinoIcons.minus,
                  onPressed: () {
                    if (_mapReady) {
                      try {
                        _mapController.move(_currentCenter, _currentZoom - 1);
                      } catch (_) {}
                    }
                  },
                  cardBg: cardBg,
                  borderCol: borderCol,
                  iconColor: textPrimary,
                ),
              ],
            ),
          ),

          // ── 5. Bottom Selected Train Detail Slider Sheet ─────────────
          if (_selectedTrain != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _selectedTrainCard(
                _selectedTrain!,
                cardBg,
                textPrimary,
                textSecondary,
                borderCol,
              ),
            ),
        ],
      ),
    );
  }

  Widget _topBar(bool isDark, Color cardBg, Color textPrimary,
      Color textSecondary, Color borderCol) {
    final onTimeCount = _allTrains.where((t) => t.delayMinutes <= 0).length;
    final delayedCount = _allTrains.where((t) => t.delayMinutes > 0).length;

    return AppleGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: BorderRadius.circular(22),
      blurSigma: 14.0,
      border: Border.all(color: borderCol),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(CupertinoIcons.chevron_back, color: textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Google Live Radar Map',
                          style: GoogleFonts.inter(
                            color: textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF30D158),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${_allTrains.length} active trains • $onTimeCount on time · $delayedCount delayed${_lastFetch != null ? " · ${_lastFetch!.hour.toString().padLeft(2, '0')}:${_lastFetch!.minute.toString().padLeft(2, '0')}" : ""}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isDark
                      ? CupertinoIcons.sun_max_fill
                      : CupertinoIcons.moon_stars_fill,
                  color: isDark ? const Color(0xFFFFD60A) : const Color(0xFF0A84FF),
                  size: 18,
                ),
                onPressed: () async {
                  await ThemeController.instance.toggleTheme();
                  if (mounted) setState(() {});
                },
              ),
              IconButton(
                tooltip: 'Refresh Radar',
                icon: _refreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFF375F),
                        ),
                      )
                    : const Icon(
                        CupertinoIcons.refresh,
                        color: Color(0xFFFF375F),
                        size: 18,
                      ),
                onPressed: () => _fetchLiveMap(isBackground: false),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Train Number & Station Autocomplete Search Field
          TrainNumberAutocomplete(
            controller: _searchCtrl,
            hint: 'Search train number (e.g. 14003) or station...',
            icon: CupertinoIcons.search,
            onTrainSelected: (selectedTrainMap) {
              final trainNo = selectedTrainMap['number'] ?? '';
              setState(() => _searchQuery = trainNo);
              final match = _allTrains.where((t) => t.number == trainNo.trim()).firstOrNull;
              if (match != null) {
                _onTrainTapped(match);
              } else if (trainNo.isNotEmpty) {
                final dummyTrain = LiveMapTrain(
                  number: trainNo,
                  typeCode: 1,
                  direction: 1,
                  lat: 28.6139,
                  lng: 77.2090,
                  bearing: 0.0,
                  delayMinutes: 0,
                  isHalt: false,
                  prevStation: selectedTrainMap['source'] ?? '',
                  prevDist: 0.0,
                  nextStation: selectedTrainMap['destination'] ?? '',
                  nextDist: 0.0,
                  speed: 0.0,
                );
                _onTrainTapped(dummyTrain);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _categoryFilterRow(Color cardBg, Color textPrimary,
      Color textSecondary, Color borderCol) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('All Active (${_allTrains.length})', _MapFilter.all, textSecondary, cardBg, borderCol),
          _filterChip('On Time 🟢', _MapFilter.onTime, textSecondary, cardBg, borderCol),
          _filterChip('Delayed ⏰', _MapFilter.delayed, textSecondary, cardBg, borderCol),
          _filterChip('Major Late (>30m) 🚨', _MapFilter.majorLate, textSecondary, cardBg, borderCol),
          _filterChip('Halted 🚉', _MapFilter.halt, textSecondary, cardBg, borderCol),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _MapFilter filterType, Color textSecondary,
      Color cardBg, Color borderCol) {
    final isSelected = _filter == filterType;
    return GestureDetector(
      onTap: () => setState(() => _filter = filterType),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF375F) : cardBg.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFFFF375F) : borderCol),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? Colors.white : textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _mapControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color cardBg,
    required Color borderCol,
    required Color iconColor,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: cardBg.withValues(alpha: 0.92),
        shape: BoxShape.circle,
        border: Border.all(color: borderCol),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor, size: 20),
        onPressed: onPressed,
      ),
    );
  }

  Widget _selectedTrainCard(
    LiveMapTrain t,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
  ) {
    final details = _selectedTrainDetails;
    final trainInfo = details?['train'] is Map ? Map<String, dynamic>.from(details!['train'] as Map) : null;
    final currLoc = details?['currentLocation'] is Map ? Map<String, dynamic>.from(details!['currentLocation'] as Map) : null;
    final prevHalt = details?['previousHalt'] is Map ? Map<String, dynamic>.from(details!['previousHalt'] as Map) : null;
    final nextHalt = details?['nextHalt'] is Map ? Map<String, dynamic>.from(details!['nextHalt'] as Map) : null;

    final name = details?['trainName']?.toString() ?? trainInfo?['name']?.toString() ?? 'Train ${t.number}';
    final type = trainInfo?['type']?.toString() ?? t.typeCategory;
    final srcName = trainInfo?['source']?['name']?.toString() ?? trainInfo?['source']?['code']?.toString() ?? t.prevStation;
    final dstName = trainInfo?['destination']?['name']?.toString() ?? trainInfo?['destination']?['code']?.toString() ?? t.nextStation;

    final delay = details?['delayMinutes'] is num ? (details!['delayMinutes'] as num).toInt() : t.delayMinutes;
    final delayText = delay > 0 ? '+$delay m late' : 'On Time';
    final statusColor = delay > 30 ? const Color(0xFFFF375F) : (delay > 0 ? const Color(0xFFFF9F0A) : const Color(0xFF30D158));

    final currStation = currLoc?['stationName']?.toString() ?? currLoc?['stationCode']?.toString();
    final currStatus = currLoc?['status']?.toString();
    final isAtStation = currStatus == 'at-station' || t.isHalt;

    final coachPos = trainInfo?['coachPosition']?.toString();

    return AppleGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(22),
      blurSigma: 14.0,
      border: Border.all(color: borderCol),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_fetchingDetails)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: Color(0xFFFF375F),
                minHeight: 2.5,
              ),
            ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF375F).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  t.number,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFF375F),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  delayText,
                  style: GoogleFonts.inter(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10.5,
                  ),
                ),
              ),
              if (isAtStation) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'HALTED',
                    style: GoogleFonts.inter(
                      color: Colors.orange,
                      fontWeight: FontWeight.w900,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              IconButton(
                icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 18, color: Colors.grey),
                onPressed: () {
                  setState(() {
                    _selectedTrain = null;
                    _selectedTrainDetails = null;
                    _selectedPolyline = [];
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${srcName.isNotEmpty ? srcName : "Origin"} ➔ ${dstName.isNotEmpty ? dstName : "Destination"} ($type)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(color: textSecondary, fontSize: 11),
          ),
          if (currStation != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(CupertinoIcons.location_fill, size: 12, color: Color(0xFFFF375F)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    isAtStation
                        ? 'Currently at $currStation'
                        : 'Running towards $currStation',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ),
                if (t.speed > 0)
                  Text(
                    '${t.speed.toStringAsFixed(1)} km/h',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF0A84FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ],
          if (prevHalt != null || nextHalt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (prevHalt != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LAST HALT',
                            style: GoogleFonts.inter(color: textSecondary, fontSize: 8, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${prevHalt['stationName']} (${prevHalt['stationCode']})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(color: textPrimary, fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (prevHalt != null && nextHalt != null) const SizedBox(width: 8),
                if (nextHalt != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NEXT HALT',
                            style: GoogleFonts.inter(color: textSecondary, fontSize: 8, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${nextHalt['stationName']} (${nextHalt['stationCode']})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(color: textPrimary, fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (coachPos != null && coachPos.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    'RAKE:',
                    style: GoogleFonts.inter(color: textSecondary, fontSize: 8.5, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    coachPos.replaceAll('-', ' • '),
                    style: GoogleFonts.inter(color: const Color(0xFF0A84FF), fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              icon: const Icon(CupertinoIcons.tram_fill, size: 16),
              label: Text(
                'Full Live Tracking Board',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF375F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TrainDetailsScreen(
                      trainNumber: t.number,
                      trainName: name,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers(List<LiveMapTrain> trains, bool isDark) {
    final markers = <Marker>[];

    final zoom = _currentZoom;
    final limit = zoom < 6.5 ? 300 : trains.length;
    final renderList = trains.take(limit);

    for (final t in renderList) {
      final isSelected = _selectedTrain?.number == t.number;
      final size = isSelected ? 32.0 : (zoom < 6.0 ? 16.0 : 22.0);

      markers.add(
        Marker(
          point: LatLng(t.lat, t.lng),
          width: size,
          height: size,
          child: GestureDetector(
            onTap: () => _onTrainTapped(t),
            child: Transform.rotate(
              angle: (t.bearing * math.pi) / 180.0,
              child: Container(
                decoration: BoxDecoration(
                  color: t.statusColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.black26,
                    width: isSelected ? 2.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: t.statusColor.withValues(alpha: 0.5),
                      blurRadius: isSelected ? 8 : 3,
                      spreadRadius: isSelected ? 2 : 0,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    CupertinoIcons.arrow_up,
                    color: Colors.white,
                    size: size * 0.55,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return markers;
  }
}
