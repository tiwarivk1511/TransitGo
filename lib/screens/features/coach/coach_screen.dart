import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../components/coach/coach_seat_map_view.dart';
import '../../../components/coach/train_rake_view.dart';
import '../../../components/common/error_box.dart';
import '../../../components/common/loading_indicator.dart';
import '../../../components/train/TrainNumberAutocomplete.dart';
import '../../../core/cache/offline_cache.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../data/models/coach.dart';
import '../../../services/coach_service.dart';

class _StationEntry {
  final String code;
  final StationCoachStop stop;
  final bool isOrigin;
  final bool isDestination;
  final bool isReversal;
  final bool isHalt;

  const _StationEntry({
    required this.code,
    required this.stop,
    required this.isOrigin,
    required this.isDestination,
    required this.isReversal,
    required this.isHalt,
  });
}

class CoachScreen extends StatefulWidget {
  final String? initialTrainNumber;

  const CoachScreen({super.key, this.initialTrainNumber});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _ctrl = TextEditingController();
  final _seatCtrl = TextEditingController();

  String? _searchedSeat;
  String? _selectedStationCode;
  bool _loading = false;
  String? _error;
  TrainFormation? _data;
  CoachInfo? _selectedCoach;

  @override
  void initState() {
    super.initState();
    final trainNumber = widget.initialTrainNumber?.trim();
    if (trainNumber != null && trainNumber.isNotEmpty) {
      _ctrl.text = trainNumber;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetch();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _seatCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final no = _ctrl.text.trim().split(' - ').first;
    if (no.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _data = null;
      _selectedCoach = null;
      _searchedSeat = null;
      _selectedStationCode = null;
      _seatCtrl.clear();
    });

    final f = await CoachService.fetch(no);
    if (!mounted) return;

    if (f != null) {
      await OfflineCache.addHistory(
        'coach',
        no,
        label: '${f.trainNumber} • ${f.trainName}',
        data: {'trainNumber': no, 'trainName': f.trainName},
      );
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _data = f;
      if (f == null) _error = 'Coach details unavailable. Check train number.';

      if (f != null) {
        final stops = _getFilteredStations(f);
        if (stops.isNotEmpty) {
          _selectedStationCode = stops.first.code;
        }
      }
    });
  }

  List<CoachInfo> _getActiveCoaches(TrainFormation f) {
    if (_selectedStationCode != null &&
        f.stationVariations.containsKey(_selectedStationCode)) {
      return f.stationVariations[_selectedStationCode]!;
    }
    return f.coaches;
  }

  StationCoachStop? _getActiveStop(TrainFormation f) {
    if (_selectedStationCode == null) return null;
    return f.stationStops[_selectedStationCode];
  }

  List<_StationEntry> _getFilteredStations(TrainFormation f) {
    final routeCodes = f.routeStationCodes.map((c) => c.toUpperCase()).toList();

    final originCode = routeCodes.isNotEmpty ? routeCodes.first : '';
    final destCode = routeCodes.isNotEmpty ? routeCodes.last : '';

    final out = <_StationEntry>[];

    for (final code in routeCodes) {
      final stop = f.stationStops[code];
      if (stop == null) continue;

      final isOrigin = code == originCode;
      final isDest = code == destCode;
      final isReversal = stop.reversal;
      final isHalt = stop.isHalt;

      // Filter: Show ONLY halt stations (isHalt == true) or reversal stations or origin/dest
      if (isHalt || isReversal || isOrigin || isDest) {
        out.add(
          _StationEntry(
            code: code,
            stop: stop,
            isOrigin: isOrigin,
            isDestination: isDest,
            isReversal: isReversal,
            isHalt: isHalt,
          ),
        );
      }
    }

    if (out.isEmpty) {
      f.stationStops.forEach((k, s) {
        if (s.isHalt || s.reversal) {
          out.add(
            _StationEntry(
              code: k,
              stop: s,
              isOrigin: k == originCode,
              isDestination: k == destCode,
              isReversal: s.reversal,
              isHalt: s.isHalt,
            ),
          );
        }
      });
    }

    return out;
  }

  void _onSearchSeat() {
    final text = _seatCtrl.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _searchedSeat = text;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDarkMode;
    final bgColor = isDark ? const Color(0xFF09090C) : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF16161C) : const Color(0xFFFFFFFF);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? Colors.white54 : const Color(0xFF636366);
    final borderCol = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E5EA);

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
          'Coach Position & Seating',
          style: GoogleFonts.inter(
            color: textPrimary,
            fontWeight: FontWeight.bold,
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
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          children: [
            _introCard(cardBg, textPrimary, textSecondary, borderCol),
            const SizedBox(height: 16),

            // Train Number Input Card
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
                  Text(
                    'SEARCH TRAIN RAKE',
                    style: GoogleFonts.inter(
                      color: textSecondary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TrainNumberAutocomplete(
                    controller: _ctrl,
                    hint: 'Train number or name (e.g. 12428, Rewa SF Express)',
                    icon: CupertinoIcons.tram_fill,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(CupertinoIcons.square_stack_3d_up_fill, size: 18),
                      label: Text(
                        'Show Coach Position & Seat Map',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A84FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _loading ? null : _fetch,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_loading)
              const LoadingIndicator(
                color: Color(0xFF0A84FF),
                label: 'Fetching dynamic rake layout & station stops…',
              )
            else if (_error != null)
              ErrorBox(message: _error!, onRetry: _fetch)
            else if (_data != null)
              _coachContent(_data!, cardBg, textPrimary, textSecondary, borderCol, isDark),
          ],
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
              CupertinoIcons.square_stack_3d_up_fill,
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
                  'Coach & Seat Map Explorer',
                  style: GoogleFonts.inter(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Explore live rake composition, platform direction, and class-wise seat berth layouts.',
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

  Widget _coachContent(
    TrainFormation f,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
    bool isDark,
  ) {
    final activeCoaches = _getActiveCoaches(f);
    final filteredStations = _getFilteredStations(f);
    final activeStop = _getActiveStop(f);

    final currentCoach =
        _selectedCoach ??
        (activeCoaches.isNotEmpty ? activeCoaches.first : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Train Rake Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderCol),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.trainName,
                          style: GoogleFonts.inter(
                            color: textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${f.trainNumber} • ${activeCoaches.length} coaches'
                          '${activeStop != null ? " • at ${activeStop.stationName}" : ""}',
                          style: GoogleFonts.inter(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A84FF).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'ENGINE 🚂 ➔ REAR',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF0A84FF),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Direct Seat Number Search Field
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.withValues(alpha: 0.08) : const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderCol),
                      ),
                      child: TextField(
                        controller: _seatCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.inter(color: textPrimary, fontSize: 12.5),
                        onSubmitted: (_) => _onSearchSeat(),
                        decoration: InputDecoration(
                          icon: const Icon(CupertinoIcons.search, size: 16, color: Color(0xFF0A84FF)),
                          hintText: 'Highlight Seat / Berth (e.g. 42 or 18)',
                          hintStyle: GoogleFonts.inter(color: textSecondary, fontSize: 12),
                          border: InputBorder.none,
                          suffixIcon: _seatCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 16, color: Colors.grey),
                                  onPressed: () {
                                    _seatCtrl.clear();
                                    setState(() => _searchedSeat = null);
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _onSearchSeat,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A84FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Find Seat',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        if (filteredStations.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'COMMERCIAL HALTS (${filteredStations.length}) & REVERSAL STATIONS',
            style: GoogleFonts.inter(
              color: textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: filteredStations.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final e = filteredStations[i];
                final isSelected = _selectedStationCode == e.code;

                Color accent;
                String tag = '';
                if (e.isOrigin) {
                  accent = const Color(0xFF30D158);
                  tag = 'ORIGIN';
                } else if (e.isDestination) {
                  accent = const Color(0xFFFF375F);
                  tag = 'DEST';
                } else if (e.isReversal) {
                  accent = const Color(0xFFFF9F0A);
                  tag = 'REVERSAL';
                } else {
                  accent = const Color(0xFF0A84FF);
                  tag = 'HALT';
                }

                return ChoiceChip(
                  label: Text('${e.stop.stationName} ($tag)'),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _selectedStationCode = e.code;
                      _selectedCoach = null;
                      _searchedSeat = null;
                      _seatCtrl.clear();
                    });
                  },
                  backgroundColor: isDark ? cardBg : const Color(0xFFE5E5EA),
                  selectedColor: accent,
                  side: BorderSide(
                    color: isSelected ? accent : borderCol,
                  ),
                  labelStyle: GoogleFonts.inter(
                    color: isSelected ? Colors.white : textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                );
              },
            ),
          ),
        ],

        const SizedBox(height: 20),

        // 3D Rake Visualizer View
        TrainRakeView(
          trainName: f.trainName,
          trainType: f.trainType,
          officialLivery: f.officialLivery,
          coaches: activeCoaches,
          selectedCoach: currentCoach,
          onCoachSelected: (coach) => setState(() => _selectedCoach = coach),
        ),

        // Quick Coach Chips Bar
        if (activeCoaches.isNotEmpty) ...[
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: activeCoaches.map((c) {
                final isSelected = currentCoach?.code == c.code;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCoach = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF0A84FF)
                          : (isDark ? cardBg : const Color(0xFFE5E5EA)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isSelected ? const Color(0xFF0A84FF) : borderCol),
                    ),
                    child: Text(
                      c.code,
                      style: GoogleFonts.inter(
                        color: isSelected ? Colors.white : textPrimary,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        if (currentCoach != null) ...[
          const SizedBox(height: 20),
          CoachSeatMapView(
            coach: currentCoach,
            highlightedSeat: _searchedSeat,
            blueprints: f.blueprints,
            onSeatSelected: (seatNo) {
              setState(() => _searchedSeat = seatNo);
            },
          ),
        ],
      ],
    );
  }
}
