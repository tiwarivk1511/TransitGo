import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/cache/offline_cache.dart';
import '../../core/theme/theme_controller.dart';
import '../../data/sources/railradar_source.dart';

class TrainNumberAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final ValueChanged<Map<String, String>>? onTrainSelected;

  const TrainNumberAutocomplete({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.onTrainSelected,
  });

  @override
  State<TrainNumberAutocomplete> createState() =>
      _TrainNumberAutocompleteState();
}

class _TrainNumberAutocompleteState extends State<TrainNumberAutocomplete> {
  List<Map<String, dynamic>> _items = [];
  Timer? _debounce;
  int _reqSeq = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), _search);
  }

  String _extractStation(Map<String, dynamic> item, List<String> possibleKeys) {
    for (final key in possibleKeys) {
      if (item.containsKey(key) &&
          item[key] != null &&
          item[key].toString().trim().isNotEmpty) {
        return item[key].toString().trim();
      }
    }
    return '';
  }

  Future<void> _search() async {
    final q = widget.controller.text.trim();
    final seq = ++_reqSeq;

    if (q.contains(' - ')) {
      if (_items.isNotEmpty || _loading) {
        setState(() {
          _items = [];
          _loading = false;
        });
      }
      return;
    }

    if (q.length < 2) {
      if (mounted) {
        setState(() {
          _items = [];
          _loading = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _loading = true);

    final seen = <String>{};
    final merged = <Map<String, dynamic>>[];

    // 1. Direct Single Train Name Lookup using RailRadarSource.fetchSingleTrainName(cleanNo)
    final digits = q.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 2) {
      final single = await RailRadarSource.fetchSingleTrainName(digits);
      final no = (single['number'] ?? single['train_number'] ?? digits).toString().trim();
      final name = (single['name'] ?? '').toString().trim();
      if (no.isNotEmpty && name.isNotEmpty && !name.startsWith('Train ')) {
        if (seen.add(no)) {
          merged.add({
            'number': no,
            'name': name,
            'source': single['source'] ?? '',
            'destination': single['destination'] ?? '',
          });
        }
      }
    }

    // 2. Open Web Search & Candidate Lookup
    final remote = await RailRadarSource.searchTrains(q, limit: 10);
    final recents = await OfflineCache.getRecentTrains(limit: 30);

    for (final raw in remote) {
      final no = (raw['number'] ?? raw['train_number'] ?? raw['train_no'] ?? '')
          .toString()
          .trim();
      if (no.isEmpty || !seen.add(no)) continue;

      final nameRaw = (raw['name'] ?? raw['trainName'] ?? raw['train_name'] ?? '').toString().trim();
      final name = (nameRaw.isNotEmpty && !nameRaw.startsWith('Train ')) ? nameRaw : 'Train $no';

      final src = _extractStation(raw, [
        'source',
        'sourceName',
        'src',
        'source_station_name',
        'src_stn_name',
        'from_station_name',
        'from'
      ]);
      final dst = _extractStation(raw, [
        'destination',
        'dst',
        'dest',
        'destName',
        'destination_station_name',
        'to_station_name',
        'destination_code'
      ]);

      merged.add({
        'number': no,
        'name': name,
        'source': src,
        'destination': dst,
      });
      if (merged.length >= 10) break;
    }

    for (final raw in recents) {
      if (merged.length >= 10) break;
      final no = (raw['trainNumber'] ?? raw['number'] ?? raw['train_number'] ?? '').toString().trim();
      final name = (raw['trainName'] ?? raw['name'] ?? raw['train_name'] ?? '').toString().trim();
      if (no.isNotEmpty && (no.toLowerCase().contains(q.toLowerCase()) || name.toLowerCase().contains(q.toLowerCase()))) {
        if (seen.add(no)) {
          merged.add({
            'number': no,
            'name': (name.isNotEmpty && !name.startsWith('Train ')) ? name : 'Train $no',
            'source': (raw['source'] ?? '').toString(),
            'destination': (raw['destination'] ?? '').toString(),
          });
        }
      }
    }

    if (!mounted || seq != _reqSeq) return;
    setState(() {
      _items = merged;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDarkMode;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? Colors.white54 : const Color(0xFF8E8E93);
    final cardBg = isDark ? const Color(0xFF09090C) : const Color(0xFFF8F9FA);
    final popupBg = isDark ? const Color(0xFF16161C) : const Color(0xFFFFFFFF);
    final borderCol = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E5EA);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Input Field
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderCol,
              width: 1.2,
            ),
          ),
          child: TextField(
            controller: widget.controller,
            keyboardType: TextInputType.text,
            style: GoogleFonts.inter(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: GoogleFonts.inter(
                color: textSecondary.withValues(alpha: 0.5),
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Icon(widget.icon, color: const Color(0xFF0A84FF), size: 20),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
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
                          icon: Icon(Icons.clear, color: textSecondary, size: 18),
                          onPressed: () {
                            widget.controller.clear();
                            setState(() => _items = []);
                          },
                        )
                      : null),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),

        // Dropdown Suggestions Card with Real-Time Name Resolution
        if (_items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 250),
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
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    thickness: 0.5,
                    color: borderCol,
                  ),
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    return _TrainAutocompleteTile(
                      item: item,
                      isDark: isDark,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      onTap: (trainNo, name, src, dst) {
                        widget.controller.text = '$trainNo - $name';
                        if (widget.onTrainSelected != null) {
                          widget.onTrainSelected!({
                            'number': trainNo,
                            'name': name,
                            'source': src,
                            'destination': dst,
                          });
                        }
                        setState(() => _items = []);
                      },
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

// ═══════════════════════════════════════════════════════════════════════
// AUTOCOMPLETE TILE WITH ON-THE-FLY OFFICIAL TRAIN NAME RESOLUTION
// ═══════════════════════════════════════════════════════════════════════
class _TrainAutocompleteTile extends StatefulWidget {
  final Map<String, dynamic> item;
  final Function(String trainNo, String name, String src, String dst) onTap;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;

  const _TrainAutocompleteTile({
    required this.item,
    required this.onTap,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  State<_TrainAutocompleteTile> createState() => _TrainAutocompleteTileState();
}

class _TrainAutocompleteTileState extends State<_TrainAutocompleteTile> {
  static final Map<String, String> _resolvedNameCache = {};
  String? _displayName;

  @override
  void initState() {
    super.initState();
    _checkAndResolve();
  }

  @override
  void didUpdateWidget(_TrainAutocompleteTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkAndResolve();
  }

  void _checkAndResolve() {
    final cleanNo = (widget.item['number'] ?? '').toString().trim();
    final name = (widget.item['name'] ?? '').toString().trim();

    if (_resolvedNameCache.containsKey(cleanNo)) {
      _displayName = _resolvedNameCache[cleanNo];
      return;
    }

    if (name.isNotEmpty && !name.startsWith('Train ') && name != 'Express') {
      _displayName = name;
      _resolvedNameCache[cleanNo] = name;
      return;
    }

    _displayName = name.isNotEmpty ? name : 'Train $cleanNo';

    if (cleanNo.isNotEmpty) {
      RailRadarSource.fetchTrainName(cleanNo).then((info) {
        final realName = info['name']?.toString().trim() ?? '';
        final src = info['source']?.toString().trim() ?? '';
        final dst = info['destination']?.toString().trim() ?? '';

        if (realName.isNotEmpty && !realName.startsWith('Train ') && mounted) {
          _resolvedNameCache[cleanNo] = realName;
          widget.item['name'] = realName;
          if (src.isNotEmpty) widget.item['source'] = src;
          if (dst.isNotEmpty) widget.item['destination'] = dst;
          setState(() => _displayName = realName);
        }
      }).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final num = (widget.item['number'] ?? '').toString().trim();
    final name = _displayName ?? (widget.item['name'] ?? '').toString().trim();
    final src = (widget.item['source'] ?? '').toString().trim();
    final dst = (widget.item['destination'] ?? '').toString().trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onTap(num, name, src, dst),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A84FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  num,
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
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: widget.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (src.isNotEmpty || dst.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${src.isNotEmpty ? src : '—'} ➔ ${dst.isNotEmpty ? dst : '—'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: widget.textSecondary,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
