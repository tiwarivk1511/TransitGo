import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/theme_controller.dart';

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
                      'Coach formation unavailable',
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

// ═══════════════════════════════════════════════════════════════════════
// HIGH-SPEED AERODYNAMIC BULLET TRAIN PASSENGER COACH
// ═══════════════════════════════════════════════════════════════════════

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
                  // Panoramic Glass Window Band
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

                  // High-Speed Speed Stripe
                  Positioned(
                    top: 32,
                    left: 0,
                    right: 0,
                    height: 4.5,
                    child: Container(color: livery.accent),
                  ),

                  // Automatic Plug Door Highlight
                  Positioned(
                    right: 5,
                    top: 11,
                    bottom: 5,
                    width: 9,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9F0A).withValues(alpha: 0.22),
                        border: Border.all(
                          color: const Color(0xFFFF9F0A).withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),

                  // Coach Code & Class Badge
                  Positioned(
                    left: 6,
                    bottom: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          code.isEmpty ? category : code,
                          style: GoogleFonts.inter(
                            color: livery.text,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          category,
                          style: GoogleFonts.inter(
                            color: livery.text.withValues(alpha: 0.7),
                            fontSize: 6.5,
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

          // Underframe Mechanical Wheels
          SizedBox(
            height: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StaticBogie(isDark: isDark),
                Text(
                  '#$position',
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white38 : const Color(0xFF636366),
                    fontSize: 7.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _StaticBogie(isDark: isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// HIGH-SPEED AERODYNAMIC BULLET NOSE ENGINE COACH
// ═══════════════════════════════════════════════════════════════════════

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
    final code = (coach.code ?? '').toString();
    final position = coach.position ?? 0;

    return SizedBox(
      width: 104,
      height: 100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            width: 102,
            height: 70,
            child: Stack(
              children: [
                // Custom Aerodynamic Bullet Nose Shape
                CustomPaint(
                  size: const Size(102, 66),
                  painter: _BulletNosePainter(
                    bodyTop: livery.bodyTop,
                    bodyBottom: livery.bodyBottom,
                    outline: livery.outline,
                    accent: livery.accent,
                  ),
                ),

                // Panoramic Cockpit Windshield (Dark Tinted Glass)
                Positioned(
                  left: 3,
                  top: 12,
                  width: 40,
                  height: 17,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(3),
                        bottomLeft: Radius.circular(0),
                      ),
                      border: Border.all(
                        color: const Color(0xFF00F2FE).withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 2,
                          left: 4,
                          width: 14,
                          height: 5,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Aerodynamic Side Window Band
                Positioned(
                  left: 52,
                  right: 6,
                  top: 12,
                  height: 17,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        2,
                        (i) => Container(
                          width: 1,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bright LED Headlight
                Positioned(
                  left: 2,
                  bottom: 12,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF00F2FE),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00F2FE).withValues(alpha: 0.95),
                          blurRadius: 9,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),

                // DTC / Engine Code
                Positioned(
                  right: 8,
                  bottom: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        code.isEmpty ? 'DTC' : code,
                        style: GoogleFonts.inter(
                          color: livery.text,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'CAB',
                        style: GoogleFonts.inter(
                          color: livery.text.withValues(alpha: 0.7),
                          fontSize: 6,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Underframe Mechanical Wheels
          SizedBox(
            height: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StaticBogie(isDark: isDark),
                Text(
                  '#$position',
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white38 : const Color(0xFF636366),
                    fontSize: 7.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _StaticBogie(isDark: isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// CUSTOM PAINTER FOR HIGH-SPEED BULLET NOSE
// ═══════════════════════════════════════════════════════════════════════

class _BulletNosePainter extends CustomPainter {
  final Color bodyTop;
  final Color bodyBottom;
  final Color outline;
  final Color accent;
  final double strokeWidth;

  _BulletNosePainter({
    required this.bodyTop,
    required this.bodyBottom,
    required this.outline,
    required this.accent,
    this.strokeWidth = 1.2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    // Aerodynamic Tapered Nose Curve (Shinkansen N700S / Vande Bharat Profile)
    path.moveTo(w, 0);
    path.lineTo(w, h * 0.90);
    path.lineTo(w * 0.28, h * 0.90);
    path.cubicTo(
      w * 0.12, h * 0.90,
      0, h * 0.70,
      0, h * 0.50, // Nose Tip
    );
    path.cubicTo(
      0, h * 0.25,
      w * 0.18, 0,
      w * 0.48, 0,
    );
    path.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [bodyTop, bodyBottom],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path, fillPaint);

    // Speed Accent Stripe
    final stripePath = Path();
    stripePath.moveTo(0, h * 0.52);
    stripePath.quadraticBezierTo(w * 0.25, h * 0.52, w, h * 0.52);
    stripePath.lineTo(w, h * 0.62);
    stripePath.quadraticBezierTo(w * 0.20, h * 0.62, 0, h * 0.52);
    stripePath.close();

    final stripePaint = Paint()
      ..color = accent
      ..style = PaintingStyle.fill;
    canvas.drawPath(stripePath, stripePaint);

    // Border Outline
    final strokePaint = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _BulletNosePainter oldDelegate) => true;
}

class _StaticGangway extends StatelessWidget {
  final bool isDark;

  const _StaticGangway({this.isDark = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 52,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFD1D1D6),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: isDark ? Colors.black54 : Colors.grey.shade400),
      ),
    );
  }
}

class _StaticBogie extends StatelessWidget {
  final bool isDark;

  const _StaticBogie({this.isDark = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 11,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFF64748B),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: isDark ? Colors.black87 : Colors.grey.shade600),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFFE2E8F0),
              border: Border.all(color: Colors.black45),
            ),
          ),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFFE2E8F0),
              border: Border.all(color: Colors.black45),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaticBallastTrack extends StatelessWidget {
  final bool isDark;

  const _StaticBallastTrack({this.isDark = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 3,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: isDark ? const Color(0xFF00F2FE) : const Color(0xFF0A84FF),
                blurRadius: isDark ? 4 : 2,
              )
            ],
          ),
        ),
        const SizedBox(height: 1.5),
        Container(
          height: 4,
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              28,
              (i) => Container(
                width: 2,
                color: isDark ? Colors.black38 : Colors.white60,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveryPalette {
  final String label;
  final Color bodyTop;
  final Color bodyBottom;
  final Color accent;
  final Color outline;
  final Color text;

  const _LiveryPalette({
    required this.label,
    required this.bodyTop,
    required this.bodyBottom,
    required this.accent,
    required this.outline,
    required this.text,
  });

  static _LiveryPalette resolve({
    required String trainName,
    required String? trainType,
    required String? apiLivery,
    required bool isDark,
  }) {
    final tName = trainName.toUpperCase();
    final tType = (trainType ?? '').toUpperCase();
    final aLiv = (apiLivery ?? '').toUpperCase();

    if (tName.contains('VANDE') ||
        tName.contains('NAMO') ||
        tName.contains('RRTS') ||
        tType.contains('VB') ||
        aLiv.contains('VANDE') ||
        aLiv.contains('RRTS')) {
      return _LiveryPalette(
        label: 'Vande Bharat',
        bodyTop: const Color(0xFFFFFFFF),
        bodyBottom: isDark ? const Color(0xFFE2E8F0) : const Color(0xFFD0D8E8),
        accent: const Color(0xFF0A84FF),
        outline: const Color(0xFF0A84FF),
        text: const Color(0xFF0F172A),
      );
    }

    if (tName.contains('TEJAS') || aLiv.contains('TEJAS')) {
      return const _LiveryPalette(
        label: 'Tejas',
        bodyTop: Color(0xFFFFF176),
        bodyBottom: Color(0xFFFBC02D),
        accent: Color(0xFF00F2FE),
        outline: Color(0xFFF57F17),
        text: Color(0xFF0F172A),
      );
    }

    return _LiveryPalette(
      label: 'Express',
      bodyTop: const Color(0xFFFFFFFF),
      bodyBottom: isDark ? const Color(0xFFCBD5E1) : const Color(0xFFB8C5D6),
      accent: isDark ? const Color(0xFF00F2FE) : const Color(0xFF0A84FF),
      outline: isDark ? const Color(0xFF00F2FE) : const Color(0xFF0A84FF),
      text: const Color(0xFF0F172A),
    );
  }
}
