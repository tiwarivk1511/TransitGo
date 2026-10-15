import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/theme_controller.dart';
import '../../data/models/coach.dart';
import '../../services/translation_service.dart';

/// Ultra-Modern 3D Vande Bharat Express Rake Visualizer Component
class TrainRakeView extends StatelessWidget {
  final String trainName;
  final String? trainType;
  final String? officialLivery;
  final List coaches;
  final dynamic selectedCoach;
  final ValueChanged<dynamic> onCoachSelected;

  const TrainRakeView({
    super.key,
    required this.trainName,
    required this.trainType,
    required this.officialLivery,
    required this.coaches,
    required this.selectedCoach,
    required this.onCoachSelected,
  });

  // Safe Property Extractors
  static String _getCode(dynamic coach) {
    if (coach is CoachInfo) return coach.code;
    if (coach is Map) return (coach['code'] ?? coach['coachCode'] ?? coach['coach'] ?? coach['name'] ?? '').toString();
    return coach?.toString() ?? '';
  }

  static String _getCategory(dynamic coach) {
    if (coach is CoachInfo) return coach.category;
    if (coach is Map) return (coach['category'] ?? coach['classType'] ?? coach['class'] ?? coach['type'] ?? '').toString();
    return '';
  }

  static int _getPosition(dynamic coach, int index) {
    if (coach is CoachInfo) return coach.position;
    if (coach is Map) {
      final pos = coach['position'] ?? coach['index'] ?? coach['sequence'];
      if (pos is num) return pos.toInt();
      if (pos is String) return int.tryParse(pos) ?? (index + 1);
    }
    return index + 1;
  }

  static String _getSelectedCode(dynamic coach) {
    if (coach == null) return '';
    return _getCode(coach).toUpperCase();
  }

