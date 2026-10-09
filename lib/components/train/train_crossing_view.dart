import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/theme_controller.dart';
import '../../data/models/train.dart';
import '../../data/sources/railradar_source.dart';
import '../../screens/train_details/train_details_screen.dart';

class TrainCrossing {
  final String trainNumber;
  final String trainName;
  final String trainType;
  final String locationName;
  final String locationCode;
  final String time;
  final String type; // "CROSSING" | "OVERTAKE" | "PARALLEL"
  final int delayMinutes;
  final bool isUserTrain;
  final bool isOpposite;

  const TrainCrossing({
    required this.trainNumber,
    required this.trainName,
    required this.trainType,
    required this.locationName,
    required this.locationCode,
    required this.time,
    required this.type,
    this.delayMinutes = 0,
    this.isUserTrain = false,
    this.isOpposite = false,
  });

  factory TrainCrossing.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? json['crossingType'] ?? 'CROSSING').toString().toUpperCase();
    final number = (json['crossingTrainNumber'] ?? json['trainNumber'] ?? json['train_no'] ?? '').toString().trim();
    final name = (json['crossingTrainName'] ?? json['trainName'] ?? json['train_name'] ?? json['name'] ?? '').toString().trim();

    return TrainCrossing(
      trainNumber: number,
      trainName: name.isNotEmpty ? name : (number.isNotEmpty ? 'Train $number' : 'Express'),
      trainType: (json['trainType'] ?? json['type'] ?? 'Express').toString(),
      locationName: (json['locationName'] ?? json['stationName'] ?? json['location'] ?? 'En Route').toString(),
      locationCode: (json['locationCode'] ?? json['stationCode'] ?? json['code'] ?? '').toString(),
      time: (json['time'] ?? json['crossingTime'] ?? '--:--').toString(),
      type: type,
      delayMinutes: (json['delayMinutes'] ?? json['delay'] ?? 0) is num
          ? (json['delayMinutes'] ?? json['delay'] ?? 0).toInt()
          : int.tryParse((json['delayMinutes'] ?? json['delay'] ?? '0').toString()) ?? 0,
      isUserTrain: json['isUserTrain'] == true,
      isOpposite: type == 'CROSSING' || json['isOpposite'] == true,
    );
  }
}

class TrainCrossingView extends StatelessWidget {
  final String currentTrainNumber;
  final String currentTrainName;
  final String? currentStationCode;
  final String? currentStationName;
  final List<TrainCrossing> crossings;
  final List<TrainRouteStop> routeStops;
  final bool loading;
  final VoidCallback? onRefresh;

