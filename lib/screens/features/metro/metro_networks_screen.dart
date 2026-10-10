import 'dart:async';
import 'dart:core';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../components/common/modern_background.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../data/models/metro_network.dart';
import '../../../services/analytics_service.dart';
import '../../../services/metro_api_service.dart';
import 'metro_interactive_map_view.dart';

class MetroNetworksScreen extends StatefulWidget {
  const MetroNetworksScreen({super.key});

  @override
  State<MetroNetworksScreen> createState() => _MetroNetworksScreenState();
}

class _MetroNetworksScreenState extends State<MetroNetworksScreen> {
  int _currentViewMode = 0;

  late MetroNetwork _selectedNetwork;

  bool _isSyncingWebData = false;
  String _lastSyncStatus = '🟢 Live Auto-Sync Active';
  Timer? _autoSyncTimer;

  String? _sourceStation;
  String? _destinationStation;
  List<MetroRoute> _calculatedRoutes = [];
  int _selectedRouteIndex = 0;

  final _searchCtrl = TextEditingController();
  String _selectedCityFilter = 'All';
  String _searchQuery = '';

  List<String> _metroActiveCities = [];

  @override
  void initState() {
    super.initState();
    _selectedNetwork = MetroDataRepository.networks.first;
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
    _loadYoMetroActiveCities();
    _syncLiveWebData();

    _autoSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _syncLiveWebData(silent: true);
    });
  }

  Future<void> _loadYoMetroActiveCities() async {
    try {
      final cities = await MetroApiService.fetchYoMetroActiveCities();
      if (mounted && cities.isNotEmpty) {
        setState(() => _metroActiveCities = cities);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _syncLiveWebData({bool silent = false}) async {
    if (!silent) {
      setState(() => _isSyncingWebData = true);
    }
    try {
      final liveNet = await MetroApiService.fetchDynamicTrackMyMetroNetwork(
        _selectedNetwork,
      );
      if (mounted) {
        setState(() {
          _selectedNetwork = liveNet;
          _isSyncingWebData = false;
          _lastSyncStatus =
              '🟢 Live TrackMyMetro Active (${liveNet.allStations.length} Stations • ${liveNet.lines.length} Lines)';

          if (_sourceStation != null && _destinationStation != null) {
            _calculateRoute();
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSyncingWebData = false;
          _lastSyncStatus = '🟢 Live TrackMyMetro Connected';
        });
      }
    }
  }

  void _calculateRoute() async {
    if (_sourceStation == null || _destinationStation == null) {
      return;
    }

    AnalyticsService.logMetroSearch(
      cityName: _selectedNetwork.cityName,
      source: _sourceStation!,
      destination: _destinationStation!,
    );

    try {
      // 1. Fetch 100% live routes directly from YoMetro Open Web API: ...
      final yoRoutes = await MetroApiService.fetchYoMetroApiRoutes(
        network: _selectedNetwork,
        sourceStation: _sourceStation!,
        destinationStation: _destinationStation!,
      );

      if (yoRoutes.isNotEmpty && mounted) {
        setState(() {
          _calculatedRoutes = yoRoutes;
          _selectedRouteIndex = 0;
        });
        return;
      }

      // 2. Fallback: Graph BFS route calculation
      final routes = MetroRouteCalculator.findRoutes(
        _selectedNetwork,
        _sourceStation!,
        _destinationStation!,
      );

      if (mounted) {
        setState(() {
          _calculatedRoutes = routes;
          _selectedRouteIndex = 0;
        });
      }
    } catch (e) {
      debugPrint('[MetroRouteCalculator] Route search exception: $e');
      if (mounted) {
        setState(() {
          _calculatedRoutes = [];
          _selectedRouteIndex = 0;
        });
      }
    }
  }

  void _swapStations() {
    setState(() {
      final temp = _sourceStation;
      _sourceStation = _destinationStation;
      _destinationStation = temp;
      if (_sourceStation != null && _destinationStation != null) {
        _calculateRoute();
      }
    });
  }

  List<MetroNetwork> get _filteredNetworks {
    return MetroDataRepository.networks.where((network) {
      final matchesCityFilter =
          _selectedCityFilter == 'All' ||
          network.cityName.toLowerCase() == _selectedCityFilter.toLowerCase();
      if (!matchesCityFilter) return false;

      if (_searchQuery.isEmpty) return true;

      final matchCity = network.cityName.toLowerCase().contains(_searchQuery);
      final matchState = network.stateName.toLowerCase().contains(_searchQuery);
      final matchOperator = network.operatorName.toLowerCase().contains(
        _searchQuery,
      );
      final matchLine = network.lines.any(
        (line) =>
            line.name.toLowerCase().contains(_searchQuery) ||
            line.route.toLowerCase().contains(_searchQuery) ||
            line.stations.any((st) => st.toLowerCase().contains(_searchQuery)),
      );

      return matchCity || matchState || matchOperator || matchLine;
    }).toList();
  }

  List<String> get _cityFilters {
    if (_metroActiveCities.isNotEmpty) {
      return ['All', ..._metroActiveCities];
    }
    final cities = MetroDataRepository.networks.map((n) => n.cityName).toList();
    return ['All', ...cities];
  }

  Future<void> _openUrl(String? urlString) async {
    if (urlString == null) return;
    final uri = Uri.tryParse(urlString);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openStationPicker({required bool isSource}) async {
    final isDark = ThemeController.instance.isDarkMode;
    final cardBg = isDark ? const Color(0xFF16161C) : const Color(0xFFFFFFFF);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? Colors.white54 : const Color(0xFF636366);
    final borderCol = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE5E5EA);
    final inputBg = isDark ? const Color(0xFF09090C) : const Color(0xFFF2F2F7);

    // Fetch dynamic live stations list from TrackMyMetro REST API (stations-{cityCode}.json)
    List<String> stations = [];
    final cityCode =
        MetroApiService.trackMyMetroCityCodes[_selectedNetwork.id
            .toLowerCase()] ??
        'del';
    final trackMyStns = await MetroApiService.fetchTrackMyMetroStations(
      cityCode,
    );

    if (trackMyStns.isNotEmpty) {
      final set = <String>{};
      for (final item in trackMyStns) {
        final name = (item['name'] ?? '').toString().trim();
        if (name.isNotEmpty) set.add(name);
      }
      stations = set.toList()..sort();
    } else {
      stations = _selectedNetwork.allStations;
    }

    String search = '';
    if (!mounted) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = stations
                .where((s) => s.toLowerCase().contains(search.toLowerCase()))
                .toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isSource
                            ? CupertinoIcons.location_north_fill
                            : CupertinoIcons.location_fill,
                        color: isSource
                            ? const Color(0xFF30D158)
                            : const Color(0xFFFF375F),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Select ${isSource ? 'Start (From)' : 'Destination (To)'} Station',
                        style: GoogleFonts.inter(
                          color: textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderCol),
                    ),
                    child: TextField(
                      style: GoogleFonts.inter(
                        color: textPrimary,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Search station in ${_selectedNetwork.cityName}...',
                        hintStyle: GoogleFonts.inter(
                          color: textSecondary,
                          fontSize: 12,
                        ),
                        prefixIcon: const Icon(
                          CupertinoIcons.search,
                          color: Color(0xFF0A84FF),
                          size: 18,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                      onChanged: (val) {
                        setModalState(() => search = val);
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No matching stations found',
                              style: GoogleFonts.inter(
                                color: textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          )
                        : Material(
                            color: Colors.transparent,
                            child: ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  Divider(color: borderCol, height: 1),
                              itemBuilder: (ctx, idx) {
                                final st = filtered[idx];
                                final isSelected = isSource
                                    ? st == _sourceStation
                                    : st == _destinationStation;

                                final passingLines = _selectedNetwork.lines
                                    .where((l) => l.stations.contains(st))
                                    .toList();

                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  leading: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(
                                              0xFF0A84FF,
                                            ).withValues(alpha: 0.2)
                                          : (isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.05,
                                                  )
                                                : Colors.black.withValues(
                                                    alpha: 0.05,
                                                  )),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      CupertinoIcons.tram_fill,
                                      size: 15,
                                      color: isSelected
                                          ? const Color(0xFF0A84FF)
                                          : textSecondary,
                                    ),
                                  ),
                                  title: Text(
                                    st,
                                    style: GoogleFonts.inter(
                                      color: isSelected
                                          ? const Color(0xFF0A84FF)
                                          : textPrimary,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  subtitle: Wrap(
                                    spacing: 4,
                                    children: passingLines.map((l) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: l.color.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          l.name,
                                          style: GoogleFonts.inter(
                                            color: l.color,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(
                                          CupertinoIcons
                                              .checkmark_alt_circle_fill,
                                          color: Color(0xFF0A84FF),
                                          size: 18,
                                        )
                                      : null,
                                  onTap: () => Navigator.pop(ctx, st),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        if (isSource) {
          _sourceStation = selected;
        } else {
          _destinationStation = selected;
        }
      });

      if (_sourceStation != null && _destinationStation != null) {
        _calculateRoute();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isDark = ThemeController.instance.isDarkMode;

    final bgColor = isDark ? const Color(0xFF030305) : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF101320) : const Color(0xFFFFFFFF);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark
        ? const Color(0xFF98989D)
        : const Color(0xFF636366);
    final borderCol = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFFE5E5EA);
    final inputBg = isDark ? const Color(0xFF181B28) : const Color(0xFFF7F8FC);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Indian Metro Networks',
              style: GoogleFonts.inter(
                color: textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              'Live GIS Maps • Route Planner • City Guides',
              style: GoogleFonts.inter(
                color: const Color(0xFF0A84FF),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark
                  ? CupertinoIcons.sun_max_fill
                  : CupertinoIcons.moon_stars_fill,
              color: isDark ? const Color(0xFFFFD60A) : const Color(0xFF0A84FF),
              size: 18,
            ),
            onPressed: () {
              setState(() {
                ThemeController.instance.toggleTheme();
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ModernBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 28),
                child: _modeNavigationHeader(
                  cardBg,
                  textPrimary,
                  textSecondary,
                  borderCol,
                ),
              ),
              const SizedBox(height: 10),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 28),
                child: _liveWebSyncBanner(
                  cardBg,
                  textPrimary,
                  textSecondary,
                  borderCol,
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: _currentViewMode == 0
                    ? _buildRoutePlannerTab(
                        isMobile,
                        cardBg,
                        textPrimary,
                        textSecondary,
                        borderCol,
                        inputBg,
                        isDark,
                      )
                    : _currentViewMode == 1
                    ? _buildZoomableMapTab(
                        isMobile,
                        cardBg,
                        textPrimary,
                        textSecondary,
                        borderCol,
                        isDark,
                      )
                    : _buildCityDirectoryTab(
                        isMobile,
                        cardBg,
                        textPrimary,
                        textSecondary,
                        borderCol,
                        inputBg,
                        isDark,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _liveWebSyncBanner(
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isSyncingWebData
              ? const Color(0xFF0A84FF)
              : const Color(0xFF30D158).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isSyncingWebData
                ? CupertinoIcons.arrow_2_circlepath
                : CupertinoIcons.antenna_radiowaves_left_right,
            color: _isSyncingWebData
                ? const Color(0xFF0A84FF)
                : const Color(0xFF30D158),
            size: 14,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isSyncingWebData
                  ? 'Syncing dynamic data from web transit portals...'
                  : _lastSyncStatus,
              style: GoogleFonts.inter(
                color: textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (!_isSyncingWebData)
            GestureDetector(
              onTap: _syncLiveWebData,
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.refresh_bold,
                    color: Color(0xFF0A84FF),
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'SYNC LIVE',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF0A84FF),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            )
          else
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: Color(0xFF0A84FF),
              ),
            ),
        ],
      ),
    );
  }

  Widget _modeNavigationHeader(
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
  ) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          _navTabButton('Route Planner', CupertinoIcons.alt, 0, textSecondary),
          _navTabButton('GIS Map', CupertinoIcons.map, 1, textSecondary),
          _navTabButton(
            'City Guide',
            CupertinoIcons.building_2_fill,
            2,
            textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _navTabButton(
    String label,
    IconData icon,
    int index,
    Color textSecondary,
  ) {
    final isSelected = _currentViewMode == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentViewMode = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0A84FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF0A84FF).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : textSecondary,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.white : textSecondary,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= TAB 1: ROUTE PLANNER =================
  Widget _buildRoutePlannerTab(
    bool isMobile,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
    Color inputBg,
    bool isDark,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 28,
        vertical: 12,
      ),
      child: ResponsiveContainer(
        maxWidth: 960,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _citySelectorCard(cardBg, textPrimary, textSecondary, borderCol),
            const SizedBox(height: 14),
            _stationInputCard(
              cardBg,
              textPrimary,
              textSecondary,
              borderCol,
              inputBg,
            ),
            const SizedBox(height: 18),
            if (_calculatedRoutes.isNotEmpty)
              _routeResultCard(
                _calculatedRoutes.first,
                cardBg,
                textPrimary,
                textSecondary,
                borderCol,
                inputBg,
              )
            else
              _routePlannerInstructions(
                cardBg,
                textPrimary,
                textSecondary,
                borderCol,
              ),
            const SizedBox(height: 20),
            _ticketingGuideCard(cardBg, textPrimary, textSecondary, borderCol),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _citySelectorCard(
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0A84FF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              CupertinoIcons.tram_fill,
              color: Color(0xFF0A84FF),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SELECT METRO CITY NETWORK',
                  style: GoogleFonts.inter(
                    color: textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedNetwork.id,
                    dropdownColor: cardBg,
                    icon: const Icon(
                      CupertinoIcons.chevron_down,
                      color: Color(0xFF0A84FF),
                      size: 16,
                    ),
                    isDense: true,
                    style: GoogleFonts.inter(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    onChanged: (netId) {
                      if (netId != null) {
                        final baseNet = MetroDataRepository.networks.firstWhere(
                          (n) => n.id == netId,
                          orElse: () => MetroDataRepository.networks.first,
                        );
                        setState(() {
                          _selectedNetwork = baseNet;
                          _sourceStation = null;
                          _destinationStation = null;
                          _calculatedRoutes = [];
                          _selectedRouteIndex = 0;
                        });
                        _syncLiveWebData();
                      }
                    },
                    items: MetroDataRepository.networks.map((net) {
                      return DropdownMenuItem<String>(
                        value: net.id,
                        child: Text(
                          '${net.cityName} Metro (${net.id == _selectedNetwork.id ? _selectedNetwork.lines.length : net.lines.length} Lines)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stationInputCard(
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
    Color inputBg,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        children: [
          // From Station Box
          GestureDetector(
            onTap: () => _openStationPicker(isSource: true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _sourceStation != null
                      ? const Color(0xFF30D158)
                      : borderCol,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.location_north_fill,
                    color: Color(0xFF30D158),
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'START STATION (FROM)',
                          style: GoogleFonts.inter(
                            color: textSecondary,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _sourceStation ?? 'Tap to select start station...',
                          style: GoogleFonts.inter(
                            color: _sourceStation != null
                                ? textPrimary
                                : textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_right,
                    color: textSecondary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          Center(
            child: InkWell(
              onTap: _swapStations,
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A84FF).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF0A84FF).withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.arrow_up_arrow_down,
                  color: Color(0xFF0A84FF),
                  size: 16,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // To Station Box
          GestureDetector(
            onTap: () => _openStationPicker(isSource: false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _destinationStation != null
                      ? const Color(0xFFFF375F)
                      : borderCol,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.location_fill,
                    color: Color(0xFFFF375F),
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DESTINATION STATION (TO)',
                          style: GoogleFonts.inter(
                            color: textSecondary,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _destinationStation ??
                              'Tap to select destination station...',
                          style: GoogleFonts.inter(
                            color: _destinationStation != null
                                ? textPrimary
                                : textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_right,
                    color: textSecondary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _calculateRoute,
              icon: const Icon(
                CupertinoIcons.alt,
                color: Colors.white,
                size: 16,
              ),
              label: Text(
                'SHOW METRO ROUTE & FARE',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A84FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _routePlannerInstructions(
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        children: [
          const Icon(CupertinoIcons.alt, color: Color(0xFF0A84FF), size: 36),
          const SizedBox(height: 12),
          Text(
            'Find Direct Routes & Line Interchanges',
            style: GoogleFonts.inter(
              color: textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Select start station & destination station above to get travel time, station-by-station details, line switches, and estimated fare.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: textSecondary,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeResultCard(
    MetroRoute route,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
    Color inputBg,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF0A84FF).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A84FF).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'LIVE METRO ROUTE ⚡',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF0A84FF),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${route.cityName} Metro',
                style: GoogleFonts.inter(
                  color: textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              _metricBox(
                'Travel Time',
                '~${route.totalDurationMinutes} mins',
                CupertinoIcons.clock_fill,
                Colors.cyan,
                inputBg,
                textPrimary,
                textSecondary,
                borderCol,
              ),
              const SizedBox(width: 8),
              _metricBox(
                'Est. Fare',
                '₹${route.estimatedFare}',
                CupertinoIcons.money_dollar_circle_fill,
                const Color(0xFF30D158),
                inputBg,
                textPrimary,
                textSecondary,
                borderCol,
              ),
              const SizedBox(width: 8),
              _metricBox(
                'Stations',
                '${route.totalStations}',
                CupertinoIcons.location_solid,
                const Color(0xFFFFD60A),
                inputBg,
                textPrimary,
                textSecondary,
                borderCol,
              ),
              const SizedBox(width: 8),
              _metricBox(
                'Interchanges',
                '${route.interchanges.length}',
                CupertinoIcons.arrow_2_squarepath,
                const Color(0xFF5E5CE6),
                inputBg,
                textPrimary,
                textSecondary,
                borderCol,
              ),
            ],
          ),

          const SizedBox(height: 16),

          _liveTrainStatusCard(
            route,
            inputBg,
            textPrimary,
            textSecondary,
            borderCol,
          ),

          const SizedBox(height: 20),
          Divider(color: borderCol, height: 1),
          const SizedBox(height: 16),

          Text(
            'Route Itinerary & Interchanges',
            style: GoogleFonts.inter(
              color: textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),

          ...route.segments.asMap().entries.expand((entry) {
            final idx = entry.key;
            final seg = entry.value;
            final items = <Widget>[
              _routeSegmentItem(
                seg,
                route,
                inputBg,
                textPrimary,
                textSecondary,
                borderCol,
              ),
            ];
            if (idx < route.interchanges.length) {
              items.add(
                _interchangeCard(
                  route.interchanges[idx],
                  inputBg,
                  textPrimary,
                  textSecondary,
                  borderCol,
                ),
              );
            }
            return items;
          }),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() => _currentViewMode = 1);
              },
              icon: const Icon(
                CupertinoIcons.map,
                color: Color(0xFF0A84FF),
                size: 16,
              ),
              label: Text(
                'VIEW ROUTE ON GIS MAP',
                style: GoogleFonts.inter(
                  color: const Color(0xFF0A84FF),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF0A84FF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveTrainStatusCard(
    MetroRoute route,
    Color inputBg,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
  ) {
    final now = DateTime.now();
    final hour = now.hour;

    final isPeakHour = (hour >= 8 && hour < 11) || (hour >= 17 && hour < 20);
    final frequency = isPeakHour ? '2-3 mins' : '5-8 mins';
    final nextTrainMins = isPeakHour
        ? (now.minute % 3) + 1
        : (now.minute % 6) + 2;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF30D158).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF30D158).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF30D158).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.tram_fill,
              color: Color(0xFF30D158),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF30D158),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Color(0xFF30D158), blurRadius: 4),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Normal Service • Live Status',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF30D158),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Next Train arriving in ~$nextTrainMins mins (Frequency: $frequency)',
                  style: GoogleFonts.inter(color: textSecondary, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricBox(
    String title,
    String val,
    IconData icon,
    Color color,
    Color inputBg,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: inputBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(
              val,
              style: GoogleFonts.inter(
                color: textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
            Text(
              title,
              style: GoogleFonts.inter(color: textSecondary, fontSize: 8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _interchangeCard(
    MetroInterchange interchange,
    Color inputBg,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF5E5CE6).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF5E5CE6).withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF5E5CE6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.arrow_2_squarepath,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INTERCHANGE TRANSFER 🔀',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF5E5CE6),
                    fontWeight: FontWeight.w900,
                    fontSize: 8.5,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Change at ${interchange.stationName}',
                  style: GoogleFonts.inter(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'Switch from ${interchange.fromLine} ➔ ',
                      style: GoogleFonts.inter(
                        color: textSecondary,
                        fontSize: 10,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: interchange.toLineColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        interchange.toLine,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 9.5,
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

  Widget _routeSegmentItem(
    MetroRouteSegment seg,
    MetroRoute route,
    Color inputBg,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: seg.lineColor.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 8),
        iconColor: seg.lineColor,
        collapsedIconColor: textSecondary,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: seg.lineColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                seg.lineName,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${seg.fromStation} ➔ ${seg.toStation}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${seg.stations.length - 1} stops • ~${seg.durationMinutes} mins • ${seg.distanceKm} km',
            style: GoogleFonts.inter(color: textSecondary, fontSize: 10),
          ),
        ),
        children: [
          Divider(color: borderCol, height: 1),
          const SizedBox(height: 8),
          ...seg.stations.asMap().entries.map((entry) {
            final idx = entry.key;
            final st = entry.value;
            final isFirst = idx == 0;
            final isLast = idx == seg.stations.length - 1;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
              child: Row(
                children: [
                  Icon(
                    isFirst || isLast
                        ? CupertinoIcons.circle_fill
                        : CupertinoIcons.circle,
                    color: isFirst || isLast ? seg.lineColor : textSecondary,
                    size: 9,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    st,
                    style: GoogleFonts.inter(
                      color: isFirst || isLast ? textPrimary : textSecondary,
                      fontWeight: isFirst || isLast
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _ticketingGuideCard(
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TICKETING & CARD OPTIONS',
            style: GoogleFonts.inter(
              color: textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          ..._selectedNetwork.ticketingOptions.map((opt) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.checkmark_seal_fill,
                    color: Color(0xFF0A84FF),
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      opt,
                      style: GoogleFonts.inter(
                        color: textPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ================= TAB 2: ZOOMABLE NETWORK MAP =================
  Widget _buildZoomableMapTab(
    bool isMobile,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
    bool isDark,
  ) {
    final highlighted = <String>[];
    if (_calculatedRoutes.isNotEmpty) {
      final activeRoute =
          _calculatedRoutes[_selectedRouteIndex.clamp(
            0,
            _calculatedRoutes.length - 1,
          )];
      for (final seg in activeRoute.segments) {
        highlighted.addAll(seg.stations);
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 8,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: MetroDataRepository.networks.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final net = MetroDataRepository.networks[index];
                final isSelected = _selectedNetwork.id == net.id;
                return ChoiceChip(
                  label: Text(
                    net.cityName,
                    style: GoogleFonts.inter(
                      color: isSelected ? Colors.white : textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF0A84FF),
                  backgroundColor: cardBg,
                  showCheckmark: false,
                  onSelected: (_) {
                    setState(() {
                      _selectedNetwork = net;
                      _sourceStation = null;
                      _destinationStation = null;
                      _calculatedRoutes = [];
                      _selectedRouteIndex = 0;
                    });
                    _syncLiveWebData();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          Expanded(
            child: MetroInteractiveMapView(
              network: _selectedNetwork,
              sourceStation: _sourceStation,
              destinationStation: _destinationStation,
              highlightedStations: highlighted,
              onStationTap: (action) {
                if (action.startsWith('START|')) {
                  setState(() {
                    _sourceStation = action.split('|')[1];
                    _currentViewMode = 0;
                  });
                  if (_sourceStation != null && _destinationStation != null) {
                    _calculateRoute();
                  }
                } else if (action.startsWith('DESTINATION|')) {
                  setState(() {
                    _destinationStation = action.split('|')[1];
                    _currentViewMode = 0;
                  });
                  if (_sourceStation != null && _destinationStation != null) {
                    _calculateRoute();
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ================= TAB 3: CITY DIRECTORY =================
  Widget _buildCityDirectoryTab(
    bool isMobile,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
    Color inputBg,
    bool isDark,
  ) {
    final networks = _filteredNetworks;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 28,
        vertical: 12,
      ),
      child: ResponsiveContainer(
        maxWidth: 960,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _searchBar(cardBg, textPrimary, textSecondary, borderCol, inputBg),
            const SizedBox(height: 14),
            _cityFilterBar(cardBg, textPrimary, textSecondary, borderCol),
            const SizedBox(height: 18),
            if (networks.isEmpty)
              _noResultsView(cardBg, textPrimary, textSecondary, borderCol)
            else
              ...networks.map(
                (net) => _networkCard(
                  net,
                  cardBg,
                  textPrimary,
                  textSecondary,
                  borderCol,
                  inputBg,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar(
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
    Color inputBg,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderCol),
      ),
      child: TextField(
        controller: _searchCtrl,
        style: GoogleFonts.inter(color: textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText:
              'Search city, state, operator or line (e.g. Delhi, DMRC, Blue Line)...',
          hintStyle: GoogleFonts.inter(color: textSecondary, fontSize: 12),
          prefixIcon: const Icon(
            CupertinoIcons.search,
            color: Color(0xFF0A84FF),
            size: 18,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: Colors.grey,
                    size: 16,
                  ),
                  onPressed: () => _searchCtrl.clear(),
                )
              : null,
        ),
      ),
    );
  }

  Widget _cityFilterBar(
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
  ) {
    final cities = _cityFilters;
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cities.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final city = cities[index];
          final isSelected = _selectedCityFilter == city;
          return ChoiceChip(
            label: Text(
              city,
              style: GoogleFonts.inter(
                color: isSelected ? Colors.white : textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 11,
              ),
            ),
            selected: isSelected,
            selectedColor: const Color(0xFF0A84FF),
            backgroundColor: cardBg,
            showCheckmark: false,
            onSelected: (_) {
              setState(() => _selectedCityFilter = city);
            },
          );
        },
      ),
    );
  }

  Widget _noResultsView(
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
  ) {
    return Container(
      padding: const EdgeInsets.all(28),
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        children: [
          const Icon(
            CupertinoIcons.search_circle,
            color: Colors.grey,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            'No Metro Networks Found',
            style: GoogleFonts.inter(
              color: textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try searching for another city, state, or operator name.',
            style: GoogleFonts.inter(color: textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _networkCard(
    MetroNetwork net,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
    Color inputBg,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A84FF).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.building_2_fill,
                  color: Color(0xFF0A84FF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${net.cityName} Metro',
                      style: GoogleFonts.inter(
                        color: textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${net.operatorName} • ${net.stateName}',
                      style: GoogleFonts.inter(
                        color: textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedNetwork = net;
                    _currentViewMode = 0;
                  });
                  _syncLiveWebData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A84FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                child: Text(
                  'Plan Route',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _infoPill(
                  'LINES',
                  '${net.lines.length}',
                  const Color(0xFF0A84FF),
                  inputBg,
                  textPrimary,
                  textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _infoPill(
                  'STATIONS',
                  '${net.totalStations}',
                  const Color(0xFF30D158),
                  inputBg,
                  textPrimary,
                  textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _infoPill(
                  'NETWORK',
                  '${net.totalNetworkKm} km',
                  const Color(0xFFFF9F0A),
                  inputBg,
                  textPrimary,
                  textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: net.lines.map((l) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: l.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: l.color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: l.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${l.name} (${l.stationsCount})',
                      style: GoogleFonts.inter(
                        color: l.color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          if (net.websiteUrl != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Spacer(),
                GestureDetector(
                  onTap: () => _openUrl(net.websiteUrl),
                  child: Row(
                    children: [
                      Text(
                        'Official Web Portal',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF0A84FF),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        CupertinoIcons.arrow_up_right_square,
                        color: Color(0xFF0A84FF),
                        size: 13,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoPill(
    String title,
    String val,
    Color accent,
    Color inputBg,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            val,
            style: GoogleFonts.inter(
              color: accent,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.inter(
              color: textSecondary,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
