import 'package:flutter/material.dart';

import '../../services/metro_api_service.dart';

class MetroLine {
  final String name;
  final Color color;
  final String route;
  final int stationsCount;
  final double distanceKm;
  final List<String> interchangeStations;
  final List<String> stations;
  final Map<String, dynamic>? stationCoords; // Dynamic coordinates
  final String? note;

  const MetroLine({
    required this.name,
    required this.color,
    required this.route,
    required this.stationsCount,
    required this.distanceKm,
    required this.interchangeStations,
    required this.stations,
    this.stationCoords,
    this.note,
  });
}

class MetroNetwork {
  final String id;
  final String cityName;
  final String stateName;
  final String operatorName;
  final String fareRange;
  final String timings;
  final int totalStations;
  final double totalNetworkKm;
  final List<String> ticketingOptions;
  final List<MetroLine> lines;
  final List<String> highlights;
  final String? websiteUrl;
  final String? mapUrl;
  final String? logoUrl;

  const MetroNetwork({
    required this.id,
    required this.cityName,
    required this.stateName,
    required this.operatorName,
    required this.fareRange,
    required this.timings,
    required this.totalStations,
    required this.totalNetworkKm,
    required this.ticketingOptions,
    required this.lines,
    required this.highlights,
    this.websiteUrl,
    this.mapUrl,
    this.logoUrl,
  });

  String get defaultLogoUrl {
    if (logoUrl != null && logoUrl!.isNotEmpty) return logoUrl!;

    switch (id.toLowerCase()) {
      case 'delhi':
        return 'https://commons.wikimedia.org/wiki/Special:FilePath/Delhi_Metro_logo.svg';
      case 'mumbai':
        return 'https://commons.wikimedia.org/wiki/Special:FilePath/Mumbai_Metro_Logo.svg';
      case 'bengaluru':
        return 'https://commons.wikimedia.org/wiki/Special:FilePath/Namma_Metro_logo.svg';
      case 'kolkata':
        return 'https://commons.wikimedia.org/wiki/Special:FilePath/Kolkata_Metro_Logo.svg';
      case 'hyderabad':
        return 'https://commons.wikimedia.org/wiki/Special:FilePath/Hyderabad_Metro_Logo.png';
      case 'chennai':
        return 'https://commons.wikimedia.org/wiki/Special:FilePath/Chennai_Metro_logo.svg';
      case 'kochi':
        return 'https://commons.wikimedia.org/wiki/Special:FilePath/Kochi_Metro_logo.svg';
      case 'pune':
        return 'https://commons.wikimedia.org/wiki/Special:FilePath/Pune_Metro_Logo.svg';
      case 'ahmedabad':
        return 'https://commons.wikimedia.org/wiki/Special:FilePath/Ahmedabad_Metro_Logo.svg';
      case 'jaipur':
        return 'https://commons.wikimedia.org/wiki/Special:FilePath/Jaipur_Metro_Logo.svg';
      case 'lucknow':
      case 'kanpur':
      case 'agra':
        return 'https://commons.wikimedia.org/wiki/Special:FilePath/Lucknow_Metro_Logo.svg';
      case 'nagpur':
        return 'https://commons.wikimedia.org/wiki/Special:FilePath/Nagpur_Metro_Logo.svg';
      case 'noida':
        return 'https://commons.wikimedia.org/wiki/Special:FilePath/Noida_Metro_Logo.svg';
      default:
        return 'https://commons.wikimedia.org/wiki/Special:FilePath/Delhi_Metro_logo.svg';
    }
  }

  Color get primaryBrandColor {
    switch (id.toLowerCase()) {
      case 'delhi':
        return const Color(0xFFE53935);
      case 'mumbai':
        return const Color(0xFF1E88E5);
      case 'bengaluru':
        return const Color(0xFF8E24AA);
      case 'kolkata':
        return const Color(0xFF1E88E5);
      case 'hyderabad':
        return const Color(0xFFE53935);
      case 'chennai':
        return const Color(0xFF1E88E5);
      case 'kochi':
        return const Color(0xFF00ACC1);
      case 'pune':
        return const Color(0xFF8E24AA);
      case 'ahmedabad':
        return const Color(0xFF1E88E5);
      case 'jaipur':
        return const Color(0xFFEC407A);
      case 'lucknow':
      case 'kanpur':
      case 'agra':
        return const Color(0xFFE53935);
      case 'nagpur':
        return const Color(0xFFFB8C00);
      case 'noida':
        return const Color(0xFF00ACC1);
      default:
        return const Color(0xFF0A84FF);
    }
  }

