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

  static final Map<String, List<Map<String, dynamic>>> _searchMemoryCache = {};

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

    final cacheKey = q.toLowerCase();
    if (_searchMemoryCache.containsKey(cacheKey)) {
      if (mounted) {
        setState(() {
          _items = _searchMemoryCache[cacheKey]!;
          _loading = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _loading = true);

    final seen = <String>{};
    final merged = <Map<String, dynamic>>[];
    final qLow = q.toLowerCase();

    // 1. Direct digits lookup for train number
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

    // 2. Instant Local SQLite Train Catalog Match (Top 25 matches)
    try {
      final catalog = await OfflineCache.searchTrainCatalog(q, limit: 25);
      for (final item in catalog) {
        final no = (item['number'] ?? item['train_number'] ?? '').toString().trim();
        final name = (item['name'] ?? item['train_name'] ?? '').toString().trim();
        if (no.isNotEmpty && seen.add(no)) {
          merged.add({
            'number': no,
            'name': isValidTrainName(name) ? name : 'Train $no',
            'source': item['source'] ?? '',
            'destination': item['destination'] ?? '',
          });
        }
      }
    } catch (_) {}

    // 3. Search local recent / tracked trains (matching number OR name)
    try {
      final recent = await OfflineCache.getRecentTrains(limit: 50);
      for (final item in recent) {
        final no = (item['train_number'] ?? item['number'] ?? '').toString().trim();
        final name = (item['train_name'] ?? item['name'] ?? '').toString().trim();
        if (no.isNotEmpty && (no.toLowerCase().contains(qLow) || name.toLowerCase().contains(qLow))) {
          if (seen.add(no)) {
            merged.add({
              'number': no,
              'name': isValidTrainName(name) ? name : 'Train $no',
              'source': _extractStation(Map<String, dynamic>.from(item), ['from', 'source', 'from_station']),
              'destination': _extractStation(Map<String, dynamic>.from(item), ['to', 'destination', 'to_station']),
            });
          }
        }
      }
    } catch (_) {}

    // 4. Search saved autocomplete queries cache
    final cached = await OfflineCache.get('train_search_${q.toLowerCase()}');
    if (cached is List) {
      for (final item in cached) {
        if (item is Map) {
          final no = (item['train_number'] ?? item['number'] ?? '').toString().trim();
          final name = (item['name'] ?? item['train_name'] ?? '').toString().trim();
          if (no.isNotEmpty && (no.toLowerCase().contains(qLow) || name.toLowerCase().contains(qLow))) {
            if (seen.add(no)) {
              merged.add({
                'number': no,
                'name': isValidTrainName(name) ? name : 'Train $no',
                'source': _extractStation(Map<String, dynamic>.from(item), ['from', 'source', 'from_station']),
                'destination': _extractStation(Map<String, dynamic>.from(item), ['to', 'destination', 'to_station']),
              });
            }
          }
        }
      }
    }

    // 5. Remote search query (matching both train number AND train name)
    final remote = await RailRadarSource.searchTrains(q, limit: 25);
    for (final item in remote) {
      final no = (item['train_number'] ?? item['number'] ?? '').toString().trim();
      final name = (item['name'] ?? item['train_name'] ?? '').toString().trim();
      if (no.isNotEmpty) {
        if (seen.add(no)) {
          merged.add({
            'number': no,
            'name': isValidTrainName(name) ? name : 'Train $no',
            'source': _extractStation(item, ['from', 'source', 'from_station']),
            'destination': _extractStation(item, ['to', 'destination', 'to_station']),
          });
        } else {
          final existingIndex = merged.indexWhere((m) => m['number'] == no);
          if (existingIndex >= 0) {
            final existingName = merged[existingIndex]['name']?.toString() ?? '';
            if (!isValidTrainName(existingName) && isValidTrainName(name)) {
              merged[existingIndex]['name'] = name;
            }
          }
        }
      }
    }

    // 6. Relevance Sorting: Exact matches & Prefix matches first
    merged.sort((a, b) {
      final aNo = a['number']?.toString().toLowerCase() ?? '';
      final bNo = b['number']?.toString().toLowerCase() ?? '';
      final aName = a['name']?.toString().toLowerCase() ?? '';
      final bName = b['name']?.toString().toLowerCase() ?? '';

      if (aNo == qLow) return -1;
      if (bNo == qLow) return 1;
      if (aNo.startsWith(qLow) && !bNo.startsWith(qLow)) return -1;
      if (!aNo.startsWith(qLow) && bNo.startsWith(qLow)) return 1;
      if (aName.startsWith(qLow) && !bName.startsWith(qLow)) return -1;
      if (!aName.startsWith(qLow) && bName.startsWith(qLow)) return 1;
      return 0;
    });

    final cappedResults = merged.take(25).toList();

    if (mounted && seq == _reqSeq) {
      if (cappedResults.isNotEmpty) {
        if (_searchMemoryCache.length > 100) _searchMemoryCache.clear();
        _searchMemoryCache[cacheKey] = cappedResults;
        unawaited(OfflineCache.put('train_search_${q.toLowerCase()}', cappedResults, ttl: const Duration(days: 7)));
      }
      setState(() {
        _items = cappedResults;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDarkMode;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? const Color(0xFF98989D) : const Color(0xFF8E8E93);
    final popupBg = isDark ? const Color(0xFF1A1D2C) : Colors.white;
    final borderCol = isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE5E5EA);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0A84FF).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
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
                style: GoogleFonts.inter(
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: GoogleFonts.inter(
                    color: textSecondary.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  suffixIcon: _loading
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
                      setState(() => _items = []);
                    },
                  )
                      : null),
                ),
              ),
            ),
          ],
        ),
        if (_items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 260),
                decoration: BoxDecoration(
                  color: popupBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderCol, width: 1),
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
                    return _TrainAutocompleteTile(
                      item: _items[i],
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

bool isValidTrainName(String name) {
  final clean = name.trim();
  if (clean.isEmpty) return false;
  if (clean.startsWith('Train ')) return false;
  if (clean == 'Express') return false;
  if (RegExp(r'^\d+$').hasMatch(clean)) return false;
  if (clean.length < 3) return false;
  return true;
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
      final cachedName = _resolvedNameCache[cleanNo]!;
      if (isValidTrainName(cachedName)) {
        _displayName = cachedName;
        return;
      }
    }

    if (isValidTrainName(name)) {
      _displayName = name;
      _resolvedNameCache[cleanNo] = name;
      return;
    }

    _displayName = 'Train $cleanNo';

    if (cleanNo.isNotEmpty) {
      RailRadarSource.fetchTrainName(cleanNo).then((info) {
        final realName = info['name']?.toString().trim() ?? '';
        final src = info['source']?.toString().trim() ?? '';
        final dst = info['destination']?.toString().trim() ?? '';

        if (isValidTrainName(realName) && mounted) {
          _resolvedNameCache[cleanNo] = realName;
          widget.item['name'] = realName;
          if (src.isNotEmpty) widget.item['source'] = src;
          if (dst.isNotEmpty) widget.item['destination'] = dst;
          setState(() => _displayName = realName);

          unawaited(OfflineCache.saveTrainCatalog([
            {
              'number': cleanNo,
              'name': realName,
              'source': src,
              'destination': dst,
            }
          ]));
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