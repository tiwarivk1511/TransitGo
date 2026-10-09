import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../components/common/error_box.dart';
import '../../../components/common/loading_indicator.dart';
import '../../../components/station/station_autocomplete.dart';
import '../../../core/cache/offline_cache.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../data/models/station.dart';
import '../../../data/models/station_traffic.dart';
import '../../../data/sources/railradar_source.dart';
import '../../../services/live_traffic_service.dart';
import '../../train_details/train_details_screen.dart';

class AlertsScreen extends StatefulWidget {
  final String? initialStationCode;

  const AlertsScreen({super.key, this.initialStationCode});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _ctrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  Station? _station;
  bool _loading = false;
  String? _error;
  StationTraffic? _stationData;

  // National Train Exceptions (Open Web RailRadar API)
  Map<String, dynamic>? _exceptionsData;
  bool _loadingExceptions = false;

  // Filter Tabs:
  // 0 = All Alerts 🚨
  // 1 = Cancelled 🚫
  // 2 = Part. Cancelled ⚠️
  // 3 = Rescheduled ⏰
  // 4 = Diverted 🔀
  // 5 = Station Delays 🚉
  int _alertTab = 0;

  @override
  void initState() {
    super.initState();
    _fetchExceptions();
    final code = widget.initialStationCode?.trim();
    if (code != null && code.isNotEmpty) {
      final normalizedCode = code.toUpperCase();
      _ctrl.text = normalizedCode;
      _station = Station(code: normalizedCode, name: normalizedCode);
      _alertTab = 5; // Jump to Station Delays if initial station provided
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchStationTraffic();
      });
    }
  }

  Future<void> _fetchExceptions() async {
    if (_loadingExceptions) return;
    setState(() => _loadingExceptions = true);
    try {
      final data = await RailRadarSource.trainExceptions();
      if (mounted) {
        setState(() {
          _exceptionsData = data;
          _loadingExceptions = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingExceptions = false);
    }
  }

  Future<void> _fetchStationTraffic() async {
    final code = _station?.code ?? _ctrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final d = await LiveTrafficService.fetch(code, hours: 8);
    if (!mounted) return;
    if (d != null) {
      await OfflineCache.addHistory(
        'alerts',
        code,
        label: '${_station?.name ?? code} ($code)',
        data: {'stationCode': code, 'stationName': _station?.name ?? code},
      );
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _stationData = d;
      if (d == null) _error = 'No station live data available.';
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getAllTrains() {
    if (_exceptionsData == null) return const [];
    final trains = _exceptionsData!['trains'];
    if (trains is List) {
      return trains.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    // Fallback for legacy API structures where categories were separate lists
    final cancelled = _getLegacyList('cancelled');
    final rescheduled = _getLegacyList('rescheduled');
    final diverted = _getLegacyList('diverted');
    return [...cancelled, ...rescheduled, ...diverted];
  }

  List<Map<String, dynamic>> _getLegacyList(String key) {
    final list = _exceptionsData?[key] ?? _exceptionsData?['${key}Trains'];
    if (list is List) {
      return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return const [];
  }

  List<Map<String, dynamic>> _filterTrains(String category) {
    final all = _getAllTrains();
    List<Map<String, dynamic>> categoryFiltered;

    if (category == 'ALL') {
      categoryFiltered = all;
    } else {
      categoryFiltered = all.where((t) {
        final primaryType = (t['primaryType'] ?? '').toString().toUpperCase();
        final exceptions = t['exceptions'] is List
            ? (t['exceptions'] as List).map((e) => e.toString().toUpperCase()).toList()
            : <String>[];

        if (category == 'CANCELLED') {
          if (primaryType == 'CANCELLED') return true;
          if (exceptions.contains('CANCELLED')) return true;
          if (t['cancelled'] == true || (t['status'] ?? '').toString().toLowerCase().contains('cancel')) return true;
        } else if (category == 'PARTIALLY_CANCELLED') {
          if (primaryType == 'PARTIALLY_CANCELLED') return true;
          if (exceptions.contains('PARTIALLY_CANCELLED')) return true;
          if (t['partiallyCancelled'] != null && t['partiallyCancelled'] != false) return true;
        } else if (category == 'RESCHEDULED') {
          if (primaryType == 'RESCHEDULED') return true;
          if (exceptions.contains('RESCHEDULED')) return true;
          if (t['rescheduled'] != null && t['rescheduled'] != false) return true;
        } else if (category == 'DIVERTED') {
          if (primaryType == 'DIVERTED') return true;
          if (exceptions.contains('DIVERTED')) return true;
          if (t['diverted'] != null && t['diverted'] != false) return true;
        }
        return false;
      }).toList();
    }

    if (_searchQuery.trim().isEmpty) return categoryFiltered;

    final query = _searchQuery.trim().toLowerCase();
    return categoryFiltered.where((t) {
      final num = (t['trainNumber'] ?? t['number'] ?? t['train_no'] ?? '').toString().toLowerCase();
      final name = (t['trainName'] ?? t['name'] ?? t['train_name'] ?? '').toString().toLowerCase();
      final msg = (t['message'] ?? t['status'] ?? t['reason'] ?? '').toString().toLowerCase();
      return num.contains(query) || name.contains(query) || msg.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDarkMode;
    final bgColor = isDark ? const Color(0xFF09090C) : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF16161C) : const Color(0xFFFFFFFF);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? Colors.white54 : const Color(0xFF8E8E93);
    final borderCol = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E5EA);

    final allTrains = _filterTrains('ALL');
    final cancelled = _filterTrains('CANCELLED');
    final partCancelled = _filterTrains('PARTIALLY_CANCELLED');
    final rescheduled = _filterTrains('RESCHEDULED');
    final diverted = _filterTrains('DIVERTED');
    final stationDelayed = _stationData?.delayed ?? [];

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
          'National Service Alerts',
          style: GoogleFonts.inter(
            color: textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_stars_fill,
              color: isDark ? const Color(0xFFFFD60A) : const Color(0xFF0A84FF),
              size: 18,
            ),
            onPressed: () async {
              await ThemeController.instance.toggleTheme();
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _fetchExceptions();
            if (_station != null) await _fetchStationTraffic();
          },
          color: const Color(0xFFFF375F),
          backgroundColor: cardBg,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
            children: [
              _summaryDashboard(cardBg, textPrimary, textSecondary, borderCol),
              const SizedBox(height: 18),

              // Filter Tabs Header
              _tabSegmentHeader(isDark, cardBg, textPrimary, textSecondary),
              const SizedBox(height: 14),

              if (_alertTab != 5) ...[
                _searchBar(cardBg, textPrimary, textSecondary, borderCol),
                const SizedBox(height: 14),
              ],

              if (_loadingExceptions && _alertTab != 5)
                const LoadingIndicator(color: Color(0xFFFF375F), label: 'Fetching national train exceptions…')
              else if (_alertTab == 0) ...[
                // All Disruptions
                _sectionHeader('ALL DISRUPTIONS', allTrains.length, const Color(0xFFFF375F), textSecondary),
                const SizedBox(height: 12),
                if (allTrains.isEmpty)
                  _noExceptionCard('No train disruptions currently reported.', cardBg, textPrimary, textSecondary, borderCol)
                else
                  ...allTrains.map((t) => _exceptionCard(t, cardBg, textPrimary, textSecondary, borderCol)),
              ] else if (_alertTab == 1) ...[
                // Cancelled
                _sectionHeader('FULLY CANCELLED TRAINS', cancelled.length, const Color(0xFFFF453A), textSecondary),
                const SizedBox(height: 12),
                if (cancelled.isEmpty)
                  _noExceptionCard('No fully cancelled train alerts reported.', cardBg, textPrimary, textSecondary, borderCol)
                else
                  ...cancelled.map((t) => _exceptionCard(t, cardBg, textPrimary, textSecondary, borderCol)),
              ] else if (_alertTab == 2) ...[
                // Part Cancelled
                _sectionHeader('PARTIALLY CANCELLED TRAINS', partCancelled.length, const Color(0xFFFF9F0A), textSecondary),
                const SizedBox(height: 12),
                if (partCancelled.isEmpty)
                  _noExceptionCard('No partially cancelled train alerts reported.', cardBg, textPrimary, textSecondary, borderCol)
                else
                  ...partCancelled.map((t) => _exceptionCard(t, cardBg, textPrimary, textSecondary, borderCol)),
              ] else if (_alertTab == 3) ...[
                // Rescheduled
                _sectionHeader('RESCHEDULED TIMINGS', rescheduled.length, const Color(0xFF0A84FF), textSecondary),
                const SizedBox(height: 12),
                if (rescheduled.isEmpty)
                  _noExceptionCard('No rescheduled train alerts reported.', cardBg, textPrimary, textSecondary, borderCol)
                else
                  ...rescheduled.map((t) => _exceptionCard(t, cardBg, textPrimary, textSecondary, borderCol)),
              ] else if (_alertTab == 4) ...[
                // Diverted
                _sectionHeader('ROUTE DIVERTED TRAINS', diverted.length, const Color(0xFF5E5CE6), textSecondary),
                const SizedBox(height: 12),
                if (diverted.isEmpty)
                  _noExceptionCard('No diverted train alerts reported.', cardBg, textPrimary, textSecondary, borderCol)
                else
                  ...diverted.map((t) => _exceptionCard(t, cardBg, textPrimary, textSecondary, borderCol)),
              ] else if (_alertTab == 5) ...[
                // Station-Specific Search Tab
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: borderCol),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            CupertinoIcons.location_fill,
                            size: 16,
                            color: Color(0xFFFF375F),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'SEARCH STATION DELAYS',
                            style: GoogleFonts.inter(
                              color: textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      StationAutocomplete(
                        controller: _ctrl,
                        label: 'Station Name or Code',
                        hint: 'e.g. NDLS or New Delhi',
                        icon: CupertinoIcons.search,
                        onStationSelected: (station) {
                          setState(() {
                            _station = station;
                            _ctrl.text = '${station.name} (${station.code})';
                          });
                          _fetchStationTraffic();
                        },
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _fetchStationTraffic,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF375F),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Show Station Delay Alerts',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_loading) const LoadingIndicator(color: Color(0xFFFF375F)),
                if (_error != null) ErrorBox(message: _error!, onRetry: _fetchStationTraffic),
                if (_stationData != null) ...[
                  if (stationDelayed.isEmpty)
                    _noDelayCard(cardBg, textPrimary, textSecondary, borderCol)
                  else ...[
                    _sectionHeader('STATION DELAYED TRAINS', stationDelayed.length, const Color(0xFFFF9F0A), textSecondary),
                    const SizedBox(height: 12),
                    ...stationDelayed.map((t) => _delayTile(t, cardBg, textPrimary, textSecondary, borderCol)),
                  ],
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryDashboard(Color cardBg, Color textPrimary, Color textSecondary, Color borderCol) {
    final summary = _exceptionsData?['summary'] is Map ? Map<String, dynamic>.from(_exceptionsData!['summary']) : null;
    final all = _getAllTrains();

    final total = summary?['total'] ?? all.length;
    final cancelledCount = summary?['cancelled'] ?? _filterTrains('CANCELLED').length;
    final partCancCount = summary?['partiallyCancelled'] ?? _filterTrains('PARTIALLY_CANCELLED').length;
    final divertedCount = summary?['diverted'] ?? _filterTrains('DIVERTED').length;
    final rescheduledCount = summary?['rescheduled'] ?? _filterTrains('RESCHEDULED').length;
    final updatedAt = summary?['updatedAt']?.toString();

    String? timeFormatted;
    if (updatedAt != null && updatedAt.isNotEmpty) {
      final dt = DateTime.tryParse(updatedAt)?.toLocal();
      if (dt != null) {
        final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
        final ampm = dt.hour >= 12 ? 'PM' : 'AM';
        final min = dt.minute.toString().padLeft(2, '0');
        timeFormatted = '$hour:$min $ampm';
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderCol),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF375F).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.bell_fill, color: Color(0xFFFF375F), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'National Railway Alerts',
                      style: GoogleFonts.inter(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Live service disruptions & train exceptions nationwide',
                      style: GoogleFonts.inter(color: textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (timeFormatted != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.clock, size: 10, color: Color(0xFFFF375F)),
                      const SizedBox(width: 4),
                      Text(
                        timeFormatted,
                        style: GoogleFonts.inter(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _metricPill('TOTAL', '$total', const Color(0xFFFF375F))),
              const SizedBox(width: 8),
              Expanded(child: _metricPill('CANCELLED', '$cancelledCount', const Color(0xFFFF453A))),
              const SizedBox(width: 8),
              Expanded(child: _metricPill('PART. CANC.', '$partCancCount', const Color(0xFFFF9F0A))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _metricPill('RESCHEDULED', '$rescheduledCount', const Color(0xFF0A84FF))),
              const SizedBox(width: 8),
              Expanded(child: _metricPill('DIVERTED', '$divertedCount', const Color(0xFF5E5CE6))),
            ],
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

  Widget _searchBar(Color cardBg, Color textPrimary, Color textSecondary, Color borderCol) {
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
          icon: const Icon(CupertinoIcons.search, size: 18, color: Color(0xFFFF375F)),
          hintText: 'Search train number, name or reason...',
          hintStyle: GoogleFonts.inter(color: textSecondary, fontSize: 13),
          border: InputBorder.none,
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 16, color: Colors.grey),
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

  Widget _tabSegmentHeader(bool isDark, Color cardBg, Color textPrimary, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E5EA),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _tabChip('All Alerts 🚨', 0, textSecondary),
            _tabChip('Cancelled 🚫', 1, textSecondary),
            _tabChip('Part. Cancelled ⚠️', 2, textSecondary),
            _tabChip('Rescheduled ⏰', 3, textSecondary),
            _tabChip('Diverted 🔀', 4, textSecondary),
            _tabChip('Station Delays estation', 5, textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _tabChip(String label, int index, Color textSecondary) {
    final isSelected = _alertTab == index;
    return GestureDetector(
      onTap: () => setState(() => _alertTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF375F) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label == 'Station Delays estation' ? 'Station Delays 🚉' : label,
          style: GoogleFonts.inter(
            color: isSelected ? Colors.white : textSecondary,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, int count, Color color, Color textSecondary) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$count TRAINS',
            style: GoogleFonts.inter(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _noExceptionCard(String message, Color cardBg, Color textPrimary, Color textSecondary, Color borderCol) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: borderCol),
    ),
    child: Column(
      children: [
        const Icon(
          CupertinoIcons.checkmark_circle_fill,
          color: Color(0xFF30D158),
          size: 40,
        ),
        const SizedBox(height: 12),
        Text(
          'No Disruptions Reported',
          style: GoogleFonts.inter(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: textSecondary, fontSize: 11),
        ),
      ],
    ),
  );

  Widget _exceptionCard(
    Map<String, dynamic> item,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
  ) {
    final num = (item['trainNumber'] ?? item['number'] ?? item['train_no'] ?? '').toString();
    final name = (item['trainName'] ?? item['name'] ?? item['train_name'] ?? 'Express').toString();
    final type = (item['trainType'] ?? item['type'] ?? '').toString();
    final primaryType = (item['primaryType'] ?? '').toString().toUpperCase();
    final message = (item['message'] ?? item['reason'] ?? item['remarks'] ?? '').toString();
    final status = (item['status'] ?? '').toString();

    Color badgeColor;
    String badgeLabel;

    if (primaryType == 'CANCELLED' || (item['cancelled'] == true)) {
      badgeColor = const Color(0xFFFF453A);
      badgeLabel = 'CANCELLED';
    } else if (primaryType == 'PARTIALLY_CANCELLED' || (item['partiallyCancelled'] != null && item['partiallyCancelled'] != false)) {
      badgeColor = const Color(0xFFFF9F0A);
      badgeLabel = 'PART. CANCELLED';
    } else if (primaryType == 'DIVERTED' || (item['diverted'] != null && item['diverted'] != false)) {
      badgeColor = const Color(0xFF5E5CE6);
      badgeLabel = 'DIVERTED';
    } else if (primaryType == 'RESCHEDULED' || (item['rescheduled'] != null && item['rescheduled'] != false)) {
      badgeColor = const Color(0xFF0A84FF);
      badgeLabel = 'RESCHEDULED';
    } else if (primaryType == 'MULTIPLE') {
      badgeColor = const Color(0xFFFF375F);
      badgeLabel = 'MULTIPLE DISRUPTIONS';
    } else {
      badgeColor = const Color(0xFFFF375F);
      badgeLabel = primaryType.isNotEmpty ? primaryType : 'ALERT';
    }

    // Parse extra callout details
    String? extraDetail;

    final resched = item['rescheduled'];
    if (resched is Map) {
      final newDep = resched['newDeparture'] ?? resched['time'] ?? resched['rescheduledTime'];
      if (newDep != null && newDep.toString().isNotEmpty) {
        extraDetail = 'New Dep: ${newDep.toString()}';
      }
    } else if (resched is String && resched.isNotEmpty) {
      extraDetail = 'Rescheduled: $resched';
    }

    final div = item['diverted'];
    if (div is Map) {
      final via = div['via'] ?? div['divertedVia'];
      final from = div['from'] ?? div['divertedFrom'];
      final to = div['to'] ?? div['divertedTo'];
      if (via != null && via.toString().isNotEmpty) {
        extraDetail = 'Diverted Via: ${via.toString()}';
      } else if (from != null || to != null) {
        extraDetail = 'Diverted: ${from ?? ''} ➔ ${to ?? ''}';
      }
    }

    final partCanc = item['partiallyCancelled'];
    if (partCanc is Map) {
      final between = partCanc['cancelledBetween'] ?? partCanc['between'];
      if (between != null && between.toString().isNotEmpty) {
        extraDetail = 'Cancelled Between: ${between.toString()}';
      }
    }

    final src = (item['source'] ?? item['from'] ?? item['sourceStation'] ?? '').toString();
    final dst = (item['destination'] ?? item['to'] ?? item['destinationStation'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderCol),
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
              if (num.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TrainDetailsScreen(
                      trainNumber: num,
                      trainName: name,
                    ),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeLabel,
                          style: GoogleFonts.inter(
                            color: badgeColor,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (type.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
                      if (extraDetail != null)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              extraDetail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: badgeColor,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$num • $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  if (src.isNotEmpty || dst.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${src.isNotEmpty ? src : "Origin"} ➔ ${dst.isNotEmpty ? dst : "Destination"}',
                      style: GoogleFonts.inter(color: textSecondary, fontSize: 11),
                    ),
                  ],
                  if (message.isNotEmpty || status.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      message.isNotEmpty ? message : status,
                      style: GoogleFonts.inter(
                        color: textSecondary,
                        fontSize: 11,
                        height: 1.3,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _noDelayCard(Color cardBg, Color textPrimary, Color textSecondary, Color borderCol) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: borderCol),
    ),
    child: Column(
      children: [
        const Icon(
          CupertinoIcons.checkmark_circle_fill,
          color: Color(0xFF30D158),
          size: 40,
        ),
        const SizedBox(height: 12),
        Text(
          'All Trains On Time!',
          style: GoogleFonts.inter(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'No delayed trains recorded at ${_stationData?.stationName} in the upcoming 8 hours.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: textSecondary, fontSize: 11),
        ),
      ],
    ),
  );

  Widget _delayTile(TrainMovement t, Color cardBg, Color textPrimary, Color textSecondary, Color borderCol) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderCol),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (t.trainNumber.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TrainDetailsScreen(
                      trainNumber: t.trainNumber,
                      trainName: t.trainName,
                    ),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9F0A).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.tram_fill, color: Color(0xFFFF9F0A), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${t.trainNumber} • ${t.trainName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${t.origin} ➔ ${t.destination}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(color: textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9F0A).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+${t.delayMinutes}m late',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFF9F0A),
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
