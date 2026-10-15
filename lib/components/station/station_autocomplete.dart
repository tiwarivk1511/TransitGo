import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/cache/offline_cache.dart';
import '../../core/theme/theme_controller.dart';
import '../../data/models/station.dart';
import '../../data/sources/railradar_source.dart';
import '../../data/sources/station_source.dart';
import '../../services/station_service.dart';

class StationAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final ValueChanged<Station> onStationSelected;
  final VoidCallback? onCleared;
  final bool autofocus;

  const StationAutocomplete({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.onStationSelected,
    this.onCleared,
    this.autofocus = false,
  });

  @override
  State<StationAutocomplete> createState() => _StationAutocompleteState();
}

class _StationAutocompleteState extends State<StationAutocomplete> {
  List<Station> _suggestions = [];
  Timer? _debounce;
  int _reqSeq = 0;
  bool _remoteLoading = false;

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _hideOverlay();
    _debounce?.cancel();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final text = widget.controller.text;
    if (text.contains('(') && text.contains(')')) {
      if (_suggestions.isNotEmpty) {
        _updateSuggestions([]);
      }
    }
  }

  void _showOverlay() {
    _hideOverlay();
    if (!mounted || _suggestions.isEmpty) return;

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? Size.zero;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final isDark = ThemeController.instance.isDarkMode;
        final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
        final textSecondary = isDark ? Colors.white54 : const Color(0xFF8E8E93);
        final popupBg = isDark ? const Color(0xFF16161C) : const Color(0xFFFFFFFF);
        final borderCol = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E5EA);

        return Positioned(
          width: size.width > 0 ? size.width : null,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, size.height + 6),
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 260),
                  decoration: BoxDecoration(
                    color: popupBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: borderCol,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      thickness: 0.5,
                      color: borderCol,
                    ),
                    itemBuilder: (_, i) {
                      final s = _suggestions[i];
                      return InkWell(
                        splashColor: const Color(0xFF0A84FF).withValues(alpha: 0.15),
                        onTap: () {
                          widget.onStationSelected(s);
                          _updateSuggestions([]);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0A84FF).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  s.code,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF0A84FF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        color: textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_outlined,
                                          size: 12,
                                          color: textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            _buildLocationSubtitle(s),
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              color: textSecondary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
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
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _updateSuggestions(List<Station> list) {
    if (!mounted) return;
    setState(() {
      _suggestions = list;
    });
    if (_suggestions.isNotEmpty) {
      _showOverlay();
    } else {
      _hideOverlay();
    }
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    final q = query.trim();

    if (q.length < 2 || q.contains('(')) {
      if (_suggestions.isNotEmpty) {
        _updateSuggestions([]);
      }
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 220), () => _search(q));
  }

  static final Map<String, List<Station>> _stationMemoryCache = {};

  Future<void> _search(String q) async {
    final seq = ++_reqSeq;

    final cacheKey = q.toLowerCase();
    if (_stationMemoryCache.containsKey(cacheKey)) {
      if (mounted) {
        _updateSuggestions(_stationMemoryCache[cacheKey]!);
        setState(() => _remoteLoading = false);
      }
      return;
    }

    final local = await StationService.search(q);
    if (!mounted || seq != _reqSeq) return;
    if (local.isNotEmpty && local.every(_hasAreaMetadata)) {
      if (_stationMemoryCache.length > 100) _stationMemoryCache.clear();
      _stationMemoryCache[cacheKey] = local;
      _updateSuggestions(local);
      setState(() => _remoteLoading = false);
      return;
    }

    if (local.isNotEmpty) {
      _updateSuggestions(local);
      setState(() => _remoteLoading = true);
    } else {
      setState(() => _remoteLoading = true);
    }

    final offlineCacheKey = 'station_search_${q.toLowerCase()}';
    final cached = await OfflineCache.get(offlineCacheKey);
    final remote = cached is List
        ? cached
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : await RailRadarSource.searchStations(q, limit: 10);
    if (!mounted || seq != _reqSeq) return;

    final remoteStations = remote
        .map((e) => Station.fromJson(e))
        .where((s) => s.code.isNotEmpty && s.name.isNotEmpty)
        .toList();
    if (cached == null && remoteStations.isNotEmpty) {
      await OfflineCache.put(
        offlineCacheKey,
        remoteStations.map((station) => station.toJson()).toList(),
        ttl: const Duration(days: 30),
      );
    }
    await StationSource.cacheStations(remoteStations);
    final localCodes = local
        .map((station) => station.code.toUpperCase())
        .toSet();
    final merged = <Station>[
      ...local,
      ...remoteStations.where(
        (station) => !localCodes.contains(station.code.toUpperCase()),
      ),
    ];

    if (!mounted || seq != _reqSeq) return;
    final finalResult = merged.take(8).toList();
    if (finalResult.isNotEmpty) {
      if (_stationMemoryCache.length > 100) _stationMemoryCache.clear();
      _stationMemoryCache[cacheKey] = finalResult;
    }
    _updateSuggestions(finalResult);
    setState(() => _remoteLoading = false);
  }

  bool _hasAreaMetadata(Station s) {
    return (s.district != null && s.district!.isNotEmpty) ||
        (s.state != null && s.state!.isNotEmpty);
  }

  String _buildLocationSubtitle(Station s) {
    final parts = <String>[];
    if (s.district != null && s.district!.isNotEmpty) {
      parts.add('District: ${s.district}');
    } else if (s.city != null && s.city!.isNotEmpty) {
      parts.add(s.city!);
    }
    if (s.state != null && s.state!.isNotEmpty) parts.add(s.state!);
    if (parts.isEmpty) {
      if (s.zone != null && s.zone!.isNotEmpty) parts.add('Zone: ${s.zone}');
    }
    return parts.isNotEmpty ? parts.join(', ') : 'Indian Railways';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDarkMode;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? Colors.white54 : const Color(0xFF8E8E93);

    return CompositedTransformTarget(
      link: _layerLink,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0A84FF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.icon,
              color: const Color(0xFF0A84FF),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: widget.controller,
              onChanged: _onQueryChanged,
              autofocus: widget.autofocus,
              style: GoogleFonts.inter(
                color: textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                labelText: widget.label,
                labelStyle: GoogleFonts.inter(
                  color: const Color(0xFF0A84FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                hintText: widget.hint,
                hintStyle: GoogleFonts.inter(
                  color: textSecondary.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                contentPadding: EdgeInsets.zero,
                suffixIcon: _remoteLoading
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0A84FF),
                          ),
                        ),
                      )
                    : (widget.controller.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: textSecondary,
                                size: 18,
                              ),
                              onPressed: () {
                                widget.controller.clear();
                                _updateSuggestions([]);
                                if (widget.onCleared != null) {
                                  widget.onCleared!();
                                }
                              },
                            )
                          : null),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
