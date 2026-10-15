import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/theme_controller.dart';
import '../../data/models/train.dart';
import '../../services/translation_service.dart';
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
                children: sameDir.map((c) => _trainCardItem(context, c, isDark, cardBg, textPrimary, textSecondary, borderCol)).toList(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                children: oppositeDir.map((c) => _trainCardItem(context, c, isDark, cardBg, textPrimary, textSecondary, borderCol)).toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _trainCardItem(
    BuildContext context,
    TrainCrossing c,
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
  ) {
    final isUser = c.isUserTrain;
    final color = isUser
        ? const Color(0xFF0A84FF)
        : (c.isOpposite ? const Color(0xFF30D158) : const Color(0xFFFF9F0A));

    return GestureDetector(
      onTap: () {
        if (c.trainNumber.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TrainDetailsScreen(
              trainNumber: c.trainNumber,
              trainName: c.trainName,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isUser ? color.withValues(alpha: 0.15) : cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUser ? color : borderCol,
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
                  style: GoogleFonts.inter(color: textSecondary, fontSize: 9.5, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              c.trainName.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}
