import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../components/common/feature_intro.dart';
import '../../../components/common/modern_background.dart';
import '../../../components/station/station_autocomplete.dart';
import '../../../core/cache/offline_cache.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../data/models/station.dart';
import '../../../data/models/station_traffic.dart';
import '../../../data/sources/station_source.dart';
import '../../../services/analytics_service.dart';
import '../../../services/live_traffic_service.dart';
import '../../../services/station_explorer_service.dart';
import '../../train_details/train_details_screen.dart';

class StationInfoScreen extends StatefulWidget {
  final String? initialStationCode;
  final String? initialStationName;

  const StationInfoScreen({
    super.key,
    this.initialStationCode,
    this.initialStationName,
  });

  @override
  State<StationInfoScreen> createState() => _StationInfoScreenState();
}

class _StationInfoScreenState extends State<StationInfoScreen>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  Station? _selected;
  late TabController _tabController;
  bool _loadingTraffic = false;
  StationTraffic? _trafficData;
  bool _loadingExplorer = false;
  StationExplorerData? _explorerData;
  int _explorerRequest = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    final code = widget.initialStationCode?.trim();
    if (code != null && code.isNotEmpty) {
      final normalizedCode = code.toUpperCase();
      final name = widget.initialStationName?.trim();
      final local = StationSource.byCode(normalizedCode);
      _selected = _enrichStation(
        local ??
            Station(
              code: normalizedCode,
              name: name == null || name.isEmpty ? normalizedCode : name,
            ),
      );
      _ctrl.text = '${_selected!.name} (${_selected!.code})';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fetchTraffic(normalizedCode);
          _fetchExplorer(_selected!);
        }
      });
    }
  }

  Station _enrichStation(Station station) {
    final local = StationSource.byCode(station.code);
    if (local == null) return station;
    return Station.fromJson({
      ...station.toJson(),
      ...local.toJson(),
      'code': station.code,
      'name': station.name.isNotEmpty ? station.name : local.name,
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchTraffic(String code) async {
    setState(() => _loadingTraffic = true);
    final data = await LiveTrafficService.fetch(code);
    if (!mounted) return;
    if (data != null && _selected != null) {
      await OfflineCache.addHistory(
        'station',
        _selected!.code,
        label: '${_selected!.name} (${_selected!.code})',
        data: {'stationCode': _selected!.code, 'stationName': _selected!.name},
      );
    }
    if (!mounted) return;
    setState(() {
      _trafficData = data;
      _loadingTraffic = false;
    });
  }

  Future<void> _fetchExplorer(Station station) async {
    final seq = ++_explorerRequest;
    setState(() => _loadingExplorer = true);
    final data = await StationExplorerService.fetch(station);
    if (!mounted || seq != _explorerRequest) return;
    setState(() {
      _explorerData = data;
      _loadingExplorer = false;
    });
  }

  void _onStationSelected(Station station) {
    final enriched = _enrichStation(station);
    setState(() {
      _selected = enriched;
      _trafficData = null;
      _explorerData = null;
      _ctrl.text = '${enriched.name} (${enriched.code})';
    });
    AnalyticsService.logStationView(
      stationCode: enriched.code,
      stationName: enriched.name,
    );
    _fetchTraffic(enriched.code);
    _fetchExplorer(enriched);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDarkMode;
    final bgColor = isDark ? const Color(0xFF030305) : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF101320) : const Color(0xFFFFFFFF);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? const Color(0xFF98989D) : const Color(0xFF636366);
    final borderCol = isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFE5E5EA);
    final inputBg = isDark ? const Color(0xFF181B28) : const Color(0xFFF7F8FC);

    final s = _selected;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Station Details & Explorer',
          style: GoogleFonts.inter(
            color: textPrimary,
            fontWeight: FontWeight.bold,
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
      body: ModernBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          physics: const BouncingScrollPhysics(),
          children: [
            const FeatureIntro(
              title: 'Explore every\nrailway station.',
              subtitle: 'Platforms, facilities, contact numbers, and live train traffic.',
              icon: CupertinoIcons.building_2_fill,
              accent: Color(0xFF0A84FF),
            ),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: borderCol),
              ),
              child: StationAutocomplete(
                controller: _ctrl,
                label: 'Search Railway Station',
                hint: 'Type station name or code (e.g. NDLS)...',
                icon: CupertinoIcons.search,
                onStationSelected: _onStationSelected,
              ),
            ),
            const SizedBox(height: 20),
            if (s != null) ...[
              _stationHeaderCard(s, cardBg, textPrimary, textSecondary, borderCol),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderCol),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: const Color(0xFF0A84FF),
                  labelColor: const Color(0xFF0A84FF),
                  unselectedLabelColor: textSecondary,
                  labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                  unselectedLabelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Facilities'),
                    Tab(text: 'Helplines'),
                    Tab(text: 'Map & Nearby'),
                    Tab(text: 'Live Traffic'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 580,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _infoCard(s, cardBg, textPrimary, textSecondary, borderCol),
                    _facilitiesTab(s, cardBg, textPrimary, textSecondary, borderCol),
                    _helplinesTab(s, cardBg, textPrimary, textSecondary, borderCol),
                    _mapTab(s, cardBg, textPrimary, textSecondary, borderCol, inputBg),
                    _trafficTab(s, cardBg, textPrimary, textSecondary, borderCol),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  }

  Widget _stationHeaderCard(Station s, Color cardBg, Color textPrimary, Color textSecondary, Color borderCol) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderCol),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0A84FF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              CupertinoIcons.building_2_fill,
              color: Color(0xFF0A84FF),
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Code: ${s.code} • ${_formatZone(s.zone)} Division',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A84FF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        s.type?.toUpperCase() ?? 'RAILWAY STATION',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF0A84FF),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF30D158).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ACTIVE 🟢',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF30D158),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(Station s, Color cardBg, Color textPrimary, Color textSecondary, Color borderCol) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: borderCol),
    ),
    child: ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        // Station Photo Carousel from Wikimedia Commons
        if (_explorerData?.images != null && _explorerData!.images.isNotEmpty) ...[
          Text(
            'STATION PHOTOS & MEDIA',
            style: GoogleFonts.inter(color: textSecondary, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _explorerData!.images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final img = _explorerData!.images[i];
                return GestureDetector(
                  onTap: () {
                    if (img.sourceUrl.isNotEmpty) {
                      launchUrl(Uri.parse(img.sourceUrl), mode: LaunchMode.externalApplication);
                    }
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 200,
                      decoration: BoxDecoration(
                        color: borderCol,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: img.url,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(color: Color(0xFF0A84FF), strokeWidth: 2),
                            ),
                            errorWidget: (_, __, ___) => const Icon(CupertinoIcons.photo, color: Colors.grey),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.black87, Colors.transparent],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                              ),
                              child: Text(
                                img.title.replaceAll('File:', ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: borderCol, height: 1),
          const SizedBox(height: 12),
        ],

        _row('Station Name', s.name, textPrimary, textSecondary),
        _row('Station Code', s.code, textPrimary, textSecondary),
        if (s.city != null && s.city!.isNotEmpty) _row('City', s.city!, textPrimary, textSecondary),
        if (s.district != null && s.district!.isNotEmpty) _row('District', s.district!, textPrimary, textSecondary),
        if (s.state != null && s.state!.isNotEmpty) _row('State', s.state!, textPrimary, textSecondary),
        _row('Railway Zone', _formatZone(s.zone), textPrimary, textSecondary),
        if (s.division != null && s.division!.isNotEmpty) _row('Division', s.division!, textPrimary, textSecondary),
        if (s.elevation != null) _row('Elevation', '${s.elevation} meters', textPrimary, textSecondary),
        if (s.hasCoordinates) _row('GPS Coordinates', '${s.latitude!.toStringAsFixed(5)}, ${s.longitude!.toStringAsFixed(5)}', textPrimary, textSecondary),

        if (_loadingExplorer)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(color: Color(0xFF0A84FF), minHeight: 2),
          ),

        if (_explorerData?.history != null && _explorerData!.history!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STATION OVERVIEW & HISTORY',
                style: GoogleFonts.inter(color: textSecondary, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.8),
              ),
              if (_explorerData?.wikipediaUrl != null)
                GestureDetector(
                  onTap: () => launchUrl(Uri.parse(_explorerData!.wikipediaUrl!), mode: LaunchMode.externalApplication),
                  child: Row(
                    children: [
                      Text('Wikipedia', style: GoogleFonts.inter(color: const Color(0xFF0A84FF), fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 3),
                      const Icon(CupertinoIcons.arrow_up_right_square, color: Color(0xFF0A84FF), size: 12),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_explorerData!.history!, style: GoogleFonts.inter(color: textPrimary, fontSize: 12, height: 1.45)),
        ],
      ],
    ),
  );

  Widget _facilitiesTab(Station s, Color cardBg, Color textPrimary, Color textSecondary, Color borderCol) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: borderCol),
    ),
    child: ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        Text('STATION AMENITIES & FACILITIES', style: GoogleFonts.inter(color: textSecondary, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
        const SizedBox(height: 12),
        _facilityTile('Wi-Fi High-Speed Internet', 'RailWire Free Wi-Fi at all platforms', CupertinoIcons.wifi, textPrimary, textSecondary),
        _facilityTile('AC Lounge & Waiting Halls', 'IRCTC Executive Lounge & General Waiting Rooms', CupertinoIcons.bed_double_fill, textPrimary, textSecondary),
        _facilityTile('Food Court & Refreshments', '24/7 IRCTC Food Plaza & Catering Stalls', CupertinoIcons.cart_fill, textPrimary, textSecondary),
        _facilityTile('Wheelchair & Battery Buggy', 'Divyangjan Friendly Ramp & Lift Access', CupertinoIcons.person_badge_plus_fill, textPrimary, textSecondary),
        _facilityTile('ATM & Cash Vending', 'SBI / Major Bank ATMs at Concourse', CupertinoIcons.money_dollar_circle_fill, textPrimary, textSecondary),
        _facilityTile('Cloak Room & Luggage Locker', '24/7 Luggage Storage Facility Available', CupertinoIcons.briefcase_fill, textPrimary, textSecondary),
        _facilityTile('Car & Two-Wheeler Parking', '24/7 Paid Parking Space Available', CupertinoIcons.car_fill, textPrimary, textSecondary),
      ],
    ),
  );

  Widget _helplinesTab(Station s, Color cardBg, Color textPrimary, Color textSecondary, Color borderCol) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: borderCol),
    ),
    child: ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        Text('EMERGENCY & STATION HELPLINES', style: GoogleFonts.inter(color: textSecondary, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
        const SizedBox(height: 12),
        _helplineTile('RailMadad Universal Helpline', '139', CupertinoIcons.phone_fill, textPrimary, textSecondary),
        _helplineTile('RPF Security & Medical Helpline', '182', CupertinoIcons.shield_fill, textPrimary, textSecondary),
        _helplineTile('GRP Police Emergency Control', '1512', CupertinoIcons.phone_circle_fill, textPrimary, textSecondary),
        _helplineTile('Women Passenger Safety Helpline', '1091', CupertinoIcons.heart_fill, textPrimary, textSecondary),
        _helplineTile('Station Master Desk (${s.code})', '139', CupertinoIcons.building_2_fill, textPrimary, textSecondary),
      ],
    ),
  );

  Widget _mapTab(Station s, Color cardBg, Color textPrimary, Color textSecondary, Color borderCol, Color inputBg) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: borderCol),
    ),
    child: ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        Center(
          child: Column(
            children: [
              const Icon(CupertinoIcons.map_pin_ellipse, color: Color(0xFF0A84FF), size: 48),
              const SizedBox(height: 10),
              Text('${s.name} (${s.code})', style: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
              if (s.hasCoordinates) ...[
                const SizedBox(height: 4),
                Text('GPS: ${s.latitude!.toStringAsFixed(4)}, ${s.longitude!.toStringAsFixed(4)}', style: GoogleFonts.inter(color: textSecondary, fontSize: 11)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=${s.latitude},${s.longitude}'), mode: LaunchMode.externalApplication),
                  icon: const Icon(CupertinoIcons.location_fill, size: 16),
                  label: const Text('Open in Google Maps'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A84FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),
        Divider(color: borderCol, height: 1),
        const SizedBox(height: 16),

        if (_explorerData?.connections != null && _explorerData!.connections.isNotEmpty) ...[
          Text('DYNAMIC TRANSIT & CONNECTIVITY', style: GoogleFonts.inter(color: textSecondary, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
          const SizedBox(height: 10),
          ..._explorerData!.connections.map((conn) {
            IconData connIcon = CupertinoIcons.tram_fill;
            final catLow = conn.category.toLowerCase();
            if (catLow.contains('bus')) connIcon = CupertinoIcons.bus;
            if (catLow.contains('taxi') || catLow.contains('auto')) connIcon = CupertinoIcons.car_fill;
            if (catLow.contains('airport') || catLow.contains('helipad')) connIcon = CupertinoIcons.airplane;
            if (catLow.contains('ferry') || catLow.contains('boat')) connIcon = CupertinoIcons.square_stack_3d_down_right_fill;

            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(connIcon, color: const Color(0xFF0A84FF), size: 18),
              title: Text(conn.name, style: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 12.5)),
              subtitle: Text('${conn.category} • ~${conn.distanceKm.toStringAsFixed(1)} km away', style: GoogleFonts.inter(color: textSecondary, fontSize: 10.5)),
            );
          }),
          const SizedBox(height: 16),
          Divider(color: borderCol, height: 1),
          const SizedBox(height: 16),
        ],

        if (_explorerData?.nearbyStations != null && _explorerData!.nearbyStations.isNotEmpty) ...[
          Text('NEARBY RAILWAY STATIONS & JUNCTIONS', style: GoogleFonts.inter(color: textSecondary, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
          const SizedBox(height: 10),
          ..._explorerData!.nearbyStations.map((st) {
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(CupertinoIcons.building_2_fill, color: Color(0xFF5E5CE6), size: 18),
              title: Text(st.name, style: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 12.5)),
              subtitle: Text('${st.category} • ~${st.distanceKm.toStringAsFixed(1)} km away', style: GoogleFonts.inter(color: textSecondary, fontSize: 10.5)),
            );
          }),
          const SizedBox(height: 16),
          Divider(color: borderCol, height: 1),
          const SizedBox(height: 16),
        ],

        Text('NEARBY LANDMARKS & ATTRACTIONS', style: GoogleFonts.inter(color: textSecondary, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
        const SizedBox(height: 10),

        if (_loadingExplorer)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(color: Color(0xFF0A84FF))),
          )
        else if (_explorerData?.touristPlaces != null && _explorerData!.touristPlaces.isNotEmpty)
          ..._explorerData!.touristPlaces.map((place) => _touristPlaceCard(place, s, inputBg, textPrimary, textSecondary, borderCol))
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No nearby attractions found within 20 km.',
              style: GoogleFonts.inter(color: textSecondary, fontSize: 11.5),
            ),
          ),
      ],
    ),
  );

  Widget _trafficTab(Station s, Color cardBg, Color textPrimary, Color textSecondary, Color borderCol) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: borderCol),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('LIVE TRAIN MOVEMENTS AT ${s.code}', style: GoogleFonts.inter(color: textSecondary, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
            IconButton(
              icon: const Icon(CupertinoIcons.refresh_bold, color: Color(0xFF0A84FF), size: 16),
              onPressed: () => _fetchTraffic(s.code),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loadingTraffic
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF0A84FF)))
              : _trafficData == null || _trafficData!.movements.isEmpty
                  ? Center(child: Text('Live train traffic currently unavailable.', style: GoogleFonts.inter(color: textSecondary, fontSize: 12)))
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _trafficData!.movements.length,
                      itemBuilder: (_, i) {
                        final t = _trafficData!.movements[i];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (t.trainNumber.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TrainDetailsScreen(
                                      trainNumber: t.trainNumber,
                                      trainName: t.trainName,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: textPrimary.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: borderCol),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${t.trainNumber} • ${t.trainName}',
                                          style: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Platform ${t.platform ?? "--"} • Time: ${t.arrival ?? t.departure ?? "--"}',
                                          style: GoogleFonts.inter(color: textSecondary, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (t.delayMinutes > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF9F0A).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '+${t.delayMinutes}m late',
                                        style: GoogleFonts.inter(color: const Color(0xFFFF9F0A), fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF30D158).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'On Time 🟢',
                                        style: GoogleFonts.inter(color: const Color(0xFF30D158), fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    ),
  );

  Widget _row(String label, String value, Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
          Text(value, style: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _facilityTile(String title, String desc, IconData icon, Color textPrimary, Color textSecondary) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Icon(icon, color: const Color(0xFF0A84FF)),
      title: Text(title, style: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 12.5)),
      subtitle: Text(desc, style: GoogleFonts.inter(color: textSecondary, fontSize: 11)),
    );
  }

  Widget _helplineTile(String title, String number, IconData icon, Color textPrimary, Color textSecondary) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Icon(icon, color: const Color(0xFF30D158)),
      title: Text(title, style: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 12.5)),
      subtitle: Text(number, style: GoogleFonts.inter(color: const Color(0xFF30D158), fontWeight: FontWeight.w900, fontSize: 14)),
      trailing: IconButton(
        icon: const Icon(CupertinoIcons.phone_circle_fill, color: Color(0xFF30D158), size: 22),
        onPressed: () => launchUrl(Uri.parse('tel:$number')),
      ),
    );
  }

  Widget _touristPlaceCard(
    StationExplorerPlace place,
    Station station,
    Color inputBg,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            final query = Uri.encodeComponent('${place.name}, ${station.name}');
            launchUrl(
              Uri.parse('https://www.google.com/maps/search/?api=1&query=$query'),
              mode: LaunchMode.externalApplication,
            );
          },
          child: Row(
            children: [
              if (place.imageUrl != null && place.imageUrl!.isNotEmpty)
                SizedBox(
                  width: 100,
                  height: 90,
                  child: CachedNetworkImage(
                    imageUrl: place.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: borderCol,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A84FF)),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: borderCol,
                      child: const Icon(CupertinoIcons.photo, color: Colors.grey),
                    ),
                  ),
                )
              else
                Container(
                  width: 90,
                  height: 90,
                  color: const Color(0xFF30D158).withValues(alpha: 0.12),
                  child: const Center(
                    child: Icon(CupertinoIcons.compass_fill, color: Color(0xFF30D158), size: 30),
                  ),
                ),

              const SizedBox(width: 12),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF30D158).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          place.category.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: const Color(0xFF30D158),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(CupertinoIcons.location_fill, color: Color(0xFF0A84FF), size: 12),
                          const SizedBox(width: 4),
                          Text(
                            '~${place.distanceKm.toStringAsFixed(1)} km from ${station.code}',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF0A84FF),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(CupertinoIcons.chevron_right, color: Colors.grey, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatZone(String? zone) {
    if (zone == null || zone.isEmpty) return 'Indian Railways';
    return zone.toUpperCase();
  }
}
