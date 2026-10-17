import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/theme_controller.dart';
import '../../data/models/train.dart';
import '../../data/sources/railradar_source.dart';
import '../../screens/train_details/train_details_screen.dart';
import '../../services/translation_service.dart';

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

    final routeOrderMap = <String, int>{};
    for (var i = 0; i < routeStops.length; i++) {
      final stop = routeStops[i];
      routeOrderMap[stop.stationCode.toUpperCase()] = i;
      routeOrderMap[stop.stationName.toUpperCase()] = i;
    }

    final Map<String, List<TrainCrossing>> stationGroupMap = {};
    for (final c in crossings) {
      final key = c.locationName.isNotEmpty
          ? c.locationName
          : (c.locationCode.isNotEmpty ? c.locationCode : 'Corridor');
      stationGroupMap.putIfAbsent(key, () => []).add(c);
    }

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
                    '↓ ${'Same Dir'.tr}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF0A84FF),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Text(
                'Crossings & Encounters'.tr,
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
                    '↑ ${'Opposite'.tr}',
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
            'No active corridor train crossings detected.'.tr,
            style: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Train encounters are tracked live as trains progress along shared corridors.'.tr,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

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
                Icon(
                  CupertinoIcons.location_solid,
                  color: isUserLocation ? Colors.white : const Color(0xFF0A84FF),
                  size: 13,
                ),
                const SizedBox(width: 6),
                Text(
                  stationName.tr,
                  style: GoogleFonts.inter(
                    color: isUserLocation ? Colors.white : textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: sameDir
                    .map((c) => _CrossingTrainCardTile(
                          crossing: c,
                          isDark: isDark,
                          cardBg: cardBg,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          borderCol: borderCol,
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                children: oppositeDir
                    .map((c) => _CrossingTrainCardTile(
                          crossing: c,
                          isDark: isDark,
                          cardBg: cardBg,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          borderCol: borderCol,
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _CrossingTrainCardTile extends StatefulWidget {
  final TrainCrossing crossing;
  final bool isDark;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color borderCol;

  const _CrossingTrainCardTile({
    required this.crossing,
    required this.isDark,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.borderCol,
  });

  @override
  State<_CrossingTrainCardTile> createState() => _CrossingTrainCardTileState();
}

class _CrossingTrainCardTileState extends State<_CrossingTrainCardTile> {
  static final Map<String, ({String name, String status})> _crossingCache = {};
  static final Map<String, String> _crossingNameCache = {};

  String? _displayName;
  String? _liveStatus;

  @override
  void initState() {
    super.initState();
    _checkAndFetch();
  }

  @override
  void didUpdateWidget(_CrossingTrainCardTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkAndFetch();
  }

  void _checkAndFetch() {
    final c = widget.crossing;
    final num = c.trainNumber.trim();
    if (num.isEmpty) return;

    // 1. Check Full Cache (Name + Live Status)
    if (_crossingCache.containsKey(num)) {
      final cached = _crossingCache[num]!;
      if (mounted) {
        setState(() {
          _displayName = cached.name;
          _liveStatus = cached.status;
        });
      }
      return;
    }

    // 2. Check Name Cache or Initial Train Name
    if (_crossingNameCache.containsKey(num)) {
      _displayName = _crossingNameCache[num];
    } else if (c.trainName.isNotEmpty && !c.trainName.startsWith('Train ')) {
      _displayName = c.trainName;
      _crossingNameCache[num] = c.trainName;
    } else {
      _displayName = 'Train $num';
      // Fast fetch train name asynchronously
      RailRadarSource.fetchSingleTrainName(num).then((info) {
        final fastName = info['name']?.toString().trim();
        if (fastName != null && fastName.isNotEmpty && !fastName.startsWith('Train ') && mounted) {
          _crossingNameCache[num] = fastName;
          setState(() => _displayName = fastName);
        }
      }).catchError((_) {});
    }

    // 3. Staggered Live Tracking Fetch to avoid concurrent API rate-limiting
    final hashOffset = (num.hashCode.abs() % 10) * 50;
    Future.delayed(Duration(milliseconds: hashOffset), () async {
      if (!mounted) return;
      await _fetchLiveTracking(num, c.trainName);
    });
  }

  Future<void> _fetchLiveTracking(String num, String initialName) async {
    try {
      final data = await RailRadarSource.liveTracking(num, includeGeometry: false);
      if (!mounted) return;

      if (data != null) {
        final realName = (data['trainName'] ??
                (data['train'] is Map ? data['train']['name'] : null) ??
                '')
            .toString()
            .trim();

        if (realName.isNotEmpty && !realName.startsWith('Train ')) {
          _crossingNameCache[num] = realName;
        }

        String statusText = '';
        if (data['currentLocation'] is Map) {
          final loc = Map<String, dynamic>.from(data['currentLocation'] as Map);
          final stName = (loc['stationName'] ?? loc['stationCode'] ?? '').toString().trim();
          final delay = loc['delayMinutes'] ?? data['delayMinutes'] ?? 0;
          final status = (loc['status'] ?? '').toString().trim();

          if (stName.isNotEmpty) {
            final delayStr = delay > 0 ? ' ($delay m late)' : ' (On Time)';
            if (status.toLowerCase().contains('departed')) {
              statusText = 'Departed $stName$delayStr';
            } else if (status.toLowerCase().contains('arrived') || status.toLowerCase().contains('halt')) {
              statusText = 'Halted at $stName$delayStr';
            } else {
              statusText = 'At $stName$delayStr';
            }
          }
        }

        if (statusText.isEmpty && data['previousHalt'] is Map) {
          final prev = Map<String, dynamic>.from(data['previousHalt'] as Map);
          final prevName = (prev['stationName'] ?? prev['stationCode'] ?? '').toString().trim();
          final delay = data['delayMinutes'] ?? 0;
          if (prevName.isNotEmpty) {
            statusText = 'Passed $prevName${delay > 0 ? " ($delay m late)" : ""}';
          }
        }

        if (statusText.isEmpty && data['nextHalt'] is Map) {
          final next = Map<String, dynamic>.from(data['nextHalt'] as Map);
          final nextName = (next['stationName'] ?? next['stationCode'] ?? '').toString().trim();
          final delay = data['delayMinutes'] ?? 0;
          if (nextName.isNotEmpty) {
            statusText = 'En Route to $nextName${delay > 0 ? " ($delay m late)" : ""}';
          }
        }

        final resolvedName = _crossingNameCache[num] ??
            ((realName.isNotEmpty && !realName.startsWith('Train '))
                ? realName
                : (initialName.isNotEmpty && !initialName.startsWith('Train ') ? initialName : 'Train $num'));

        _crossingCache[num] = (name: resolvedName, status: statusText);

        if (mounted) {
          setState(() {
            _displayName = resolvedName;
            if (statusText.isNotEmpty) _liveStatus = statusText;
          });
        }
      } else {
        // Fallback: fetch single train name if live tracking returned null
        final info = await RailRadarSource.fetchSingleTrainName(num);
        final fallbackName = info['name']?.toString().trim();
        if (fallbackName != null && fallbackName.isNotEmpty && !fallbackName.startsWith('Train ') && mounted) {
          _crossingNameCache[num] = fallbackName;
          _crossingCache[num] = (name: fallbackName, status: _liveStatus ?? '');
          setState(() => _displayName = fallbackName);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.crossing;
    final isUser = c.isUserTrain;
    final color = isUser
        ? const Color(0xFF0A84FF)
        : (c.isOpposite ? const Color(0xFF30D158) : const Color(0xFFFF9F0A));

    final nameText = _displayName ?? (c.trainName.isNotEmpty ? c.trainName : 'Train ${c.trainNumber}');

    return GestureDetector(
      onTap: () {
        if (c.trainNumber.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TrainDetailsScreen(
              trainNumber: c.trainNumber,
              trainName: nameText,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isUser ? color.withValues(alpha: 0.15) : widget.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUser ? color : widget.borderCol,
            width: isUser ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    c.trainNumber,
                    style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w900, fontSize: 10),
                  ),
                ),
                const Spacer(),
                Text(
                  c.time,
                  style: GoogleFonts.inter(color: widget.textSecondary, fontSize: 9.5, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              nameText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(color: widget.textPrimary, fontWeight: FontWeight.w800, fontSize: 11.5),
            ),
            if (_liveStatus != null && _liveStatus!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _liveStatus!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: color,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