  String get operatorCode {
    if (operatorName.contains('(') && operatorName.contains(')')) {
      final match = RegExp(r'\(([^)]+)\)').firstMatch(operatorName);
      if (match != null) return match.group(1)!;
    }
    final clean = cityName.replaceAll(RegExp(r'\s+.*'), '').trim();
    return clean.substring(0, clean.length.clamp(0, 4)).toUpperCase();
  }

  /// Get all unique stations in this metro network
  List<String> get allStations {
    final set = <String>{};
    for (final line in lines) {
      for (final st in line.stations) {
        String norm = st.trim();
        if (norm.toLowerCase().contains('anand vihar')) norm = 'Anand Vihar';
        if (norm.toLowerCase().contains('karkarduma') || norm.toLowerCase().contains('karkardooma')) norm = 'Karkarduma';
        if (norm.toLowerCase().contains('punjabi bagh')) norm = 'Punjabi Bagh';
        if (norm.isNotEmpty) set.add(norm);
      }
    }
    final sorted = set.toList()..sort();
    return sorted;
  }
}

class MetroRouteSegment {
  final String lineName;
  final Color lineColor;
  final String fromStation;
  final String toStation;
  final List<String> stations;
  final double distanceKm;
  final int durationMinutes;

  MetroRouteSegment({
    required this.lineName,
    required this.lineColor,
    required this.fromStation,
    required this.toStation,
    required this.stations,
    required this.distanceKm,
    required this.durationMinutes,
  });
}

class MetroInterchange {
  final String stationName;
  final String fromLine;
  final String toLine;
  final Color toLineColor;

  MetroInterchange({
    required this.stationName,
    required this.fromLine,
    required this.toLine,
    required this.toLineColor,
  });
}

class MetroRoute {
  final String cityName;
  final String sourceStation;
  final String destinationStation;
  final List<MetroRouteSegment> segments;
  final List<MetroInterchange> interchanges;
  final int totalStations;
  final int totalDurationMinutes;
  final double totalDistanceKm;
  final int estimatedFare;
  final String routeTag;

  MetroRoute({
    required this.cityName,
    required this.sourceStation,
    required this.destinationStation,
    required this.segments,
    required this.interchanges,
    required this.totalStations,
    required this.totalDurationMinutes,
    required this.totalDistanceKm,
    required this.estimatedFare,
    this.routeTag = 'Recommended Route ⚡',
  });
}

class MetroRouteCalculator {
  static MetroRoute? findRoute(
    MetroNetwork network,
    String source,
    String destination,
  ) {
    final routes = findRoutes(network, source, destination);
    return routes.isNotEmpty ? routes.first : null;
  }

  static List<MetroRoute> findRoutes(
    MetroNetwork network,
    String source,
    String destination,
  ) {
    if (source.trim().isEmpty || destination.trim().isEmpty) return const [];
    if (source.trim().toLowerCase() == destination.trim().toLowerCase()) return const [];

    final route = _bfsShortestPath(network, source, destination);
    if (route != null) return [route];
    return const [];
  }

