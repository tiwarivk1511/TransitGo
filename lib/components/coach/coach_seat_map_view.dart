import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/theme_controller.dart';
import '../../data/models/coach.dart';
import '../../services/translation_service.dart';

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
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (cabins.isNotEmpty) return cabins;
    }
    return [];
  }

  void _scrollToSeat(String seatNo) {
    void executeScroll() {
      if (!_scrollController.hasClients) return;
      final cleanDigits = seatNo.replaceAll(RegExp(r'[^\d]'), '');
      final parsedSeat = int.tryParse(cleanDigits.isNotEmpty ? cleanDigits : seatNo);
      if (parsedSeat == null || parsedSeat < 1) return;

      final approxIndex = ((parsedSeat - 1) / 8).floor();
      final maxExtent = _scrollController.position.maxScrollExtent;
      final targetOffset = (approxIndex * 130.0).clamp(0.0, maxExtent);

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    }

    if (!_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) executeScroll();
      });
    } else {
      executeScroll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDarkMode;
    final cardBg = isDark ? const Color(0xFF16161C) : const Color(0xFFFFFFFF);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? Colors.white54 : const Color(0xFF8E8E93);
    final borderCol = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E5EA);

    final category = widget.coach.category.toUpperCase();
    final blueprint = _findBlueprint();
    final cabins = _readCabins(blueprint);
    final hasExactLayout = cabins.isNotEmpty;

    final seatCount =
        blueprint?['total_seats'] as int? ??
        blueprint?['seats_count'] as int? ??
        (widget.coach.totalBerths > 0 ? widget.coach.totalBerths : null) ??
        _guessSeatCount(category);

    final isPantry = category == 'PC' || category == 'PANTRY';
    final isEog = category == 'EOG' || category == 'SLR' || category == 'POWER';
    final isLoco = category == 'LOCO' || category == 'ENG';
    final isDoubleDecker = category == 'ACDC' || category == 'DDC';
    final hasSeatStatus = widget.coach.hasSeats;

    return Container(
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
                      ? 'Locomotive Engine'.tr
                      : isEog
                          ? 'Power Car / Luggage Van'.tr
                          : isPantry
                              ? 'Pantry Car'.tr
                              : isDoubleDecker
                                  ? 'AC Double Decker Express (3-Deck Chair Car)'.tr
                                  : '${_getCategoryTitle(category).tr} ($seatCount ${'Seats'.tr})',
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
                      '${'Focused Seat / Berth #'.tr}$_selectedSeat${_getBerthTypeLabel(category, _selectedSeat!).isNotEmpty ? " • ${_getBerthTypeLabel(category, _selectedSeat!).tr}" : ""}',
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
                  _legendDot(const Color(0xFF30D158), 'Available'.tr, textSecondary),
                  const SizedBox(width: 10),
                  _legendDot(const Color(0xFFFF9F0A), 'Booked'.tr, textSecondary),
                  const SizedBox(width: 10),
                ] else
                  _legendDot(textSecondary, 'Architectural Preview'.tr, textSecondary),
                const Spacer(),
                _legendDot(const Color(0xFF0A84FF), 'Selected Seat'.tr, textSecondary),
              ],
            ),
          const SizedBox(height: 14),

          SizedBox(
            height: 480,
            child: isLoco
                ? _nonPassengerView('Locomotive Engine Unit 🚂'.tr, '${'Power Engine at position #'.tr}${widget.coach.position}', CupertinoIcons.tram_fill, textPrimary, textSecondary)
                : isEog
                    ? _nonPassengerView('Power Car / Luggage & Guard Van 🔋'.tr, '${'EOG Generator & Guard Van at position #'.tr}${widget.coach.position}', CupertinoIcons.battery_charging, textPrimary, textSecondary)
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
    return int.tryParse(value?.toString() ?? '');
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
          style: GoogleFonts.inter(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _nonPassengerView(String title, String subtitle, IconData icon, Color textPrimary, Color textSecondary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: const Color(0xFF0A84FF)),
          const SizedBox(height: 12),
          Text(title, style: GoogleFonts.inter(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.inter(color: textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _pantryView(Color textPrimary, Color textSecondary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.sparkles, size: 48, color: Color(0xFFFF9F0A)),
          const SizedBox(height: 12),
          Text('Onboard Catering & Kitchen Pantry Car 🍳'.tr, style: GoogleFonts.inter(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Contains food prep equipment, refrigerators & staff catering area.'.tr, textAlign: TextAlign.center, style: GoogleFonts.inter(color: textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _doubleDeckerLayout(int totalSeats, bool isDark, Color textPrimary, Color textSecondary, Color borderCol) {
    final lowerCount = (totalSeats * 0.45).round();
    final upperCount = (totalSeats * 0.45).round();
    final mezzanineCount = totalSeats - lowerCount - upperCount;

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        _deckSection('UPPER DECK CHAIR CAR 🔝'.tr, 1, upperCount, isDark, textPrimary, textSecondary, borderCol),
        const SizedBox(height: 16),
        _deckSection('MEZZANINE END DECK 🚪'.tr, upperCount + 1, upperCount + mezzanineCount, isDark, textPrimary, textSecondary, borderCol),
        const SizedBox(height: 16),
        _deckSection('LOWER DECK CHAIR CAR 🔽'.tr, upperCount + mezzanineCount + 1, totalSeats, isDark, textPrimary, textSecondary, borderCol),
      ],
    );
  }

  Widget _deckSection(String title, int start, int end, bool isDark, Color textPrimary, Color textSecondary, Color borderCol) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: GoogleFonts.inter(color: const Color(0xFF0A84FF), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
      const SizedBox(height: 8),
      _buildTypicalChairCar(start, end, isDark, textPrimary, textSecondary, borderCol),
    ],
  );

  Widget _buildBlueprintCabin(Map<String, dynamic> cabin, int index, bool isDark, Color textPrimary, Color textSecondary, Color borderCol) {
    final title = (cabin['name'] ?? cabin['title'] ?? cabin['label'] ?? 'CABIN / BAY ${index + 1}').toString();
    final mainSeats = _asList(cabin['main'] ?? cabin['seats'] ?? cabin['left']);
    final sideSeats = _asList(cabin['side'] ?? cabin['right']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF09090C) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase().tr, style: GoogleFonts.inter(color: textSecondary, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: mainSeats.map((s) => _seatBox(s, isDark, textPrimary, borderCol)).toList(),
                ),
              ),
              if (sideSeats.isNotEmpty) ...[
                Container(width: 1, height: 40, color: borderCol, margin: const EdgeInsets.symmetric(horizontal: 8)),
                Expanded(
                  flex: 2,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: sideSeats.map((s) => _seatBox(s, isDark, textPrimary, borderCol)).toList(),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypicalLayout(String category, int seatCount, bool isDark, Color textPrimary, Color textSecondary, Color borderCol) {
    if (category == 'EC') {
      return _buildTypicalChairCar2x2(1, seatCount, isDark, textPrimary, textSecondary, borderCol);
    }
    if (category == 'CC' || category == '2S' || category == 'GS' || category == 'GEN' || category == 'UR') {
      return _buildTypicalChairCar(1, seatCount, isDark, textPrimary, textSecondary, borderCol);
    }

    final is2A = category.startsWith('A') || category == '2A';
    final is1A = category.startsWith('H') || category == '1A';
    final is3E = category.startsWith('M') || category == '3E';
    final baySize = is1A ? 4 : (is2A ? 6 : (is3E ? 9 : 8));
    final cabinCount = (seatCount / baySize).ceil();

    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      itemCount: cabinCount,
      itemBuilder: (_, index) {
        final start = index * baySize + 1;
        final end = (start + baySize - 1).clamp(1, seatCount);
        final title = is1A ? 'CABIN / COUPE ${index + 1}' : 'BAY ${index + 1} (#$start - #$end)';

        final mainList = <int>[];
        final sideList = <int>[];

        for (var i = start; i <= end; i++) {
          if (is1A) {
            mainList.add(i);
          } else if (is2A) {
            final rem = i % 6;
            if (rem == 5 || rem == 0) {
              sideList.add(i);
            } else {
              mainList.add(i);
            }
          } else if (is3E) {
            final rem = i % 9;
            if (rem == 7 || rem == 8 || rem == 0) {
              sideList.add(i);
            } else {
              mainList.add(i);
            }
          } else {
            final rem = i % 8;
            if (rem == 7 || rem == 0) {
              sideList.add(i);
            } else {
              mainList.add(i);
            }
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF09090C) : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderCol),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title.tr, style: GoogleFonts.inter(color: textSecondary, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: mainList.map((s) => _seatBox(s, isDark, textPrimary, borderCol)).toList(),
                    ),
                  ),
                  if (sideList.isNotEmpty) ...[
                    Container(width: 1, height: 40, color: borderCol, margin: const EdgeInsets.symmetric(horizontal: 8)),
                    Expanded(
                      flex: 2,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: sideList.map((s) => _seatBox(s, isDark, textPrimary, borderCol)).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypicalChairCar(int start, int end, bool isDark, Color textPrimary, Color textSecondary, Color borderCol) {
    final rows = <List<int>>[];
    for (var i = start; i <= end; i += 5) {
      final row = <int>[];
      for (var j = i; j < i + 5 && j <= end; j++) {
        row.add(j);
      }
      rows.add(row);
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      itemCount: rows.length,
      itemBuilder: (_, index) {
        final row = rows[index];
        final left3 = row.take(3).toList();
        final right2 = row.skip(3).toList();

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: left3.map((s) => _seatBox(s, isDark, textPrimary, borderCol)).toList(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: right2.map((s) => _seatBox(s, isDark, textPrimary, borderCol)).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypicalChairCar2x2(int start, int end, bool isDark, Color textPrimary, Color textSecondary, Color borderCol) {
    final rows = <List<int>>[];
    for (var i = start; i <= end; i += 4) {
      final row = <int>[];
      for (var j = i; j < i + 4 && j <= end; j++) {
        row.add(j);
      }
      rows.add(row);
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      itemCount: rows.length,
      itemBuilder: (_, index) {
        final row = rows[index];
        final left2 = row.take(2).toList();
        final right2 = row.skip(2).toList();

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: left2.map((s) => _seatBox(s, isDark, textPrimary, borderCol)).toList(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: right2.map((s) => _seatBox(s, isDark, textPrimary, borderCol)).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _seatBox(dynamic seatData, bool isDark, Color textPrimary, Color borderCol) {
    late String seatNo;
    late String status;

    if (seatData is Map) {
      seatNo = (seatData['no'] ?? seatData['number'] ?? seatData['seat'] ?? '').toString();
      status = (seatData['status'] ?? seatData['state'] ?? 'AVAILABLE').toString().toUpperCase();
    } else {
      seatNo = seatData.toString();
      status = 'AVAILABLE';
    }

    final normSeatNo = seatNo.replaceAll(RegExp(r'[^\d]'), '');
    final normSelected = (_selectedSeat ?? '').replaceAll(RegExp(r'[^\d]'), '');
    final isSelected = seatNo == _selectedSeat ||
        (normSeatNo.isNotEmpty && normSeatNo == normSelected);

    final isBooked = status == 'BOOKED' || status == 'OCCUPIED';

    Color boxBg = isDark ? const Color(0xFF16161C) : Colors.white;
    Color textCol = textPrimary;
    Color border = borderCol;

    if (isBooked) {
      boxBg = const Color(0xFFFF9F0A).withValues(alpha: 0.15);
      textCol = const Color(0xFFFF9F0A);
      border = const Color(0xFFFF9F0A).withValues(alpha: 0.4);
    } else if (status == 'AVAILABLE') {
      boxBg = const Color(0xFF30D158).withValues(alpha: 0.12);
      textCol = isDark ? const Color(0xFF30D158) : const Color(0xFF248A3D);
      border = const Color(0xFF30D158).withValues(alpha: 0.3);
    }

    if (isSelected) {
      boxBg = const Color(0xFF0A84FF);
      textCol = Colors.white;
      border = const Color(0xFF0A84FF);
    }

    return GestureDetector(
      onTap: () => _selectSeat(seatNo),
      child: Container(
        width: 38,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: boxBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border, width: isSelected ? 1.5 : 1.0),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFF0A84FF).withValues(alpha: 0.4), blurRadius: 6)]
              : null,
        ),
        child: Text(
          seatNo,
          style: GoogleFonts.inter(
            color: textCol,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  int _guessSeatCount(String category) {
    if (category.startsWith('H') || category == '1A') return 24;
    if (category.startsWith('A') || category == '2A') return 54;
    if (category.startsWith('B') || category == '3A') return 72;
    if (category.startsWith('M') || category == '3E') return 83;
    if (category.startsWith('S') || category == 'SL') return 72;
    if (category == 'EC') return 56;
    if (category == 'CC') return 78;
    if (category == 'ACDC' || category == 'DDC') return 120;
    return 80;
  }
}
