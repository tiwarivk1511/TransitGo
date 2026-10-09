import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TrainCard extends StatelessWidget {
  final String trainNumber;
  final String trainName;
  final String trainType;
  final String fromCode;
  final String fromName;
  final String toCode;
  final String toName;
  final String departure;
  final String arrival;
  final int distance;
  final int? delayMinutes;

  /// Optional metadata — populated when the API returns it.
  final List<String>? runDays;   // e.g. ['mon','tue','wed',...]
  final int? durationMin;        // in minutes
  final int? halts;              // stops between from → to

  final VoidCallback onTap;

  const TrainCard({
    super.key,
    required this.trainNumber,
    required this.trainName,
    required this.trainType,
    required this.fromCode,
    required this.fromName,
    required this.toCode,
    required this.toName,
    required this.departure,
    required this.arrival,
    required this.distance,
    this.delayMinutes,
    this.runDays,
    this.durationMin,
    this.halts,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final delayed = (delayMinutes ?? 0) > 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 50% Visible Translucent Glass Color
    final cardBg = isDark
        ? const Color(0xFF101320).withValues(alpha: 0.50)
        : const Color(0xFFFFFFFF).withValues(alpha: 0.50);

    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? const Color(0xFF98989D) : const Color(0xFF8E8E93);
    final borderCol = delayed
        ? Colors.orangeAccent.withValues(alpha: 0.4)
        : (isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE5E5EA));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderCol),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Top row: number · delay · type ────────────────
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A84FF).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              trainNumber,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF0A84FF),
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (delayed)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orangeAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '+${delayMinutes}m',
                                style: GoogleFonts.inter(
                                  color: Colors.orangeAccent,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          const Spacer(),
                          Text(
                            trainType.toUpperCase(),
                            style: GoogleFonts.inter(
                              color: textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // ── Train name ────────────────────────────────────
                      Text(
                        trainName.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      // ── Running days chips ────────────────────────────
                      if (runDays != null && runDays!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _DaysRow(days: runDays!, isDark: isDark),
                      ],

                      const SizedBox(height: 16),

                      // ── Times + distance + duration ───────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _timeBlock(
                            departure,
                            fromName,
                            true,
                            textPrimary,
                            textSecondary,
                          ),
                          Column(
                            children: [
                              Text(
                                _fmtDistance(distance),
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF0A84FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(width: 60, height: 1, color: borderCol),
                              if (durationMin != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _fmtDuration(durationMin!),
                                  style: GoogleFonts.inter(
                                    color: textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          _timeBlock(
                            arrival,
                            toName,
                            false,
                            textPrimary,
                            textSecondary,
                          ),
                        ],
                      ),

                      // ── Halts badge ───────────────────────────────────
                      if (halts != null && halts! > 0) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.swap_horiz_rounded,
                              size: 12,
                              color: textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$halts halts between',
                              style: GoogleFonts.inter(
                                color: textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeBlock(
    String time,
    String station,
    bool start,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Column(
      crossAxisAlignment:
          start ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        RichText(
          textAlign: start ? TextAlign.start : TextAlign.end,
          text: TextSpan(
            style: GoogleFonts.inter(
              color: textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
            children: _build12hSpans(time, textSecondary),
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 100,
          child: Text(
            station,
            style: GoogleFonts.inter(
              color: textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: start ? TextAlign.start : TextAlign.end,
          ),
        ),
      ],
    );
  }

  static List<TextSpan> _build12hSpans(String raw, Color textSecondary) {
    final t = _to12h(raw);
    if (t == null) {
      return [TextSpan(text: raw.isEmpty ? '--' : raw)];
    }
    return [
      TextSpan(text: t.time),
      TextSpan(
        text: ' ${t.period}',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: textSecondary,
        ),
      ),
    ];
  }

  static _Time12? _to12h(String raw) {
    if (raw.isEmpty || raw == '--') return null;

    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw.trim());
    if (m == null) return null;

    var h = int.tryParse(m.group(1)!) ?? 0;
    final min = m.group(2)!;
    if (h < 0 || h > 23) return null;

    final period = h >= 12 ? 'PM' : 'AM';
    if (h == 0) {
      h = 12;
    } else if (h > 12) {
      h = h - 12;
    }

    return _Time12('$h:$min', period);
  }

  static String _fmtDistance(int d) {
    if (d <= 0) return '—';
    return '$d km';
  }

  static String _fmtDuration(int mins) {
    if (mins <= 0) return '';
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

class _Time12 {
  final String time;
  final String period;
  const _Time12(this.time, this.period);
}

class _DaysRow extends StatelessWidget {
  final List<String> days;
  final bool isDark;
  const _DaysRow({required this.days, required this.isDark});

  static const _allDays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  @override
  Widget build(BuildContext context) {
    final activeSet = days.map((e) => e.toLowerCase().trim()).toSet();

    return Row(
      children: _allDays.map((d) {
        final active = activeSet.contains(d);
        final label = d.substring(0, 1).toUpperCase();

        return Container(
          margin: const EdgeInsets.only(right: 5),
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF0A84FF)
                : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE5E5EA)),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: active
                  ? Colors.white
                  : (isDark ? Colors.white38 : const Color(0xFF8E8E93)),
            ),
          ),
        );
      }).toList(),
    );
  }
}
