import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/coach.dart';

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
                  '${livery.label.toUpperCase()} RAKE',
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
                  '${coaches.length} COACHES',
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
                      'Coach formation unavailable',
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
                            const Padding(
                              padding: EdgeInsets.only(bottom: 22),
                              child: _RRTSGangway(),
                            ),
                          GestureDetector(
                            onTap: () => onCoachSelected(coach),
                            child: isLoco
                                ? _RRTSDrivingCoach(
                                    coach: coach,
                                    selected: selected,
                                    livery: livery,
                                  )
                                : _RRTSPassengerCoach(
                                    coach: coach,
                                    selected: selected,
                                    livery: livery,
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          const SizedBox(height: 4),
          const _RRTSBallastTrack(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// HIGH-SPEED AERODYNAMIC BULLET NOSE DRIVING ENGINE COACH
// ═══════════════════════════════════════════════════════════════════════

class _RRTSDrivingCoach extends StatelessWidget {
  final CoachInfo coach;
  final bool selected;
  final _LiveryPalette livery;

  const _RRTSDrivingCoach({
    required this.coach,
    required this.selected,
    required this.livery,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 134,
      height: 125,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 132,
            height: 84,
            child: Stack(
              children: [
                // Custom Aerodynamic Bullet Nose Body Shape
                CustomPaint(
                  size: const Size(132, 84),
                  painter: _BulletNosePainter(
                    bodyTop: livery.bodyTop,
                    bodyBottom: livery.bodyBottom,
                    outline: selected ? const Color(0xFF00F2FE) : livery.outline,
                    accent: livery.accent,
                    strokeWidth: selected ? 2.5 : 1.2,
                  ),
                ),

                // Panoramic Cockpit Windshield (Dark Tinted Glass)
                Positioned(
                  left: 12,
                  top: 10,
                  width: 48,
                  height: 22,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(22),
                        topRight: Radius.circular(4),
                        bottomLeft: Radius.circular(8),
                      ),
                      border: Border.all(
                        color: const Color(0xFF00F2FE).withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 2,
                          left: 4,
                          width: 18,
                          height: 6,
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
                  left: 64,
                  right: 8,
                  top: 14,
                  height: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        2,
                        (i) => Container(
                          width: 1.2,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bright LED Headlight
                Positioned(
                  left: 3,
                  bottom: 16,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF00F2FE),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00F2FE).withValues(alpha: 0.95),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),

                // DTC Coach Code Text
                Positioned(
                  right: 8,
                  bottom: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        coach.code.isEmpty ? 'DTC' : coach.code,
                        style: GoogleFonts.inter(
                          color: livery.text,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'CAB',
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

          // Underframe Mechanical Wheels
          SizedBox(
            height: 18,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _RRTSBogie(),
                Text(
                  '#${coach.position}',
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const _RRTSBogie(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// HIGH-SPEED AERODYNAMIC BULLET PASSENGER COACH
// ═══════════════════════════════════════════════════════════════════════

class _RRTSPassengerCoach extends StatelessWidget {
  final CoachInfo coach;
  final bool selected;
  final _LiveryPalette livery;

  const _RRTSPassengerCoach({
    required this.coach,
    required this.selected,
    required this.livery,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 114,
      height: 125,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 112,
            height: 84,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [livery.bodyTop, livery.bodyBottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? const Color(0xFF00F2FE) : livery.outline,
                width: selected ? 2.5 : 1.2,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF00F2FE).withValues(alpha: 0.6),
                        blurRadius: 14,
                        spreadRadius: 1,
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 4),
                      )
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Stack(
                children: [
                  // Panoramic Glass Window Band
                  Positioned(
                    left: 6,
                    right: 6,
                    top: 12,
                    height: 22,
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
                          4,
                          (i) => Container(
                            width: 1.2,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // High-Speed Accent Speed Stripe
                  Positioned(
                    top: 38,
                    left: 0,
                    right: 0,
                    height: 5,
                    child: Container(
                      color: livery.accent,
                    ),
                  ),

                  // Automatic Plug Door Highlight
                  Positioned(
                    right: 6,
                    top: 12,
                    bottom: 6,
                    width: 10,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9F0A).withValues(alpha: 0.25),
                        border: Border.all(
                          color: const Color(0xFFFF9F0A).withValues(alpha: 0.6),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),

                  // Coach Code & Class Title
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          coach.code.isEmpty ? coach.category : coach.code,
                          style: GoogleFonts.inter(
                            color: livery.text,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          coach.category,
                          style: GoogleFonts.inter(
                            color: livery.text.withValues(alpha: 0.7),
                            fontSize: 7,
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

          // Underframe Mechanical Bogies
          SizedBox(
            height: 18,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _RRTSBogie(),
                Text(
                  '#${coach.position}',
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const _RRTSBogie(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// CUSTOM PAINTER FOR BULLET NOSE ENGINE COACH
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

class _RRTSGangway extends StatelessWidget {
  const _RRTSGangway();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Colors.black54),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          6,
          (i) => Container(
            height: 1,
            color: Colors.white12,
          ),
        ),
      ),
    );
  }
}

class _RRTSBogie extends StatelessWidget {
  const _RRTSBogie();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 12,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black87),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF94A3B8),
              border: Border.all(color: Colors.black),
            ),
          ),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF94A3B8),
              border: Border.all(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}

class _RRTSBallastTrack extends StatelessWidget {
  const _RRTSBallastTrack();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 3,
          decoration: BoxDecoration(
            color: const Color(0xFF94A3B8),
            borderRadius: BorderRadius.circular(2),
            boxShadow: const [
              BoxShadow(color: Color(0xFF00F2FE), blurRadius: 4),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Container(
          height: 4,
          color: const Color(0xFF334155),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              30,
              (i) => Container(
                width: 2,
                color: Colors.black38,
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
      return const _LiveryPalette(
        label: 'Vande Bharat',
        bodyTop: Color(0xFFFFFFFF),
        bodyBottom: Color(0xFFE2E8F0),
        accent: Color(0xFF0A84FF),
        outline: Color(0xFF0A84FF),
        text: Color(0xFF0F172A),
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

    if (tName.contains('RAJDHANI') || aLiv.contains('LHB_RED')) {
      return const _LiveryPalette(
        label: 'Rajdhani Red',
        bodyTop: Color(0xFFEF5350),
        bodyBottom: Color(0xFFC62828),
        accent: Color(0xFFAAAAA9),
        outline: Color(0xFFB71C1C),
        text: Colors.white,
      );
    }

    return const _LiveryPalette(
      label: 'Express',
      bodyTop: Color(0xFFF8FAFC),
      bodyBottom: Color(0xFFCBD5E1),
      accent: Color(0xFF00F2FE),
      outline: Color(0xFF00F2FE),
      text: Color(0xFF0F172A),
    );
  }
}
