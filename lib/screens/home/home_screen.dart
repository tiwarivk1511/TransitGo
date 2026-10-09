import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/common/apple_glass_card.dart';
import '../../components/common/modern_background.dart';
import '../../components/station/station_autocomplete.dart';
import '../../components/train/TrainNumberAutocomplete.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/utils/responsive_helper.dart';
import '../../data/models/station.dart';
import '../features/alerts/alerts_screen.dart';
import '../features/coach/coach_screen.dart';
import '../features/fare/fare_screen.dart';
import '../features/history/history_screen.dart';
import '../features/live_traffic/live_traffic_screen.dart';
import '../features/metro/metro_networks_screen.dart';
import '../features/more/more_screen.dart';
import '../features/pnr/pnr_screen.dart';
import '../features/radar/radar_screen.dart';
import '../features/station_info/station_info_screen.dart';
import '../train_details/train_details_screen.dart';
import '../train_search/train_search_screen.dart';

import '../../services/analytics_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _trainCtrl = TextEditingController();
  Station? _from;
  Station? _to;
  Map<String, String>? _selectedTrain;

  @override
  void initState() {
    super.initState();
    _trainCtrl.addListener(_onTrainQueryChanged);
    _fromCtrl.addListener(() {
      if (_fromCtrl.text.trim().isEmpty && _from != null) {
        setState(() => _from = null);
      }
    });
    _toCtrl.addListener(() {
      if (_toCtrl.text.trim().isEmpty && _to != null) {
        setState(() => _to = null);
      }
    });
    AnalyticsService.logScreenView('HomeScreen');
  }

  void _onTrainQueryChanged() {
    final train = _selectedTrain;
    if (train == null ||
        _trainCtrl.text == '${train['number']} - ${train['name']}') {
      return;
    }
    setState(() => _selectedTrain = null);
  }

  String _stationLabel(Station station) {
    final area = [
      station.district,
      station.state,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(', ');
    return '${station.name} (${station.code})'
        '${area.isEmpty ? '' : ' · $area'}';
  }

  void _swap() {
    setState(() {
      final t = _from;
      _from = _to;
      _to = t;
      final tt = _fromCtrl.text;
      _fromCtrl.text = _toCtrl.text;
      _toCtrl.text = tt;
    });
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _trainCtrl.removeListener(_onTrainQueryChanged);
    _trainCtrl.dispose();
    super.dispose();
  }

  void _go(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final horizontalPadding = ResponsiveHelper.isMobile(context)
            ? 18.0
            : 28.0;
        final isDark = ThemeController.instance.isDarkMode;

        final cardColor = isDark
            ? const Color(0xFF101320)
            : const Color(0xFFFFFFFF);
        final inputBgColor = isDark
            ? const Color(0xFF181B28)
            : const Color(0xFFF7F8FC);
        final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
        final textSecondary = isDark
            ? const Color(0xFF98989D)
            : const Color(0xFF8E8E93);
        final borderColor = isDark
            ? Colors.white.withValues(alpha: 0.10)
            : const Color(0xFFE5E5EA);

        final isFindButtonEnabled =
            _from != null &&
            _to != null &&
            _fromCtrl.text.trim().isNotEmpty &&
            _toCtrl.text.trim().isNotEmpty;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: ModernBackground(
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 16,
                ),
                child: ResponsiveContainer(
                  maxWidth: 960,
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Apple Style Header with Theme Toggle
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 44,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderColor),
                            ),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TransitGO',
                                style: GoogleFonts.inter(
                                  color: textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                'Indian Railways & Metros Live',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF0A84FF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),

                          // LIVE Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF30D158,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(
                                  0xFF30D158,
                                ).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF30D158),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0xFF30D158),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'LIVE',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF30D158),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Theme Toggle Button (Sun / Moon)
                          InkWell(
                            onTap: () => ThemeController.instance.toggleTheme(),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cardColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: borderColor),
                              ),
                              child: Icon(
                                isDark
                                    ? CupertinoIcons.sun_max_fill
                                    : CupertinoIcons.moon_stars_fill,
                                color: isDark
                                    ? const Color(0xFFFFD60A)
                                    : const Color(0xFF0A84FF),
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Text(
                        'Plan your next\ntrain journey',
                        style: GoogleFonts.inter(
                          fontSize: ResponsiveHelper.isMobile(context)
                              ? 30
                              : 38,
                          height: 1.08,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Find trains, track live status, and explore metro lines.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Journey Planner Card (Apple Glass Inset)
                      AppleGlassCard(
                        padding: EdgeInsets.all(
                          ResponsiveHelper.isMobile(context) ? 18 : 24,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        blurSigma: 14.0,
                        border: Border.all(color: borderColor),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  CupertinoIcons.alt,
                                  color: Color(0xFF0A84FF),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'PLAN A JOURNEY',
                                  style: GoogleFonts.inter(
                                    color: textPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'FROM  •  TO',
                                  style: GoogleFonts.inter(
                                    color: textSecondary,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            StationAutocomplete(
                              controller: _fromCtrl,
                              label: 'Origin Station',
                              hint: 'e.g. NDLS',
                              icon: CupertinoIcons.location_north_fill,
                              onStationSelected: (s) => setState(() {
                                _from = s;
                                _fromCtrl.text = _stationLabel(s);
                              }),
                              onCleared: () => setState(() => _from = null),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Divider(color: borderColor, indent: 36),
                            ),
                            StationAutocomplete(
                              controller: _toCtrl,
                              label: 'Destination Station',
                              hint: 'e.g. MMCT',
                              icon: CupertinoIcons.location_fill,
                              onStationSelected: (s) => setState(() {
                                _to = s;
                                _toCtrl.text = _stationLabel(s);
                              }),
                              onCleared: () => setState(() => _to = null),
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _swap,
                                icon: const Icon(
                                  CupertinoIcons.arrow_up_arrow_down,
                                  color: Color(0xFF0A84FF),
                                  size: 15,
                                ),
                                label: Text(
                                  'Swap',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF0A84FF),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: isFindButtonEnabled
                                    ? () => _go(
                                        TrainSearchScreen(
                                          fromCode: _from!.code,
                                          toCode: _to!.code,
                                          fromName: _from!.name,
                                          toName: _to!.name,
                                          fromCity: _from!.city,
                                          toCity: _to!.city,
                                          fromLatitude: _from!.latitude,
                                          fromLongitude: _from!.longitude,
                                          toLatitude: _to!.latitude,
                                          toLongitude: _to!.longitude,
                                          fromDistrict: _from!.district,
                                          fromState: _from!.state,
                                          toDistrict: _to!.district,
                                          toState: _to!.state,
                                        ),
                                      )
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0A84FF),
                                  disabledBackgroundColor: isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.black.withValues(alpha: 0.05),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Find Trains',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      CupertinoIcons.arrow_right,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08),
                      const SizedBox(height: 24),

                      _sectionHeading(
                        'Track a train',
                        'Get live running status by name or number',
                        CupertinoIcons.antenna_radiowaves_left_right,
                        textPrimary,
                        textSecondary,
                      ),
                      const SizedBox(height: 12),

                      AppleGlassCard(
                        padding: EdgeInsets.all(
                          ResponsiveHelper.isMobile(context) ? 18 : 24,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        blurSigma: 14.0,
                        border: Border.all(color: borderColor),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TrainNumberAutocomplete(
                              controller: _trainCtrl,
                              hint: 'Enter train name or number',
                              icon: CupertinoIcons.tram_fill,
                              onTrainSelected: (train) =>
                                  setState(() => _selectedTrain = train),
                            ),
                            if (_selectedTrain != null) ...[
                              const SizedBox(height: 12),
                              _selectedTrainCard(
                                _selectedTrain!,
                                inputBgColor,
                                textPrimary,
                                textSecondary,
                                borderColor,
                              ),
                            ],
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _selectedTrain == null
                                    ? null
                                    : () => _go(
                                        TrainDetailsScreen(
                                          trainNumber:
                                              _selectedTrain!['number']!,
                                          trainName: _selectedTrain!['name']!,
                                        ),
                                      ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0A84FF),
                                  disabledBackgroundColor: isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.black.withValues(alpha: 0.05),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  'Track Train',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08),
                      const SizedBox(height: 24),

                      _sectionHeading(
                        'Explore TransitGo',
                        'Everything you need for your journey',
                        CupertinoIcons.square_grid_2x2_fill,
                        textPrimary,
                        textSecondary,
                      ),
                      const SizedBox(height: 14),

                      // Bento Features Grid
                      Column(
                        children: [
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _bentoCard(
                                    icon: CupertinoIcons.ticket_fill,
                                    title: 'PNR Status',
                                    subtitle: 'Check booking & seat status',
                                    badgeText: 'PNR CHECK',
                                    color: const Color(0xFFFF9F0A),
                                    cardColor: cardColor,
                                    textColor: textPrimary,
                                    subtitleColor: textSecondary,
                                    borderColor: borderColor,
                                    onTap: () => _go(const PnrScreen()),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _bentoCard(
                                    icon: CupertinoIcons
                                        .antenna_radiowaves_left_right,
                                    title: 'Live Station',
                                    subtitle: 'Real-time train arrivals',
                                    badgeText: 'LIVE RADAR',
                                    color: const Color(0xFFFF453A),
                                    cardColor: cardColor,
                                    textColor: textPrimary,
                                    subtitleColor: textSecondary,
                                    borderColor: borderColor,
                                    isLiveIndicator: true,
                                    onTap: () => _go(const LiveTrafficScreen()),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _bentoCard(
                                    icon: CupertinoIcons
                                        .antenna_radiowaves_left_right,
                                    title: 'Live Radar Map',
                                    subtitle: '2,000+ active trains live',
                                    badgeText: 'RADAR 📡',
                                    color: const Color(0xFFFF375F),
                                    cardColor: cardColor,
                                    textColor: textPrimary,
                                    subtitleColor: textSecondary,
                                    borderColor: borderColor,
                                    onTap: () => _go(const ScheduleScreen()),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _bentoCard(
                                    icon:
                                        CupertinoIcons.square_stack_3d_up_fill,
                                    title: 'Coach Position',
                                    subtitle: 'Platform & rake layout',
                                    badgeText: 'COACH',
                                    color: const Color(0xFF0A84FF),
                                    cardColor: cardColor,
                                    textColor: textPrimary,
                                    subtitleColor: textSecondary,
                                    borderColor: borderColor,
                                    onTap: () => _go(const CoachScreen()),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _bentoCard(
                                    icon:
                                        CupertinoIcons.money_dollar_circle_fill,
                                    title: 'Train Fare',
                                    subtitle: 'Class & ticket prices',
                                    badgeText: 'FARES',
                                    color: const Color(0xFF64D2FF),
                                    cardColor: cardColor,
                                    textColor: textPrimary,
                                    subtitleColor: textSecondary,
                                    borderColor: borderColor,
                                    onTap: () => _go(const FareScreen()),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _bentoCard(
                                    icon: CupertinoIcons.bell_fill,
                                    title: 'Alerts',
                                    subtitle: 'Delays & news updates',
                                    badgeText: 'ALERTS',
                                    color: const Color(0xFFFF375F),
                                    cardColor: cardColor,
                                    textColor: textPrimary,
                                    subtitleColor: textSecondary,
                                    borderColor: borderColor,
                                    onTap: () => _go(const AlertsScreen()),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _bentoCard(
                                    icon: CupertinoIcons.tram_fill,
                                    title: 'Metro Networks',
                                    subtitle: 'City lines & fares',
                                    badgeText: 'METRO',
                                    color: const Color(0xFF30D158),
                                    cardColor: cardColor,
                                    textColor: textPrimary,
                                    subtitleColor: textSecondary,
                                    borderColor: borderColor,
                                    onTap: () =>
                                        _go(const MetroNetworksScreen()),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _bentoCard(
                                    icon: CupertinoIcons.building_2_fill,
                                    title: 'Station Details',
                                    subtitle: 'Facilities & helpline',
                                    badgeText: 'STATION',
                                    color: const Color(0xFF0A84FF),
                                    cardColor: cardColor,
                                    textColor: textPrimary,
                                    subtitleColor: textSecondary,
                                    borderColor: borderColor,
                                    onTap: () => _go(const StationInfoScreen()),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _bentoCard(
                                    icon: CupertinoIcons.time_solid,
                                    title: 'History',
                                    subtitle: 'Recent searches',
                                    badgeText: 'RECENT',
                                    color: textSecondary,
                                    cardColor: cardColor,
                                    textColor: textPrimary,
                                    subtitleColor: textSecondary,
                                    borderColor: borderColor,
                                    onTap: () => _go(const HistoryScreen()),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _bentoCard(
                                    icon: CupertinoIcons.ellipsis,
                                    title: 'More Features',
                                    subtitle: 'Settings & tools',
                                    badgeText: 'MORE',
                                    color: textSecondary,
                                    cardColor: cardColor,
                                    textColor: textPrimary,
                                    subtitleColor: textSecondary,
                                    borderColor: borderColor,
                                    onTap: () => _go(const MoreScreen()),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _selectedTrainCard(
    Map<String, String> train,
    Color inputBg,
    Color textPrimary,
    Color textSecondary,
    Color border,
  ) {
    final source = train['source'] ?? '';
    final destination = train['destination'] ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${train['number']}  •  ${train['name']}',
            style: GoogleFonts.inter(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (source.isNotEmpty || destination.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${source.isNotEmpty ? source : '—'} → '
              '${destination.isNotEmpty ? destination : '—'}',
              style: GoogleFonts.inter(color: textSecondary, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeading(
    String title,
    String subtitle,
    IconData icon,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF0A84FF).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF0A84FF), size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bentoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color color,
    required Color cardColor,
    required Color textColor,
    required Color subtitleColor,
    required Color borderColor,
    bool isLiveIndicator = false,
    required VoidCallback onTap,
  }) {
    return AppleGlassCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(22),
      blurSigma: 14.0,
      border: Border.all(color: borderColor, width: 1.0),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLiveIndicator) ...[
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: color, blurRadius: 4),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        badgeText,
                        style: GoogleFonts.inter(
                          color: color,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: subtitleColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  CupertinoIcons.chevron_right,
                  color: subtitleColor,
                  size: 14,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
