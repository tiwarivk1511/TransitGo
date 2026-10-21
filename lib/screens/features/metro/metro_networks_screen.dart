import 'dart:async';
import 'dart:core';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../components/common/modern_background.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../data/models/metro_network.dart';
import '../../../services/analytics_service.dart';
import '../../../services/metro_api_service.dart';
import '../../../services/remote_config_service.dart';
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
  String? _sourceSlug;
  String? _destinationStation;
  String? _destinationSlug;

  List<MetroRoute> _calculatedRoutes = [];

  bool _isCalculatingRoute = false;
  String? _routeError;
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
      await RemoteConfigService.refresh();

      final liveNet = await MetroApiService.fetchDynamicTrackMyMetroNetwork(
        _selectedNetwork,
      );

      unawaited(MetroApiService.syncAllCitiesMetroStations());

      if (mounted) {
        setState(() {
          _selectedNetwork = liveNet;
          _isSyncingWebData = false;
          _lastSyncStatus =
              '🟢 Live Metro Active (${liveNet.allStations.length} Stations • ${liveNet.lines.length} Lines)';

          if (_sourceStation != null && _destinationStation != null) {
            _calculateRoute();
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSyncingWebData = false;
          _lastSyncStatus = '🟢 Live Metro Connected';
        });
      }
    }
  }

  void _calculateRoute() async {
    if (_sourceStation == null || _destinationStation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _sourceStation == null && _destinationStation == null
                ? 'Please select both start and destination stations.'
                : (_sourceStation == null
                    ? 'Please select a start station (From).'
                    : 'Please select a destination station (To).'),
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFFFF375F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (_sourceStation == _destinationStation) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Start and destination station cannot be the same.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFFFF9F0A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() {
      _isCalculatingRoute = true;
      _routeError = null;
    });

    AnalyticsService.logMetroSearch(
      cityName: _selectedNetwork.cityName,
      source: _sourceStation!,
      destination: _destinationStation!,
    );

    try {
      final yoRoutes = await MetroApiService.fetchYoMetroApiRoutes(
        network: _selectedNetwork,
        sourceStation: _sourceStation!,
        destinationStation: _destinationStation!,
        sourceSlug: _sourceSlug,
        destinationSlug: _destinationSlug,
      );

      if (yoRoutes.isNotEmpty && mounted) {
        setState(() {
          _calculatedRoutes = yoRoutes;
          _selectedRouteIndex = 0;
          _isCalculatingRoute = false;
        });
        return;
      }

      final routes = MetroRouteCalculator.findRoutes(
        _selectedNetwork,
        _sourceStation!,
        _destinationStation!,
      );

      if (mounted) {
        setState(() {
          _calculatedRoutes = routes;
          _selectedRouteIndex = 0;
          _isCalculatingRoute = false;
          if (routes.isEmpty) {
            _routeError =
                'No direct or connecting route found between $_sourceStation and $_destinationStation.';
          }
        });
      }
    } catch (e) {
      debugPrint('[MetroRouteCalculator] Route search exception: $e');
      if (mounted) {
        setState(() {
          _calculatedRoutes = [];
          _selectedRouteIndex = 0;
          _isCalculatingRoute = false;
          _routeError =
              'Unable to calculate route. Please check network connection.';
        });
      }
    }
  }

  void _swapStations() {
    setState(() {
      final tempSt = _sourceStation;
      final tempSl = _sourceSlug;
      _sourceStation = _destinationStation;
      _sourceSlug = _destinationSlug;
      _destinationStation = tempSt;
      _destinationSlug = tempSl;
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

  void _openStationPicker({required bool isSource}) async {
    final isDark = ThemeController.instance.isDarkMode;
    final cardBg = isDark ? const Color(0xFF16161C) : const Color(0xFFFFFFFF);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? Colors.white54 : const Color(0xFF636366);
    final borderCol = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE5E5EA);
    final inputBg = isDark ? const Color(0xFF09090C) : const Color(0xFFF2F2F7);

    final zoneId = MetroApiService.yoMetroZoneIds[_selectedNetwork.id.toLowerCase()];
    List<Map<String, String>> stationItems = [];

    if (zoneId != null) {
      final yoStns = await MetroApiService.fetchYoMetroStations(zoneId);
      for (final item in yoStns) {
        final name = (item['name'] ?? '').toString().trim();
        final slug = (item['slug'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          stationItems.add({
            'name': name,
            'slug': slug.isNotEmpty
                ? slug
                : MetroApiService.formatYoMetroStationSlug(
                    name,
                    _selectedNetwork.cityName,
                  ),
          });
        }
      }
    }

    if (stationItems.isEmpty) {
      final cityCode =
          MetroApiService.trackMyMetroCityCodes[_selectedNetwork.id
              .toLowerCase()] ??
          'del';
      final trackMyStns = await MetroApiService.fetchTrackMyMetroStations(
        cityCode,
      );

      for (final item in trackMyStns) {
        final name = (item['name'] ?? '').toString().trim();
        final slug = (item['slug'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          stationItems.add({
            'name': name,
            'slug': slug.isNotEmpty
                ? slug
                : MetroApiService.formatYoMetroStationSlug(
                    name,
                    _selectedNetwork.cityName,
                  ),
          });
        }
      }
    }

    if (stationItems.isEmpty) {
      for (final name in _selectedNetwork.allStations) {
        stationItems.add({
          'name': name,
          'slug': MetroApiService.formatYoMetroStationSlug(
            name,
            _selectedNetwork.cityName,
          ),
        });
      }
    }

    String search = '';
    if (!mounted) return;

    final selectedItem = await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = stationItems
                .where(
                  (s) => s['name']!.toLowerCase().contains(
                    search.toLowerCase(),
                  ),
                )
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
                                final stObj = filtered[idx];
                                final stName = stObj['name']!;
                                final isSelected = isSource
                                    ? stName == _sourceStation
                                    : stName == _destinationStation;

                                final passingLines = _selectedNetwork.lines
                                    .where((l) => l.stations.contains(stName))
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
                                    stName,
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
                                  onTap: () => Navigator.pop(ctx, stObj),
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

    if (selectedItem != null && mounted) {
      setState(() {
        if (isSource) {
          _sourceStation = selectedItem['name'];
          _sourceSlug = selectedItem['slug'];
        } else {
          _destinationStation = selectedItem['name'];
          _destinationSlug = selectedItem['slug'];
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
            if (_isCalculatingRoute)
              _loadingRouteSkeleton(cardBg, borderCol)
            else if (_calculatedRoutes.isNotEmpty)
              _routeResultCard(
                _calculatedRoutes.first,
                cardBg,
                textPrimary,
                textSecondary,
                borderCol,
                inputBg,
              )
            else if (_routeError != null)
              _errorRouteCard(
                _routeError!,
                cardBg,
                textPrimary,
                textSecondary,
                borderCol,
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

  Widget _loadingRouteSkeleton(Color cardBg, Color borderCol) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF0A84FF),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Finding optimal metro route & line transfers...',
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorRouteCard(
    String message,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFFF375F).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF375F).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              color: Color(0xFFFF375F),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
                          _sourceSlug = null;
                          _destinationStation = null;
                          _destinationSlug = null;
                          _calculatedRoutes = [];
                          _selectedRouteIndex = 0;
                          _routeError = null;
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
              onPressed: _isCalculatingRoute ? null : _calculateRoute,
              icon: _isCalculatingRoute
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      CupertinoIcons.alt,
                      color: Colors.white,
                      size: 16,
                    ),
              label: Text(
                _isCalculatingRoute
                    ? 'CALCULATING ROUTE...'
                    : 'SHOW METRO ROUTE & FARE',
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

          // Journey Summary Grid (Fare, Time, Stations, Interchanges)
          Row(
            children: [
              Expanded(
                child: _summaryStatPill(
                  icon: CupertinoIcons.ticket_fill,
                  label: 'EST. FARE',
                  value: '₹${route.estimatedFare}',
                  color: const Color(0xFF30D158),
                  inputBg: inputBg,
                  borderCol: borderCol,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryStatPill(
                  icon: CupertinoIcons.clock_fill,
                  label: 'TIME',
                  value: '${route.totalDurationMinutes} min',
                  color: const Color(0xFF0A84FF),
                  inputBg: inputBg,
                  borderCol: borderCol,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryStatPill(
                  icon: CupertinoIcons.tram_fill,
                  label: 'STATIONS',
                  value: '${route.totalStations}',
                  color: const Color(0xFFFF9F0A),
                  inputBg: inputBg,
                  borderCol: borderCol,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryStatPill(
                  icon: CupertinoIcons.arrow_2_squarepath,
                  label: 'SWITCHES',
                  value: '${route.interchanges.length}',
                  color: const Color(0xFFBF5AF2),
                  inputBg: inputBg,
                  borderCol: borderCol,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Divider(color: borderCol, height: 1),
          const SizedBox(height: 16),

          Text(
            'STATION BY STATION JOURNEY ROUTE',
            style: GoogleFonts.inter(
              color: textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),

          // Render Route Segments
          ...route.segments.asMap().entries.map((entry) {
            final idx = entry.key;
            final seg = entry.value;
            final isLast = idx == route.segments.length - 1;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Line Segment Header Banner
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: seg.lineColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: seg.lineColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: seg.lineColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          seg.lineName,
                          style: GoogleFonts.inter(
                            color: seg.lineColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      Text(
                        '${seg.stations.length} Stops • ${seg.durationMinutes}m',
                        style: GoogleFonts.inter(
                          color: textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Station List on this Line
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Column(
                    children: seg.stations.asMap().entries.map((stEntry) {
                      final stIdx = stEntry.key;
                      final stName = stEntry.value;
                      final isFirstSt = stIdx == 0;
                      final isLastSt = stIdx == seg.stations.length - 1;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: (isFirstSt || isLastSt)
                                    ? seg.lineColor
                                    : textSecondary.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                stName,
                                style: GoogleFonts.inter(
                                  color: (isFirstSt || isLastSt)
                                      ? textPrimary
                                      : textSecondary,
                                  fontWeight: (isFirstSt || isLastSt)
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  fontSize: (isFirstSt || isLastSt) ? 13 : 11.5,
                                ),
                              ),
                            ),
                            if (isFirstSt && idx == 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF30D158,
                                  ).withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'BOARD 🟢',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF30D158),
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              )
                            else if (isLastSt && isLast)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFFF375F,
                                  ).withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'EXIT 🏁',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFFF375F),
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Interchange Transfer Card
                if (!isLast && idx < route.interchanges.length) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9F0A).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFFF9F0A).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.arrow_2_squarepath,
                          color: Color(0xFFFF9F0A),
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'LINE INTERCHANGE AT ${route.interchanges[idx].stationName.toUpperCase()}',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFFF9F0A),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Switch from ${route.interchanges[idx].fromLine} ➔ ${route.interchanges[idx].toLine}',
                                style: GoogleFonts.inter(
                                  color: textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _summaryStatPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color inputBg,
    required Color borderCol,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.grey,
              fontSize: 7.5,
              fontWeight: FontWeight.w900,
            ),
          ),
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
    final net = _selectedNetwork;

    return Container(
      padding: const EdgeInsets.all(20),
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
              const Icon(
                CupertinoIcons.qrcode,
                color: Color(0xFF0A84FF),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'TICKETING & SMART CARD OPTIONS',
                style: GoogleFonts.inter(
                  color: textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...net.ticketingOptions.map((opt) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.checkmark_alt_circle_fill,
                    color: Color(0xFF30D158),
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      opt,
                      style: GoogleFonts.inter(
                        color: textSecondary,
                        fontSize: 12,
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

  // ================= TAB 2: GIS MAP =================
  Widget _buildZoomableMapTab(
    bool isMobile,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
    bool isDark,
  ) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: MetroInteractiveMapView(
                network: _selectedNetwork,
                sourceStation: _sourceStation,
                destinationStation: _destinationStation,
              ),
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
    final filtered = _filteredNetworks;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 28,
        vertical: 12,
      ),
      child: ResponsiveContainer(
        maxWidth: 1100,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input Field
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderCol),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: GoogleFonts.inter(color: textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search city, line color, or metro station...',
                  hintStyle: GoogleFonts.inter(
                    color: textSecondary,
                    fontSize: 12,
                  ),
                  prefixIcon: const Icon(
                    CupertinoIcons.search,
                    color: Color(0xFF0A84FF),
                    size: 18,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            CupertinoIcons.clear_circled_solid,
                            size: 16,
                            color: Colors.grey,
                          ),
                          onPressed: () => _searchCtrl.clear(),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Filter City Chips Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _cityFilters.map((city) {
                  final isSelected = _selectedCityFilter == city;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(city),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _selectedCityFilter = city);
                      },
                      selectedColor: const Color(0xFF0A84FF),
                      backgroundColor: cardBg,
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF0A84FF)
                            : borderCol,
                      ),
                      labelStyle: GoogleFonts.inter(
                        color: isSelected ? Colors.white : textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 18),

            // Networks Grid
            filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(
                            CupertinoIcons.building_2_fill,
                            color: textSecondary,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No metro networks found for "$_searchQuery"',
                            style: GoogleFonts.inter(
                              color: textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (ctx, idx) {
                      final net = filtered[idx];
                      return _CityNetworkCardWidget(
                        baseNetwork: net,
                        cardBg: cardBg,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        borderCol: borderCol,
                        inputBg: inputBg,
                        isDark: isDark,
                        onPlanRouteTap: (selectedNet) {
                          setState(() {
                            _selectedNetwork = selectedNet;
                            _currentViewMode = 0;
                          });
                          _syncLiveWebData();
                        },
                      );
                    },
                  ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _CityNetworkCardWidget extends StatefulWidget {
  final MetroNetwork baseNetwork;
  final Function(MetroNetwork selected) onPlanRouteTap;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color borderCol;
  final Color inputBg;
  final bool isDark;

  const _CityNetworkCardWidget({
    required this.baseNetwork,
    required this.onPlanRouteTap,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.borderCol,
    required this.inputBg,
    required this.isDark,
  });

  @override
  State<_CityNetworkCardWidget> createState() => _CityNetworkCardWidgetState();
}

class _CityNetworkCardWidgetState extends State<_CityNetworkCardWidget> {
  late MetroNetwork _liveNetwork;
  bool _loadingLive = false;
  String? _expandedLineName;

  @override
  void initState() {
    super.initState();
    _liveNetwork = widget.baseNetwork;
    _fetchLive();
  }

  void _fetchLive() async {
    setState(() => _loadingLive = true);
    try {
      final live = await MetroApiService.fetchDynamicTrackMyMetroNetwork(widget.baseNetwork);
      if (mounted) {
        setState(() {
          _liveNetwork = live;
          _loadingLive = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLive = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final net = _liveNetwork;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: widget.borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Metro Network Branding Logo Badge
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: net.primaryBrandColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: net.primaryBrandColor.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: net.primaryBrandColor.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.network(
                    net.defaultLogoUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.tram_fill,
                              color: net.primaryBrandColor,
                              size: 16,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              net.operatorCode,
                              style: GoogleFonts.inter(
                                color: net.primaryBrandColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 8,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Text(
                          '${net.cityName} Metro',
                          style: GoogleFonts.inter(
                            color: widget.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (_loadingLive)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF0A84FF)),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF30D158).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'LIVE 🟢',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF30D158),
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '${net.operatorName} • ${net.stateName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: widget.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => widget.onPlanRouteTap(net),
                icon: const Icon(CupertinoIcons.alt, size: 14),
                label: Text(
                  'Plan Route',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A84FF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Live Stats Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _infoChip(
                '${net.totalStations} Operational Stations',
                CupertinoIcons.tram_fill,
                widget.inputBg,
                widget.textSecondary,
                widget.borderCol,
              ),
              _infoChip(
                '${net.totalNetworkKm} km Network',
                CupertinoIcons.map,
                widget.inputBg,
                widget.textSecondary,
                widget.borderCol,
              ),
              _infoChip(
                '${net.lines.length} Active Lines',
                CupertinoIcons.color_filter,
                widget.inputBg,
                widget.textSecondary,
                widget.borderCol,
              ),
              _infoChip(
                net.fareRange,
                CupertinoIcons.ticket_fill,
                widget.inputBg,
                widget.textSecondary,
                widget.borderCol,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Live Lines & Stations Breakdown
          Text(
            'LIVE OPERATIONAL METRO LINES (${net.lines.length}):',
            style: GoogleFonts.inter(
              color: widget.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),

          ...net.lines.map((line) {
            final isExpanded = _expandedLineName == line.name;

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: widget.inputBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: widget.borderCol),
              ),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _expandedLineName = isExpanded ? null : line.name;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: line.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  line.name,
                                  style: GoogleFonts.inter(
                                    color: widget.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  line.route,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: widget.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${line.stationsCount} stns',
                            style: GoogleFonts.inter(
                              color: widget.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            isExpanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                            size: 12,
                            color: const Color(0xFF0A84FF),
                          ),
                        ],
                      ),

                      if (isExpanded && line.stations.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Divider(color: widget.borderCol, height: 1),
                        const SizedBox(height: 8),
                        Text(
                          'STATIONS ON THIS LINE:',
                          style: GoogleFonts.inter(
                            color: widget.textSecondary,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: line.stations.map((st) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: line.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: line.color.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                st,
                                style: GoogleFonts.inter(
                                  color: widget.textPrimary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _infoChip(
    String label,
    IconData icon,
    Color inputBg,
    Color textSecondary,
    Color borderCol,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF0A84FF)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
