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

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final text = widget.controller.text;
    if (text.contains('(') && text.contains(')')) {
      if (_suggestions.isNotEmpty) {
        setState(() => _suggestions = []);
      }
    }
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    final q = query.trim();

    if (q.length < 2 || q.contains('(')) {
      if (_suggestions.isNotEmpty) {
        setState(() => _suggestions = []);
      }
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 220), () => _search(q));
  }

  Future<void> _search(String q) async {
    final seq = ++_reqSeq;

    final local = await StationService.search(q);
    if (!mounted || seq != _reqSeq) return;
    if (local.isNotEmpty && local.every(_hasAreaMetadata)) {
      setState(() {
        _suggestions = local;
        _remoteLoading = false;
      });
      return;
    }

    if (local.isNotEmpty) {
      setState(() {
        _suggestions = local;
        _remoteLoading = true;
      });
    } else {
      setState(() => _remoteLoading = true);
    }

    final cacheKey = 'station_search_${q.toLowerCase()}';
    final cached = await OfflineCache.get(cacheKey);
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
        cacheKey,
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
    setState(() {
      _suggestions = merged.take(8).toList();
      _remoteLoading = false;
    });
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
    final popupBg = isDark ? const Color(0xFF16161C) : const Color(0xFFFFFFFF);
    final borderCol = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E5EA);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Modern Station Input Field
        Row(
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
                                  setState(() => _suggestions = []);
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

        // Glassmorphic Overlay Dropdown Suggestions Card
        if (_suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
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
                      blurRadius: 16,
                      offset: const Offset(0, 6),
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
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        splashColor: const Color(0xFF0A84FF).withValues(alpha: 0.15),
                        onTap: () {
                          widget.onStationSelected(s);
                          setState(() => _suggestions = []);
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
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
