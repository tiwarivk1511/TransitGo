import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/coach.dart';
import '../../services/translation_service.dart';

class TrainRakeView extends StatelessWidget {
  final String trainName;
  final String? trainType;
  final String? officialLivery;
  final List coaches;
  final CoachInfo? selectedCoach;
  final ValueChanged onCoachSelected;

  const TrainRakeView({
    super.key,
    required this.trainName,
    required this.trainType,
    required this.officialLivery,
    required this.coaches,
    required this.selectedCoach,
    required this.onCoachSelected,
  });

  @override
  Widget build(BuildContext context) {
    final livery = _LiveryPalette.resolve(
      trainName: trainName,
      trainType: trainType,
      apiLivery: officialLivery,
    );

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF121216),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge & Info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: livery.accent.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.train_rounded, size: 14, color: livery.accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${livery.label.toUpperCase().tr} ${'RAKE'.tr}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: livery.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${coaches.length} ${'COACHES'.tr}',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Aerodynamic High Speed Bullet Rake Horizontal Scroll View
          Expanded(
            child: coaches.isEmpty
                ? Center(
                    child: Text(
                      'Coach formation unavailable'.tr,
                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: coaches.length,
                    itemBuilder: (context, index) {
                      final coach = coaches[index];
                      final selected =
                          selectedCoach?.position == coach.position &&
                              selectedCoach?.code == coach.code;
                      final isLoco =
                          coach.category == 'LOCO' ||
                              coach.code.toUpperCase().contains('ENG') ||
                              coach.code.toUpperCase().contains('DTC') ||
                              index == 0;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (index > 0)
                            Container(
                              width: 10,
                              height: 3,
                              margin: const EdgeInsets.only(bottom: 28),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(1.5),
                              ),
                            ),

                          GestureDetector(
                            onTap: () => onCoachSelected(coach),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: isLoco ? 110 : 86,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isLoco
                                      ? [
                                          const Color(0xFF1F2937),
                                          const Color(0xFF111827),
                                        ]
                                      : [
                                          livery.top.withValues(alpha: selected ? 1.0 : 0.85),
                                          livery.bottom.withValues(alpha: selected ? 1.0 : 0.85),
                                        ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.15),
                                  width: selected ? 2.0 : 1.0,
                                ),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: livery.accent.withValues(alpha: 0.5),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '#${coach.position}',
                                        style: GoogleFonts.inter(
                                          color: Colors.white54,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (selected)
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      Icon(
                                        isLoco
                                            ? Icons.train_outlined
                                            : Icons.directions_railway_rounded,
                                        size: isLoco ? 22 : 18,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        coach.code.toUpperCase(),
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    coach.category.toUpperCase().tr,
                                    style: GoogleFonts.inter(
                                      color: Colors.white70,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
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
        top: Color(0xFF0038A8),
        bottom: Color(0xFFFFFFFF),
        accent: Color(0xFF0055FF),
      );
    }

    if (name.contains('rajdhani') || api.contains('rajdhani')) {
      return const _LiveryPalette(
        label: 'Rajdhani LHB',
        top: Color(0xFFB91C1C),
        bottom: Color(0xFFD97706),
        accent: Color(0xFFEF4444),
      );
    }

    if (name.contains('shatabdi') || api.contains('shatabdi')) {
      return const _LiveryPalette(
        label: 'Shatabdi LHB',
        top: Color(0xFF1D4ED8),
        bottom: Color(0xFF60A5FA),
        accent: Color(0xFF3B82F6),
      );
    }

    if (name.contains('duronto') || api.contains('duronto')) {
      return const _LiveryPalette(
        label: 'Duronto Express',
        top: Color(0xFF15803D),
        bottom: Color(0xFFEAB308),
        accent: Color(0xFF22C55E),
      );
    }

    if (name.contains('garib rath') || api.contains('garib')) {
      return const _LiveryPalette(
        label: 'Garib Rath Express',
        top: Color(0xFF047857),
        bottom: Color(0xFFF59E0B),
        accent: Color(0xFF10B981),
      );
    }

    if (name.contains('tejas') || api.contains('tejas')) {
      return const _LiveryPalette(
        label: 'Tejas Express',
        top: Color(0xFFC2410C),
        bottom: Color(0xFFF97316),
        accent: Color(0xFFFB923C),
      );
    }

    if (api.contains('lhb') || name.contains('express') || type.contains('superfast')) {
      return const _LiveryPalette(
        label: 'LHB Express Rake',
        top: Color(0xFF991B1B),
        bottom: Color(0xFFB91C1C),
        accent: Color(0xFFF87171),
      );
    }

    return const _LiveryPalette(
      label: 'Standard ICF Express Rake',
      top: Color(0xFF1E3A8A),
      bottom: Color(0xFF2563EB),
      accent: Color(0xFF60A5FA),
    );
  }
}
