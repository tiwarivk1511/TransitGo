import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/theme_controller.dart';
import '../../services/translation_service.dart';

/// Ultra-Modern 3D Static Vande Bharat Express Rake Visualizer Component
class StaticTrainRakeView extends StatelessWidget {
  final String trainName;
  final String? trainType;
  final String? officialLivery;
  final List coaches;

  const StaticTrainRakeView({
    super.key,
    required this.trainName,
    this.trainType,
    this.officialLivery,
    required this.coaches,
  });

  List _getProcessedCoaches() {
    if (coaches.isEmpty) return [];

    bool isSpecialLTrain = coaches.length == 1 &&
        ((coaches.first.code ?? '').toString().trim().toUpperCase() == 'L' ||
            (coaches.first.category ?? '').toString().trim().toUpperCase() == 'L');

    if (isSpecialLTrain) {
      List generatedCoaches = [];
      generatedCoaches.add(_SyntheticCoach(code: 'DTC', category: 'LOCO', position: 1));

      for (int i = 2; i <= 23; i++) {
        String cat = 'GS';
        if (i >= 2 && i <= 4) cat = 'SL';
        if (i >= 5 && i <= 15) cat = '3A';
        if (i >= 16 && i <= 20) cat = '2A';
        if (i >= 21) cat = 'GS';

        generatedCoaches.add(_SyntheticCoach(
          code: '$cat${i - 1}',
          category: cat,
          position: i,
        ));
      }

      generatedCoaches.add(_SyntheticCoach(code: 'EOG', category: 'EOG', position: 24));
      return generatedCoaches;
    }

    return coaches;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveCoaches = _getProcessedCoaches();
    final isDark = Theme.of(context).brightness == Brightness.dark ||
        ThemeController.instance.isDarkMode;

    final livery = _LiveryPalette.resolve(
      trainName: trainName,
      trainType: trainType,
      apiLivery: officialLivery,
      isDark: isDark,
    );

    final bgGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF090D16), Color(0xFF121824)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        : const LinearGradient(
            colors: [Color(0xFFEBF3FE), Color(0xFFFFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );

    final borderCol = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFF0A84FF).withValues(alpha: 0.2);

    return Container(
      height: 165,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(
        gradient: bgGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderCol, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: effectiveCoaches.isEmpty
                ? Center(
                    child: Text(
                      'Coach formation unavailable'.tr,
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white38 : const Color(0xFF636366),
                        fontSize: 11,
                      ),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: effectiveCoaches.length,
                    itemBuilder: (context, index) {
                      final coach = effectiveCoaches[index];
                      final cat = (coach.category ?? '').toString().toUpperCase();
                      final code = (coach.code ?? '').toString().toUpperCase();
                      final isLoco = cat == 'LOCO' ||
                          code.contains('ENG') ||
                          code.contains('DTC') ||
                          code.contains('VB') ||
                          index == 0 ||
                          index == effectiveCoaches.length - 1;

                      final isRearNose = index == effectiveCoaches.length - 1 && index > 0;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (index > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 22),
                              child: _StaticGangway(isDark: isDark),
                            ),
                          isLoco
                              ? _StaticDrivingCoach(
                                  coach: coach,
                                  livery: livery,
                                  isDark: isDark,
                                  isRearNose: isRearNose,
                                )
                              : _StaticPassengerCoach(
                                  coach: coach,
                                  livery: livery,
                                  isDark: isDark,
                                ),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(height: 4),
          _StaticBallastTrack(isDark: isDark, accentColor: livery.accent),
        ],
      ),
    );
  }
}

class _SyntheticCoach {
  final String code;
  final String category;
  final int position;

  _SyntheticCoach({
    required this.code,
    required this.category,
    required this.position,
  });
}

/// 3D Realistic Passenger Coach Widget
class _StaticPassengerCoach extends StatelessWidget {
  final dynamic coach;
  final _LiveryPalette livery;
  final bool isDark;

  const _StaticPassengerCoach({
    required this.coach,
    required this.livery,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final code = (coach.code ?? '').toString();
    final category = (coach.category ?? '').toString();
    final position = coach.position ?? 0;

    const width = 116.0; // Increased width for spacious, detailed coach
    const height = 86.0;

    return SizedBox(
      width: width,
      height: 120,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF8FAFC), // White roof rail
                  livery.bodyTop,
                  livery.bodyBottom,
                  const Color(0xFF0F172A),
                ],
                stops: const [0.0, 0.22, 0.72, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: livery.outline, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
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

                  Positioned(
                    left: 10,
                    bottom: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          code.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: livery.textColor,
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
                            color: livery.subtextColor,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (position > 0)
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 3),
          _StaticBogieWheels(isDark: isDark),
        ],
      ),
    );
  }
}

