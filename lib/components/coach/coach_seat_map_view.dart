import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/theme_controller.dart';
import '../../data/models/coach.dart';

class CoachSeatMapView extends StatefulWidget {
  final CoachInfo coach;
  final String? highlightedSeat;
  final Map<String, dynamic>? blueprints;
  final ValueChanged<String>? onSeatSelected;

  const CoachSeatMapView({
    super.key,
    required this.coach,
    this.highlightedSeat,
    this.blueprints,
    this.onSeatSelected,
  });

  @override
  State<CoachSeatMapView> createState() => _CoachSeatMapViewState();
}

class _CoachSeatMapViewState extends State<CoachSeatMapView> {
  final ScrollController _scrollController = ScrollController();
  String? _selectedSeat;

  @override
  void initState() {
    super.initState();
    _selectedSeat = widget.highlightedSeat;
    if (_selectedSeat != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToSeat(_selectedSeat!);
      });
    }
  }

  @override
  void didUpdateWidget(covariant CoachSeatMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final coachChanged =
        widget.coach.code != oldWidget.coach.code ||
        widget.coach.category != oldWidget.coach.category;
    if (coachChanged || widget.highlightedSeat != oldWidget.highlightedSeat) {
      _selectedSeat = widget.highlightedSeat;
      if (_selectedSeat != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToSeat(_selectedSeat!);
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _selectSeat(String seatNo) {
    setState(() => _selectedSeat = seatNo);
    widget.onSeatSelected?.call(seatNo);
  }

  Map<String, dynamic>? _findBlueprint() {
    final blueprints = widget.blueprints;
    if (blueprints == null) return null;

    final category = widget.coach.category.trim().toUpperCase();
    final candidates = <String>{
      category,
      widget.coach.code.trim().toUpperCase(),
      widget.coach.classType?.trim().toUpperCase() ?? '',
      widget.coach.className?.trim().toUpperCase() ?? '',
      _guessBlueprintKey(category),
    }..remove('');

    for (final candidate in candidates) {
      for (final entry in blueprints.entries) {
        if (entry.key.trim().toUpperCase() == candidate && entry.value is Map) {
          return Map<String, dynamic>.from(entry.value as Map);
        }
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _readCabins(Map<String, dynamic>? blueprint) {
    if (blueprint == null) return [];

    final rawLayout =
        blueprint['cabins'] ??
        blueprint['bays'] ??
        blueprint['sections'] ??
        blueprint['layout'];
    if (rawLayout is List) {
      final cabins = rawLayout
          .whereType<Map>()
          .map((cabin) => Map<String, dynamic>.from(cabin))
          .toList();
      if (cabins.isNotEmpty) return cabins;
    }
    if (rawLayout is Map) {
      return _readCabins(Map<String, dynamic>.from(rawLayout));
    }

    final seats = blueprint['seats'] ?? blueprint['berths'];
    if (seats is List && seats.isNotEmpty) {
      return [
        {'cabinNumber': 1, 'main': seats},
      ];
    }
    return [];
  }

  int _readSeatCount(
    Map<String, dynamic>? blueprint,
    List<Map<String, dynamic>> cabins,
  ) {
    final apiCount = _toInt(
      blueprint?['totalBerths'] ??
          blueprint?['totalSeats'] ??
          blueprint?['seatCount'] ??
          blueprint?['berthCount'],
    );
    if (apiCount != null && apiCount > 0) return apiCount;
    final layoutCount = cabins.fold<int>(0, (total, cabin) {
      final main = _asList(cabin['main'] ?? cabin['berths'] ?? cabin['seats']);
      final side = _asList(cabin['side']);
      return total + main.length + side.length;
    });
    if (layoutCount > 0) return layoutCount;
    if (widget.coach.totalBerths > 0) return widget.coach.totalBerths;
    return _typicalSeatCount(widget.coach.category);
  }

  bool _apiHasSeatStatus(List<Map<String, dynamic>> cabins) {
    for (final cabin in cabins) {
      for (final berth in [
        ..._asList(cabin['main'] ?? cabin['berths'] ?? cabin['seats']),
        ..._asList(cabin['side']),
      ]) {
        if (berth is Map &&
            (berth.containsKey('status') ||
                berth.containsKey('available') ||
                berth.containsKey('isAvailable') ||
                berth.containsKey('booked') ||
                berth.containsKey('isBooked'))) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.coach.category.toUpperCase();
    final codeUpper = widget.coach.code.toUpperCase();

    final isLoco = category == 'LOCO' || codeUpper.contains('ENG') || codeUpper.contains('VB');
    final isEog = category == 'EOG' || codeUpper == 'LPR' || codeUpper == 'SLRD' || codeUpper == 'VP' || codeUpper == 'SLR';
    final isPantry = category == 'PC' || category.contains('PANTRY') || codeUpper == 'PC';
    final isDoubleDecker = widget.coach.isDoubleDecker || category == 'ACDC' || category == 'DDC' || category.contains('DOUBLE');

    final blueprint = _findBlueprint();
    final cabins = _readCabins(blueprint);
    final seatCount = isDoubleDecker ? 120 : _readSeatCount(blueprint, cabins);
    final hasSeatStatus = _apiHasSeatStatus(cabins);
    final hasExactLayout = cabins.isNotEmpty;

    final isDark = ThemeController.instance.isDarkMode;
    final cardBg = isDark ? const Color(0xFF16161C) : const Color(0xFFFFFFFF);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? Colors.white54 : const Color(0xFF636366);
    final borderCol = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E5EA);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A84FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.coach.code,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF0A84FF),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isLoco
                      ? 'Locomotive Engine'
                      : isEog
                          ? 'Power Car / Luggage Van'
                          : isPantry
                              ? 'Pantry Car'
                              : isDoubleDecker
                                  ? 'AC Double Decker Express (3-Deck Chair Car)'
                                  : '${_getCategoryTitle(category)} ($seatCount Seats)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Active Selected Seat Info Banner
          if (_selectedSeat != null && _selectedSeat!.isNotEmpty && !isPantry && !isLoco && !isEog)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0A84FF).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF0A84FF).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.checkmark_circle_fill, color: Color(0xFF0A84FF), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Focused Seat / Berth #$_selectedSeat${_getBerthTypeLabel(category, _selectedSeat!).isNotEmpty ? " • ${_getBerthTypeLabel(category, _selectedSeat!)}" : ""}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF0A84FF),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _selectedSeat = null),
                    child: const Icon(CupertinoIcons.xmark_circle_fill, size: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),

          if (!isLoco && !isEog && !isPantry)
            Row(
              children: [
                if (hasSeatStatus) ...[
                  _legendDot(const Color(0xFF30D158), 'Available', textSecondary),
                  const SizedBox(width: 10),
                  _legendDot(const Color(0xFFFF9F0A), 'Booked', textSecondary),
                  const SizedBox(width: 10),
                ] else
                  _legendDot(textSecondary, 'Architectural Preview', textSecondary),
                const Spacer(),
                _legendDot(const Color(0xFF0A84FF), 'Selected Seat', textSecondary),
              ],
            ),
          const SizedBox(height: 14),

          // Seat Map Container
          SizedBox(
            height: 480,
            child: isLoco
                ? _nonPassengerView('Locomotive Engine Unit 🚂', 'Power Engine at position #${widget.coach.position}', CupertinoIcons.tram_fill, textPrimary, textSecondary)
                : isEog
                    ? _nonPassengerView('Power Car / Luggage & Guard Van 🔋', 'EOG Generator & Guard Van at position #${widget.coach.position}', CupertinoIcons.battery_charging, textPrimary, textSecondary)
                    : isPantry
                        ? _pantryView(textPrimary, textSecondary)
                        : isDoubleDecker
                            ? _doubleDeckerLayout(seatCount, isDark, textPrimary, textSecondary, borderCol)
                            : hasExactLayout
                                ? ListView.builder(
                                    controller: _scrollController,
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: cabins.length,
                                    itemBuilder: (_, index) =>
                                        _buildBlueprintCabin(cabins[index], index, isDark, textPrimary, textSecondary, borderCol),
                                  )
                                : _buildTypicalLayout(category, seatCount, isDark, textPrimary, textSecondary, borderCol),
          ),
        ],
      ),
    );
  }

  String _getBerthTypeLabel(String category, String seatStr) {
    final s = int.tryParse(seatStr);
    if (s == null || s < 1) return '';
    final cat = category.toUpperCase();

    if (cat.startsWith('H') || cat == '1A') {
      final isCoupe = (s - 1) % 4 >= 2;
      return isCoupe ? 'Coupe Berth' : ((s % 2 == 1) ? 'Lower Berth 🛏️' : 'Upper Berth 🛏️');
    }

    if (cat.startsWith('A') || cat == '2A') {
      final rem = s % 6;
      if (rem == 1 || rem == 3) return 'Lower Berth 🛏️';
      if (rem == 2 || rem == 4) return 'Upper Berth 🛏️';
      if (rem == 5) return 'Side Lower 🪟';
      if (rem == 0) return 'Side Upper 🪟';
    }

    if (cat.startsWith('B') || cat == '3A' || cat.startsWith('S') || cat == 'SL') {
      final rem = s % 8;
      if (rem == 1 || rem == 4) return 'Lower Berth 🛏️';
      if (rem == 2 || rem == 5) return 'Middle Berth 🛏️';
      if (rem == 3 || rem == 6) return 'Upper Berth 🛏️';
      if (rem == 7) return 'Side Lower 🪟';
      if (rem == 0) return 'Side Upper 🪟';
    }

    if (cat.startsWith('M') || cat == '3E') {
      final rem = s % 9;
      if (rem == 1 || rem == 4) return 'Lower Berth 🛏️';
      if (rem == 2 || rem == 5) return 'Middle Berth 🛏️';
      if (rem == 3 || rem == 6) return 'Upper Berth 🛏️';
      if (rem == 7) return 'Side Lower 🪟';
      if (rem == 8) return 'Side Middle 🪟';
      if (rem == 0) return 'Side Upper 🪟';
    }

    if (cat == 'CC' || cat == '2S' || cat == 'GEN' || cat == 'GS' || cat == 'ACDC' || cat == 'DDC') {
      final rem = s % 5;
      if (rem == 1 || rem == 0) return 'Window Seat 🪟';
      if (rem == 2) return 'Middle Seat';
      if (rem == 3 || rem == 4) return 'Aisle Seat 🚶';
    }

    if (cat == 'EC') {
      final rem = s % 4;
      if (rem == 1 || rem == 0) return 'Window Seat 🪟';
      if (rem == 2 || rem == 3) return 'Aisle Seat 🚶';
    }

    return '';
  }

  String _getCategoryTitle(String cat) {
    if (cat == 'LOCO') return 'Locomotive Engine';
    if (cat == 'EOG') return 'Power Car / Luggage Van';
    if (cat == 'ACDC' || cat == 'DDC') return 'AC Double Decker Chair Car';
    if (cat.startsWith('H') || cat == '1A') return 'First AC (1A) Cabin/Coupe';
    if (cat.startsWith('A') || cat == '2A') return '2-Tier AC (2A) Sleeper';
    if (cat.startsWith('B') || cat == '3A') return '3-Tier AC (3A) Sleeper';
    if (cat.startsWith('M') || cat == '3E') return '3-Tier Economy (3E) Sleeper';
    if (cat.startsWith('S') || cat == 'SL') return 'Sleeper Class (SL)';
    if (cat == 'EC') return 'Executive Chair Car (EC)';
    if (cat == 'CC') return 'AC Chair Car (CC)';
    if (cat == '2S' || cat == 'GEN' || cat == 'GS' || cat == 'UR') return 'General / 2nd Seating (GS)';
    return '$cat Class';
  }

  String _guessBlueprintKey(String category) {
    if (category.startsWith('H')) return '1A';
    if (category.startsWith('A')) return '2A';
    if (category.startsWith('B')) return '3A';
    if (category.startsWith('M')) return '3E';
    if (category.startsWith('S')) return 'SL';
    if (category == 'EC') return 'EC';
    if (category == 'CC' || category == 'ACDC' || category == 'DDC') return 'CC';
    if (category == '2S' || category == 'GS' || category == 'GEN' || category == 'UR') return '2S';
    return category;
  }

  static List _asList(dynamic value) => value is List ? value : const [];

  static int? _toInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  Widget _legendDot(Color color, String label, Color textSecondary) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(color: textSecondary, fontSize: 9.5, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildBlueprintCabin(
    Map<String, dynamic> cabin,
    int index,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
  ) {
    final cabinNo = cabin['cabinNumber'] ?? cabin['bayNumber'] ?? index + 1;
    final mainBerths = _asList(cabin['main'] ?? cabin['berths'] ?? cabin['seats']);
    final sideBerths = _asList(cabin['side']);

    if (mainBerths.isEmpty && sideBerths.isEmpty) return const SizedBox.shrink();

    final bayBg = isDark ? const Color(0xFF09090C) : const Color(0xFFF8F9FA);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bayBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bay / Cabin $cabinNo',
                  style: GoogleFonts.inter(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: mainBerths.map((b) => _buildApiSeat(b, isDark, textPrimary, textSecondary, borderCol)).toList(),
                ),
              ],
            ),
          ),
          if (sideBerths.isNotEmpty) ...[
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Side Bay',
                  style: GoogleFonts.inter(color: textSecondary, fontSize: 9, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  direction: Axis.vertical,
                  spacing: 6,
                  runSpacing: 6,
                  children: sideBerths.map((b) => _buildApiSeat(b, isDark, textPrimary, textSecondary, borderCol)).toList(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildApiSeat(
    dynamic value,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
  ) {
    if (value is Map) {
      final seat = Map<String, dynamic>.from(value);
      final number = seat['number'] ?? seat['seatNumber'] ?? seat['berthNumber'] ?? '—';
      final type = seat['type'] ?? seat['berthType'] ?? seat['label'] ?? '';
      return _seatBox('$number', '$type', status: seat, isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary, borderCol: borderCol);
    }
    return _seatBox(value.toString(), '', isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary, borderCol: borderCol);
  }

  static int _typicalSeatCount(String category) {
    if (category.startsWith('H') || category == '1A') return 24;
    if (category.startsWith('A') || category == '2A') return 54;
    if (category.startsWith('B') || category == '3A') return 72;
    if (category.startsWith('M') || category == '3E') return 83;
    if (category.startsWith('S') || category == 'SL') return 72;
    if (category == 'EC') return 45;
    if (category == 'CC' || category == 'ACDC' || category == 'DDC') return 78;
    if (category == '2S' || category == 'GEN' || category == 'GS' || category == 'UR') return 108;
    return 72;
  }

  // AC Double Decker 3-Deck Seating Layout (Upper Deck, Lower Deck, Mezzanine)
  Widget _doubleDeckerLayout(
    int seatCount,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
  ) {
    return ListView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      children: [
        _deckSectionCard(
          title: 'UPPER DECK 🔼',
          subtitle: 'Seats 1 – 50 (Upper Floor 3+2 Seating)',
          startSeat: 1,
          count: 50,
          isThreePlusTwo: true,
          isDark: isDark,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          borderCol: borderCol,
        ),
        const SizedBox(height: 14),
        _deckSectionCard(
          title: 'LOWER DECK 🔽',
          subtitle: 'Seats 51 – 100 (Lower Floor 3+2 Seating)',
          startSeat: 51,
          count: 50,
          isThreePlusTwo: true,
          isDark: isDark,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          borderCol: borderCol,
        ),
        const SizedBox(height: 14),
        _deckSectionCard(
          title: 'MEZZANINE / END DECKS 🪜',
          subtitle: 'Seats 101 – 120 (Entry Level 2+2 Seating)',
          startSeat: 101,
          count: 20,
          isThreePlusTwo: false,
          isDark: isDark,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          borderCol: borderCol,
        ),
      ],
    );
  }

  Widget _deckSectionCard({
    required String title,
    required String subtitle,
    required int startSeat,
    required int count,
    required bool isThreePlusTwo,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderCol,
  }) {
    final bayBg = isDark ? const Color(0xFF09090C) : const Color(0xFFF8F9FA);
    final rowSeatsCount = isThreePlusTwo ? 5 : 4;
    final rowCount = (count / rowSeatsCount).ceil();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bayBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A84FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF0A84FF),
                    fontWeight: FontWeight.w900,
                    fontSize: 10.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(rowCount, (rIdx) {
            if (isThreePlusTwo) {
              return _chairCarRow(rIdx, count, isDark, textPrimary, textSecondary, borderCol, startOffset: startSeat - 1);
            } else {
              return _executiveChairRow(rIdx, count, isDark, textPrimary, textSecondary, borderCol, startOffset: startSeat - 1);
            }
          }),
        ],
      ),
    );
  }

  Widget _buildTypicalLayout(
    String category,
    int seatCount,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
  ) {
    if (seatCount <= 0) return _noSeatData(textSecondary);

    if (category.startsWith('H') || category == '1A') {
      final cabinCount = (seatCount / 4).ceil();
      return ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        itemCount: cabinCount,
        itemBuilder: (_, index) => _firstClassCabinBay(index, seatCount, isDark, textPrimary, textSecondary, borderCol),
      );
    }

    if (category == 'EC') {
      final rowCount = (seatCount / 4).ceil();
      return ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        itemCount: rowCount,
        itemBuilder: (_, index) => _executiveChairRow(index, seatCount, isDark, textPrimary, textSecondary, borderCol),
      );
    }

    if (category == 'CC' || category == '2S' || category == 'GEN' || category == 'GS' || category == 'UR') {
      final rowCount = (seatCount / 5).ceil();
      return ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        itemCount: rowCount,
        itemBuilder: (_, index) => _chairCarRow(index, seatCount, isDark, textPrimary, textSecondary, borderCol),
      );
    }

    final isTwoTier = category.startsWith('A') || category == '2A';
    final is3Economy = category.startsWith('M') || category == '3E';
    final seatsPerBay = isTwoTier ? 6 : (is3Economy ? 9 : 8);
    final bayCount = (seatCount / seatsPerBay).ceil();

    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      itemCount: bayCount,
      itemBuilder: (_, bayIndex) => _sleeperBay(bayIndex, seatCount, isTwoTier, is3Economy, isDark, textPrimary, textSecondary, borderCol),
    );
  }

  Widget _firstClassCabinBay(
    int cabinIndex,
    int seatCount,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
  ) {
    final start = cabinIndex * 4 + 1;
    final cabinLetter = String.fromCharCode(65 + (cabinIndex % 26));
    final isCoupe = cabinIndex % 2 == 1 && (start + 1 <= seatCount);

    final bayBg = isDark ? const Color(0xFF09090C) : const Color(0xFFF8F9FA);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bayBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.lock_fill, color: Color(0xFF0A84FF), size: 14),
              const SizedBox(width: 6),
              Text(
                'First AC ${isCoupe ? "Coupe" : "Cabin"} -$cabinLetter',
                style: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const Spacer(),
              Text(
                isCoupe ? '2 Berths' : '4 Berths',
                style: GoogleFonts.inter(color: textSecondary, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _layoutSeat(start, 'LOWER', visible: start <= seatCount, isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary, borderCol: borderCol),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _layoutSeat(start + 1, 'UPPER', visible: start + 1 <= seatCount, isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary, borderCol: borderCol),
              ),
            ],
          ),
          if (!isCoupe && start + 2 <= seatCount) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _layoutSeat(start + 2, 'LOWER', visible: start + 2 <= seatCount, isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary, borderCol: borderCol),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _layoutSeat(start + 3, 'UPPER', visible: start + 3 <= seatCount, isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary, borderCol: borderCol),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _sleeperBay(
    int bayIndex,
    int seatCount,
    bool isTwoTier,
    bool is3Economy,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
  ) {
    final seatsPerBay = isTwoTier ? 6 : (is3Economy ? 9 : 8);
    final start = bayIndex * seatsPerBay + 1;
    final bayBg = isDark ? const Color(0xFF09090C) : const Color(0xFFF8F9FA);

    final mainCount = isTwoTier ? 4 : 6;
    final mainBerths = List.generate(mainCount, (i) => start + i);
    final mainLabels = isTwoTier
        ? ['LOWER', 'UPPER', 'LOWER', 'UPPER']
        : ['LOWER', 'MIDDLE', 'UPPER', 'LOWER', 'MIDDLE', 'UPPER'];

    final sideStart = start + mainCount;
    final sideCount = is3Economy ? 3 : 2;
    final sideBerths = List.generate(sideCount, (i) => sideStart + i);
    final sideLabels = is3Economy
        ? ['SIDE LOWER', 'SIDE MIDDLE', 'SIDE UPPER']
        : ['SIDE LOWER', 'SIDE UPPER'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bayBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Bay ${bayIndex + 1}',
                style: GoogleFonts.inter(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main Bay Berths
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    Row(
                      children: List.generate(mainCount ~/ 2, (i) {
                        final seatNo = mainBerths[i];
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: _layoutSeat(seatNo, mainLabels[i], visible: seatNo <= seatCount, isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary, borderCol: borderCol),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(mainCount ~/ 2, (i) {
                        final idx = (mainCount ~/ 2) + i;
                        final seatNo = mainBerths[idx];
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: _layoutSeat(seatNo, mainLabels[idx], visible: seatNo <= seatCount, isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary, borderCol: borderCol),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),

              // Gangway Aisle Divider
              Container(
                width: 16,
                alignment: Alignment.center,
                child: Container(
                  width: 1.5,
                  height: 90,
                  color: borderCol,
                ),
              ),

              // Side Bay Berths
              Expanded(
                flex: 1,
                child: Column(
                  children: List.generate(sideCount, (i) {
                    final seatNo = sideBerths[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _layoutSeat(seatNo, sideLabels[i], visible: seatNo <= seatCount, side: true, isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary, borderCol: borderCol),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chairCarRow(
    int rowIndex,
    int seatCount,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color borderCol, {
    int startOffset = 0,
  }) {
    final start = startOffset + rowIndex * 5 + 1;
    final maxSeat = startOffset + seatCount;
    final bayBg = isDark ? const Color(0xFF09090C) : const Color(0xFFF8F9FA);

    final leftSeats = [start, start + 1, start + 2];
    final leftLabels = ['WINDOW', 'MIDDLE', 'AISLE'];

    final rightSeats = [start + 3, start + 4];
    final rightLabels = ['AISLE', 'WINDOW'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bayBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: List.generate(3, (i) {
                final seatNo = leftSeats[i];
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _layoutSeat(seatNo, leftLabels[i], visible: seatNo <= maxSeat, isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary, borderCol: borderCol),
                  ),
                );
              }),
            ),
          ),
          Container(
            width: 18,
            alignment: Alignment.center,
            child: Text(
              'AISLE',
              style: GoogleFonts.inter(color: textSecondary.withValues(alpha: 0.5), fontSize: 7, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: List.generate(2, (i) {
                final seatNo = rightSeats[i];
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _layoutSeat(seatNo, rightLabels[i], visible: seatNo <= maxSeat, isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary, borderCol: borderCol),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _executiveChairRow(
    int rowIndex,
    int seatCount,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color borderCol, {
    int startOffset = 0,
  }) {
    final start = startOffset + rowIndex * 4 + 1;
    final maxSeat = startOffset + seatCount;
    final bayBg = isDark ? const Color(0xFF09090C) : const Color(0xFFF8F9FA);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bayBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _layoutSeat(start, 'WINDOW', visible: start <= maxSeat, isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary, borderCol: borderCol)),
                const SizedBox(width: 4),
                Expanded(child: _layoutSeat(start + 1, 'AISLE', visible: start + 1 <= maxSeat, isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary, borderCol: borderCol)),
              ],
            ),
          ),
          Container(
            width: 24,
            alignment: Alignment.center,
            child: Text(
              'AISLE',
              style: GoogleFonts.inter(color: textSecondary.withValues(alpha: 0.5), fontSize: 7, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _layoutSeat(start + 2, 'AISLE', visible: start + 2 <= maxSeat, isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary, borderCol: borderCol)),
                const SizedBox(width: 4),
                Expanded(child: _layoutSeat(start + 3, 'WINDOW', visible: start + 3 <= maxSeat, isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary, borderCol: borderCol)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _layoutSeat(
    int number,
    String label, {
    required bool visible,
    bool side = false,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderCol,
  }) {
    if (!visible) return const SizedBox.shrink();
    final selected = _selectedSeat == '$number';

    final seatBg = selected
        ? const Color(0xFF0A84FF)
        : (isDark ? const Color(0xFF16161C) : const Color(0xFFFFFFFF));

    final seatTextColor = selected ? Colors.white : textPrimary;
    final labelColor = selected ? Colors.white70 : textSecondary;

    return GestureDetector(
      onTap: () => _selectSeat('$number'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        decoration: BoxDecoration(
          color: seatBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF0A84FF) : borderCol,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0A84FF).withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: labelColor,
                fontWeight: FontWeight.bold,
                fontSize: side ? 7.5 : 8.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$number',
              style: GoogleFonts.inter(
                color: seatTextColor,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nonPassengerView(String title, String subtitle, IconData icon, Color textPrimary, Color textSecondary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: const Color(0xFF0A84FF).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: const Color(0xFF0A84FF),
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: textSecondary,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pantryView(Color textPrimary, Color textSecondary) {
    return _nonPassengerView('Pantry Car 🍽️', 'Catering & kitchen unit at position #${widget.coach.position}', CupertinoIcons.scissors, textPrimary, textSecondary);
  }

  Widget _noSeatData(Color textSecondary) {
    return Center(
      child: Text(
        'Seat layout is not available for this coach.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(color: textSecondary, fontSize: 12),
      ),
    );
  }

  void _scrollToSeat(String seatNumber) {
    if (!_scrollController.hasClients) return;
    final seatIndex = int.tryParse(seatNumber);
    if (seatIndex == null || seatIndex < 1) return;
    final category = widget.coach.category.toUpperCase();
    final isDoubleDecker = widget.coach.isDoubleDecker || category == 'ACDC' || category == 'DDC' || category.contains('DOUBLE');

    if (isDoubleDecker) {
      double offset = 0;
      if (seatIndex > 100) {
        offset = 800.0;
      } else if (seatIndex > 50) {
        offset = 400.0;
      }
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
      return;
    }

    final hasExactLayout = _readCabins(_findBlueprint()).isNotEmpty;
    final seatsPerBay = isFirstClass(category) ? 4 : _seatsPerBay(category);
    final bayHeight = 110.0;
    final offset =
        (hasExactLayout
                ? ((seatIndex - 1) ~/ 4) * 58.0
                : ((seatIndex - 1) ~/ seatsPerBay) * bayHeight)
            .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  bool isFirstClass(String category) => category.startsWith('H') || category == '1A';

  int _seatsPerBay(String category) {
    if (category.startsWith('A') || category == '2A') return 6;
    if (category.startsWith('M') || category == '3E') return 9;
    if (category == 'EC') return 4;
    if (category == 'CC' || category == '2S' || category == 'GS' || category == 'ACDC' || category == 'DDC') return 5;
    return 8;
  }

  Widget _seatBox(
    String number,
    String type, {
    Map<String, dynamic>? status,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderCol,
  }) {
    final selected = _selectedSeat == number;
    final seatColor = _statusColor(status);
    final borderColor = selected ? const Color(0xFF0A84FF) : seatColor;
    return GestureDetector(
      onTap: number == '—'
          ? null
          : () => _selectSeat(number),
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF0A84FF)
              : seatColor.withValues(alpha: status == null ? 0.1 : 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
        ),
        child: Column(
          children: [
            Text(
              number,
              style: GoogleFonts.inter(
                color: selected ? Colors.white : textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
            if (type.isNotEmpty)
              Text(
                type,
                style: GoogleFonts.inter(
                  color: selected ? Colors.white70 : textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 8,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(Map<String, dynamic>? seat) {
    if (seat == null) return const Color(0xFF8E8E93);
    final isAvailable = seat['available'] ?? seat['isAvailable'];
    final isBooked = seat['booked'] ?? seat['isBooked'];
    if (isAvailable == true || isBooked == false) return const Color(0xFF30D158);
    if (isAvailable == false || isBooked == true) return const Color(0xFFFF9F0A);

    final status = (seat['status'] ?? seat['berthStatus'] ?? '')
        .toString()
        .toLowerCase();
    if (status.contains('avail') || status == 'avl' || status == 'free') {
      return const Color(0xFF30D158);
    }
    if (status.contains('book') ||
        status.contains('occup') ||
        status.contains('confirm') ||
        status == 'rac' ||
        status == 'wl') {
      return const Color(0xFFFF9F0A);
    }
    return const Color(0xFF8E8E93);
  }
}
