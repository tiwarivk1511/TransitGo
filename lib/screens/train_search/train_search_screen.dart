import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/common/error_box.dart';
import '../../components/common/modern_background.dart';
import '../../components/train/train_card.dart';
import '../../core/cache/offline_cache.dart';
import '../../core/theme/theme_controller.dart';
import '../../data/models/train.dart';
import '../../services/train_service.dart';
import '../train_details/train_details_screen.dart';

class TrainSearchScreen extends StatefulWidget {
  final String fromCode;
  final String toCode;
  final String fromName;
  final String toName;
  final String? fromCity;
  final String? toCity;
  final double? fromLatitude;
  final double? fromLongitude;
  final double? toLatitude;
  final double? toLongitude;
  final String? fromDistrict;
  final String? fromState;
  final String? toDistrict;
  final String? toState;

  const TrainSearchScreen({
    super.key,
    required this.fromCode,
    required this.toCode,
    required this.fromName,
    required this.toName,
    this.fromCity,
    this.toCity,
    this.fromLatitude,
    this.fromLongitude,
    this.toLatitude,
    this.toLongitude,
    this.fromDistrict,
    this.fromState,
    this.toDistrict,
    this.toState,
  });

  @override
  State<TrainSearchScreen> createState() => _TrainSearchScreenState();
}

class _TrainSearchScreenState extends State<TrainSearchScreen> {
  bool _loading = true;
  bool _fetching = false;
  bool _disposed = false;

  String? _error;
  List<Map<String, dynamic>> _trains = [];
  _TrainFilters _filters = const _TrainFilters();

  List<Map<String, dynamic>> get _visibleTrains =>
      _trains.where(_matchesFilters).toList();

  int get _activeFilterCount {
    var count = _filters.trainTypes.isNotEmpty ? 1 : 0;
    count += _filters.runDays.isNotEmpty ? 1 : 0;
    count += _filters.departureStart > 0 || _filters.departureEnd < 1439
        ? 1
        : 0;
    count += _filters.maxHalts < 100 ? 1 : 0;
    count += _filters.maxDurationHours < 120 ? 1 : 0;
    count += _filters.maxDistanceKm < 5000 ? 1 : 0;
    return count;
  }

  @override
  void initState() {
    super.initState();
    unawaited(
      OfflineCache.addHistory(
        'route_search',
        '${widget.fromCode} → ${widget.toCode}',
        label: '${widget.fromName} → ${widget.toName}',
        data: {
          'fromCode': widget.fromCode,
          'toCode': widget.toCode,
          'fromName': widget.fromName,
          'toName': widget.toName,
          if (widget.fromCity != null) 'fromCity': widget.fromCity,
          if (widget.toCity != null) 'toCity': widget.toCity,
        },
      ),
    );
    _load();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_fetching || _disposed) return;
    _fetching = true;

    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response = await TrainService.trainsBetween(
        widget.fromCode,
        widget.toCode,
      );

      if (_disposed) return;