  static MetroRoute? _bfsShortestPath(
    MetroNetwork network,
    String source,
    String destination,
  ) {
    final lines = network.lines;
    if (lines.isEmpty) return null;

    final adj = <String, List<({String station, MetroLine line})>>{};

    for (final line in lines) {
      final stns = line.stations;
      for (var i = 0; i < stns.length; i++) {
        final curr = stns[i].trim();
        if (curr.isEmpty) continue;

        adj.putIfAbsent(curr.toLowerCase(), () => []);

        if (i > 0) {
          final prev = stns[i - 1].trim();
          if (prev.isNotEmpty) {
            adj[curr.toLowerCase()]!.add((station: prev, line: line));
          }
        }
        if (i < stns.length - 1) {
          final next = stns[i + 1].trim();
          if (next.isNotEmpty) {
            adj[curr.toLowerCase()]!.add((station: next, line: line));
          }
        }
      }
    }

    final srcKey = source.trim().toLowerCase();
    final dstKey = destination.trim().toLowerCase();

    if (!adj.containsKey(srcKey) || !adj.containsKey(dstKey)) return null;

    final queue = <List<({String station, MetroLine? line})>>[
      [ (station: source, line: null) ]
    ];
    final visited = <String>{srcKey};

    List<({String station, MetroLine? line})>? bestPath;

    while (queue.isNotEmpty) {
      final path = queue.removeAt(0);
      final current = path.last;
      final currKey = current.station.trim().toLowerCase();

      if (currKey == dstKey) {
        bestPath = path;
        break;
      }

      final neighbors = adj[currKey] ?? const [];
      for (final nbr in neighbors) {
        final nbrKey = nbr.station.trim().toLowerCase();
        if (visited.add(nbrKey)) {
          queue.add([...path, (station: nbr.station, line: nbr.line)]);
        }
      }
    }

    if (bestPath == null || bestPath.length < 2) return null;

    final segments = <MetroRouteSegment>[];
    final interchanges = <MetroInterchange>[];

    MetroLine? currentLine = bestPath[1].line;
    List<String> currentSegmentStns = [bestPath[0].station];

    for (var i = 1; i < bestPath.length; i++) {
      final step = bestPath[i];
      final line = step.line;

      if (line == currentLine || line == null) {
        currentSegmentStns.add(step.station);
      } else {
        if (currentSegmentStns.isNotEmpty) {
          segments.add(MetroRouteSegment(
            lineName: currentLine?.name ?? 'Metro Line',
            lineColor: currentLine?.color ?? const Color(0xFF0A84FF),
            fromStation: currentSegmentStns.first,
            toStation: currentSegmentStns.last,
            stations: List.from(currentSegmentStns),
            distanceKm: double.parse(((currentSegmentStns.length - 1) * 1.3).toStringAsFixed(1)),
            durationMinutes: (currentSegmentStns.length - 1) * 2,
          ));
        }

        interchanges.add(MetroInterchange(
          stationName: currentSegmentStns.isNotEmpty ? currentSegmentStns.last : step.station,
          fromLine: currentLine?.name ?? '',
          toLine: line.name,
          toLineColor: line.color,
        ));

        currentLine = line;
        currentSegmentStns = [step.station];
      }
    }

    if (currentSegmentStns.isNotEmpty && currentLine != null) {
      segments.add(MetroRouteSegment(
        lineName: currentLine.name,
        lineColor: currentLine.color,
        fromStation: currentSegmentStns.first,
        toStation: currentSegmentStns.last,
        stations: List.from(currentSegmentStns),
        distanceKm: double.parse(((currentSegmentStns.length - 1) * 1.3).toStringAsFixed(1)),
        durationMinutes: (currentSegmentStns.length - 1) * 2,
      ));
    }

    final totalStns = bestPath.length;
    final totalKm = double.parse(((totalStns - 1) * 1.3).toStringAsFixed(1));
    final durationMins = (totalStns - 1) * 2 + (interchanges.length * 5);
    final fare = (totalKm * 1.5).clamp(10.0, 60.0).round();

    return MetroRoute(
      cityName: network.cityName,
      sourceStation: source,
      destinationStation: destination,
      segments: segments,
      interchanges: interchanges,
      totalStations: totalStns,
      totalDurationMinutes: durationMins,
      totalDistanceKm: totalKm,
      estimatedFare: fare,
    );
  }
}

class MetroDataRepository {
  static final Map<String, MetroNetwork> _liveCache = {};

  /// Asynchronously fetches 100% live dynamic network data for a given city
  static Future<MetroNetwork> getLiveNetwork(MetroNetwork baseNetwork) async {
    if (_liveCache.containsKey(baseNetwork.id)) {
      return _liveCache[baseNetwork.id]!;
    }
    final live = await MetroApiService.fetchDynamicTrackMyMetroNetwork(baseNetwork);
    _liveCache[baseNetwork.id] = live;
    return live;
  }

  /// Asynchronously fetches live dynamic network data for ALL Indian metro networks
  static Future<List<MetroNetwork>> fetchAllLiveNetworks() async {
    final results = <MetroNetwork>[];
    for (final baseNet in networks) {
      try {
        final live = await getLiveNetwork(baseNet);
        results.add(live);
      } catch (_) {
        results.add(baseNet);
      }
    }
    return results;
  }

