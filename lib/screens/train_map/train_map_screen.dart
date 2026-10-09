import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../components/common/error_box.dart';
import '../../components/common/live_speed_card.dart';
import '../../core/cache/offline_cache.dart';
import '../../core/theme/theme_controller.dart';
import '../../data/models/train.dart';
import '../../services/train_service.dart';
import '../train_details/train_details_screen.dart';

class TrainMapScreen extends StatefulWidget {
  final String trainNumber;
  final String trainName;

  const TrainMapScreen({
    super.key,
    required this.trainNumber,
    required this.trainName,
  });

  @override
  State<TrainMapScreen> createState() => _TrainMapScreenState();
}

class _TrainMapScreenState extends State<TrainMapScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _mapController = MapController();
  late final AnimationController _positionController;

  TrainTracking? _data;
  LatLng? _displayedTrainPosition;
  LatLng? _positionFrom;
  LatLng? _positionTo;
  bool _loading = true;
  String? _error;
  DateTime? _lastFetch;
  bool _didInitialFit = false;
  bool _mapReady = false;
  bool _followTrain = true;
  StreamSubscription<TrainTracking>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _positionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addListener(_updateAnimatedPosition);

    _loadCacheFirst();
    _subscribe();
  }

  Future<void> _loadCacheFirst() async {
    final cleanNo = widget.trainNumber.trim().split(' - ').first;
    final cached = await OfflineCache.get('live_$cleanNo');
    if (cached is Map && mounted && _data == null) {
      try {
        final parsed = TrainTracking.parse(Map<String, dynamic>.from(cached), cleanNo);
        final target = _trainLatLng(parsed);
        setState(() {
          _data = parsed;
          _loading = false;
        });
        _animateToPosition(target);
        if (parsed.routeGeometry.length >= 2) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _fitRoute());
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _positionController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _sub?.cancel();
      _sub = null;
    } else if (state == AppLifecycleState.resumed) {
      _subscribe();
    }
  }

  void _subscribe() {
    _sub?.cancel();
    _sub =
        TrainService.stream(
          widget.trainNumber,
          interval: const Duration(seconds: 30),
          includeGeometry: true,
        ).listen(
          _onData,
          onError: (_) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              if (_data == null) _error = 'Failed to load map.';
            });
          },
        );
  }

  void _onData(TrainTracking d) {
    if (!mounted) return;
    final target = _trainLatLng(d);
    setState(() {
      _data = d;
      _loading = false;
      _error = null;
      _lastFetch = DateTime.now();
    });
    _animateToPosition(target);

    // First successful load with geometry → fit route
    if (!_didInitialFit && d.routeGeometry.length >= 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitRoute());
    } else if (!_didInitialFit && target != null) {
      _didInitialFit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _mapReady) {
          _mapController.move(target, 12);
        }
      });
    }
  }

  void _animateToPosition(LatLng? target) {
    if (target == null) {
      _positionController.stop();
      _positionFrom = null;
      _positionTo = null;
      if (_displayedTrainPosition != null) {
        setState(() => _displayedTrainPosition = null);
      }
      return;
    }
    final current = _displayedTrainPosition;
    if (current == null) {
      setState(() => _displayedTrainPosition = target);
      return;
    }
    if (current.latitude == target.latitude &&
        current.longitude == target.longitude) {
      return;
    }

    _positionController.stop();
    _positionFrom = current;
    _positionTo = target;
    _positionController.forward(from: 0);
  }

  void _updateAnimatedPosition() {
    final from = _positionFrom;
    final to = _positionTo;
    if (!mounted || from == null || to == null) return;

    final t = Curves.easeInOut.transform(_positionController.value);
    final position = LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
    setState(() => _displayedTrainPosition = position);

    if (_followTrain && _mapReady) {
      _mapController.move(position, _mapController.camera.zoom);
    }
  }

  void _fitRoute() {
    final d = _data;
    if (d == null || !_mapReady) return;
    final points = _getRoutePoints(d);
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 12);
      _didInitialFit = true;
      return;
    }
    final valid = points.where((p) => p.latitude.isFinite && p.longitude.isFinite).toList();
    if (valid.length < 2) return;

    try {
      final bounds = LatLngBounds.fromPoints(valid);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(56)),
      );
      _didInitialFit = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[FitRouteError] LatLngBounds failed: $e');
    }
  }

  void _centerOnTrain() {
    final d = _data;
    if (d == null) return;
    final loc = _trainLatLng(d);
    if (loc != null && _mapReady) {
      _mapController.move(loc, 12);
      setState(() => _followTrain = true);
    }
  }

  LatLng? _trainLatLng(TrainTracking d) {
    final curCode = d.currentLocation.stationCode.trim().toUpperCase();
    final curName = d.currentLocation.stationName.trim().toLowerCase();
    final curSeq = d.currentLocation.sequence;
    final status = d.status.toLowerCase();
    final isHaltOrAtStation = d.currentLocation.isHalt ||
        status == 'at-station' ||
        status == 'not-started' ||
        status == 'reached' ||
        status == 'completed' ||
        (d.currentLocation.speedKmh != null && d.currentLocation.speedKmh! <= 0);

    // 1. If Train is AT A STATION (Halted, At-Station, Not Started, or Speed 0)
    //    MUST return the EXACT station coordinates directly!
    if (isHaltOrAtStation || curCode.isNotEmpty) {
      // First check geoStops
      for (final stop in d.geoStops) {
        if (stop.latLng != null) {
          if ((curSeq > 0 && stop.sequence == curSeq) ||
              (curCode.isNotEmpty && stop.code.toUpperCase() == curCode) ||
              (curName.isNotEmpty && stop.name.toLowerCase() == curName)) {
            return stop.latLng;
          }
        }
      }

      // Check route stops
      if (d.route.isNotEmpty) {
        for (final stop in d.route) {
          if ((curSeq > 0 && stop.sequence == curSeq) ||
              (curCode.isNotEmpty && stop.stationCode.toUpperCase() == curCode) ||
              (curName.isNotEmpty && stop.stationName.toLowerCase() == curName)) {
            final geoMatch = _positionForStop(d, stop);
            if (geoMatch != null) return geoMatch;
          }
        }
      }

      // Check source or destination
      if (status == 'not-started' && d.source?.latLng != null) {
        return d.source!.latLng;
      }
      if ((status == 'reached' || status == 'completed') && d.destination?.latLng != null) {
        return d.destination!.latLng;
      }
    }

    // 2. If Train has GPS coordinates in live payload
    if (d.currentLocation.hasGpsCoordinates && d.currentLocation.latLng != null) {
      return d.currentLocation.latLng;
    }

    // 3. If Train is RUNNING between stations, interpolate along current segment
    final byCurrentSegment = _positionFromCurrentSegment(d);
    if (byCurrentSegment != null) return byCurrentSegment;

    // 4. Interpolate by covered station distance along geometry track
    final covered = d.currentLocation.distanceFromOriginKm;
    if (covered != null && covered.isFinite && covered >= 0) {
      final byStationDistance = _positionAtStationDistance(d, covered);
      if (byStationDistance != null) return byStationDistance;
    }

    // 5. Fallback to origin or first station
    if (d.source?.latLng != null) return d.source!.latLng;
    if (d.geoStops.isNotEmpty && d.geoStops.first.latLng != null) {
      return d.geoStops.first.latLng;
    }

    return null;
  }

  LatLng? _positionAtStationDistance(TrainTracking data, double coveredKm) {
    final positionedStops = <({double distanceKm, LatLng position})>[];
    for (final stop in data.route) {
      if (!stop.distance.isFinite || stop.distance < 0) continue;
      final position = _positionForStop(data, stop);
      if (position == null) continue;
      positionedStops.add((distanceKm: stop.distance, position: position));
    }
    if (positionedStops.length < 2) return null;

    for (var i = 0; i < positionedStops.length - 1; i++) {
      final start = positionedStops[i];
      final end = positionedStops[i + 1];
      if (end.distanceKm <= start.distanceKm ||
          coveredKm < start.distanceKm ||
          coveredKm > end.distanceKm) {
        continue;
      }
      final fraction =
          ((coveredKm - start.distanceKm) / (end.distanceKm - start.distanceKm))
              .clamp(0.0, 1.0);
      return _positionBetweenStops(
        data.routeGeometry,
        start.position,
        end.position,
        fraction,
      );
    }
    return null;
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

  LatLng? _positionFromCurrentSegment(TrainTracking data) {
    final location = data.currentLocation;
    final code = location.stationCode.trim().toUpperCase();
    var currentIndex = -1;
    if (location.sequence > 0) {
      currentIndex = data.route.indexWhere(
        (stop) => stop.sequence == location.sequence,
      );
    }
    if (currentIndex < 0 && code.isNotEmpty) {
      currentIndex = data.route.indexWhere(
        (stop) => stop.stationCode.toUpperCase() == code,
      );
    }
    if (currentIndex < 0) return null;

    final currentStop = data.route[currentIndex];
    final currentPosition = _positionForStop(data, currentStop);
    if (currentPosition == null) return null;
    if (location.isHalt || location.status.toLowerCase() == 'at-station') {
      return currentPosition;
    }

    var nextIndex = currentIndex + 1;
    while (nextIndex < data.route.length &&
        _positionForStop(data, data.route[nextIndex]) == null) {
      nextIndex++;
    }
    if (nextIndex >= data.route.length) return null;
    final nextStop = data.route[nextIndex];
    final nextPosition = _positionForStop(data, nextStop);
    if (nextPosition == null) return null;

    double? progress = location.segmentProgress;
    if (progress != null && progress.isFinite) {
      if (progress > 1 && progress <= 100) progress /= 100;
      if (progress < 0 || progress > 1) progress = null;
    }
    if (progress == null) {
      final distanceSinceStop = location.distanceFromLastStationKm;
      final segmentDistance = nextStop.distance - currentStop.distance;
      if (distanceSinceStop != null &&
          distanceSinceStop.isFinite &&
          distanceSinceStop >= 0 &&
          segmentDistance > 0) {
        progress = (distanceSinceStop / segmentDistance).clamp(0.0, 1.0);
      }
    }
    if (progress == null) return null;

    return _positionBetweenStops(
      data.routeGeometry,
      currentPosition,
      nextPosition,
      progress,
    );
  }

  LatLng _positionBetweenStops(
    List<LatLng> geometry,
    LatLng start,
    LatLng end,
    double fraction,
  ) {
    if (geometry.length < 2) {
      return LatLng(
        start.latitude + (end.latitude - start.latitude) * fraction,
        start.longitude + (end.longitude - start.longitude) * fraction,
      );
    }

    final startIndex = _nearestGeometryIndex(geometry, start);
    final endIndex = _nearestGeometryIndex(geometry, end);
    if (startIndex == null || endIndex == null || startIndex == endIndex) {
      return LatLng(
        start.latitude + (end.latitude - start.latitude) * fraction,
        start.longitude + (end.longitude - start.longitude) * fraction,
      );
    }
    return _positionAlongGeometry(geometry, startIndex, endIndex, fraction);
  }

  int? _nearestGeometryIndex(List<LatLng> geometry, LatLng position) {
    if (geometry.isEmpty) return null;
    const distance = Distance();
    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    for (var i = 0; i < geometry.length; i++) {
      final candidateDistance = distance.as(
        LengthUnit.Meter,
        position,
        geometry[i],
      );
      if (candidateDistance < nearestDistance) {
        nearestIndex = i;
        nearestDistance = candidateDistance;
      }
    }
    return nearestIndex;
  }

  LatLng _positionAlongGeometry(
    List<LatLng> geometry,
    int startIndex,
    int endIndex,
    double fraction,
  ) {
    const distance = Distance();
    final direction = startIndex < endIndex ? 1 : -1;
    final lengths = <double>[];
    var totalLength = 0.0;
    for (var i = startIndex; i != endIndex; i += direction) {
      final length = distance.as(
        LengthUnit.Meter,
        geometry[i],
        geometry[i + direction],
      );
      lengths.add(length);
      totalLength += length;
    }
    if (totalLength <= 0) return geometry[startIndex];

    var remaining = totalLength * fraction.clamp(0.0, 1.0);
    for (var i = 0; i < lengths.length; i++) {
      final length = lengths[i];
      if (remaining <= length || i == lengths.length - 1) {
        final part = length <= 0 ? 0.0 : (remaining / length).clamp(0.0, 1.0);
        final segmentStart = geometry[startIndex + i * direction];
        final segmentEnd = geometry[startIndex + (i + 1) * direction];
        return LatLng(
          segmentStart.latitude +
              (segmentEnd.latitude - segmentStart.latitude) * part,
          segmentStart.longitude +
              (segmentEnd.longitude - segmentStart.longitude) * part,
        );
      }
      remaining -= length;
    }
    return geometry[endIndex];
  }

  LatLng? _positionAtRouteProgress(List<LatLng> geometry, double progress) {
    if (geometry.length < 2) return geometry.isEmpty ? null : geometry.first;

    const distance = Distance();
    final segmentLengths = <double>[];
    var routeLength = 0.0;
    for (var i = 0; i < geometry.length - 1; i++) {
      final length = distance.as(
        LengthUnit.Kilometer,
        geometry[i],
        geometry[i + 1],
      );
      segmentLengths.add(length);
      routeLength += length;
    }
    if (routeLength <= 0) return geometry.first;

    var remaining = routeLength * progress.clamp(0.0, 1.0);
    for (var i = 0; i < segmentLengths.length; i++) {
      final segmentLength = segmentLengths[i];
      if (remaining <= segmentLength || i == segmentLengths.length - 1) {
        final fraction = segmentLength <= 0
            ? 0.0
            : (remaining / segmentLength).clamp(0.0, 1.0);
        final start = geometry[i];
        final end = geometry[i + 1];
        return LatLng(
          start.latitude + (end.latitude - start.latitude) * fraction,
          start.longitude + (end.longitude - start.longitude) * fraction,
        );
      }
      remaining -= segmentLength;
    }
    return geometry.last;
  }

  void _openSpeedTest(TrainTracking d, Color cardBg) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<TrainTracking>(
            stream: TrainService.stream(
              widget.trainNumber,
              interval: const Duration(seconds: 30),
              includeGeometry: true,
            ),
            initialData: d,
            builder: (context, snapshot) {
              final liveData = snapshot.data ?? d;
              return LiveSpeedCard(
                trainLivePosition:
                    liveData.currentLocation.hasGpsCoordinates
                    ? liveData.currentLocation.latLng
                    : null,
                trainRoute: liveData.routeGeometry,
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final isDark = ThemeController.instance.isDarkMode;
        final bgColor = isDark ? const Color(0xFF09090C) : const Color(0xFFF2F2F7);
        final cardBg = isDark ? const Color(0xFF16161C) : const Color(0xFFFFFFFF);
        final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
        final textSecondary = isDark ? Colors.white54 : const Color(0xFF8E8E93);

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: cardBg,
            elevation: 0,
            leading: IconButton(
              tooltip: 'Back',
              icon: Icon(
                CupertinoIcons.chevron_back,
                color: textPrimary,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _data?.trainName ?? widget.trainName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'LIVE MAP • ${widget.trainNumber}',
                  style: GoogleFonts.inter(color: textSecondary, fontSize: 10),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                icon: Icon(CupertinoIcons.refresh_bold, color: textSecondary, size: 16),
                onPressed: _subscribe,
              ),
              IconButton(
                tooltip: 'List view',
                icon: Icon(CupertinoIcons.list_bullet, color: textSecondary, size: 18),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TrainDetailsScreen(
                        trainNumber: widget.trainNumber,
                        trainName: widget.trainName,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: Icon(
                  isDark ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_stars_fill,
                  color: isDark ? const Color(0xFFFFD60A) : const Color(0xFF0A84FF),
                  size: 18,
                ),
                onPressed: () => ThemeController.instance.toggleTheme(),
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF0A84FF)),
                )
              : _error != null && _data == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ErrorBox(message: _error!, onRetry: _subscribe),
                  ),
                )
              : _data == null ||
                    (_data!.routeGeometry.isEmpty &&
                        _trainLatLng(_data!) == null &&
                        _data!.geoStops.every((stop) => stop.latLng == null))
              ? _emptyState(textSecondary)
              : _mapView(_data!, isDark, cardBg, textPrimary, textSecondary),
        );
      },
    );
  }

  Widget _emptyState(Color textSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.map, color: textSecondary, size: 48),
            const SizedBox(height: 12),
            Text(
              'Route geometry not available for this train yet.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: textSecondary),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _subscribe,
              icon: const Icon(CupertinoIcons.refresh, color: Color(0xFF0A84FF)),
              label: Text(
                'Retry',
                style: GoogleFonts.inter(color: const Color(0xFF0A84FF)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapView(TrainTracking d, bool isDark, Color cardBg, Color textPrimary, Color textSecondary) {
    final trainPos = _displayedTrainPosition ?? _trainLatLng(d);
    final routePoints = _getRoutePoints(d);
    final initialCenter =
        trainPos ??
        (routePoints.isNotEmpty
            ? routePoints.first
            : (d.geoStops.any((s) => s.latLng != null)
                ? d.geoStops.firstWhere((stop) => stop.latLng != null).latLng!
                : const LatLng(22.5937, 78.9629)));

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 6,
            minZoom: 3,
            maxZoom: 18,
            onMapReady: () {
              _mapReady = true;
              if (routePoints.isNotEmpty && !_didInitialFit) {
                _didInitialFit = true;
                _fitRoute();
              } else if (trainPos != null && routePoints.isEmpty) {
                _mapController.move(trainPos, 12);
              }
            },
            backgroundColor: isDark ? const Color(0xFF09090C) : const Color(0xFFF2F2F7),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onPositionChanged: (_, hasGesture) {
              if (hasGesture && _followTrain) {
                setState(() => _followTrain = false);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://mt{s}.google.com/vt/lyrs=m,transit&x={x}&y={y}&z={z}',
              fallbackUrl: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
              subdomains: const ['0', '1', '2', '3'],
              userAgentPackageName: 'com.transitgo.app',
              tileProvider: NetworkTileProvider(
                headers: {
                  'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
                },
              ),
              errorTileCallback: (tile, error, stackTrace) {
                if (kDebugMode) debugPrint('[TrainMapTileError] Handshake / Network tile error for ${tile.coordinates}: $error');
              },
              maxZoom: 20,
            ),
            PolylineLayer(
              polylines: routePoints.length < 2
                  ? const <Polyline<Object>>[]
                  : [
                      Polyline(
                        points: routePoints,
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.5)
                            : const Color(0xFF0A84FF).withValues(alpha: 0.25),
                        strokeWidth: 8.0,
                      ),
                      Polyline(
                        points: routePoints,
                        color: isDark
                            ? const Color(0xFF0A84FF)
                            : const Color(0xFF1C1C1E),
                        strokeWidth: 4.5,
                      ),
                    ],
            ),
            if (trainPos != null && routePoints.length >= 2) ...[
              () {
                final covered = _coveredSlice(d, trainPos, routePoints);
                if (covered.length < 2) return const SizedBox.shrink();
                return PolylineLayer(
                  polylines: [
                    Polyline(
                      points: covered,
                      color: isDark
                          ? const Color(0xFF30D158)
                          : const Color(0xFF0A84FF),
                      strokeWidth: 4.5,
                    ),
                  ],
                );
              }(),
            ],
            MarkerLayer(markers: _stationMarkers(d, isDark, cardBg, textPrimary)),
            if (trainPos != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: trainPos,
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    child: const _TrainMarker(),
                  ),
                ],
              ),
          ],
        ),
        Positioned(
          right: 12,
          bottom: 215, // Raised above bottom card so all 3 buttons stay 100% visible
          child: Column(
            children: [
              _mapButton(
                icon: CupertinoIcons.arrow_up_left_arrow_down_right,
                tooltip: 'Fit route',
                onTap: _fitRoute,
                cardBg: cardBg,
                textPrimary: textPrimary,
              ),
              const SizedBox(height: 8),
              _mapButton(
                icon: CupertinoIcons.location,
                tooltip: 'Centre on train',
                active: _followTrain,
                onTap: _centerOnTrain,
                cardBg: cardBg,
                textPrimary: textPrimary,
              ),
              const SizedBox(height: 8),
              _mapButton(
                icon: CupertinoIcons.speedometer,
                tooltip: 'Live speed test',
                cardBg: cardBg,
                textPrimary: textPrimary,
                onTap: () => _openSpeedTest(d, cardBg),
              ),
            ],
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: _InfoCard(
            data: d,
            lastFetch: _lastFetch,
            cardBg: cardBg,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            onSpeedTestTap: () => _openSpeedTest(d, cardBg),
          ),
        ),
      ],
    );
  }

  Widget _mapButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required Color cardBg,
    required Color textPrimary,
    bool active = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? const Color(0xFF0A84FF)
            : cardBg,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              icon,
              size: 18,
              color: active ? Colors.white : textPrimary,
            ),
          ),
        ),
      ),
    );
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
    // 1. High-resolution decoded railway track polyline geometry anchored to station stops
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

  List<Marker> _stationMarkers(TrainTracking d, bool isDark, Color cardBg, Color textPrimary) {
    final markers = <Marker>[];
    final geoByCode = <String, LatLng>{};
    for (final s in d.geoStops) {
      if (s.latLng != null && s.code.isNotEmpty) {
        geoByCode[s.code.toUpperCase()] = s.latLng!;
      }
    }
    if (d.source?.latLng != null) {
      geoByCode[d.source!.code.toUpperCase()] = d.source!.latLng!;
    }
    if (d.destination?.latLng != null) {
      geoByCode[d.destination!.code.toUpperCase()] = d.destination!.latLng!;
    }

    final routeStops = d.route;
    if (routeStops.isEmpty) return markers;

    final firstSeq = routeStops.first.sequence;
    final lastSeq = routeStops.last.sequence;
    final currentCode = d.currentLocation.stationCode.trim().toUpperCase();

    for (var i = 0; i < routeStops.length; i++) {
      final stop = routeStops[i];
      final stCode = stop.stationCode.trim().toUpperCase();
      final pos = geoByCode[stCode];
      if (pos == null) continue;

      final isOrigin = i == 0 || stop.sequence == firstSeq;
      final isDestination = i == routeStops.length - 1 || stop.sequence == lastSeq;
      final isHalt = stop.isHalt;
      final isCurrent = stCode.isNotEmpty && stCode == currentCode;

      // Color specifications requested by user:
      // Origin = Green, Destination = Red, Halts = Yellow, Intermediate Non-Halts = Black
      Color dotColor;
      Color labelBgColor;
      Color labelTextColor;

      if (isCurrent) {
        dotColor = const Color(0xFF0A84FF);
        labelBgColor = const Color(0xFF0A84FF);
        labelTextColor = Colors.white;
      } else if (isOrigin) {
        // GREEN FOR ORIGIN
        dotColor = const Color(0xFF30D158);
        labelBgColor = const Color(0xFF30D158);
        labelTextColor = Colors.white;
      } else if (isDestination) {
        // RED FOR DESTINATION
        dotColor = const Color(0xFFFF375F);
        labelBgColor = const Color(0xFFFF375F);
        labelTextColor = Colors.white;
      } else if (isHalt) {
        // YELLOW FOR COMMERCIAL HALT STATIONS
        dotColor = const Color(0xFFFFD60A);
        labelBgColor = const Color(0xFFFFD60A);
        labelTextColor = Colors.black;
      } else {
        // BLACK FOR NON-HALT INTERMEDIATE STATIONS
        dotColor = isDark ? const Color(0xFF3A3A3C) : const Color(0xFF1C1C1E);
        labelBgColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFF1C1C1E);
        labelTextColor = Colors.white;
      }

      // Non-halt small dot marker for passing stations
      if (!isHalt && !isOrigin && !isDestination && !isCurrent) {
        markers.add(
          Marker(
            point: pos,
            width: 10,
            height: 10,
            alignment: Alignment.center,
            child: Container(
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.2),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 3),
                ],
              ),
            ),
          ),
        );
        continue;
      }

      // Commercial Halts, Origin, Destination, and Current Station Pill Markers
      markers.add(
        Marker(
          point: pos,
          width: 120,
          height: 48,
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: labelBgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white,
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: labelTextColor == Colors.black ? Colors.black : Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${stop.stationCode}${stop.platform != null && stop.platform!.isNotEmpty ? " • P${stop.platform}" : ""}',
                      style: GoogleFonts.inter(
                        color: labelTextColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: isCurrent ? 14 : 10,
                height: isCurrent ? 14 : 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return markers;
  }
}

class _TrainMarker extends StatefulWidget {
  const _TrainMarker();

  @override
  State<_TrainMarker> createState() => _TrainMarkerState();
}

class _TrainMarkerState extends State<_TrainMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.18);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF0A84FF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0A84FF).withValues(alpha: 0.6),
                  blurRadius: 16 * _pulseController.value + 6,
                  spreadRadius: 3 * _pulseController.value + 1,
                ),
              ],
            ),
            child: const Icon(
              CupertinoIcons.tram_fill,
              color: Colors.white,
              size: 22,
            ),
          ),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  final TrainTracking data;
  final DateTime? lastFetch;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback? onSpeedTestTap;

  const _InfoCard({
    required this.data,
    this.lastFetch,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
    this.onSpeedTestTap,
  });

  @override
  Widget build(BuildContext context) {
    final delayed = data.delayMinutes > 0;
    final statusColor = delayed ? const Color(0xFFFF9F0A) : const Color(0xFF30D158);
    final speed = data.currentLocation.speedKmh ?? 0;

    final totalKm = data.distance ?? 0;
    final coveredKm = data.currentLocation.distanceFromOriginKm ?? 0;
    final pct = (data.progressFraction * 100).clamp(0, 100).toInt();

    final destName = data.destination?.name.isNotEmpty == true
        ? data.destination!.name
        : (data.destination?.code.isNotEmpty == true ? data.destination!.code : 'Destination');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: ThemeController.instance.isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE5E5EA),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Train Number & Name + Live Speed Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A84FF).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.tram_fill, color: Color(0xFF0A84FF), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data.trainNumber} • ${data.trainName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'At ${data.currentLocation.stationName.isNotEmpty ? data.currentLocation.stationName : "Route"} • ${data.statusLabel}${delayed ? " (${data.delayMinutes}m late)" : ""}',
                          style: GoogleFonts.inter(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: onSpeedTestTap,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A84FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF0A84FF).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.speedometer, color: Color(0xFF0A84FF), size: 14),
                      const SizedBox(width: 4),
                      Column(
                        children: [
                          Text(
                            speed > 0 ? '${speed.round()}' : 'TEST',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF0A84FF),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            speed > 0 ? 'km/h' : 'SPEED',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF0A84FF),
                              fontWeight: FontWeight.bold,
                              fontSize: 7.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(color: ThemeController.instance.isDarkMode ? Colors.white10 : const Color(0xFFE5E5EA), height: 1),
          const SizedBox(height: 10),

          // Row 2: Next Stop & Destination Station
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NEXT STOP', style: GoogleFonts.inter(color: textSecondary, fontSize: 8.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      data.nextHalt?.name ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                    if (data.nextHalt?.arrivalTime != null)
                      Text(
                        'ETA: ${data.nextHalt!.arrivalTime}',
                        style: GoogleFonts.inter(color: const Color(0xFF0A84FF), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 28,
                color: ThemeController.instance.isDarkMode ? Colors.white10 : const Color(0xFFE5E5EA),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DESTINATION', style: GoogleFonts.inter(color: textSecondary, fontSize: 8.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      destName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                    if (data.destination?.arrivalTime != null)
                      Text(
                        'STA: ${data.destination!.arrivalTime}',
                        style: GoogleFonts.inter(color: const Color(0xFF30D158), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 3: Covered vs Total Distance & Progress Bar
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Covered: ${coveredKm.round()} km',
                    style: GoogleFonts.inter(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$pct% Completed',
                    style: GoogleFonts.inter(color: const Color(0xFF0A84FF), fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    'Total: ${totalKm.round()} km',
                    style: GoogleFonts.inter(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Stack(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: textSecondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: data.progressFraction.clamp(0.0, 1.0),
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A84FF),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
