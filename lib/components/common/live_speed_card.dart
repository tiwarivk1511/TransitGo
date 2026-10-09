import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/theme_controller.dart';

class LiveSpeedCard extends StatefulWidget {
  final String? trainNumber;
  final LatLng? trainLivePosition;
  final List<LatLng> trainRoute;

  const LiveSpeedCard({
    super.key,
    this.trainNumber,
    this.trainLivePosition,
    this.trainRoute = const [],
  });

  @override
  State<LiveSpeedCard> createState() => _LiveSpeedCardState();
}

class _LiveSpeedCardState extends State<LiveSpeedCard> {
  StreamSubscription<Position>? _positionSubscription;

  LatLng? _trainPos;
  Position? _userPosition;
  double? _userSpeedKmh;
  double? _accuracy;
  double? _distanceToTrainMeters;
  bool _isInTrain = false;
  String? _error;
  bool _startingGps = false;

  bool get _isTracking => _positionSubscription != null;

  @override
  void initState() {
    super.initState();
    _trainPos = widget.trainLivePosition;
  }

  @override
  void didUpdateWidget(LiveSpeedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trainLivePosition != null) {
      _trainPos = widget.trainLivePosition;
    }
    _evaluateInTrainProximity();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _toggleGpsTracking() async {
    if (_isTracking) {
      await _stopGpsTracking();
      if (mounted) {
        setState(() {
          _accuracy = null;
          _error = null;
          _isInTrain = false;
        });
      }
      return;
    }

    setState(() {
      _startingGps = true;
      _error = null;
      _userSpeedKmh = null;
      _accuracy = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _setError('Turn on device Location (GPS) to verify in-train speed.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _setError('Location permission is required for in-train GPS speed.');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _setError('Please allow location access in your device Settings.');
        return;
      }

      final subscription = Geolocator.getPositionStream(
        locationSettings: _locationSettings(),
      ).listen(_onGpsPosition, onError: _onGpsError);

      if (!mounted) {
        await subscription.cancel();
        return;
      }
      setState(() => _positionSubscription = subscription);
    } on LocationServiceDisabledException {
      _setError('Turn on device Location (GPS) to verify in-train speed.');
    } on PermissionDeniedException {
      _setError('Location permission is required for in-train GPS speed.');
    } catch (error) {
      _setError('GPS tracking error: $error');
    } finally {
      if (mounted) setState(() => _startingGps = false);
    }
  }

  LocationSettings _locationSettings() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          intervalDuration: const Duration(seconds: 1),
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          activityType: ActivityType.fitness,
          distanceFilter: 0,
          pauseLocationUpdatesAutomatically: false,
        );
      default:
        return const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
        );
    }
  }

  void _onGpsPosition(Position pos) {
    if (!mounted) return;
    final accuracy = pos.accuracy;
    final speedMps = pos.speed;

    setState(() {
      _userPosition = pos;
      _accuracy = accuracy.isFinite && accuracy >= 0 ? accuracy : null;
      _userSpeedKmh = accuracy.isFinite && speedMps.isFinite && speedMps >= 0
          ? speedMps * 3.6
          : 0.0;
      _error = null;
    });

    _evaluateInTrainProximity();
  }

  /// Evaluates 200-meter proximity radius between user's GPS and train location/track
  void _evaluateInTrainProximity() {
    if (_userPosition == null) return;
    final userLatLng = LatLng(_userPosition!.latitude, _userPosition!.longitude);

    double minDistanceMeters = double.infinity;

    // 1. Distance to train's live GPS coordinates
    if (_trainPos != null) {
      const dist = Distance();
      minDistanceMeters = dist.as(LengthUnit.Meter, userLatLng, _trainPos!);
    }

    // 2. Distance to train route track geometry coordinates
    if (widget.trainRoute.isNotEmpty) {
      const dist = Distance();
      for (final pt in widget.trainRoute) {
        final d = dist.as(LengthUnit.Meter, userLatLng, pt);
        if (d < minDistanceMeters) {
          minDistanceMeters = d;
        }
      }
    }

    if (minDistanceMeters.isFinite) {
      // 200-meter radius threshold
      const double radiusThresholdMeters = 200.0;
      final inTrain = minDistanceMeters <= radiusThresholdMeters;

      if (mounted) {
        setState(() {
          _distanceToTrainMeters = minDistanceMeters;
          _isInTrain = inTrain;
        });
      }
    }
  }

  Future<void> _stopGpsTracking() async {
    final subscription = _positionSubscription;
    _positionSubscription = null;
    await subscription?.cancel();
    if (!mounted) return;
    setState(() {
      _userSpeedKmh = null;
      _accuracy = null;
      _isInTrain = false;
      _distanceToTrainMeters = null;
    });
  }

  void _onGpsError(Object error) {
    if (!mounted) return;
    setState(() {
      _positionSubscription = null;
      _userSpeedKmh = null;
      _error = 'GPS sensor signal lost. Check location settings.';
    });
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDarkMode;
    final cardBg = isDark ? const Color(0xFF16161C) : const Color(0xFFFFFFFF);
    final innerBg = isDark ? const Color(0xFF09090C) : const Color(0xFFF8F9FA);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? const Color(0xFF98989D) : const Color(0xFF636366);
    final borderCol = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E5EA);

    // Speedometer displays real-time GPS speed when in-train verified (within 200m radius)
    final gpsSpeed = (_isInTrain && _userSpeedKmh != null) ? _userSpeedKmh! : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A84FF).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.location_fill, color: Color(0xFF0A84FF), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'IN-TRAIN GPS SPEEDOMETER',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (_isTracking)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isInTrain
                        ? const Color(0xFF30D158).withValues(alpha: 0.15)
                        : const Color(0xFFFF9F0A).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _isInTrain ? const Color(0xFF30D158) : const Color(0xFFFF9F0A),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _isInTrain ? 'VERIFIED 🚆' : 'NOT ONBOARD 📍',
                        style: GoogleFonts.inter(
                          color: _isInTrain ? const Color(0xFF30D158) : const Color(0xFFFF9F0A),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Speedometer Digital Display
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: innerBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderCol),
            ),
            child: Column(
              children: [
                Text(
                  _isTracking
                      ? (_isInTrain
                          ? 'Real-Time In-Train GPS Speed (200m Radius Verified 🟢)'
                          : 'Not Onboard Train • Speed Locked (Must be within 200m 🔒)')
                      : 'Satellite GPS Speed Sensor Ready (Must be within 200m of train)',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: _isTracking && !_isInTrain
                        ? const Color(0xFFFF9F0A)
                        : textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),

                // Digital Speed Display
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      gpsSpeed.round().toString(),
                      style: GoogleFonts.inter(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        color: gpsSpeed > 0 ? const Color(0xFF30D158) : textPrimary,
                        letterSpacing: -1.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'km/h',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0A84FF),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Gauge Bar
                Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: textSecondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: (gpsSpeed / 160).clamp(0.0, 1.0),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: gpsSpeed > 100
                              ? const Color(0xFFFF9F0A)
                              : const Color(0xFF0A84FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          if (_error != null) ...[
            Text(
              _error!,
              style: GoogleFonts.inter(color: const Color(0xFFFF453A), fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
          ],

          if (_isTracking) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _isInTrain
                    ? const Color(0xFF30D158).withValues(alpha: 0.15)
                    : const Color(0xFFFF9F0A).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isInTrain ? const Color(0xFF30D158) : const Color(0xFFFF9F0A),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isInTrain ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.exclamationmark_triangle_fill,
                    color: _isInTrain ? const Color(0xFF30D158) : const Color(0xFFFF9F0A),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isInTrain
                          ? 'In-Train Verified 🚆 • Location matches train track (${_distanceToTrainMeters != null ? "${_distanceToTrainMeters!.round()}m radius" : "<200m"})'
                          : 'Not Onboard Train 📍 • Distance: ${_distanceToTrainMeters != null ? (_distanceToTrainMeters! >= 1000 ? "${(_distanceToTrainMeters! / 1000).toStringAsFixed(1)} km" : "${_distanceToTrainMeters!.round()} m") : "Calculating…"} (Must be within 200m)',
                      style: GoogleFonts.inter(
                        color: _isInTrain ? const Color(0xFF30D158) : const Color(0xFFFF9F0A),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _startingGps ? null : _toggleGpsTracking,
              icon: Icon(
                _isTracking ? CupertinoIcons.stop_fill : CupertinoIcons.location_fill,
                size: 16,
              ),
              label: Text(
                _startingGps
                    ? 'Acquiring Satellites…'
                    : (_isTracking ? 'STOP IN-TRAIN GPS' : 'START IN-TRAIN GPS SPEEDOMETER'),
                style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isTracking ? const Color(0xFFFF453A) : const Color(0xFF0A84FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          if (_accuracy != null) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                'GPS Accuracy: ±${_accuracy!.round()} meters',
                style: GoogleFonts.inter(color: textSecondary, fontSize: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
