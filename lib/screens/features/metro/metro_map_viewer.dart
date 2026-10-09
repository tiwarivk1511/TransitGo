import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../../core/theme/theme_controller.dart';

class MetroMapViewer extends StatefulWidget {
  final String cityName;
  final String mapUrl;

  const MetroMapViewer({
    super.key,
    required this.cityName,
    required this.mapUrl,
  });

  @override
  State<MetroMapViewer> createState() => _MetroMapViewerState();
}

class _MetroMapViewerState extends State<MetroMapViewer> {
  final TransformationController _transformController = TransformationController();
  double _currentScale = 1.0;

  bool _isLoading = true;
  String? _svgString;
  String? _error;

  @override
  void initState() {
    super.initState();
    _transformController.addListener(_onScaleChanged);
    _loadAndSanitizeSvg();
  }

  @override
  void didUpdateWidget(covariant MetroMapViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mapUrl != widget.mapUrl || oldWidget.cityName != widget.cityName) {
      _loadAndSanitizeSvg();
    }
  }

  @override
  void dispose() {
    _transformController.removeListener(_onScaleChanged);
    _transformController.dispose();
    super.dispose();
  }

  String _sanitizeSvg(String rawSvg) {
    var body = rawSvg.trim();

    // 1. Strip XML declaration before <svg
    final svgIdx = body.toLowerCase().indexOf('<svg');
    if (svgIdx > 0) {
      body = body.substring(svgIdx);
    }

    // 2. Strip unsupported CSS Color 4 display-p3 color functions that cause flutter_svg stroke parsing failure e.g. stroke:color(display-p3 ...)
    body = body.replaceAll(
      RegExp(r'(stroke|fill)\s*:\s*color\([^)]*\)\s*;?'),
      '',
    );

    // 3. Convert inline style="..." rules into explicit SVG attributes so flutter_svg renders all line paths
    body = body.replaceAllMapped(RegExp(r'\sstyle="([^"]*)"'), (match) {
      final styleStr = match.group(1) ?? '';
      final attrs = <String>[];
      for (final pair in styleStr.split(';')) {
        final parts = pair.split(':');
        if (parts.length == 2) {
          final k = parts[0].trim();
          final v = parts[1].trim();
          if (k == 'fill' ||
              k == 'stroke' ||
              k == 'stroke-width' ||
              k == 'stroke-opacity' ||
              k == 'fill-opacity' ||
              k == 'opacity' ||
              k == 'stroke-linecap' ||
              k == 'stroke-linejoin') {
            attrs.add('$k="$v"');
          }
        }
      }
      return attrs.isNotEmpty ? ' ${attrs.join(' ')} ' : ' ';
    });

    return body;
  }

  Future<void> _loadAndSanitizeSvg() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _svgString = null;
    });

    final url = _resolvedMapUrl;

    try {
      final uri = Uri.parse(url);
      final response = await http.get(
        uri,
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 16; Pixel 10) AppleWebKit/537.36 (KHTML, like Gecko) Edg/154.0.0.0 Mobile Safari/537.36',
          'Accept': 'image/svg+xml, text/xml, */*',
          'Origin': 'https://yometro.com',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final sanitized = _sanitizeSvg(response.body);
        if (sanitized.contains('<svg') || sanitized.contains('<SVG')) {
          if (mounted) {
            setState(() {
              _svgString = sanitized;
              _isLoading = false;
              _error = null;
            });
            return;
          }
        }
      }
      throw Exception('Server returned status ${response.statusCode}');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Unable to load ${widget.cityName} vector SVG map. Check network connection.';
        });
      }
    }
  }

  void _onScaleChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    if (mounted && scale != _currentScale) {
      setState(() => _currentScale = scale);
    }
  }

  void _zoomIn() {
    _transformController.value = _transformController.value * Matrix4.diagonal3Values(1.3, 1.3, 1.0);
  }

  void _zoomOut() {
    _transformController.value = _transformController.value * Matrix4.diagonal3Values(0.75, 0.75, 1.0);
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  String get _resolvedMapUrl {
    if (widget.mapUrl.startsWith('http') || widget.mapUrl.startsWith('https')) {
      return widget.mapUrl;
    }
    final rawCity = widget.cityName.toLowerCase().replaceAll(' ', '');
    String citySlug = rawCity;

    if (rawCity.contains('bengaluru') || rawCity.contains('bangalore') || rawCity.contains('namma')) {
      citySlug = 'namma';
    } else if (rawCity.contains('navimumbai') || rawCity.contains('navi')) {
      citySlug = 'navi-mumbai';
    } else if (rawCity.contains('delhi')) {
      citySlug = 'delhi';
    } else if (rawCity.contains('gandhinagar')) {
      citySlug = 'ahmedabad';
    } else if (rawCity.contains('mumbaimono')) {
      citySlug = 'mumbai';
    }

    return 'https://yometro.com/images/maps/$citySlug-metro-route-map.svg';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDarkMode;
    final bgColor = isDark ? const Color(0xFF09090C) : const Color(0xFFF2F2F7);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? const Color(0xFF98989D) : const Color(0xFF636366);
    final cardBg = isDark ? const Color(0xFF16161C) : const Color(0xFFFFFFFF);
    final borderCol = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E5EA);

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: bgColor,
      child: Stack(
        children: [
          // High-Res Zoomable Vector SVG Metro Map Body
          Positioned.fill(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Color(0xFF0A84FF)),
                        const SizedBox(height: 16),
                        Text(
                          'Loading ${widget.cityName} Vector Metro Map…',
                          style: GoogleFonts.inter(
                            color: textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : _error != null || _svgString == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                CupertinoIcons.exclamationmark_triangle_fill,
                                color: Color(0xFFFF375F),
                                size: 44,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _error ?? 'Failed to load vector map',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _loadAndSanitizeSvg,
                                icon: const Icon(CupertinoIcons.refresh_bold, size: 14),
                                label: const Text('Retry Load'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0A84FF),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.white, // Crisp white canvas for 100% SVG line contrast
                        child: InteractiveViewer(
                          transformationController: _transformController,
                          minScale: 0.5,
                          maxScale: 6.0,
                          clipBehavior: Clip.hardEdge,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: SvgPicture.string(
                                _svgString!,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
          ),

          // Top Floating Header Info Badge
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: cardBg.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A84FF).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.map_fill, color: Color(0xFF0A84FF), size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.cityName} Metro System Map',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Pinch or double tap to zoom • ${(_currentScale * 100).round()}% Zoom',
                          style: GoogleFonts.inter(
                            color: textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating Control Buttons (Zoom In, Zoom Out, Reset)
          Positioned(
            right: 14,
            bottom: 18,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _zoomBtn(
                  icon: CupertinoIcons.scope,
                  tooltip: 'Reset zoom',
                  onTap: _resetZoom,
                  cardBg: cardBg,
                  textPrimary: textPrimary,
                  borderCol: borderCol,
                ),
                const SizedBox(height: 8),
                _zoomBtn(
                  icon: CupertinoIcons.plus,
                  tooltip: 'Zoom in',
                  onTap: _zoomIn,
                  cardBg: cardBg,
                  textPrimary: textPrimary,
                  borderCol: borderCol,
                ),
                const SizedBox(height: 8),
                _zoomBtn(
                  icon: CupertinoIcons.minus,
                  tooltip: 'Zoom out',
                  onTap: _zoomOut,
                  cardBg: cardBg,
                  textPrimary: textPrimary,
                  borderCol: borderCol,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _zoomBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required Color cardBg,
    required Color textPrimary,
    required Color borderCol,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: cardBg.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, size: 18, color: textPrimary),
          ),
        ),
      ),
    );
  }
}