  const TrainCrossingView({
    super.key,
    required this.currentTrainNumber,
    required this.currentTrainName,
    this.currentStationCode,
    this.currentStationName,
    required this.crossings,
    this.routeStops = const [],
    this.loading = false,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDarkMode;
    final cardBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? Colors.white54 : const Color(0xFF8E8E93);
    final borderCol = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E5EA);

    // Build route station order index map from searched train's route
    final routeOrderMap = <String, int>{};
    for (var i = 0; i < routeStops.length; i++) {
      final stop = routeStops[i];
      routeOrderMap[stop.stationCode.toUpperCase()] = i;
      routeOrderMap[stop.stationName.toUpperCase()] = i;
    }

    // Group crossings by station location
    final Map<String, List<TrainCrossing>> stationGroupMap = {};
    for (final c in crossings) {
      final key = c.locationName.isNotEmpty
          ? c.locationName
          : (c.locationCode.isNotEmpty ? c.locationCode : 'Corridor');
      stationGroupMap.putIfAbsent(key, () => []).add(c);
    }

    // Ensure searched user train is inserted at its current location
    final userCurrentKey = (currentStationName != null && currentStationName!.isNotEmpty)
        ? currentStationName!
        : (currentStationCode != null && currentStationCode!.isNotEmpty ? currentStationCode! : '');

    if (userCurrentKey.isNotEmpty) {
      final list = stationGroupMap.putIfAbsent(userCurrentKey, () => []);
      if (!list.any((c) => c.isUserTrain || c.trainNumber == currentTrainNumber)) {
        list.insert(
          0,
          TrainCrossing(
            trainNumber: currentTrainNumber,
            trainName: currentTrainName,
            trainType: 'Searched Train',
            locationName: userCurrentKey,
            locationCode: currentStationCode ?? userCurrentKey,
            time: 'NOW',
            type: 'SAME_DIR',
            isUserTrain: true,
            isOpposite: false,
          ),
        );
      }
    }

    // Sort station keys according to searched train's route sequence
    final stationKeys = stationGroupMap.keys.toList()
      ..sort((a, b) {
        final codeA = a.toUpperCase();
        final codeB = b.toUpperCase();
        final idxA = routeOrderMap[codeA] ?? 999;
        final idxB = routeOrderMap[codeB] ?? 999;
        return idxA.compareTo(idxB);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // RailRadar Corridor Header Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF09090C) : const Color(0xFFE5E5EA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderCol),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(CupertinoIcons.arrow_down, color: Color(0xFF0A84FF), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '↓ Same Dir',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF0A84FF),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Text(
                'Crossings & Encounters',
                style: GoogleFonts.inter(
                  color: textSecondary,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 0.8,
                ),
              ),
              Row(
                children: [
                  const Icon(CupertinoIcons.arrow_up, color: Color(0xFF30D158), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '↑ Opposite',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF30D158),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF0A84FF)),
            ),
          )
        else if (crossings.isEmpty)
          _buildEmptyState(textPrimary, textSecondary, cardBg, borderCol)
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stationKeys.length,
            itemBuilder: (context, index) {
              final stName = stationKeys[index];
              final list = stationGroupMap[stName]!;
              final sameDir = list.where((c) => !c.isOpposite).toList();
              final oppositeDir = list.where((c) => c.isOpposite).toList();
              final isUserLocation = list.any((c) => c.isUserTrain || c.trainNumber == currentTrainNumber) ||
                  stName.toUpperCase() == userCurrentKey.toUpperCase();

              return _buildCorridorStationRow(
                context: context,
                stationName: stName,
                sameDir: sameDir,
                oppositeDir: oppositeDir,
                isUserLocation: isUserLocation,
                isDark: isDark,
                cardBg: cardBg,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                borderCol: borderCol,
              );
            },
          ),
      ],
    );
  }

  Widget _buildEmptyState(Color textPrimary, Color textSecondary, Color cardBg, Color borderCol) {
    return Container(
      padding: const EdgeInsets.all(28),
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        children: [
          const Icon(CupertinoIcons.arrow_2_squarepath, color: Color(0xFF0A84FF), size: 40),
          const SizedBox(height: 12),
          Text(
            'No active corridor train crossings detected.',
            style: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Train encounters are tracked live as trains progress along shared corridors.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // RAILRADAR CORRIDOR LADDER ROW (Station Pill + Same Dir + Opposite)
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildCorridorStationRow({
    required BuildContext context,
    required String stationName,
    required List<TrainCrossing> sameDir,
    required List<TrainCrossing> oppositeDir,
    required bool isUserLocation,
    required bool isDark,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderCol,
  }) {
    return Column(
      children: [
        // Station Pill Badge on Railway Ladder
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: isUserLocation ? const Color(0xFF0A84FF) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isUserLocation ? Colors.white : Colors.transparent,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isUserLocation ? const Color(0xFF0A84FF).withValues(alpha: 0.5) : Colors.black12,
                  blurRadius: isUserLocation ? 8 : 4,
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
                    color: isUserLocation ? Colors.white : textSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  stationName.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: isUserLocation ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF1C1C1E)),
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 0.8,
                  ),
                ),
                if (isUserLocation) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'LIVE 🚆',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF0A84FF),
                        fontWeight: FontWeight.w900,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 6),

        // Corridor Split Row (Same Dir Left | Ladder Middle | Opposite Dir Right)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Same Direction Trains (↓)
            Expanded(
              child: sameDir.isEmpty
                  ? const SizedBox.shrink()
                  : Column(
                      children: sameDir.map((t) => _buildTrainCard(context, t, isLeft: true, isDark: isDark, cardBg: cardBg, textPrimary: textPrimary, textSecondary: textSecondary, borderCol: borderCol)).toList(),
                    ),
            ),

            // Middle: Vertical Railway Ladder Track Graphic (|||||||||)
            Container(
              width: 24,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: List.generate(
                  5,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    height: 2,
                    decoration: BoxDecoration(
                      color: const Color(0xFF475569),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
            ),

            // Right Column: Opposite Direction Trains (↑)
            Expanded(
              child: oppositeDir.isEmpty
                  ? const SizedBox.shrink()
                  : Column(
                      children: oppositeDir.map((t) => _buildTrainCard(context, t, isLeft: false, isDark: isDark, cardBg: cardBg, textPrimary: textPrimary, textSecondary: textSecondary, borderCol: borderCol)).toList(),
                    ),
            ),
          ],
        ),

        const SizedBox(height: 12),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // RAILRADAR CORRIDOR TRAIN CARD ITEM
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildTrainCard(
    BuildContext context,
    TrainCrossing item, {
    required bool isLeft,
    required bool isDark,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderCol,
  }) {
    final isUser = item.isUserTrain || item.trainNumber == currentTrainNumber;

    if (isUser) {
      return _AnimatedUserTrainCard(
        item: item,
        isLeft: isLeft,
        isDark: isDark,
        textPrimary: textPrimary,
      );
    }

    return _CrossingTrainCardItem(
      item: item,
      isLeft: isLeft,
      isDark: isDark,
      cardBg: cardBg,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      borderCol: borderCol,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// CROSSING TRAIN CARD ITEM WITH ON-THE-FLY OFFICIAL NAME RESOLUTION
// ═══════════════════════════════════════════════════════════════════════
class _CrossingTrainCardItem extends StatefulWidget {
  final TrainCrossing item;
  final bool isLeft;
  final bool isDark;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color borderCol;

  const _CrossingTrainCardItem({
    required this.item,
    required this.isLeft,
    required this.isDark,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.borderCol,
  });

  @override
  State<_CrossingTrainCardItem> createState() => _CrossingTrainCardItemState();
}

class _CrossingTrainCardItemState extends State<_CrossingTrainCardItem> {
  static final Map<String, String> _resolvedNameCache = {};
  String? _displayName;

  @override
  void initState() {
    super.initState();
    _checkAndResolveName();
  }

  @override
  void didUpdateWidget(_CrossingTrainCardItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkAndResolveName();
  }

  void _checkAndResolveName() {
    final num = widget.item.trainNumber.trim();
    final name = widget.item.trainName.trim();

    if (_resolvedNameCache.containsKey(num)) {
      _displayName = _resolvedNameCache[num];
      return;
    }

    if (name.isNotEmpty && !name.startsWith('Train ') && name != 'Express') {
      _displayName = name;
      _resolvedNameCache[num] = name;
      return;
    }

    _displayName = name.isNotEmpty ? name : 'Train $num';

    // Fetch official train name from Open Web RailRadar API: https://railradar.in/app/v1/trains/{num}/live
    RailRadarSource.fetchTrainName(num).then((data) {
      final realName = data['name']?.toString().trim() ?? '';
      if (realName.isNotEmpty && !realName.startsWith('Train ') && realName != 'Express') {
        _resolvedNameCache[num] = realName;
        if (mounted) {
          setState(() => _displayName = realName);
        }
      }
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isLeft = widget.isLeft;
    final isDark = widget.isDark;
    final textPrimary = widget.textPrimary;
    final borderCol = widget.borderCol;

    final delayed = item.delayMinutes > 0;
    final delayText = delayed ? '+${item.delayMinutes}m' : '';

    final arrowSymbol = isLeft ? '↓' : '↑';
    final arrowColor = isLeft ? const Color(0xFF0A84FF) : const Color(0xFF30D158);
    final trainTitle = _displayName ?? item.trainName;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (item.trainNumber.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TrainDetailsScreen(
                      trainNumber: item.trainNumber,
                      trainName: trainTitle,
                    ),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: isLeft ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Train Number + Arrow + Delay Pill
                  Row(
                    mainAxisAlignment: isLeft ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      Text(
                        '$arrowSymbol ${item.trainNumber}',
                        style: GoogleFonts.inter(
                          color: arrowColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                        ),
                      ),
                      if (delayed) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9F0A).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            delayText,
                            style: GoogleFonts.inter(
                              color: const Color(0xFFFF9F0A),
                              fontWeight: FontWeight.w800,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Full Official Train Name
                  Text(
                    trainTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: isLeft ? TextAlign.right : TextAlign.left,
                    style: GoogleFonts.inter(
                      color: textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      height: 1.2,
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

// ═══════════════════════════════════════════════════════════════════════
// ANIMATED PULSING SEARCHED TRAIN CARD ITEM
// ═══════════════════════════════════════════════════════════════════════
class _AnimatedUserTrainCard extends StatefulWidget {
  final TrainCrossing item;
  final bool isLeft;
  final bool isDark;
  final Color textPrimary;

  const _AnimatedUserTrainCard({
    required this.item,
    required this.isLeft,
    required this.isDark,
    required this.textPrimary,
  });

  @override
  State<_AnimatedUserTrainCard> createState() => _AnimatedUserTrainCardState();
}

class _AnimatedUserTrainCardState extends State<_AnimatedUserTrainCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final delayed = widget.item.delayMinutes > 0;
    final delayText = delayed ? '+${widget.item.delayMinutes}m' : '';

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        final animVal = _pulseCtrl.value;
        final glowRadius = 6.0 + (animVal * 8.0);
        final borderAlpha = 0.5 + (animVal * 0.5);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0A84FF).withValues(alpha: 0.28 + (animVal * 0.12)),
                const Color(0xFF00F2FE).withValues(alpha: 0.18 + (animVal * 0.12)),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF00F2FE).withValues(alpha: borderAlpha),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00F2FE).withValues(alpha: 0.35 * animVal),
                blurRadius: glowRadius,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment:
                  widget.isLeft ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Header Badge
                Row(
                  mainAxisAlignment: widget.isLeft
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A84FF),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'SEARCHED TRAIN 🚆',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 8.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (delayed) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9F0A),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          delayText,
                          style: GoogleFonts.inter(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 8.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),

                // Train Number & Name
                Text(
                  '${widget.item.trainNumber} • ${widget.item.trainName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: widget.isLeft ? TextAlign.right : TextAlign.left,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
