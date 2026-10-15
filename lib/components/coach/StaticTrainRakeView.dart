import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/theme_controller.dart';
import '../../services/translation_service.dart';

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
            colors: [Color(0xFF09090C), Color(0xFF16161C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        : const LinearGradient(
            colors: [Color(0xFFEBF3FE), Color(0xFFFFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );

    final borderCol = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFF0A84FF).withValues(alpha: 0.2);

    return Container(
      height: 148,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        gradient: bgGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 14,
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
                      final isLoco = cat == 'LOCO' || code.contains('ENG') || code.contains('DTC') || index == 0;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (index > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: _StaticGangway(isDark: isDark),
                            ),
                          isLoco
                              ? _StaticDrivingCoach(coach: coach, livery: livery, isDark: isDark)
                              : _StaticPassengerCoach(coach: coach, livery: livery, isDark: isDark),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(height: 3),
          _StaticBallastTrack(isDark: isDark),
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

    return SizedBox(
      width: 90,
      height: 100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: 88,
            height: 66,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [livery.bodyTop, livery.bodyBottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: livery.outline, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Stack(
                children: [
                  Positioned(
                    left: 5,
                    right: 5,
                    top: 11,
                    height: 18,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFF00F2FE).withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(
                          3,
                          (_) => Container(
                            width: 1,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    top: 32,
                    left: 0,
                    right: 0,
                    height: 4.5,
                    child: Container(color: livery.accent),
                  ),

                  Positioned(
                    right: 5,
                    top: 11,
                    height: 46,
                    width: 10,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 0.8,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          code.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: livery.textColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          category.toUpperCase().tr,
                          style: GoogleFonts.inter(
                            color: livery.subtextColor,
                            fontSize: 7.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (position > 0)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '#$position',
                          style: GoogleFonts.inter(
                            color: livery.textColor,
                            fontSize: 7.5,
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

class _StaticDrivingCoach extends StatelessWidget {
  final dynamic coach;
  final _LiveryPalette livery;
  final bool isDark;

  const _StaticDrivingCoach({
    required this.coach,
    required this.livery,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final code = (coach.code ?? 'DTC').toString();

    return SizedBox(
      width: 100,
      height: 100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: 98,
            height: 66,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [livery.bodyTop, livery.bodyBottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                bottomLeft: Radius.circular(10),
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              border: Border.all(color: livery.outline, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(26),
                bottomLeft: Radius.circular(8),
                topRight: Radius.circular(6),
                bottomRight: Radius.circular(6),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 2,
                    top: 10,
                    width: 24,
                    height: 18,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        ),
                        border: Border.all(
                          color: const Color(0xFF00F2FE).withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    left: 32,
                    right: 6,
                    top: 11,
                    height: 18,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFF00F2FE).withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    top: 32,
                    left: 0,
                    right: 0,
                    height: 4.5,
                    child: Container(color: livery.accent),
                  ),

                  Positioned(
                    left: 32,
                    bottom: 6,
                    child: Text(
                      code.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: livery.textColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
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

class _StaticGangway extends StatelessWidget {
  final bool isDark;
  const _StaticGangway({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 38,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFF8E8E93),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: isDark ? Colors.black45 : Colors.white70,
          width: 0.8,
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
        const SizedBox(width: 24),
        _wheelPair(isDark),
      ],
    );
  }

  Widget _wheelPair(bool isDark) {
    final wheelColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366);
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: wheelColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black, width: 1.5),
          ),
        ),
        Container(
          width: 8,
          height: 2.5,
          color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFC7C7CC),
        ),
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: wheelColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black, width: 1.5),
          ),
        ),
      ],
    );
  }
}

class _StaticBallastTrack extends StatelessWidget {
  final bool isDark;
  const _StaticBallastTrack({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFF8E8E93),
        borderRadius: BorderRadius.circular(1.5),
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
        bodyTop: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        bodyBottom: isDark ? const Color(0xFF0038A8) : const Color(0xFF0055FF),
        accent: const Color(0xFF00F2FE),
        outline: const Color(0xFF0088FF),
        textColor: Colors.white,
        subtextColor: const Color(0xFF64D2FF),
      );
    }

    if (name.contains('rajdhani') || api.contains('rajdhani')) {
      return _LiveryPalette(
        bodyTop: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFDC2626),
        bodyBottom: isDark ? const Color(0xFF991B1B) : const Color(0xFFB91C1C),
        accent: const Color(0xFFFFD60A),
        outline: const Color(0xFFEF4444),
        textColor: Colors.white,
        subtextColor: const Color(0xFFFFD60A),
      );
    }

    if (name.contains('shatabdi') || api.contains('shatabdi')) {
      return _LiveryPalette(
        bodyTop: isDark ? const Color(0xFF1E3A8A) : const Color(0xFF2563EB),
        bodyBottom: isDark ? const Color(0xFF1D4ED8) : const Color(0xFF3B82F6),
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
      outline: const Color(0xFF6366F1),
      textColor: Colors.white,
      subtextColor: const Color(0xFFA5B4FC),
    );
  }
}