  static int _getSelectedPosition(dynamic coach) {
    if (coach == null) return -1;
    if (coach is CoachInfo) return coach.position;
    if (coach is Map) {
      final pos = coach['position'] ?? coach['index'];
      if (pos is num) return pos.toInt();
      if (pos is String) return int.tryParse(pos) ?? -1;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDarkMode;
    final livery = _LiveryPalette.resolve(
      trainName: trainName,
      trainType: trainType,
      apiLivery: officialLivery,
    );

    final rawLabel = livery.label.toUpperCase().tr;
    final badgeLabel = rawLabel.endsWith('RAKE') ? rawLabel : '$rawLabel ${'RAKE'.tr}';

    final selectedCode = _getSelectedCode(selectedCoach);
    final selectedPos = _getSelectedPosition(selectedCoach);

    final cardBg = isDark ? const Color(0xFF090D16) : const Color(0xFFFFFFFF);
    final borderCol = isDark ? const Color(0xFF1E293D) : const Color(0xFFE2E8F0);

    return Container(
      height: 215,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderCol, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.08),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge & Train Status Line
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: livery.accent.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: livery.accent.withValues(alpha: 0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Icon(Icons.train_rounded, size: 14, color: livery.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  badgeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: livery.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: livery.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: livery.accent.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: livery.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${coaches.length} ${'COACHES'.tr}',
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3D Horizontal Train Composition Scroll View
          Expanded(
            child: coaches.isEmpty
                ? Center(
                    child: Text(
                      'Coach formation unavailable'.tr,
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white38 : const Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: coaches.length,
                    itemBuilder: (context, index) {
                      final coach = coaches[index];
                      final code = _getCode(coach).toUpperCase();
                      final category = _getCategory(coach).toUpperCase();
                      final position = _getPosition(coach, index);

                      final isSelected = (selectedPos > 0 && selectedPos == position && selectedCode == code) ||
                          (selectedPos <= 0 && selectedCode == code);

                      final isDrivingNose = category == 'LOCO' ||
                          code.contains('ENG') ||
                          code.contains('DTC') ||
                          code.contains('VB') ||
                          index == 0 ||
                          index == coaches.length - 1;

                      final isRearNose = index == coaches.length - 1 && index > 0;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (index > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: _3DGangwayConnector(isDark: isDark),
                            ),

                          GestureDetector(
                            onTap: () => onCoachSelected(coach),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              transform: Matrix4.translationValues(0, isSelected ? -8 : 0, 0),
                              child: isDrivingNose
                                  ? _3DVandeBharatLocoWidget(
                                      code: code,
                                      category: category,
                                      position: position,
                                      isRearNose: isRearNose,
                                      isSelected: isSelected,
                                      livery: livery,
                                      isDark: isDark,
                                    )
                                  : _3DPassengerCoachWidget(
                                      code: code,
                                      category: category,
                                      position: position,
                                      isSelected: isSelected,
                                      livery: livery,
                                      isDark: isDark,
                                    ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(height: 6),

          // 3D Metallic Ballast Track & Rail Lines
          _3DBallastTrack(isDark: isDark, accentColor: livery.accent),
        ],
      ),
    );
  }
}

/// 3D Realistic Vande Bharat Express Aerodynamic Driving Nose Coach
class _3DVandeBharatLocoWidget extends StatelessWidget {
  final String code;
  final String category;
  final int position;
  final bool isRearNose;
  final bool isSelected;
  final _LiveryPalette livery;
  final bool isDark;

  const _3DVandeBharatLocoWidget({
    required this.code,
    required this.category,
    required this.position,
    required this.isRearNose,
    required this.isSelected,
    required this.livery,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    const width = 142.0; // Increased width for spacious, high-detail loco
    const height = 86.0;

    final primaryGlow = livery.accent;

    return SizedBox(
      width: width,
      height: 128,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            height: height,
            width: width,
            decoration: BoxDecoration(
              // 3D Volumetric Metallic Body Gradient
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF8FAFC), // White roof
                  livery.top,
                  livery.bottom,
                  const Color(0xFF0F172A),
                ],
                stops: const [0.0, 0.25, 0.70, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: isRearNose
                  ? const BorderRadius.only(
                      topRight: Radius.circular(42),
                      bottomRight: Radius.circular(10),
                      topLeft: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                    )
                  : const BorderRadius.only(
                      topLeft: Radius.circular(42),
                      bottomLeft: Radius.circular(10),
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
              border: Border.all(
                color: isSelected ? Colors.white : primaryGlow,
                width: isSelected ? 2.4 : 1.4,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: primaryGlow.withValues(alpha: 0.75),
                    blurRadius: 18,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: isRearNose
                  ? const BorderRadius.only(
                      topRight: Radius.circular(40),
                      bottomRight: Radius.circular(8),
                      topLeft: Radius.circular(6),
                      bottomLeft: Radius.circular(6),
                    )
                  : const BorderRadius.only(
                      topLeft: Radius.circular(40),
                      bottomLeft: Radius.circular(8),
                      topRight: Radius.circular(6),
                      bottomRight: Radius.circular(6),
                    ),
              child: Stack(
                children: [
                  // 3D Roof Reflection Highlight Glare
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.45),
                            Colors.white.withValues(alpha: 0.05),
                            Colors.transparent,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),

                  // Roof Streamlined AC Cowl
                  Positioned(
                    top: 2,
                    left: isRearNose ? 8 : 40,
                    right: isRearNose ? 40 : 8,
                    height: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: const [
                          BoxShadow(color: Color(0xFF38BDF8), blurRadius: 4),
                        ],
                      ),
                    ),
                  ),

                  // 3D Aerodynamic Cockpit Windshield Canopy
                  Positioned(
                    left: isRearNose ? null : 4,
                    right: isRearNose ? 4 : null,
                    top: 8,
                    width: 42,
                    height: 25,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF38BDF8),
                            Color(0xFF0284C7),
                            Color(0xFF0F172A),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: isRearNose ? const Radius.circular(4) : const Radius.circular(26),
                          bottomLeft: const Radius.circular(4),
                          topRight: isRearNose ? const Radius.circular(26) : const Radius.circular(4),
                          bottomRight: const Radius.circular(4),
                        ),
                        border: Border.all(
                          color: const Color(0xFF38BDF8),
                          width: 1.4,
                        ),
                        boxShadow: const [
                          BoxShadow(color: Color(0xFF38BDF8), blurRadius: 8, spreadRadius: 0.5),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Align(
                          alignment: isRearNose ? Alignment.topRight : Alignment.topLeft,
                          child: Container(
                            width: 16,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 3D Vande Bharat Front Chevron / V-Nose Accent
                  Positioned(
                    left: isRearNose ? null : 2,
                    right: isRearNose ? 2 : null,
                    top: 36,
                    width: 24,
                    height: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: livery.accent,
                        borderRadius: BorderRadius.only(
                          topLeft: isRearNose ? Radius.zero : const Radius.circular(10),
                          topRight: isRearNose ? const Radius.circular(10) : Radius.zero,
                          bottomLeft: const Radius.circular(4),
                          bottomRight: const Radius.circular(4),
                        ),
                        boxShadow: [
                          BoxShadow(color: livery.accent, blurRadius: 6),
                        ],
                      ),
                    ),
                  ),

                  // Tinted Side Driver & Passenger Window Band
                  Positioned(
                    left: isRearNose ? 10 : 52,
                    right: isRearNose ? 52 : 10,
                    top: 14,
                    height: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                          width: 0.9,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(
                          4,
                          (_) => Container(
                            width: 1.2,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Center Speed Livery Stripe
                  Positioned(
                    top: 40,
                    left: 0,
                    right: 0,
                    height: 5,
                    child: Container(
                      decoration: BoxDecoration(
                        color: primaryGlow,
                        boxShadow: [
                          BoxShadow(color: primaryGlow, blurRadius: 6),
                        ],
                      ),
                    ),
                  ),

                  // Projector LED Headlights at Nose Base
                  Positioned(
                    left: isRearNose ? null : 4,
                    right: isRearNose ? 4 : null,
                    bottom: 12,
                    child: Container(
                      width: 12,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFF00F2FE),
                            blurRadius: 12,
                            spreadRadius: 2.5,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Position Number Pill Tag
                  Positioned(
                    left: isRearNose ? 10 : 54,
                    top: 42,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#$position',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),

                  if (isSelected)
                    Positioned(
                      right: isRearNose ? 54 : 10,
                      top: 42,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryGlow,
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Coach Code & Category Label
                  Positioned(
                    left: isRearNose ? 12 : 54,
                    bottom: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          code.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                            shadows: const [
                              Shadow(color: Colors.black87, blurRadius: 4),
                            ],
                          ),
                        ),
                        Text(
                          category.toUpperCase().tr,
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),

          // 3D Dual-Axle Suspension Bogie Wheels
          _3DDualBogieWheels(isDark: isDark),
        ],
      ),
    );
  }
}

/// 3D Realistic Passenger Coach Widget
class _3DPassengerCoachWidget extends StatelessWidget {
  final String code;
  final String category;
  final int position;
  final bool isSelected;
  final _LiveryPalette livery;
  final bool isDark;

  const _3DPassengerCoachWidget({
    required this.code,
    required this.category,
    required this.position,
    required this.isSelected,
    required this.livery,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    const width = 116.0; // Increased width for spacious, detailed passenger coach
    const height = 86.0;

    return SizedBox(
      width: width,
      height: 128,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            height: height,
            width: width,
            decoration: BoxDecoration(
              // 3D Volumetric Metallic Body Gradient
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF8FAFC), // White roof rail
                  livery.top.withValues(alpha: isSelected ? 1.0 : 0.92),
                  livery.bottom.withValues(alpha: isSelected ? 1.0 : 0.92),
                  const Color(0xFF0F172A),
                ],
                stops: const [0.0, 0.22, 0.72, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.white : livery.accent.withValues(alpha: 0.5),
                width: isSelected ? 2.2 : 1.2,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: livery.accent.withValues(alpha: 0.65),
                    blurRadius: 16,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  // 3D Roof Reflection Glare
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 18,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.4),
                            Colors.white.withValues(alpha: 0.05),
                            Colors.transparent,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),

                  // Roof AC Cowl
                  Positioned(
                    top: 2,
                    left: 12,
                    right: 12,
                    height: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Panorama Tinted Glass Passenger Window Band
                  Positioned(
                    left: 10,
                    right: 10,
                    top: 12,
                    height: 22,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                          width: 0.9,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(
                          5,
                          (_) => Container(
                            width: 1.2,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Center Speed Livery Stripe
                  Positioned(
                    top: 38,
                    left: 0,
                    right: 0,
                    height: 4.5,
                    child: Container(color: livery.accent),
                  ),

                  // Position Number Pill Tag
                  Positioned(
                    left: 10,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#$position',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),

                  if (isSelected)
                    Positioned(
                      right: 10,
                      top: 4,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: livery.accent,
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Coach Code & Category Label
                  Positioned(
                    left: 10,
                    bottom: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          code.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                            shadows: const [
                              Shadow(color: Colors.black87, blurRadius: 4),
                            ],
                          ),
                        ),
                        Text(
                          category.toUpperCase().tr,
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),

          // 3D Dual-Axle Suspension Bogie Wheels
          _3DDualBogieWheels(isDark: isDark),
        ],
      ),
    );
  }
}

class _3DGangwayConnector extends StatelessWidget {
  final bool isDark;
  const _3DGangwayConnector({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFF64748B),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: isDark ? Colors.black54 : Colors.white,
          width: 0.9,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          4,
          (_) => Container(
            height: 1.2,
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

class _3DDualBogieWheels extends StatelessWidget {
  final bool isDark;
  const _3DDualBogieWheels({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _single3DBogie(isDark),
        const SizedBox(width: 22),
        _single3DBogie(isDark),
      ],
    );
  }

  Widget _single3DBogie(bool isDark) {
    final wheelColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: wheelColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black, width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 2, offset: Offset(0, 1)),
            ],
          ),
        ),
        Container(width: 7, height: 2.5, color: const Color(0xFF334155)),
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: wheelColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black, width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 2, offset: Offset(0, 1)),
            ],
          ),
        ),
      ],
    );
  }
}

class _3DBallastTrack extends StatelessWidget {
  final bool isDark;
  final Color accentColor;

  const _3DBallastTrack({
    required this.isDark,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.4),
            isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
            accentColor.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.3),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}

class _LiveryPalette {
  final String label;
  final Color top;
  final Color bottom;
  final Color accent;

  const _LiveryPalette({
    required this.label,
    required this.top,
    required this.bottom,
    required this.accent,
  });

  static _LiveryPalette resolve({
    required String trainName,
    String? trainType,
    String? apiLivery,
  }) {
    final name = trainName.toLowerCase();
    final type = (trainType ?? '').toLowerCase();
    final api = (apiLivery ?? '').toLowerCase();

    if (name.contains('vande bharat') || type.contains('vande') || api.contains('vande')) {
      return const _LiveryPalette(
        label: 'Vande Bharat Express',
        top: Color(0xFF0284C7),
        bottom: Color(0xFF0369A1),
        accent: Color(0xFF38BDF8),
      );
    }

    if (name.contains('rajdhani') || api.contains('rajdhani')) {
      return const _LiveryPalette(
        label: 'Rajdhani LHB',
        top: Color(0xFFB91C1C),
        bottom: Color(0xFF991B1B),
        accent: Color(0xFFF87171),
      );
    }

    if (name.contains('shatabdi') || api.contains('shatabdi')) {
      return const _LiveryPalette(
        label: 'Shatabdi LHB',
        top: Color(0xFF1D4ED8),
        bottom: Color(0xFF1E40AF),
        accent: Color(0xFF60A5FA),
      );
    }

    if (name.contains('duronto') || api.contains('duronto')) {
      return const _LiveryPalette(
        label: 'Duronto Express',
        top: Color(0xFF15803D),
        bottom: Color(0xFF166534),
        accent: Color(0xFF4ADE80),
      );
    }

    if (name.contains('garib rath') || api.contains('garib')) {
      return const _LiveryPalette(
        label: 'Garib Rath Express',
        top: Color(0xFF047857),
        bottom: Color(0xFF065F46),
        accent: Color(0xFF34D399),
      );
    }

    if (name.contains('tejas') || api.contains('tejas')) {
      return const _LiveryPalette(
        label: 'Tejas Express',
        top: Color(0xFFC2410C),
        bottom: Color(0xFF9A3412),
        accent: Color(0xFFFB923C),
      );
    }

    if (api.contains('lhb') || name.contains('express') || type.contains('superfast')) {
      return const _LiveryPalette(
        label: 'LHB Express Rake',
        top: Color(0xFF991B1B),
        bottom: Color(0xFF7F1D1D),
        accent: Color(0xFFF87171),
      );
    }

    return const _LiveryPalette(
      label: 'Standard ICF Express Rake',
      top: Color(0xFF1E3A8A),
      bottom: Color(0xFF1E1B4B),
      accent: Color(0xFF60A5FA),
    );
  }
}