      if (response == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _fetching = false;
            _error =
                'Unable to fetch trains between ${widget.fromName} (${widget.fromCode}) and ${widget.toName} (${widget.toCode}).';
          });
        }
        return;
      }

      final rawList = (response['trains'] is List) ? (response['trains'] as List) : [];
      final parsedTrains = <Map<String, dynamic>>[];

      for (final item in rawList) {
        if (item is Map) {
          parsedTrains.add(Map<String, dynamic>.from(item));
        }
      }

      if (mounted) {
        setState(() {
          _trains = parsedTrains;
          _loading = false;
          _fetching = false;
          if (parsedTrains.isEmpty) {
            _error =
                'No trains found operating between ${widget.fromName} (${widget.fromCode}) and ${widget.toName} (${widget.toCode}).';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _fetching = false;
          _error = 'Failed to load trains between ${widget.fromCode} and ${widget.toCode}.';
        });
      }
    } finally {
      _fetching = false;
    }
  }

  bool _matchesFilters(Map<String, dynamic> item) {
    final train = Map<String, dynamic>.from(item['train'] as Map? ?? {});
    final from = Map<String, dynamic>.from(item['from'] as Map? ?? {});
    final type = (train['type'] ?? '').toString().trim().toLowerCase();
    if (_filters.trainTypes.isNotEmpty && !_filters.trainTypes.contains(type)) {
      return false;
    }

    if (_filters.runDays.isNotEmpty) {
      final rawDays = train['runDays'];
      final days = rawDays is List
          ? rawDays.map((day) => day.toString().trim().toLowerCase()).toSet()
          : <String>{};
      if (days.isEmpty ||
          !_filters.runDays.any(
            (day) => days.any((runningDay) => runningDay.startsWith(day)),
          )) {
        return false;
      }
    }

    final departure = _parseMinutes(from['departure']?.toString());
    if (departure != null &&
        (departure < _filters.departureStart ||
            departure > _filters.departureEnd)) {
      return false;
    }

    final halts = _asInt(item['halts']);
    if (halts != null && halts > _filters.maxHalts) return false;

    final duration = _asInt(item['duration']);
    if (duration != null && duration > _filters.maxDurationHours * 60) {
      return false;
    }

    final distance = _asDouble(item['distance']);
    if (distance != null && distance > _filters.maxDistanceKm) return false;
    return true;
  }

  int? _parseMinutes(String? raw) {
    if (raw == null) return null;
    final match = RegExp(
      r'(\d{1,2}):(\d{2})(?:\s*(AM|PM))?',
      caseSensitive: false,
    ).firstMatch(raw);
    if (match == null) return null;
    var hour = int.tryParse(match.group(1)!) ?? 0;
    final minute = int.tryParse(match.group(2)!) ?? 0;
    final period = match.group(3)?.toUpperCase();
    if (period == 'PM' && hour < 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    if (hour > 23 || minute > 59) return null;
    return hour * 60 + minute;
  }

  int? _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  Future<void> _showFilters() async {
    final isDark = ThemeController.instance.isDarkMode;
    final sheetBg = isDark ? const Color(0xFF16161C) : const Color(0xFFFFFFFF);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? const Color(0xFF98989D) : const Color(0xFF636366);

    final types =
        _trains
            .map(
              (item) =>
                  ((item['train'] as Map?)?['type'] ?? '').toString().trim(),
            )
            .where((type) => type.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    var selectedTypes = Set<String>.from(_filters.trainTypes);
    var selectedDays = Set<String>.from(_filters.runDays);
    var departureRange = RangeValues(
      _filters.departureStart.toDouble(),
      _filters.departureEnd.toDouble(),
    );
    var maxHalts = _filters.maxHalts.toDouble();
    var maxDurationHours = _filters.maxDurationHours.toDouble();
    var maxDistanceKm = _filters.maxDistanceKm.toDouble();

    final result = await showModalBottomSheet<_TrainFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => FractionallySizedBox(
          heightFactor: 0.9,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filter trains',
                        style: GoogleFonts.inter(
                          color: textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setSheetState(() {
                        selectedTypes = {};
                        selectedDays = {};
                        departureRange = const RangeValues(0, 1439);
                        maxHalts = 100;
                        maxDurationHours = 120;
                        maxDistanceKm = 5000;
                      }),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  children: [
                    if (types.isNotEmpty) ...[
                      _filterSectionTitle('TRAIN TYPE', textSecondary),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final type in types)
                            FilterChip(
                              label: Text(type),
                              selected: selectedTypes.contains(
                                type.toLowerCase(),
                              ),
                              onSelected: (selected) => setSheetState(() {
                                if (selected) {
                                  selectedTypes.add(type.toLowerCase());
                                } else {
                                  selectedTypes.remove(type.toLowerCase());
                                }
                              }),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                    _filterSectionTitle('RUNNING DAYS', textSecondary),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final day in _TrainFilters.days.entries)
                          FilterChip(
                            label: Text(day.value),
                            selected: selectedDays.contains(day.key),
                            onSelected: (selected) => setSheetState(() {
                              if (selected) {
                                selectedDays.add(day.key);
                              } else {
                                selectedDays.remove(day.key);
                              }
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _filterSectionTitle(
                      'DEPARTURE TIME  •  '
                      '${_formatMinutes(departureRange.start.round())} – '
                      '${_formatMinutes(departureRange.end.round())}',
                      textSecondary,
                    ),
                    RangeSlider(
                      values: departureRange,
                      min: 0,
                      max: 1439,
                      divisions: 96,
                      activeColor: const Color(0xFF0A84FF),
                      onChanged: (range) =>
                          setSheetState(() => departureRange = range),
                    ),
                    _filterSlider(
                      title: 'MAXIMUM HALTS',
                      value: maxHalts,
                      min: 0,
                      max: 100,
                      divisions: 50,
                      label: maxHalts.round().toString(),
                      textSecondary: textSecondary,
                      onChanged: (value) =>
                          setSheetState(() => maxHalts = value),
                    ),
                    _filterSlider(
                      title: 'MAXIMUM DURATION',
                      value: maxDurationHours,
                      min: 1,
                      max: 120,
                      divisions: 119,
                      label: _formatDuration(maxDurationHours.round()),
                      textSecondary: textSecondary,
                      onChanged: (value) =>
                          setSheetState(() => maxDurationHours = value),
                    ),
                    _filterSlider(
                      title: 'MAXIMUM DISTANCE',
                      value: maxDistanceKm,
                      min: 0,
                      max: 5000,
                      divisions: 100,
                      label: '${maxDistanceKm.round()} km',
                      textSecondary: textSecondary,
                      onChanged: (value) =>
                          setSheetState(() => maxDistanceKm = value),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(
                      sheetContext,
                      _TrainFilters(
                        trainTypes: selectedTypes,
                        runDays: selectedDays,
                        departureStart: departureRange.start.round(),
                        departureEnd: departureRange.end.round(),
                        maxHalts: maxHalts.round(),
                        maxDurationHours: maxDurationHours.round(),
                        maxDistanceKm: maxDistanceKm.round(),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A84FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Apply filters', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null && mounted) setState(() => _filters = result);
  }

  Widget _filterSectionTitle(String title, Color textSecondary) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: GoogleFonts.inter(
        color: textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    ),
  );

  Widget _filterSlider({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required Color textSecondary,
    required ValueChanged<double> onChanged,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _filterSectionTitle('$title  •  $label', textSecondary),
      Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        activeColor: const Color(0xFF0A84FF),
        onChanged: onChanged,
      ),
      const SizedBox(height: 8),
    ],
  );

  String _formatMinutes(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

  String _formatDuration(int hours) =>
      hours < 24 ? '${hours}h' : '${hours ~/ 24}d ${hours % 24}h';

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDarkMode;
    final bgColor = isDark ? const Color(0xFF09090C) : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF16161C) : const Color(0xFFFFFFFF);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? const Color(0xFF98989D) : const Color(0xFF636366);

    return Scaffold(
      backgroundColor: Colors.transparent,
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
              '${widget.fromName} (${widget.fromCode}) ➔ ${widget.toName} (${widget.toCode})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                fontSize: 14.5,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              _loading
                  ? 'Fetching direct trains…'
                  : '${_trains.length} direct train option${_trains.length == 1 ? "" : "s"}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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
      body: ModernBackground(
        child:_buildBody(bgColor, cardBg, textPrimary, textSecondary),
      ),
    );
  }

  Widget _buildBody(Color bgColor, Color cardBg, Color textPrimary, Color textSecondary) {
    if (_loading && _trains.isEmpty && _error == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF0A84FF)),
            const SizedBox(height: 16),
            Text(
              'Searching direct trains between ${widget.fromCode} and ${widget.toCode}…',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_error != null && _trains.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ErrorBox(message: _error!, onRetry: () => _load()),
              const SizedBox(height: 16),
              Text(
                'Or search a different route.',
                style: GoogleFonts.inter(color: textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    if (_trains.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(silent: true),
        color: const Color(0xFF0A84FF),
        backgroundColor: cardBg,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 160),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    Icon(
                      CupertinoIcons.tram_fill,
                      color: textSecondary,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No direct trains found\nbetween ${widget.fromCode} and ${widget.toCode}.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Try searching another station pair.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_visibleTrains.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.slider_horizontal_3,
                color: textSecondary,
                size: 42,
              ),
              const SizedBox(height: 12),
              Text(
                'No trains match these filters.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(
                onPressed: () =>
                    setState(() => _filters = const _TrainFilters()),
                child: const Text('Clear filters'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      color: const Color(0xFF0A84FF),
      backgroundColor: cardBg,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _visibleTrains.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) return _buildFilterBar(textSecondary);
          final trainIndex = i - 1;
          return _buildCard(_visibleTrains[trainIndex]);
        },
      ),
    );
  }

  Widget _buildFilterBar(Color textSecondary) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '${_visibleTrains.length} of ${_trains.length} train options',
            style: GoogleFonts.inter(color: textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _showFilters,
          icon: const Icon(CupertinoIcons.slider_horizontal_3, size: 14),
          label: Text(
            _activeFilterCount == 0
                ? 'Filters'
                : 'Filters ($_activeFilterCount)',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0A84FF),
            side: const BorderSide(
              color: Color(0xFF0A84FF),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    ),
  );

  Widget _buildCard(Map<String, dynamic> item) {
    final train = Map<String, dynamic>.from(item['train'] as Map? ?? {});
    final from = Map<String, dynamic>.from(item['from'] as Map? ?? {});
    final to = Map<String, dynamic>.from(item['to'] as Map? ?? {});

    List<String>? runDays;
    final rawDays = train['runDays'];
    if (rawDays is List) {
      runDays = rawDays.map((e) => e.toString()).toList();
    }

    final distanceRaw = item['distance'];
    final double distD = distanceRaw is num
        ? distanceRaw.toDouble()
        : double.tryParse(distanceRaw?.toString() ?? '0') ?? 0;

    final durationMin =
        (item['duration'] as num?)?.toInt() ??
        int.tryParse(item['duration']?.toString() ?? '');

    final halts =
        (item['halts'] as num?)?.toInt() ??
        int.tryParse(item['halts']?.toString() ?? '');

    final trainNumber = train['number']?.toString() ?? '';
    final trainName = train['name']?.toString() ?? '';
    final originCode = from['code']?.toString() ?? widget.fromCode;
    final originName = from['name']?.toString() ?? widget.fromName;
    final destinationCode = to['code']?.toString() ?? widget.toCode;
    final destinationName = to['name']?.toString() ?? widget.toName;

    return TrainCard(
      trainNumber: trainNumber,
      trainName: trainName,
      trainType: train['type']?.toString() ?? 'Express',
      fromCode: originCode,
      fromName: originName,
      toCode: destinationCode,
      toName: destinationName,
      departure: from['departure']?.toString() ?? '--',
      arrival: to['arrival']?.toString() ?? '--',
      distance: distD.round(),
      runDays: runDays,
      durationMin: durationMin,
      halts: halts,
      onTap: () {
        if (trainNumber.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TrainDetailsScreen(
              trainNumber: trainNumber,
              trainName: trainName,
              journeyInfo: TrainJourneyInfo(
                trainType: train['type']?.toString() ?? 'Express',
                fromCode: originCode,
                fromName: originName,
                toCode: destinationCode,
                toName: destinationName,
                departure: from['departure']?.toString() ?? '--',
                arrival: to['arrival']?.toString() ?? '--',
                distanceKm: distD.round(),
                durationMin: durationMin,
                halts: halts,
                runDays: runDays ?? const [],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TrainFilters {
  final Set<String> trainTypes;
  final Set<String> runDays;
  final int departureStart;
  final int departureEnd;
  final int maxHalts;
  final int maxDurationHours;
  final int maxDistanceKm;

  const _TrainFilters({
    this.trainTypes = const {},
    this.runDays = const {},
    this.departureStart = 0,
    this.departureEnd = 1439,
    this.maxHalts = 100,
    this.maxDurationHours = 120,
    this.maxDistanceKm = 5000,
  });

  static const days = {
    'mon': 'Mon',
    'tue': 'Tue',
    'wed': 'Wed',
    'thu': 'Thu',
    'fri': 'Fri',
    'sat': 'Sat',
    'sun': 'Sun',
  };
}
