import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../data/models/metro_network.dart';
import 'metro_map_viewer.dart';

class MetroInteractiveMapView extends StatefulWidget {
  final MetroNetwork network;
  final String? sourceStation;
  final String? destinationStation;
  final List<String>? highlightedStations;
  final ValueChanged<String>? onStationTap;

  const MetroInteractiveMapView({
    super.key,
    required this.network,
    this.sourceStation,
    this.destinationStation,
    this.highlightedStations,
    this.onStationTap,
  });

  @override
  State<MetroInteractiveMapView> createState() => _MetroInteractiveMapViewState();
}

class _MetroInteractiveMapViewState extends State<MetroInteractiveMapView> {
  String _getMapSvgUrl(MetroNetwork network) {
    if (network.mapUrl != null &&
        network.mapUrl!.startsWith('http') &&
        !network.mapUrl!.contains('bengaluru-metro-route-map.svg')) {
      return network.mapUrl!;
    }

    final rawId = network.id.toLowerCase().replaceAll(' ', '');
    String citySlug = rawId;

    if (rawId.contains('bengaluru') || rawId.contains('bangalore') || rawId.contains('namma')) {
      citySlug = 'namma';
    } else if (rawId.contains('navimumbai') || rawId.contains('navi')) {
      citySlug = 'navi-mumbai';
    } else if (rawId.contains('delhi')) {
      citySlug = 'delhi';
    } else if (rawId.contains('gandhinagar')) {
      citySlug = 'ahmedabad';
    } else if (rawId.contains('mumbaimono')) {
      citySlug = 'mumbai';
    }

    return 'https://yometro.com/images/maps/$citySlug-metro-route-map.svg';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDarkMode;
    final cardBg = isDark ? const Color(0xFF16161C) : const Color(0xFFFFFFFF);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final borderCol = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E5EA);
    final inputBg = isDark ? const Color(0xFF09090C) : const Color(0xFFF2F2F7);

    final svgUrl = _getMapSvgUrl(widget.network);

    return Column(
      children: [
        // Responsive Top Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: borderCol),
          ),
          child: Row(
            children: [
              const Icon(CupertinoIcons.map_fill, color: Color(0xFF0A84FF), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${widget.network.cityName} Official Metro System Map',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Zoomable Vector SVG Metro Map Body Component
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: MetroMapViewer(
                cityName: widget.network.cityName,
                mapUrl: svgUrl,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
