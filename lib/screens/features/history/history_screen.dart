import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../components/common/feature_intro.dart';
import '../../../core/cache/offline_cache.dart';
import '../../../core/theme/theme_controller.dart';
import '../../train_details/train_details_screen.dart';
import '../../train_search/train_search_screen.dart';
import '../alerts/alerts_screen.dart';
import '../coach/coach_screen.dart';
import '../fare/fare_screen.dart';
import '../live_traffic/live_traffic_screen.dart';
import '../pnr/pnr_screen.dart';
import '../radar/radar_screen.dart';
import '../station_info/station_info_screen.dart';

enum _HistoryFilter { all, routes, trains, pnr, coach, stations, fares }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return value == null ? null : double.tryParse(value.toString());
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _historyKinds = [
    'route_search',
    'train',
    'pnr',
    'coach',
    'fare',
    'radar',
    'traffic',
    'alerts',
    'station',
  ];

  List<Map<String, dynamic>> _items = [];
  _HistoryFilter _filter = _HistoryFilter.all;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      ..._historyKinds.map((kind) => OfflineCache.getHistory(kind)),
      OfflineCache.getHistory('search'),
    ]);
    if (!mounted) return;
    final items = results.expand((history) => history).toList()
      ..sort((a, b) => _createdAt(b).compareTo(_createdAt(a)));
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  static int _createdAt(Map<String, dynamic> item) {
    final value = item['created'];
    return value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> _dataFor(Map<String, dynamic> item) {
    final value = item['data'];
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  String _kind(Map<String, dynamic> item) =>
      item['kind']?.toString() ?? 'search';

  _HistoryFilter _category(String kind) {
    switch (kind) {
      case 'route_search':
      case 'search':
        return _HistoryFilter.routes;
      case 'train':
        return _HistoryFilter.trains;
      case 'pnr':
        return _HistoryFilter.pnr;
      case 'coach':
        return _HistoryFilter.coach;
      case 'fare':
        return _HistoryFilter.fares;
      case 'radar':
      case 'traffic':
      case 'alerts':
      case 'station':
        return _HistoryFilter.stations;
      default:
        return _HistoryFilter.all;
    }
  }

  List<Map<String, dynamic>> get _visibleItems => _items
      .where(
        (item) =>
            _filter == _HistoryFilter.all || _category(_kind(item)) == _filter,
      )
      .toList();

  Future<void> _clearHistory() async {
    if (_filter == _HistoryFilter.all) {
      await OfflineCache.clearHistory('');
      await _load();
      return;
    }
    final kinds = _historyKinds
        .where((kind) => _category(kind) == _filter)
        .toList();
    if (_filter == _HistoryFilter.routes) kinds.add('search');
    for (final kind in kinds) {
      await OfflineCache.clearHistory('', kind: kind);
    }
    await _load();
  }

  Future<void> _openItem(Map<String, dynamic> item) async {
    final data = _dataFor(item);
    final query = item['query']?.toString() ?? '';
    final label = item['label']?.toString() ?? query;
    final kind = _kind(item);
    Widget? screen;

    switch (kind) {
      case 'route_search':
        final fromCode = data['fromCode']?.toString() ?? '';
        final toCode = data['toCode']?.toString() ?? '';
        if (fromCode.isNotEmpty && toCode.isNotEmpty) {
          screen = TrainSearchScreen(
            fromCode: fromCode,
            toCode: toCode,
            fromName: data['fromName']?.toString() ?? fromCode,
            toName: data['toName']?.toString() ?? toCode,
            fromCity: data['fromCity']?.toString(),
            toCity: data['toCity']?.toString(),
            fromLatitude: _asDouble(data['fromLatitude']),
            fromLongitude: _asDouble(data['fromLongitude']),
            toLatitude: _asDouble(data['toLatitude']),
            toLongitude: _asDouble(data['toLongitude']),
            fromDistrict: data['fromDistrict']?.toString(),
            fromState: data['fromState']?.toString(),
            toDistrict: data['toDistrict']?.toString(),
            toState: data['toState']?.toString(),
          );
        }
        break;
      case 'search':
        final codes = RegExp(
          r'^([A-Za-z0-9]{2,6})\s*(?:→|->)\s*([A-Za-z0-9]{2,6})$',
        ).firstMatch(query);
        if (codes != null) {
          screen = TrainSearchScreen(
            fromCode: codes.group(1)!,
            toCode: codes.group(2)!,
            fromName: codes.group(1)!,
            toName: codes.group(2)!,
          );
        }
        break;
      case 'train':
        screen = TrainDetailsScreen(
          trainNumber: data['trainNumber']?.toString() ?? query,
          trainName: data['trainName']?.toString() ?? label,
        );
        break;
      case 'pnr':
        screen = PnrScreen(initialPnr: data['pnr']?.toString() ?? query);
        break;
      case 'coach':
        screen = CoachScreen(
          initialTrainNumber: data['trainNumber']?.toString() ?? query,
        );
        break;
      case 'fare':
        screen = FareScreen(
          initialTrainNumber: data['trainNumber']?.toString(),
          initialFromCode: data['fromCode']?.toString(),
          initialToCode: data['toCode']?.toString(),
          initialClassCode: data['classCode']?.toString(),
          initialQuotaCode: data['quotaCode']?.toString(),
        );
        break;
      case 'radar':
        screen = ScheduleScreen(
          initialStationCode: data['stationCode']?.toString() ?? query,
        );
        break;
      case 'traffic':
        screen = LiveTrafficScreen(
          initialStationCode: data['stationCode']?.toString() ?? query,
        );
        break;
      case 'alerts':
        screen = AlertsScreen(
          initialStationCode: data['stationCode']?.toString() ?? query,
        );
        break;
      case 'station':
        screen = StationInfoScreen(
          initialStationCode: data['stationCode']?.toString() ?? query,
          initialStationName: data['stationName']?.toString() ?? label,
        );
        break;
    }

    final target = screen;
    if (target == null) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => target));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleItems;
    final isDark = ThemeController.instance.isDarkMode;
    final bgColor = isDark ? const Color(0xFF09090C) : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF16161C) : const Color(0xFFFFFFFF);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? Colors.white54 : const Color(0xFF8E8E93);
    final borderCol = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E5EA);

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
          'History',
          style: GoogleFonts.inter(
            color: textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (visible.isNotEmpty)
            IconButton(
              tooltip:
                  'Clear ${_filter == _HistoryFilter.all ? 'all' : 'filtered'} history',
              icon: Icon(CupertinoIcons.trash, color: textSecondary, size: 18),
              onPressed: _clearHistory,
            ),
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
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF0A84FF)),
              )
            : ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                children: [
                  const FeatureIntro(
                    title: 'Pick up where\nyou left off.',
                    subtitle:
                        'Open recent searches again, grouped by what you need.',
                    icon: CupertinoIcons.time_solid,
                    accent: Color(0xFF0A84FF),
                  ),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _filterChip('All', _HistoryFilter.all, cardBg, textPrimary, textSecondary, borderCol),
                        _filterChip('Routes', _HistoryFilter.routes, cardBg, textPrimary, textSecondary, borderCol),
                        _filterChip('Trains', _HistoryFilter.trains, cardBg, textPrimary, textSecondary, borderCol),
                        _filterChip('PNR', _HistoryFilter.pnr, cardBg, textPrimary, textSecondary, borderCol),
                        _filterChip('Coach', _HistoryFilter.coach, cardBg, textPrimary, textSecondary, borderCol),
                        _filterChip('Stations', _HistoryFilter.stations, cardBg, textPrimary, textSecondary, borderCol),
                        _filterChip('Fares', _HistoryFilter.fares, cardBg, textPrimary, textSecondary, borderCol),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (visible.isEmpty)
                    _emptyState(cardBg, textPrimary, textSecondary, borderCol)
                  else ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 11),
                      child: Text(
                        'RECENT ACTIVITY  •  ${visible.length}',
                        style: GoogleFonts.inter(
                          color: textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    ...visible.map((item) => _historyTile(item, cardBg, textPrimary, textSecondary, borderCol)),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _filterChip(String label, _HistoryFilter filter, Color cardBg, Color textPrimary, Color textSecondary, Color borderCol) {
    final selected = _filter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = filter),
        selectedColor: const Color(0xFF0A84FF),
        backgroundColor: cardBg,
        side: BorderSide(
          color: selected
              ? const Color(0xFF0A84FF)
              : borderCol,
        ),
        labelStyle: GoogleFonts.inter(
          color: selected ? Colors.white : textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _emptyState(Color cardBg, Color textPrimary, Color textSecondary, Color borderCol) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
    decoration: BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: borderCol),
    ),
    child: Column(
      children: [
        const Icon(
          CupertinoIcons.search,
          color: Color(0xFF0A84FF),
          size: 36,
        ),
        const SizedBox(height: 12),
        Text(
          'No history recorded yet.',
          style: GoogleFonts.inter(
            color: textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Searches, live train tracking, PNR checks, and fares will appear here.',
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

  Widget _historyTile(Map<String, dynamic> item, Color cardBg, Color textPrimary, Color textSecondary, Color borderCol) {
    final query = item['query']?.toString() ?? '';
    final label = item['label']?.toString() ?? query;
    final kind = _kind(item);
    final accent = _accentFor(kind);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderCol),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openItem(item),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_iconFor(kind), color: accent, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        kind.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(CupertinoIcons.chevron_right, color: textSecondary, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _accentFor(String kind) {
    switch (kind) {
      case 'route_search':
      case 'search':
        return const Color(0xFF0A84FF);
      case 'pnr':
        return const Color(0xFFFF9F0A);
      case 'coach':
        return const Color(0xFF5E5CE6);
      case 'fare':
        return const Color(0xFF64D2FF);
      default:
        return const Color(0xFF30D158);
    }
  }

  IconData _iconFor(String kind) {
    switch (kind) {
      case 'route_search':
      case 'search':
        return CupertinoIcons.alt;
      case 'pnr':
        return CupertinoIcons.ticket_fill;
      case 'coach':
        return CupertinoIcons.square_stack_3d_up_fill;
      case 'fare':
        return CupertinoIcons.money_dollar_circle_fill;
      default:
        return CupertinoIcons.tram_fill;
    }
  }
}