  static final List<MetroNetwork> networks = [
    const MetroNetwork(
      id: 'delhi',
      cityName: 'Delhi NCR',
      stateName: 'Delhi / Haryana / UP',
      operatorName: 'Delhi Metro Rail Corporation (DMRC)',
      fareRange: '₹10 – ₹60',
      timings: '05:30 AM – 11:30 PM',
      totalStations: 288,
      totalNetworkKm: 393.0,
      ticketingOptions: [
        'DMRC Travel App (QR Code)',
        'NCMC National Common Mobility Card',
        'DMRC Smart Card (10% Off)',
        'WhatsApp QR Ticket (+91 9650855800)',
      ],
      highlights: [
        'India\'s largest & busiest metro network',
        'Direct Airport Express Line to IGI Airport T3',
        'Driverless Unattended Train Operation (UTO) on Magenta & Pink Lines',
      ],
      websiteUrl: 'https://www.delhimetrorail.com',
      mapUrl: 'https://yometro.com/images/maps/delhi-metro-route-map.svg',
      lines: [
        MetroLine(
          name: 'Red Line (Line 1)',
          color: Color(0xFFE53935),
          route: 'Rithala ↔ Shaheed Sthal (Ghaziabad)',
          stationsCount: 29,
          distanceKm: 34.7,
          interchangeStations: ['Kashmere Gate', 'Welcome', 'Netaji Subhash Place', 'Inderlok'],
          stations: [],
        ),
        MetroLine(
          name: 'Yellow Line (Line 2)',
          color: Color(0xFFFDD835),
          route: 'Samaypur Badli ↔ Millennium City Centre Gurugram',
          stationsCount: 37,
          distanceKm: 49.0,
          interchangeStations: ['Kashmere Gate', 'Chandni Chowk', 'New Delhi', 'Rajiv Chowk', 'Central Secretariat', 'INA', 'Hauz Khas', 'Sikanderpur'],
          stations: [],
        ),
        MetroLine(
          name: 'Blue Line (Line 3 & 4)',
          color: Color(0xFF1E88E5),
          route: 'Dwarka Sec 21 ↔ Noida Electronic City / Vaishali',
          stationsCount: 58,
          distanceKm: 65.3,
          interchangeStations: ['Dwarka Sec 21', 'Mandi House', 'Rajiv Chowk', 'Kirti Nagar', 'Mayur Vihar Ph-1', 'Anand Vihar'],
          stations: [],
        ),
        MetroLine(
          name: 'Green Line (Line 5)',
          color: Color(0xFF43A047),
          route: 'Inderlok / Kirti Nagar ↔ Brig. Hoshiar Singh (Bahadurgarh)',
          stationsCount: 24,
          distanceKm: 29.6,
          interchangeStations: ['Inderlok', 'Kirti Nagar', 'Ashok Park Main', 'Punjabi Bagh West'],
          stations: [],
        ),
        MetroLine(
          name: 'Violet Line (Line 6)',
          color: Color(0xFF8E24AA),
          route: 'Kashmere Gate ↔ Raja Nahar Singh (Ballabhgarh)',
          stationsCount: 34,
          distanceKm: 46.6,
          interchangeStations: ['Kashmere Gate', 'Mandi House', 'Central Secretariat', 'Lajpat Nagar', 'Kalkaji Mandir'],
          stations: [],
        ),
        MetroLine(
          name: 'Pink Line (Line 7)',
          color: Color(0xFFEC407A),
          route: 'Majlis Park ↔ Shiv Vihar (Ring Road)',
          stationsCount: 38,
          distanceKm: 59.2,
          interchangeStations: ['Netaji Subhash Place', 'Rajouri Garden', 'INA', 'Lajpat Nagar', 'Mayur Vihar Ph-1', 'Anand Vihar', 'Welcome'],
          stations: [],
        ),
        MetroLine(
          name: 'Magenta Line (Line 8)',
          color: Color(0xFFD81B60),
          route: 'Janakpuri West ↔ Botanical Garden',
          stationsCount: 25,
          distanceKm: 37.4,
          interchangeStations: ['Janakpuri West', 'Hauz Khas', 'Kalkaji Mandir', 'Botanical Garden'],
          stations: [],
        ),
        MetroLine(
          name: 'Airport Express (Orange Line)',
          color: Color(0xFFFB8C00),
          route: 'New Delhi ↔ Yashobhoomi Dwarka Sector 25',
          stationsCount: 7,
          distanceKm: 24.9,
          interchangeStations: ['New Delhi', 'Dhaula Kuan', 'Dwarka Sec 21'],
          stations: [],
        ),
      ],
    ),
    const MetroNetwork(
      id: 'mumbai',
      cityName: 'Mumbai',
      stateName: 'Maharashtra',
      operatorName: 'MMMOCL & MMOPL',
      fareRange: '₹10 – ₹50',
      timings: '05:30 AM – 11:30 PM',
      totalStations: 43,
      totalNetworkKm: 59.1,
      ticketingOptions: [
        'Mumbai1 Mobile App (QR Code)',
        'NCMC National Common Mobility Card',
        'Paper Barcode Tickets & Tokens',
      ],
      highlights: [
        'Line 3 Aqua Line: South Mumbai underground corridor',
        'Line 1 connects Eastern & Western suburbs',
      ],
      websiteUrl: 'https://www.mmmocl.co.in',
      mapUrl: 'https://yometro.com/images/maps/mumbai-metro-route-map.svg',
      lines: [
        MetroLine(
          name: 'Line 1 (Blue Line)',
          color: Color(0xFF1E88E5),
          route: 'Versova ↔ Andheri ↔ Ghatkopar',
          stationsCount: 12,
          distanceKm: 11.4,
          interchangeStations: ['Andheri', 'Ghatkopar', 'DN Nagar'],
          stations: [],
        ),
        MetroLine(
          name: 'Line 2A (Yellow Line)',
          color: Color(0xFFFDD835),
          route: 'Dahisar East ↔ Andheri West',
          stationsCount: 17,
          distanceKm: 18.6,
          interchangeStations: ['Dahisar East', 'Andheri West'],
          stations: [],
        ),
        MetroLine(
          name: 'Line 7 (Red Line)',
          color: Color(0xFFE53935),
          route: 'Dahisar East ↔ Gundavali (Andheri East)',
          stationsCount: 14,
          distanceKm: 16.5,
          interchangeStations: ['Dahisar East', 'Gundavali'],
          stations: [],
        ),
        MetroLine(
          name: 'Line 3 (Aqua Line Underground)',
          color: Color(0xFF00ACC1),
          route: 'Aarey Colony ↔ BKC ↔ CSMT ↔ Cuffe Parade',
          stationsCount: 27,
          distanceKm: 33.5,
          interchangeStations: ['CSMT', 'Churchgate', 'BKC', 'Marol Naka'],
          stations: [],
        ),
      ],
    ),
    const MetroNetwork(
      id: 'kolkata',
      cityName: 'Kolkata',
      stateName: 'West Bengal',
      operatorName: 'Metro Railway Kolkata (Indian Railways)',
      fareRange: '₹5 – ₹50',
      timings: '06:45 AM – 09:55 PM',
      totalStations: 48,
      totalNetworkKm: 59.4,
      ticketingOptions: [
        'Metro Ride Kolkata App (QR Ticket)',
        'Kolkata Metro Smart Card',
        'Token & NCMC Card',
      ],
      highlights: [
        'India\'s First Metro Railway Network (Opened 1984)',
        'India\'s First Underwater Metro Tunnel beneath Hooghly River (Line 2 Green Line)',
      ],
      websiteUrl: 'https://mtp.indianrailways.gov.in',
      mapUrl: 'https://yometro.com/images/maps/kolkata-metro-route-map.svg',
      lines: [
        MetroLine(
          name: 'Line 1 (Blue Line - North-South)',
          color: Color(0xFF1E88E5),
          route: 'Dakshineswar ↔ Dum Dum ↔ Esplanade ↔ Kavi Subhash',
          stationsCount: 26,
          distanceKm: 32.2,
          interchangeStations: ['Dum Dum', 'Esplanade', 'Kavi Subhash'],
          stations: [],
        ),
        MetroLine(
          name: 'Line 2 (Green Line - Underwater)',
          color: Color(0xFF43A047),
          route: 'Howrah Maidan ↔ Howrah ↔ Esplanade ↔ Sealdah ↔ Salt Lake Sec V',
          stationsCount: 12,
          distanceKm: 16.6,
          interchangeStations: ['Howrah', 'Esplanade', 'Sealdah'],
          stations: [],
        ),
      ],
    ),
    const MetroNetwork(
      id: 'bengaluru',
      cityName: 'Bengaluru',
      stateName: 'Karnataka',
      operatorName: 'BMRCL (Namma Metro)',
      fareRange: '₹10 – ₹60',
      timings: '05:00 AM – 11:00 PM',
      totalStations: 68,
      totalNetworkKm: 73.81,
      ticketingOptions: [
        'Namma Metro App (QR Ticket)',
        'NCMC Card & Smart Card',
      ],
      highlights: [
        'Namma Metro Purple & Green Lines connecting Whitefield to Challaghatta',
      ],
      websiteUrl: 'https://www.bmrc.co.in',
      mapUrl: 'https://yometro.com/images/maps/namma-metro-route-map.svg',
      lines: [
        MetroLine(
          name: 'Purple Line',
          color: Color(0xFF8E24AA),
          route: 'Whitefield (Kadugodi) ↔ Challaghatta',
          stationsCount: 37,
          distanceKm: 43.49,
          interchangeStations: ['Majestic'],
          stations: [],
        ),
        MetroLine(
          name: 'Green Line',
          color: Color(0xFF43A047),
          route: 'Nagasandra ↔ Silk Institute',
          stationsCount: 32,
          distanceKm: 34.0,
          interchangeStations: ['Majestic'],
          stations: [],
        ),
      ],
    ),
    const MetroNetwork(
      id: 'hyderabad',
      cityName: 'Hyderabad',
      stateName: 'Telangana',
      operatorName: 'L&T Metro Rail / HMRL',
      fareRange: '₹10 – ₹60',
      timings: '06:00 AM – 11:00 PM',
      totalStations: 57,
      totalNetworkKm: 69.2,
      ticketingOptions: ['TSavaari App', 'Metro Smart Card'],
      highlights: ['Red, Blue and Green lines connecting Miyapur, Raidurg & LB Nagar'],
      websiteUrl: 'https://www.ltmetrorail.com',
      mapUrl: 'https://yometro.com/images/maps/hyderabad-metro-route-map.svg',
      lines: [
        MetroLine(
          name: 'Red Line (Line 1)',
          color: Color(0xFFE53935),
          route: 'Miyapur ↔ LB Nagar',
          stationsCount: 27,
          distanceKm: 29.2,
          interchangeStations: ['Ameerpet', 'MGBS'],
          stations: [],
        ),
        MetroLine(
          name: 'Blue Line (Line 3)',
          color: Color(0xFF1E88E5),
          route: 'Nagole ↔ Raidurg',
          stationsCount: 23,
          distanceKm: 27.0,
          interchangeStations: ['Ameerpet', 'JBS Parade Ground'],
          stations: [],
        ),
      ],
    ),
    const MetroNetwork(
      id: 'chennai',
      cityName: 'Chennai',
      stateName: 'Tamil Nadu',
      operatorName: 'Chennai Metro Rail Limited (CMRL)',
      fareRange: '₹10 – ₹50',
      timings: '05:00 AM – 11:00 PM',
      totalStations: 41,
      totalNetworkKm: 54.1,
      ticketingOptions: ['CMRL Mobile App', 'Singara Chennai NCMC Card'],
      highlights: ['Blue & Green Lines connecting Airport to Central & Wimco Nagar'],
      websiteUrl: 'https://chennaimetrorail.org',
      mapUrl: 'https://yometro.com/images/maps/chennai-metro-route-map.svg',
      lines: [
        MetroLine(
          name: 'Blue Line (Line 1)',
          color: Color(0xFF1E88E5),
          route: 'Wimco Nagar Depot ↔ Chennai International Airport',
          stationsCount: 26,
          distanceKm: 32.65,
          interchangeStations: ['Chennai Central', 'Alandur'],
          stations: [],
        ),
        MetroLine(
          name: 'Green Line (Line 2)',
          color: Color(0xFF43A047),
          route: 'Chennai Central ↔ St. Thomas Mount',
          stationsCount: 17,
          distanceKm: 22.0,
          interchangeStations: ['Chennai Central', 'Alandur'],
          stations: [],
        ),
      ],
    ),
    const MetroNetwork(
      id: 'pune',
      cityName: 'Pune',
      stateName: 'Maharashtra',
      operatorName: 'MahaMetro Pune',
      fareRange: '₹10 – ₹35',
      timings: '06:00 AM – 10:00 PM',
      totalStations: 30,
      totalNetworkKm: 33.2,
      ticketingOptions: ['Pune Metro App', 'One Pune Card'],
      highlights: ['Purple & Aqua lines connecting PCMC to Swargate & Vanaz to Ramwadi'],
      websiteUrl: 'https://www.punemetrorail.org',
      mapUrl: 'https://yometro.com/images/maps/pune-metro-route-map.svg',
      lines: [
        MetroLine(
          name: 'Purple Line (Line 1)',
          color: Color(0xFF8E24AA),
          route: 'PCMC ↔ Swargate',
          stationsCount: 14,
          distanceKm: 17.5,
          interchangeStations: ['Civil Court'],
          stations: [],
        ),
        MetroLine(
          name: 'Aqua Line (Line 2)',
          color: Color(0xFF00ACC1),
          route: 'Vanaz ↔ Ramwadi',
          stationsCount: 16,
          distanceKm: 15.7,
          interchangeStations: ['Civil Court'],
          stations: [],
        ),
      ],
    ),
    const MetroNetwork(
      id: 'ahmedabad',
      cityName: 'Ahmedabad / Gandhinagar',
      stateName: 'Gujarat',
      operatorName: 'GMRC',
      fareRange: '₹5 – ₹25',
      timings: '06:20 AM – 10:00 PM',
      totalStations: 32,
      totalNetworkKm: 40.0,
      ticketingOptions: ['GMRC App', 'Smart Card'],
      highlights: ['Red & Blue lines connecting Thaltej Gam to Vastral Gam'],
      websiteUrl: 'https://www.gujaratmetrorail.com',
      mapUrl: 'https://yometro.com/images/maps/ahmedabad-metro-route-map.svg',
      lines: [
        MetroLine(
          name: 'Blue Line (East-West)',
          color: Color(0xFF1E88E5),
          route: 'Thaltej Gam ↔ Vastral Gam',
          stationsCount: 17,
          distanceKm: 21.1,
          interchangeStations: ['Old High Court'],
          stations: [],
        ),
      ],
    ),
    const MetroNetwork(
      id: 'kochi',
      cityName: 'Kochi',
      stateName: 'Kerala',
      operatorName: 'KMRL',
      fareRange: '₹10 – ₹60',
      timings: '06:00 AM – 10:00 PM',
      totalStations: 25,
      totalNetworkKm: 28.1,
      ticketingOptions: ['Kochi1 Card', 'KMRL App'],
      highlights: ['Cyan Line connecting Aluva to Tripunithura'],
      websiteUrl: 'https://kochimetro.org',
      mapUrl: 'https://yometro.com/images/maps/kochi-metro-route-map.svg',
      lines: [
        MetroLine(
          name: 'Cyan Line',
          color: Color(0xFF00ACC1),
          route: 'Aluva ↔ Tripunithura',
          stationsCount: 25,
          distanceKm: 28.1,
          interchangeStations: [],
          stations: [],
        ),
      ],
    ),
    const MetroNetwork(
      id: 'lucknow',
      cityName: 'Lucknow',
      stateName: 'Uttar Pradesh',
      operatorName: 'UPMRC',
      fareRange: '₹10 – ₹60',
      timings: '06:00 AM – 10:00 PM',
      totalStations: 21,
      totalNetworkKm: 22.87,
      ticketingOptions: ['GoSmart Card', 'UPMRC App'],
      highlights: ['Red Line connecting CCS Airport to Munshipulia'],
      websiteUrl: 'https://lmrcl.com',
      mapUrl: 'https://yometro.com/images/maps/lucknow-metro-route-map.svg',
      lines: [
        MetroLine(
          name: 'Red Line',
          color: Color(0xFFE53935),
          route: 'CCS Airport ↔ Munshipulia',
          stationsCount: 21,
          distanceKm: 22.87,
          interchangeStations: [],
          stations: [],
        ),
      ],
    ),
    const MetroNetwork(
      id: 'jaipur',
      cityName: 'Jaipur',
      stateName: 'Rajasthan',
      operatorName: 'JMRC',
      fareRange: '₹6 – ₹22',
      timings: '06:20 AM – 09:20 PM',
      totalStations: 11,
      totalNetworkKm: 12.0,
      ticketingOptions: ['Metro Smart Card', 'QR Ticket'],
      highlights: ['Pink Line connecting Mansarovar to Badi Chaupar'],
      websiteUrl: 'https://transport.rajasthan.gov.in/jmrc',
      mapUrl: 'https://yometro.com/images/maps/jaipur-metro-route-map.svg',
      lines: [
        MetroLine(
          name: 'Pink Line',
          color: Color(0xFFEC407A),
          route: 'Mansarovar ↔ Badi Chaupar',
          stationsCount: 11,
          distanceKm: 12.0,
          interchangeStations: [],
          stations: [],
        ),
      ],
    ),
    const MetroNetwork(
      id: 'kanpur',
      cityName: 'Kanpur',
      stateName: 'Uttar Pradesh',
      operatorName: 'UPMRC',
      fareRange: '₹10 – ₹30',
      timings: '06:00 AM – 10:00 PM',
      totalStations: 9,
      totalNetworkKm: 8.98,
      ticketingOptions: ['Kanpur Metro QR', 'GoSmart Card'],
      highlights: ['Orange Line connecting IIT Kanpur to Moti Jheel'],
      websiteUrl: 'https://upmetrorail.com',
      mapUrl: 'https://yometro.com/images/maps/kanpur-metro-route-map.svg',
      lines: [
        MetroLine(
          name: 'Orange Line',
          color: Color(0xFFFB8C00),
          route: 'IIT Kanpur ↔ Moti Jheel',
          stationsCount: 9,
          distanceKm: 8.98,
          interchangeStations: [],
          stations: [],
        ),
      ],
    ),
    const MetroNetwork(
      id: 'nagpur',
      cityName: 'Nagpur',
      stateName: 'Maharashtra',
      operatorName: 'MahaMetro Nagpur',
      fareRange: '₹5 – ₹25',
      timings: '06:00 AM – 10:00 PM',
      totalStations: 37,
      totalNetworkKm: 38.2,
      ticketingOptions: ['Maha Card', 'Nagpur Metro App'],
      highlights: ['Orange & Aqua Lines connecting Khapri, Automotive Square & Lokmanya Nagar'],
      websiteUrl: 'https://www.metrorailnagpur.com',
      mapUrl: 'https://yometro.com/images/maps/nagpur-metro-route-map.svg',
      lines: [
        MetroLine(
          name: 'Orange Line',
          color: Color(0xFFFB8C00),
          route: 'Khapri ↔ Automotive Square',
          stationsCount: 18,
          distanceKm: 19.6,
          interchangeStations: ['Sitabuldi'],
          stations: [],
        ),
        MetroLine(
          name: 'Aqua Line',
          color: Color(0xFF00ACC1),
          route: 'Lokmanya Nagar ↔ Prajapati Nagar',
          stationsCount: 20,
          distanceKm: 18.6,
          interchangeStations: ['Sitabuldi'],
          stations: [],
        ),
      ],
    ),
    const MetroNetwork(
      id: 'noida',
      cityName: 'Noida / Greater Noida',
      stateName: 'Uttar Pradesh',
      operatorName: 'NMRC',
      fareRange: '₹10 – ₹50',
      timings: '06:00 AM – 10:00 PM',
      totalStations: 21,
      totalNetworkKm: 29.7,
      ticketingOptions: ['NMRC Smart Card', 'Noida Metro App'],
      highlights: ['Aqua Line connecting Noida Sector 51 to Depot Greater Noida'],
      websiteUrl: 'https://www.nmrcnoida.com',
      mapUrl: 'https://yometro.com/images/maps/noida-metro-route-map.svg',
      lines: [
        MetroLine(
          name: 'Aqua Line',
          color: Color(0xFF00ACC1),
          route: 'Noida Sector 51 ↔ Depot (Greater Noida)',
          stationsCount: 21,
          distanceKm: 29.7,
          interchangeStations: ['Noida Sector 51'],
          stations: [],
        ),
      ],
    ),
    const MetroNetwork(
      id: 'agra',
      cityName: 'Agra',
      stateName: 'Uttar Pradesh',
      operatorName: 'UPMRC',
      fareRange: '₹10 – ₹20',
      timings: '06:00 AM – 10:00 PM',
      totalStations: 6,
      totalNetworkKm: 6.0,
      ticketingOptions: ['Agra Metro App', 'GoSmart Card'],
      highlights: ['Yellow Line connecting Taj East Gate to Mankameshwar Temple'],
      websiteUrl: 'https://upmetrorail.com',
      mapUrl: 'https://yometro.com/images/maps/agra-metro-route-map.svg',
      lines: [
        MetroLine(
          name: 'Yellow Line',
          color: Color(0xFFFDD835),
          route: 'Taj East Gate ↔ Mankameshwar Temple',
          stationsCount: 6,
          distanceKm: 6.0,
          interchangeStations: [],
          stations: [],
        ),
      ],
    ),
  ];
}
