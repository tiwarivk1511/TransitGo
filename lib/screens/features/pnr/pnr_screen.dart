import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../components/common/error_box.dart';
import '../../../components/common/feature_intro.dart';
import '../../../components/common/loading_indicator.dart';
import '../../../core/cache/offline_cache.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../data/models/pnr.dart';
import '../../../services/analytics_service.dart';
import '../../../services/pnr_service.dart';
import '../coach/coach_screen.dart';

class PnrScreen extends StatefulWidget {
  final String? initialPnr;

  const PnrScreen({super.key, this.initialPnr});

  @override
  State<PnrScreen> createState() => _PnrScreenState();
}

class _PnrScreenState extends State<PnrScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;
  PnrData? _data;

  @override
  void initState() {
    super.initState();
    final pnr = widget.initialPnr?.trim();
    if (pnr != null && pnr.isNotEmpty) {
      _ctrl.text = pnr;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetch();
      });
    }
  }

  Future<void> _fetch() async {
    final pnr = _ctrl.text.trim();
    if (pnr.length != 10) {
      setState(() => _error = 'Please enter a valid 10-digit PNR number');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    AnalyticsService.logPnrSearch(pnrNumber: pnr);
    final d = await PnrService.fetch(pnr);
    if (!mounted) return;
    if (d != null) {
      await OfflineCache.addHistory(
        'pnr',
        pnr,
        label: 'PNR $pnr',
        data: {'pnr': pnr},
      );
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _data = d;
      if (d == null) _error = 'PNR status unavailable. Please check the 10-digit number.';
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark ||
        ThemeController.instance.isDarkMode;
    final bgColor = isDark ? const Color(0xFF09090C) : const Color(0xFFF2F2F7);
    final cardColor = isDark ? const Color(0xFF16161C) : const Color(0xFFFFFFFF);
    final inputBg = isDark ? const Color(0xFF09090C) : const Color(0xFFF2F2F7);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? const Color(0xFF98989D) : const Color(0xFF636366);
    final borderCol = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E5EA);
    final accentCol = isDark ? const Color(0xFFFF9F0A) : const Color(0xFFD77900);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'PNR Status Enquiry',
          style: GoogleFonts.inter(
            color: textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_stars_fill,
              color: isDark ? const Color(0xFFFFD60A) : const Color(0xFF0A84FF),
              size: 18,
            ),
            onPressed: () async {
              await ThemeController.instance.toggleTheme();
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          physics: const BouncingScrollPhysics(),
          children: [
            FeatureIntro(
              title: 'Live PNR Telemetry',
              subtitle: 'Check passenger booking status, berth allocation, and chart preparation state.',
              icon: CupertinoIcons.ticket_fill,
              accent: accentCol,
            ),
            const SizedBox(height: 16),

            // Input PNR Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: borderCol),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PNR NUMBER (10 DIGITS)',
                    style: GoogleFonts.inter(
                      color: textSecondary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _ctrl,
                    keyboardType: TextInputType.number,
                    maxLength: 10,
                    onSubmitted: (_) => _fetch(),
                    style: GoogleFonts.inter(
                      color: textPrimary,
                      fontSize: 20,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'XXXXXXXXXX',
                      hintStyle: GoogleFonts.inter(
                        color: isDark ? Colors.white38 : const Color(0xFF8E8E93),
                        letterSpacing: 3,
                      ),
                      prefixIcon: Icon(
                        CupertinoIcons.number,
                        color: accentCol,
                      ),
                      filled: true,
                      fillColor: inputBg,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: borderCol),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: accentCol,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(CupertinoIcons.search, size: 18),
                      label: Text(
                        'Check Live PNR Status',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentCol,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _loading ? null : _fetch,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_loading)
              LoadingIndicator(
                color: accentCol,
                label: 'Fetching official PRS passenger status…',
              )
            else if (_error != null)
              ErrorBox(message: _error!, onRetry: _fetch)
            else if (_data != null)
              _pnrCard(_data!, cardColor, textPrimary, textSecondary, borderCol, isDark),
          ],
        ),
      ),
    );
  }

  Widget _pnrCard(
    PnrData d,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
    bool isDark,
  ) {
    final trainTitle = d.trainName.isNotEmpty
        ? '${d.trainNumber} • ${d.trainName}'
        : 'Train ${d.trainNumber}';

    final isChartPrepared = d.chartingStatus.toLowerCase().contains('prepar');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderCol),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9F0A).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.ticket_fill,
                  color: Color(0xFFFF9F0A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trainTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${d.source} ➔ ${d.destination}',
                      style: GoogleFonts.inter(
                        color: textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Journey Date & Class Pills
          Row(
            children: [
              if (d.journeyClass.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A84FF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'CLASS: ${d.journeyClass.toUpperCase()}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF0A84FF),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (d.journeyDate.isNotEmpty)
                Text(
                  d.journeyDate,
                  style: GoogleFonts.inter(
                    color: textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const Spacer(),
              if (d.chartingStatus.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isChartPrepared
                        ? const Color(0xFF30D158).withValues(alpha: 0.15)
                        : const Color(0xFFFF9F0A).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    d.chartingStatus.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: isChartPrepared ? const Color(0xFF30D158) : const Color(0xFFFF9F0A),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),

          Divider(color: borderCol, height: 28),

          Text(
            'PASSENGER STATUS DETAILS (${d.passengers.length})',
            style: GoogleFonts.inter(
              color: textSecondary,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),

          ...d.passengers.map((p) => _passengerTile(p, textPrimary, textSecondary, borderCol, isDark)),

          const SizedBox(height: 16),

          // Quick Coach Rake Explorer Shortcut Button
          if (d.trainNumber.isNotEmpty)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                icon: const Icon(CupertinoIcons.square_stack_3d_up_fill, size: 16),
                label: Text(
                  'Explore Coach Rake & Seat Map',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0A84FF),
                  side: const BorderSide(color: Color(0xFF0A84FF)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (_) => CoachScreen(initialTrainNumber: d.trainNumber),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _passengerTile(
    PnrPassenger p,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
    bool isDark,
  ) {
    final statusCol = _statusColor(p, isDark);
    final tileBg = isDark ? const Color(0xFF09090C) : const Color(0xFFF8F9FA);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: statusCol.withValues(alpha: 0.15),
            child: Text(
              'P${p.serialNumber}',
              style: GoogleFonts.inter(
                color: statusCol,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.display,
                  style: GoogleFonts.inter(
                    color: statusCol,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                if (p.bookingStatus.isNotEmpty && p.bookingStatus != p.currentStatus) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Booking: ${p.bookingStatus}',
                    style: GoogleFonts.inter(
                      color: textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (p.coach != null || p.berthNo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0A84FF).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${p.coach ?? ""} ${p.berthNo != null ? "#${p.berthNo}" : ""}'.trim(),
                    style: GoogleFonts.inter(
                      color: const Color(0xFF0A84FF),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  if (p.berthType != null && p.berthType!.isNotEmpty)
                    Text(
                      p.berthType!,
                      style: GoogleFonts.inter(
                        color: textSecondary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _statusColor(PnrPassenger p, bool isDark) {
    if (p.isConfirmed) return isDark ? const Color(0xFF30D158) : const Color(0xFF248A3D);
    if (p.isCancelled) return isDark ? const Color(0xFFFF453A) : const Color(0xFFD70015);
    if (p.isRac) return isDark ? const Color(0xFF64D2FF) : const Color(0xFF007AFF);
    return isDark ? const Color(0xFFFF9F0A) : const Color(0xFFC77000);
  }
}