/// 3D Realistic Vande Bharat Express Aerodynamic Driving Nose Coach
class _StaticDrivingCoach extends StatelessWidget {
  final dynamic coach;
  final _LiveryPalette livery;
  final bool isDark;
  final bool isRearNose;

  const _StaticDrivingCoach({
    required this.coach,
    required this.livery,
    required this.isDark,
    this.isRearNose = false,
  });

  @override
  Widget build(BuildContext context) {
    final code = (coach.code ?? 'DTC').toString();
    final category = (coach.category ?? 'LOCO').toString();
    final position = coach.position ?? 1;

    const width = 142.0; // Increased width for spacious, detailed loco
    const height = 86.0;

    return SizedBox(
      width: width,
      height: 120,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF8FAFC), // White roof
                  livery.bodyTop,
                  livery.bodyBottom,
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
              border: Border.all(color: livery.outline, width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
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
                  // 3D Roof Reflection Glare
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

                  // Roof AC Cowl
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

                  // 3D Vande Bharat Chevron V-Accent
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

                  // Driver Side Cabin Window
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
                        color: livery.accent,
                        boxShadow: [
                          BoxShadow(color: livery.accent, blurRadius: 6),
                        ],
                      ),
                    ),
                  ),

                  // Projector LED Headlights
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

                  // Position Number Tag
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

                  // Code Label
                  Positioned(
                    left: isRearNose ? 12 : 54,
                    bottom: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          code.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: livery.textColor,
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
                            color: livery.subtextColor,
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
          const SizedBox(height: 3),
          _StaticBogieWheels(isDark: isDark),
        ],
      ),
    );
  }
}

class _StaticGangway extends StatelessWidget {
  final bool isDark;
  const _StaticGangway({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 38,
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

class _StaticBogieWheels extends StatelessWidget {
  final bool isDark;
  const _StaticBogieWheels({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _wheelPair(isDark),
        const SizedBox(width: 22),
        _wheelPair(isDark),
      ],
    );
  }

  Widget _wheelPair(bool isDark) {
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

class _StaticBallastTrack extends StatelessWidget {
  final bool isDark;
  final Color accentColor;

  const _StaticBallastTrack({
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
  final Color bodyTop;
  final Color bodyBottom;
  final Color accent;
  final Color outline;
  final Color textColor;
  final Color subtextColor;

  const _LiveryPalette({
    required this.bodyTop,
    required this.bodyBottom,
    required this.accent,
    required this.outline,
    required this.textColor,
    required this.subtextColor,
  });

  static _LiveryPalette resolve({
    required String trainName,
    String? trainType,
    String? apiLivery,
    bool isDark = true,
  }) {
    final name = trainName.toLowerCase();
    final type = (trainType ?? '').toLowerCase();
    final api = (apiLivery ?? '').toLowerCase();

    if (name.contains('vande bharat') || type.contains('vande') || api.contains('vande')) {
      return _LiveryPalette(
        bodyTop: const Color(0xFF0284C7),
        bodyBottom: const Color(0xFF0369A1),
        accent: const Color(0xFF38BDF8),
        outline: const Color(0xFF0284C7),
        textColor: Colors.white,
        subtextColor: const Color(0xFF7DD3FC),
      );
    }

    if (name.contains('rajdhani') || api.contains('rajdhani')) {
      return _LiveryPalette(
        bodyTop: isDark ? const Color(0xFFB91C1C) : const Color(0xFFDC2626),
        bodyBottom: isDark ? const Color(0xFF991B1B) : const Color(0xFFB91C1C),
        accent: const Color(0xFFF87171),
        outline: const Color(0xFFEF4444),
        textColor: Colors.white,
        subtextColor: const Color(0xFFFCA5A5),
      );
    }

    if (name.contains('shatabdi') || api.contains('shatabdi')) {
      return _LiveryPalette(
        bodyTop: isDark ? const Color(0xFF1D4ED8) : const Color(0xFF2563EB),
        bodyBottom: isDark ? const Color(0xFF1E40AF) : const Color(0xFF1D4ED8),
        accent: const Color(0xFF60A5FA),
        outline: const Color(0xFF3B82F6),
        textColor: Colors.white,
        subtextColor: const Color(0xFF93C5FD),
      );
    }

    return _LiveryPalette(
      bodyTop: isDark ? const Color(0xFF1E1B4B) : const Color(0xFF312E81),
      bodyBottom: isDark ? const Color(0xFF312E81) : const Color(0xFF4338CA),
      accent: const Color(0xFF818CF8),
      outline: const Color(0xFF6363F1),
      textColor: Colors.white,
      subtextColor: const Color(0xFFA5B4FC),
    );
  }
}
