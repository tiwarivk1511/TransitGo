import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../components/common/error_box.dart';
import '../../../components/common/loading_indicator.dart';
import '../../../components/station/station_autocomplete.dart';
import '../../../core/cache/offline_cache.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../data/models/station.dart';
import '../../../data/models/station_traffic.dart';
import '../../../services/live_traffic_service.dart';
import '../../train_details/train_details_screen.dart';

enum _Filter { all, onTime, delayed, atStation }

class LiveTrafficScreen extends StatefulWidget {
  final String? initialStationCode;

  const LiveTrafficScreen({super.key, this.initialStationCode});

  @override
  State<LiveTrafficScreen> createState() => _LiveTrafficScreenState();
}

class _LiveTrafficScreenState extends State<LiveTrafficScreen>
    with WidgetsBindingObserver {
  final _ctrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  Station? _station;
  bool _loading = false;
  bool _refreshing = false;
  String? _error;
  StationTraffic? _data;
  DateTime? _lastFetch;
  StreamSubscription<StationTraffic>? _sub;
  _Filter _filter = _Filter.all;
  int _selectedHours = 8;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final code = widget.initialStationCode?.trim();
    if (code != null && code.isNotEmpty) {
      final normalizedCode = code.toUpperCase();
      _ctrl.text = normalizedCode;
      _station = Station(code: normalizedCode, name: normalizedCode);
      unawaited(_rememberStation(_station!, 'traffic'));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _subscribe(normalizedCode);
      });
    }
  }

  Future<void> _rememberStation(Station station, String kind) =>
      OfflineCache.addHistory(
        kind,
        station.code,
        label: '${station.name} (${station.code})',
        data: {'stationCode': station.code, 'stationName': station.name},
      );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _ctrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _sub?.cancel();
      _sub = null;
    } else if (state == AppLifecycleState.resumed && _station != null) {
      _subscribe(_station!.code);
    }
  }

  void _subscribe(String code) {
    _sub?.cancel();
    if (mounted) setState(() => _loading = _data == null);

    _sub = LiveTrafficService.stream(code, hours: _selectedHours).listen(
      (data) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _data = data;
          _lastFetch = DateTime.now();
          _error = null;
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Live stream error.';
        });
      },
    );
  }

  Future<void> _manualRefresh() async {
    final code =
        _station?.code ?? _ctrl.text.trim().toUpperCase().split(' ').first;
    if (code.isEmpty) return;
    if (_refreshing) return;
    _refreshing = true;
    if (mounted) setState(() {});

    try {
      final d = await LiveTrafficService.fetch(code, hours: _selectedHours);
      if (!mounted) return;
      if (d != null && _station == null) {
        final station = Station(code: code, name: code);
        unawaited(_rememberStation(station, 'traffic'));
      }
      setState(() {
        _data = d ?? _data;
        _lastFetch = DateTime.now();
        if (d == null) _error = 'No live traffic found for $code.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to refresh.');
    } finally {
      _refreshing = false;
      if (mounted) setState(() {});
    }
  }

  void _onStationSelected(Station s) {
    setState(() {
      _station = s;
      _ctrl.text = '${s.name} (${s.code})';
      _data = null;
      _filter = _Filter.all;
      _error = null;
    });
    unawaited(_rememberStation(s, 'traffic'));
    _subscribe(s.code);
  }

  void _selectHours(int hours) {
    if (_selectedHours == hours) return;
    setState(() {
      _selectedHours = hours;
      _data = null;
      _error = null;
    });
    final code =
        _station?.code ?? _ctrl.text.trim().toUpperCase().split(' ').first;
    if (code.isNotEmpty) _subscribe(code);
  }

  List<TrainMovement> get _visibleMovements {
    final all = _data?.movements ?? [];
    List<TrainMovement> filtered;

    switch (_filter) {
      case _Filter.onTime:
        filtered = all.where((m) => m.delayMinutes <= 0).toList();
        break;
      case _Filter.delayed:
        filtered = all.where((m) => m.delayMinutes > 0).toList();
        break;
      case _Filter.atStation:
        filtered = all.where((m) => m.isAtStation).toList();
        break;
      case _Filter.all:
        filtered = all;
        break;
    }

    if (_searchQuery.trim().isEmpty) return filtered;

    final query = _searchQuery.trim().toLowerCase();
    return filtered.where((m) {
      final num = m.trainNumber.toLowerCase();
      final name = m.trainName.toLowerCase();
      final src = m.source.toLowerCase();
      final dst = m.destination.toLowerCase();
      final pf = (m.platform ?? '').toLowerCase();
      return num.contains(query) ||
          name.contains(query) ||
          src.contains(query) ||
          dst.contains(query) ||
          pf.contains(query);
    }).toList();
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

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Live Station Traffic',
          style: GoogleFonts.inter(
            color: textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
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
          if (_data != null)
            IconButton(
              tooltip: 'Refresh Board',
              icon: _refreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0A84FF),
                      ),
                    )
                  : const Icon(
                      CupertinoIcons.refresh,
                      color: Color(0xFF0A84FF),
                      size: 18,
                    ),
              onPressed: _manualRefresh,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _manualRefresh,
          color: const Color(0xFF0A84FF),
          backgroundColor: cardBg,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _introCard(cardBg, textPrimary, textSecondary, borderCol),
                const SizedBox(height: 16),

                // Station Search Input Field
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: borderCol),
                  ),
                  child: StationAutocomplete(
                    controller: _ctrl,
                    label: 'Station Name or Code',
                    hint: 'e.g. NDLS, HWH, CSMT or New Delhi',
                    icon: CupertinoIcons.search,
                    onStationSelected: _onStationSelected,
                  ),
                ),
                const SizedBox(height: 14),

                // Time Window Selector (2h, 4h, 6h, 8h)
                _trafficWindowSelector(
                    isDark, cardBg, textPrimary, textSecondary, borderCol),
                const SizedBox(height: 16),

                if (_data != null) ...[
                  _liveHeaderCard(
                      isDark, cardBg, textPrimary, textSecondary, borderCol),
                  const SizedBox(height: 14),

                  _searchBar(cardBg, textPrimary, textSecondary, borderCol),
                  const SizedBox(height: 14),
                ],

                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: LoadingIndicator(
                      color: Color(0xFF0A84FF),
                      label: 'Fetching live station board…',
                    ),
                  )
                else if (_error != null && _data == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: ErrorBox(message: _error!, onRetry: _manualRefresh),
                  )
                else if (_data == null || _visibleMovements.isEmpty)
                  _emptyState(cardBg, textPrimary, textSecondary, borderCol)
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _visibleMovements.length,
                    itemBuilder: (_, i) => _movementCard(
                      _visibleMovements[i],
                      cardBg,
                      textPrimary,
                      textSecondary,
                      borderCol,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _introCard(
      Color cardBg, Color textPrimary, Color textSecondary, Color borderCol) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0A84FF).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.antenna_radiowaves_left_right,
              color: Color(0xFF0A84FF),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Station Live Traffic Board',
                  style: GoogleFonts.inter(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Live station train departures, arrivals, platform assignments & delay telemetry powered by Open Web RailRadar.',
                  style: GoogleFonts.inter(
                    color: textSecondary,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trafficWindowSelector(bool isDark, Color cardBg, Color textPrimary,
      Color textSecondary, Color borderCol) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.clock,
            color: Color(0xFF0A84FF),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'WINDOW',
            style: GoogleFonts.inter(
              color: textSecondary,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [2, 4, 6, 8]
                  .map(
                    (hours) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: hours == 8 ? 0 : 6),
                        child: GestureDetector(
                          onTap: () => _selectHours(hours),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _selectedHours == hours
                                  ? const Color(0xFF0A84FF)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _selectedHours == hours
                                    ? const Color(0xFF0A84FF)
                                    : borderCol,
                              ),
                            ),
                            child: Text(
                              '${hours}h',
                              style: GoogleFonts.inter(
                                color: _selectedHours == hours
                                    ? Colors.white
                                    : textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar(
      Color cardBg, Color textPrimary, Color textSecondary, Color borderCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: TextField(
        controller: _searchCtrl,
        style: GoogleFonts.inter(color: textPrimary, fontSize: 13),
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          icon: const Icon(CupertinoIcons.search,
              size: 18, color: Color(0xFF0A84FF)),
          hintText: 'Search train number, name or platform...',
          hintStyle: GoogleFonts.inter(color: textSecondary, fontSize: 13),
          border: InputBorder.none,
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(CupertinoIcons.xmark_circle_fill,
                      size: 16, color: Colors.grey),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _liveHeaderCard(bool isDark, Color cardBg, Color textPrimary,
      Color textSecondary, Color borderCol) {
    final d = _data!;
    final delayedCount = d.delayed.length;
    final onTimeCount = d.movements.length - delayedCount;
    final atStationCount = d.movements.where((m) => m.isAtStation).length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderCol),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A84FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  d.stationCode,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF0A84FF),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.stationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF30D158),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'LIVE • ${_selectedHours}h window',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF30D158),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_lastFetch != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '· ${_formatDateTimeInIst(_lastFetch!)}',
                            style: GoogleFonts.inter(
                              color: textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (d.windowFrom != null && d.windowTo != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'WINDOW',
                        style: GoogleFonts.inter(
                          color: textSecondary,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${d.windowFrom} – ${d.windowTo}',
                        style: GoogleFonts.inter(
                          color: textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _metricPill(
                      'TOTAL', '${d.totalCount}', const Color(0xFF0A84FF))),
              const SizedBox(width: 8),
              Expanded(
                  child: _metricPill('ON TIME', '$onTimeCount',
                      const Color(0xFF30D158))),
              const SizedBox(width: 8),
              Expanded(
                  child: _metricPill(
                      'DELAYED',
                      '$delayedCount',
                      delayedCount > 0
                          ? const Color(0xFFFF9F0A)
                          : const Color(0xFF30D158))),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterTabChip('All Trains', _Filter.all, d.movements.length,
                    textSecondary),
                _filterTabChip(
                    'On Time 🟢', _Filter.onTime, onTimeCount, textSecondary),
                _filterTabChip(
                    'Delayed ⏰', _Filter.delayed, delayedCount, textSecondary),
                _filterTabChip('At Station 🚉', _Filter.atStation,
                    atStationCount, textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color.withValues(alpha: 0.85),
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterTabChip(
      String label, _Filter f, int count, Color textSecondary) {
    final isSelected = _filter == f;
    return GestureDetector(
      onTap: () => setState(() => _filter = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0A84FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$label ($count)',
          style: GoogleFonts.inter(
            color: isSelected ? Colors.white : textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _emptyState(Color cardBg, Color textPrimary, Color textSecondary,
      Color borderCol) {
    final hasStation = _station != null || _data != null;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        children: [
          Icon(
            hasStation
                ? CupertinoIcons.checkmark_circle_fill
                : CupertinoIcons.tram_fill,
            color: hasStation
                ? const Color(0xFF30D158)
                : const Color(0xFF0A84FF),
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            hasStation
                ? (_filter == _Filter.delayed
                    ? 'No delayed trains in the selected $_selectedHours-hour window.'
                    : _filter == _Filter.onTime
                        ? 'No on-time trains in the selected $_selectedHours-hour window.'
                        : 'No train movements in the selected $_selectedHours-hour window.')
                : 'Search or select a station to view its live traffic board',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _movementCard(
    TrainMovement m,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
  ) {
    final delayed = m.isDelayed;
    final isAtStation = m.isAtStation;
    final type = m.trainType ?? 'Express';

    // Status pill colors
    Color statusColor;
    String statusLabel;

    if (isAtStation) {
      statusColor = const Color(0xFF30D158);
      statusLabel = 'AT STATION';
    } else if (m.status == 'upcoming') {
      statusColor = const Color(0xFF0A84FF);
      statusLabel = 'UPCOMING';
    } else if (m.status == 'not-started') {
      statusColor = Colors.grey;
      statusLabel = 'NOT STARTED';
    } else if (m.status == 'running') {
      statusColor = const Color(0xFF30D158);
      statusLabel = 'RUNNING';
    } else {
      statusColor = const Color(0xFF0A84FF);
      statusLabel = (m.status ?? 'SCHEDULED').toUpperCase();
    }

    final arrTime = _formatBoardTime(m.expectedArrival ?? m.arrival);
    final depTime = _formatBoardTime(m.expectedDeparture ?? m.departure);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isAtStation
              ? const Color(0xFF30D158).withValues(alpha: 0.3)
              : borderCol,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TrainDetailsScreen(
                    trainNumber: m.trainNumber,
                    trainName: m.trainName,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF0A84FF).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          m.trainNumber,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF0A84FF),
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusLabel,
                          style: GoogleFonts.inter(
                            color: statusColor,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (type.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            type,
                            style: GoogleFonts.inter(
                              color: textSecondary,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (delayed)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFFF9F0A).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '+${m.delayMinutes}m late',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFFF9F0A),
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF30D158).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'On Time',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF30D158),
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    m.trainName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '${m.source} ➔ ${m.destination}',
                        style: GoogleFonts.inter(
                          color: textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (m.platform != null && m.platform!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'PF ${m.platform}',
                            style: GoogleFonts.inter(
                              color: textPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _timeTile('ARRIVAL', arrTime, textPrimary, textSecondary),
                      const SizedBox(width: 20),
                      _timeTile('DEPARTURE', depTime, textPrimary, textSecondary),
                    ],
                  ),
                  if (m.runDays.isNotEmpty && m.runDays.length < 7) ...[
                    const SizedBox(height: 8),
                    _runDaysRow(m.runDays, textSecondary),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeTile(
      String label, String value, Color textPrimary, Color textSecondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: textSecondary,
            fontSize: 8.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: GoogleFonts.inter(
            color: value != '--' ? textPrimary : textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _runDaysRow(List<String> days, Color textSecondary) {
    const order = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    const labels = {
      'mon': 'M',
      'tue': 'T',
      'wed': 'W',
      'thu': 'T',
      'fri': 'F',
      'sat': 'S',
      'sun': 'S',
    };
    final activeSet = days.map((d) => d.toLowerCase().substring(0, 3)).toSet();

    return Row(
      children: [
        Text(
          'RUNS',
          style: GoogleFonts.inter(
            color: textSecondary,
            fontSize: 8.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 6),
        ...order.map((day) {
          final isActive = activeSet.contains(day);
          return Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.only(right: 3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF0A84FF).withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              labels[day]!,
              style: GoogleFonts.inter(
                color: isActive ? const Color(0xFF0A84FF) : textSecondary,
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }),
      ],
    );
  }
}

String _formatBoardTime(String? value) {
  if (value == null || value.trim().isEmpty || value.trim() == '--') {
    return '--';
  }

  final text = value.trim();
  final timestamp = DateTime.tryParse(text);
  if (timestamp != null && text.contains('T')) {
    final ist = timestamp.toUtc().add(const Duration(hours: 5, minutes: 30));
    return DateFormat('h:mm a').format(ist);
  }

  final match = RegExp(
    r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM)?$',
    caseSensitive: false,
  ).firstMatch(text);
  if (match == null) return '--';

  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  final period = match.group(3)?.toUpperCase();
  if (hour == null || minute == null || minute > 59) return '--';

  late final int hour12;
  late final String meridiem;
  if (period != null) {
    if (hour < 1 || hour > 12) return '--';
    hour12 = hour;
    meridiem = period;
  } else {
    if (hour > 23) return '--';
    hour12 = hour % 12 == 0 ? 12 : hour % 12;
    meridiem = hour < 12 ? 'AM' : 'PM';
  }

  return '$hour12:${minute.toString().padLeft(2, '0')} $meridiem';
}

String _formatDateTimeInIst(DateTime dateTime) {
  final ist = dateTime.toUtc().add(const Duration(hours: 5, minutes: 30));
  return DateFormat('h:mm a').format(ist);
}
