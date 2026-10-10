import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../components/coach/StaticTrainRakeView.dart';
import '../../components/common/error_box.dart';
import '../../components/common/live_speed_card.dart';
import '../../components/common/loading_indicator.dart';
import '../../components/common/modern_background.dart';
import '../../components/train/train_crossing_view.dart';
import '../../core/cache/offline_cache.dart';
import '../../core/theme/theme_controller.dart';
import '../../data/models/coach.dart';
import '../../data/models/train.dart';
import '../../data/sources/railradar_source.dart';
import '../../services/train_service.dart';
import '../../services/wake_me_up_service.dart';
import '../train_map/train_map_screen.dart';

import '../../services/analytics_service.dart';

class TrainDetailsScreen extends StatefulWidget {
  final String trainNumber;
  final String trainName;
  final TrainJourneyInfo? journeyInfo;

  const TrainDetailsScreen({
    super.key,
    required this.trainNumber,
    required this.trainName,
    this.journeyInfo,
  });

  @override
  State<TrainDetailsScreen> createState() => _TrainDetailsScreenState();
}

class _TrainDetailsScreenState extends State<TrainDetailsScreen>
    with WidgetsBindingObserver {
  // Detail View Mode: 0 = Live Timeline, 1 = Crossings (XING), 2 = Coach Formation
  int _detailTab = 0;

  TrainTracking? _data;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  DateTime? _lastFetch;
  StreamSubscription<TrainTracking>? _sub;
  final ScrollController _detailScrollController = ScrollController();
  bool _hasScrolledToCurrent = false;

  // Train Crossings (XING) State
  List<TrainCrossing> _crossings = [];
  bool _loadingCrossings = false;

  String? _fetchedTrainName;

  String get _displayTrainName {
    if (_data != null &&
        _data!.trainName.isNotEmpty &&
        !_data!.trainName.startsWith('Train ')) {
      return _data!.trainName;
    }
    if (_fetchedTrainName != null &&
        _fetchedTrainName!.isNotEmpty &&
        !_fetchedTrainName!.startsWith('Train ')) {
      return _fetchedTrainName!;
    }
    if (widget.trainName.isNotEmpty && !widget.trainName.startsWith('Train ')) {
      return widget.trainName;
    }
    return 'Train ${widget.trainNumber}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resolveTrainName();
    AnalyticsService.logTrainView(
      trainNumber: widget.trainNumber,
      trainName: widget.trainName,
    );
    unawaited(
      OfflineCache.addHistory(
        'train',
        widget.trainNumber,
        label: '${widget.trainNumber} • ${widget.trainName}',
        data: {
          'trainNumber': widget.trainNumber,
          'trainName': widget.trainName,
        },
      ),
    );
    _subscribe();
    _fetchCrossings();
  }

  void _resolveTrainName() {
    final cleanNo = widget.trainNumber.trim().split(' - ').first;
    RailRadarSource.fetchSingleTrainName(cleanNo)
        .then((info) {
          final name = info['name']?.toString().trim() ?? '';
          if (name.isNotEmpty && !name.startsWith('Train ') && mounted) {
            setState(() => _fetchedTrainName = name);
          }
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _detailScrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _fetchCrossings() async {
    if (_loadingCrossings) return;
    setState(() => _loadingCrossings = true);
    try {
      final raw = await TrainService.trainCrossings(widget.trainNumber);
      if (mounted) {
        setState(() {
          _crossings = raw.map((e) => TrainCrossing.fromJson(e)).toList();
          _loadingCrossings = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCrossings = false);
    }
  }

  void _scrollToCurrentStation() {
    if (_data == null || !_detailScrollController.hasClients) return;
    final curIdx = _data!.currentIndex;
    if (curIdx < 0) return;

    // Timeline station item height is ~110px. Scroll so current live station appears centered
    final offset = (curIdx * 110.0 - 100.0).clamp(
      0.0,
      _detailScrollController.position.maxScrollExtent,
    );

    _detailScrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 750),
      curve: Curves.fastOutSlowIn,
    );
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
    if (mounted) setState(() => _loading = _data == null);

    _sub =
        TrainService.stream(
          widget.trainNumber,
          interval: const Duration(seconds: 30),
        ).listen(
          (data) {
            if (!mounted) return;
            setState(() {
              _data = data;
              _loading = false;
              _error = null;
              _lastFetch = DateTime.now();
            });
            if (!_hasScrolledToCurrent) {
              _hasScrolledToCurrent = true;
              Future.delayed(const Duration(milliseconds: 400), () {
                if (mounted) _scrollToCurrentStation();
              });
            }
          },
          onError: (e) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              if (_data == null) _error = 'Failed to load live status.';
            });
          },
        );
  }

  Future<void> _manualRefresh() async {
    if (_refreshing) return;
    _refreshing = true;
    if (mounted) setState(() {});

    try {
      final d = await TrainService.liveTracking(widget.trainNumber);
      await _fetchCrossings();
      if (!mounted) return;
      setState(() {
        if (d != null) _data = d;
        _lastFetch = DateTime.now();
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to refresh.');
    } finally {
      _refreshing = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _wakeMeUp() async {
    if (_data == null) return;
    final isDark = ThemeController.instance.isDarkMode;
    final sheetBg = isDark ? const Color(0xFF16161C) : const Color(0xFFFFFFFF);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? Colors.white54 : const Color(0xFF8E8E93);

    final sel = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _data!.route.length,
        itemBuilder: (_, i) {
          final s = _data!.route[i];
          final t = TrainRouteStop.formatHm(s.scheduledArrival);
          return Material(
            color: Colors.transparent,
            child: ListTile(
              title: Text(
                s.stationName,
                style: GoogleFonts.inter(color: textPrimary),
              ),
              subtitle: Text(
                '${t ?? '--'} • Day ${s.arrivalDay}',
                style: GoogleFonts.inter(color: textSecondary, fontSize: 11),
              ),
              onTap: () => Navigator.pop(context, s.stationCode),
            ),
          );
        },
      ),
    );
    if (sel == null) return;
    final target = _data!.route.firstWhere((s) => s.stationCode == sel);
    WakeMeUpService.arm(
      trainNumber: _data!.trainNumber,
      targetStationCode: target.stationCode,
      targetStationName: target.stationName,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: sheetBg,
        content: Text(
          '🔔 Alarm set for ${target.stationName}',
          style: GoogleFonts.inter(color: textPrimary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final d = _data;
        final trainType = d?.trainType ?? widget.journeyInfo?.trainType ?? '';
        final isDark = ThemeController.instance.isDarkMode;
        final cardBg = isDark
            ? const Color(0xFF16161C)
            : const Color(0xFFFFFFFF);
        final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
        final textSecondary = isDark ? Colors.white54 : const Color(0xFF8E8E93);

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: d != null
              ? FloatingActionButton.extended(
                  onPressed: _wakeMeUp,
                  backgroundColor: const Color(0xFF0A84FF),
                  icon: const Icon(
                    CupertinoIcons.bell_fill,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: Text(
                    'Wake Me Up',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              : null,
          appBar: AppBar(
            backgroundColor: cardBg,
            elevation: 0,
            leading: IconButton(
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
                  _displayTrainName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${d?.trainNumber ?? widget.trainNumber}'
                  '${trainType.isNotEmpty ? " • $trainType" : ""}',
                  style: GoogleFonts.inter(color: textSecondary, fontSize: 10),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Map view',
                icon: Icon(CupertinoIcons.map, color: textSecondary, size: 18),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TrainMapScreen(
                        trainNumber: widget.trainNumber,
                        trainName: _displayTrainName,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: _refreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF0A84FF),
                        ),
                      )
                    : Icon(
                        CupertinoIcons.refresh_bold,
                        color: textSecondary,
                        size: 16,
                      ),
                onPressed: _manualRefresh,
              ),
              IconButton(
                icon: Icon(
                  isDark
                      ? CupertinoIcons.sun_max_fill
                      : CupertinoIcons.moon_stars_fill,
                  color: isDark
                      ? const Color(0xFFFFD60A)
                      : const Color(0xFF0A84FF),
                  size: 18,
                ),
                onPressed: () => ThemeController.instance.toggleTheme(),
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: ModernBackground(
            child: Column(
              children: [
                Expanded(
                  child: _loading
                      ? const LoadingIndicator(label: 'Fetching live status…')
                      : _error != null && _data == null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: ErrorBox(
                              message: _error!,
                              onRetry: _manualRefresh,
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _manualRefresh,
                          color: const Color(0xFF0A84FF),
                          backgroundColor: cardBg,
                          child: _data == null
                              ? ListView(
                                  children: [
                                    const SizedBox(height: 200),
                                    Center(
                                      child: Text(
                                        'No data available',
                                        style: TextStyle(color: textSecondary),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView(
                                  controller: _detailScrollController,
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    100,
                                  ),
                                  children: [
                                    // Top Live Status Banner Header
                                    _StatusHeader(
                                      data: _data!,
                                      lastFetch: _lastFetch,
                                      cardBg: cardBg,
                                      textPrimary: textPrimary,
                                      textSecondary: textSecondary,
                                    ),
                                    const SizedBox(height: 16),

                                    // Live Speedometer Telemetry Card
                                    LiveSpeedCard(
                                      trainLivePosition:
                                          _data!
                                              .currentLocation
                                              .hasGpsCoordinates
                                          ? _data!.currentLocation.latLng
                                          : null,
                                      trainRoute: _data!.routeGeometry,
                                    ),
                                    const SizedBox(height: 16),

                                    // Cupertino Segmented Control Tab Switcher
                                    _tabSegmentHeader(
                                      isDark,
                                      cardBg,
                                      textPrimary,
                                      textSecondary,
                                    ),
                                    const SizedBox(height: 16),

                                    // Tab 0: Live Timeline
                                    if (_detailTab == 0) ...[
                                      _JourneySummary(
                                        data: _data!,
                                        cardBg: cardBg,
                                        textPrimary: textPrimary,
                                        textSecondary: textSecondary,
                                      ),
                                      if (_data!.nextHalt != null) ...[
                                        const SizedBox(height: 16),
                                        _NextHaltCard(
                                          data: _data!,
                                          nextHalt: _data!.nextHalt!,
                                          cardBg: cardBg,
                                          textPrimary: textPrimary,
                                          textSecondary: textSecondary,
                                        ),
                                      ],
                                      const SizedBox(height: 16),
                                      _RouteTimeline(
                                        data: _data!,
                                        cardBg: cardBg,
                                        textPrimary: textPrimary,
                                        textSecondary: textSecondary,
                                      ),
                                    ]
                                    // Tab 1: Train Crossings (XING) & Encounters
                                    else if (_detailTab == 1)
                                      TrainCrossingView(
                                        currentTrainNumber: widget.trainNumber,
                                        currentTrainName: _displayTrainName,
                                        currentStationCode:
                                            _data?.currentLocation.stationCode,
                                        currentStationName:
                                            _data?.currentLocation.stationName,
                                        crossings: _crossings,
                                        routeStops: _data?.route ?? const [],
                                        loading: _loadingCrossings,
                                        onRefresh: _fetchCrossings,
                                      )
                                    // Tab 2: Coach Rake Formation
                                    else if (_detailTab == 2)
                                      if (_data!.coachComposition.isNotEmpty)
                                        _CoachStrip(
                                          coaches: _data!.coachComposition,
                                          trainName: _data!.trainName,
                                          trainType: _data!.trainType,
                                        )
                                      else
                                        _noCoachData(
                                          cardBg,
                                          textPrimary,
                                          textSecondary,
                                        ),
                                  ],
                                ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tabSegmentHeader(
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE5E5EA),
        ),
      ),
      child: Row(
        children: [
          _tabChip('Timeline 📜', 0, textSecondary),
          _tabChip('Crossings (XING) 🔀', 1, textSecondary),
          _tabChip('Coaches 🚆', 2, textSecondary),
        ],
      ),
    );
  }

  Widget _tabChip(String label, int index, Color textSecondary) {
    final isSelected = _detailTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _detailTab = index);
          if (index == 0) {
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) _scrollToCurrentStation();
            });
          } else if (index == 1 && _crossings.isEmpty && !_loadingCrossings) {
            _fetchCrossings();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0A84FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: isSelected ? Colors.white : textSecondary,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _noCoachData(Color cardBg, Color textPrimary, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Icon(
            CupertinoIcons.square_stack_3d_up_fill,
            color: Color(0xFF0A84FF),
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            'Coach composition not available for this train.',
            style: GoogleFonts.inter(
              color: textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// HEADER
// ═════════════════════════════════════════════════════════════════════
class _StatusHeader extends StatelessWidget {
  final TrainTracking data;
  final DateTime? lastFetch;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;

  const _StatusHeader({
    required this.data,
    this.lastFetch,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final delayed = data.delayMinutes > 0;
    final statusColor = _statusColor(data.status);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusPill(
                label: data.statusLabel,
                color: statusColor,
                isLive: data.isLive,
              ),
              const Spacer(),
              if (lastFetch != null)
                Text(
                  '${DateFormat('h:mm a').format(lastFetch!)} • '
                  '${_relativeTime(lastFetch!)}',
                  style: GoogleFonts.inter(color: textSecondary, fontSize: 10),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (data.currentLocation.stationName.isNotEmpty) ...[
            Text(
              'CURRENTLY AT',
              style: GoogleFonts.inter(
                color: textSecondary,
                fontSize: 9,
                letterSpacing: 2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              data.currentLocation.stationName,
              style: GoogleFonts.inter(
                color: textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (data.currentLocation.isHalt) ...[
              const SizedBox(height: 2),
              Text(
                'HALTED • ${data.currentLocation.stationCode}',
                style: GoogleFonts.inter(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ] else if (data.currentLocation.stationCode.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                data.currentLocation.stationCode,
                style: GoogleFonts.inter(color: textSecondary, fontSize: 11),
              ),
            ],
            const SizedBox(height: 16),
          ],
          _ProgressBar(data: data, textSecondary: textSecondary),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  icon: CupertinoIcons.timer,
                  value: '${data.delayMinutes}',
                  label: 'MIN LATE',
                  color: delayed
                      ? const Color(0xFFFF9F0A)
                      : const Color(0xFF30D158),
                  textSecondary: textSecondary,
                ),
              ),
              Expanded(
                child: _Stat(
                  icon: CupertinoIcons.arrow_2_squarepath,
                  value: data.totalHalts?.toString() ?? '—',
                  label: 'HALTS',
                  color: const Color(0xFF5E5CE6),
                  textSecondary: textSecondary,
                ),
              ),
              Expanded(
                child: _Stat(
                  icon: CupertinoIcons.percent,
                  value: '${(data.progressFraction * 100).toStringAsFixed(0)}%',
                  label: 'DONE',
                  color: const Color(0xFF0A84FF),
                  textSecondary: textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'running':
        return const Color(0xFF0A84FF);
      case 'at-station':
        return const Color(0xFF64D2FF);
      case 'not-started':
        return const Color(0xFFFF9F0A);
      case 'reached':
      case 'completed':
        return const Color(0xFF30D158);
      case 'cancelled':
        return const Color(0xFFFF453A);
      default:
        return const Color(0xFF8E8E93);
    }
  }

  static String _relativeTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 10) return 'just now';
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool isLive;
  const _StatusPill({
    required this.label,
    required this.color,
    required this.isLive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.7),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Color textSecondary;
  const _Stat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.inter(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            color: textSecondary,
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final TrainTracking data;
  final Color textSecondary;
  const _ProgressBar({required this.data, required this.textSecondary});

  @override
  Widget build(BuildContext context) {
    final total = data.distance ?? 0;
    final covered = data.currentLocation.distanceFromOriginKm ?? 0;
    final pct = data.progressFraction;

    return Column(
      children: [
        Row(
          children: [
            Text(
              data.source?.code ?? '—',
              style: GoogleFonts.inter(
                color: textSecondary,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
            const Spacer(),
            Text(
              '${covered.toStringAsFixed(0)} / ${total.toStringAsFixed(0)} km',
              style: GoogleFonts.inter(
                color: textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              data.destination?.code ?? '—',
              style: GoogleFonts.inter(
                color: textSecondary,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
              widthFactor: pct,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A84FF),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _JourneySummary extends StatelessWidget {
  final TrainTracking data;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;

  const _JourneySummary({
    required this.data,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _endpoint(
            'DEPARTURE',
            data.source?.name ?? '—',
            data.source?.code ?? '',
            data.source?.departureTime,
            textPrimary,
            textSecondary,
          ),
          const Icon(
            CupertinoIcons.arrow_right,
            color: Color(0xFF0A84FF),
            size: 18,
          ),
          _endpoint(
            'DESTINATION',
            data.destination?.name ?? '—',
            data.destination?.code ?? '',
            data.destination?.arrivalTime,
            textPrimary,
            textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _endpoint(
    String label,
    String name,
    String code,
    String? time,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: textSecondary,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          code,
          style: GoogleFonts.inter(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          name,
          style: GoogleFonts.inter(color: textSecondary, fontSize: 10),
        ),
        if (time != null && time.isNotEmpty)
          Text(
            time,
            style: GoogleFonts.inter(
              color: const Color(0xFF0A84FF),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }
}

class _NextHaltCard extends StatelessWidget {
  final TrainTracking data;
  final TrainStopRef nextHalt;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;

  const _NextHaltCard({
    required this.data,
    required this.nextHalt,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final arr = nextHalt.arrivalTime ?? '--';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF0A84FF).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0A84FF).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.location_fill,
              color: Color(0xFF0A84FF),
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEXT STOP',
                  style: GoogleFonts.inter(
                    color: textSecondary,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  nextHalt.name,
                  style: GoogleFonts.inter(
                    color: textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'ETA: $arr',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF0A84FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachStrip extends StatelessWidget {
  final List<CoachInfo> coaches;
  final String trainName;
  final String trainType;
  final String? officialLivery;

  const _CoachStrip({
    required this.coaches,
    required this.trainName,
    required this.trainType,
    this.officialLivery,
  });

  @override
  Widget build(BuildContext context) {
    return StaticTrainRakeView(
      trainName: trainName,
      trainType: trainType,
      officialLivery: officialLivery,
      coaches: coaches,
    );
  }
}

class _RouteTimeline extends StatelessWidget {
  final TrainTracking data;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;

  const _RouteTimeline({
    required this.data,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final stops = data.route;
    final isDark = ThemeController.instance.isDarkMode;
    final borderCol = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE5E5EA);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.clock_fill,
                color: Color(0xFF0A84FF),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'LIVE ROUTE TIMELINE',
                style: GoogleFonts.inter(
                  color: textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Text(
                '${stops.length} STOPS',
                style: GoogleFonts.inter(
                  color: textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...stops.asMap().entries.map((entry) {
            final idx = entry.key;
            final stop = entry.value;
            final isFirst = idx == 0;
            final isLast = idx == stops.length - 1;
            final isCurrent = idx == data.currentIndex;
            final isPassed = idx < data.currentIndex;
            final isHalt = stop.isHalt || isFirst || isLast;

            final arrStr =
                TrainRouteStop.formatHm(stop.effectiveArrival) ?? '--';
            final depStr =
                TrainRouteStop.formatHm(stop.effectiveDeparture) ?? '--';
            final schArrStr =
                TrainRouteStop.formatHm(stop.scheduledArrival) ?? '--';
            final schDepStr =
                TrainRouteStop.formatHm(stop.scheduledDeparture) ?? '--';

            final liveTrainDelay = data.delayMinutes;
            final stopDelay = stop.delayMinutes ?? (isPassed ? 0 : liveTrainDelay);

            String passTimeDisplay = arrStr;
            if (!isHalt && !isFirst && !isLast) {
              if (stop.effectiveArrival != null) {
                passTimeDisplay = TrainRouteStop.formatHm(stop.effectiveArrival) ?? '--';
              } else if (stop.scheduledArrival != null && stopDelay > 0) {
                final estDt = stop.scheduledArrival!.add(Duration(minutes: stopDelay));
                passTimeDisplay = DateFormat('h:mm a').format(estDt);
              } else if (stop.scheduledDeparture != null && stopDelay > 0) {
                final estDt = stop.scheduledDeparture!.add(Duration(minutes: stopDelay));
                passTimeDisplay = DateFormat('h:mm a').format(estDt);
              } else if (schArrStr != '--') {
                passTimeDisplay = schArrStr;
              } else if (schDepStr != '--') {
                passTimeDisplay = schDepStr;
              }
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isCurrent
                    ? const Color(0xFF30D158).withValues(alpha: 0.12)
                    : (isHalt
                          ? (isDark
                                ? const Color(0xFF09090C)
                                : const Color(0xFFF8F9FA))
                          : Colors.transparent),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCurrent
                      ? const Color(0xFF30D158).withValues(alpha: 0.5)
                      : (isHalt ? borderCol : Colors.transparent),
                  width: isCurrent ? 1.5 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Material(
                  color: Colors.transparent,
                  child: Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      leading: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            isCurrent
                                ? CupertinoIcons.checkmark_circle_fill
                                : (isPassed
                                      ? CupertinoIcons.circle_fill
                                      : (isHalt
                                            ? CupertinoIcons.circle_fill
                                            : CupertinoIcons.circle)),
                            color: isCurrent
                                ? const Color(0xFF30D158)
                                : (isPassed
                                      ? const Color(0xFF0A84FF)
                                      : (isHalt
                                            ? const Color(0xFF0A84FF)
                                            : textSecondary)),
                            size: isHalt ? 18 : 12,
                          ),
                        ],
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              children: [
                                Text(
                                  stop.stationName,
                                  style: GoogleFonts.inter(
                                    color: isCurrent
                                        ? const Color(0xFF30D158)
                                        : textPrimary,
                                    fontWeight: isHalt || isCurrent
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isHalt
                                        ? const Color(
                                            0xFF0A84FF,
                                          ).withValues(alpha: 0.15)
                                        : textSecondary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    stop.stationCode,
                                    style: GoogleFonts.inter(
                                      color: isHalt
                                          ? const Color(0xFF0A84FF)
                                          : textSecondary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (isHalt)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFFF9F0A,
                                      ).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'HALT',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFFF9F0A),
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Day ${stop.arrivalDay} • ${stop.distance.round()} km'
                          '${stop.platform != null && stop.platform!.isNotEmpty ? " • Platform ${stop.platform}" : ""}',
                          style: GoogleFonts.inter(
                            color: textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (isFirst)
                            Text(
                              'DEP: $depStr',
                              style: GoogleFonts.inter(
                                color: isCurrent
                                    ? const Color(0xFF30D158)
                                    : textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            )
                          else if (isLast)
                            Text(
                              'ARR: $arrStr',
                              style: GoogleFonts.inter(
                                color: isCurrent
                                    ? const Color(0xFF30D158)
                                    : textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            )
                          else if (!isHalt)
                            Text(
                              'Pass: $passTimeDisplay',
                              style: GoogleFonts.inter(
                                color: isCurrent
                                    ? const Color(0xFF30D158)
                                    : textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
                              ),
                            )
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'A: $arrStr',
                                  style: GoogleFonts.inter(
                                    color: isCurrent
                                        ? const Color(0xFF30D158)
                                        : textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '•',
                                  style: GoogleFonts.inter(
                                    color: textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'D: $depStr',
                                  style: GoogleFonts.inter(
                                    color: isCurrent
                                        ? const Color(0xFF30D158)
                                        : const Color(0xFF0A84FF),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 2),
                          if (stopDelay > 0)
                            Text(
                              '+${stopDelay}m late',
                              style: GoogleFonts.inter(
                                color: isPassed
                                    ? const Color(0xFFFF9F0A).withValues(alpha: 0.7)
                                    : const Color(0xFFFF9F0A),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          else if (isPassed || isCurrent)
                            Text(
                              'On Time 🟢',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF30D158),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                        ],
                      ),
                      children: [
                        Divider(color: borderCol, height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Scheduled Arrival',
                                  style: GoogleFonts.inter(
                                    color: textSecondary,
                                    fontSize: 9,
                                  ),
                                ),
                                Text(
                                  schArrStr,
                                  style: GoogleFonts.inter(
                                    color: textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Scheduled Departure',
                                  style: GoogleFonts.inter(
                                    color: textSecondary,
                                    fontSize: 9,
                                  ),
                                ),
                                Text(
                                  schDepStr,
                                  style: GoogleFonts.inter(
                                    color: textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Platform',
                                  style: GoogleFonts.inter(
                                    color: textSecondary,
                                    fontSize: 9,
                                  ),
                                ),
                                Text(
                                  stop.platform ?? '—',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF0A84FF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 38,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              WakeMeUpService.arm(
                                trainNumber: data.trainNumber,
                                targetStationCode: stop.stationCode,
                                targetStationName: stop.stationName,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: cardBg,
                                  content: Text(
                                    '🔔 Alarm set for ${stop.stationName}',
                                    style: GoogleFonts.inter(
                                      color: textPrimary,
                                    ),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(
                              CupertinoIcons.bell_fill,
                              color: Color(0xFF0A84FF),
                              size: 14,
                            ),
                            label: Text(
                              'SET ALARM FOR THIS STATION',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF0A84FF),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF0A84FF)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
