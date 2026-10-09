import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
  });

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

Set<String> _getConnectedInterchangeStations(String stationName) {
  final set = <String>{stationName};
  final norm = stationName.trim().toLowerCase();

  // Kashmere Gate (Red / Yellow / Violet)
  if (norm.contains('kashmere gate')) set.add('Kashmere Gate');

  // Rajiv Chowk (Yellow / Blue)
  if (norm.contains('rajiv chowk')) set.add('Rajiv Chowk');

  // Mandi House (Blue / Violet)
  if (norm.contains('mandi house')) set.add('Mandi House');

  // Central Secretariat (Yellow / Violet)
  if (norm.contains('central secretariat')) set.add('Central Secretariat');

  // INA / Dilli Haat - INA (Yellow / Pink)
  if (norm.contains('ina')) {
    set.add('INA');
    set.add('Dilli Haat - INA');
    set.add('Dilli Haat INA');
  }

  // Hauz Khas (Yellow / Magenta)
  if (norm.contains('hauz khas')) set.add('Hauz Khas');

  // Lajpat Nagar (Violet / Pink)
  if (norm.contains('lajpat nagar')) set.add('Lajpat Nagar');

  // Kalkaji Mandir (Violet / Magenta)
  if (norm.contains('kalkaji mandir')) set.add('Kalkaji Mandir');

  // Botanical Garden (Blue / Magenta)
  if (norm.contains('botanical garden')) set.add('Botanical Garden');

  // Janakpuri West (Blue / Magenta)
  if (norm.contains('janakpuri west')) set.add('Janakpuri West');

  // Netaji Subhash Place (Red / Pink)
  if (norm.contains('netaji subhash place') || norm.contains('nsp')) set.add('Netaji Subhash Place');

  // Rajouri Garden (Blue / Pink)
  if (norm.contains('rajouri garden')) set.add('Rajouri Garden');

  // Inderlok (Red / Green)
  if (norm.contains('inderlok')) set.add('Inderlok');

  // Welcome (Red / Pink)
  if (norm.contains('welcome')) set.add('Welcome');

  // Mayur Vihar Phase-1 (Blue / Pink)
  if (norm.contains('mayur vihar phase-1') || norm.contains('mayur vihar phase 1')) {
    set.add('Mayur Vihar Phase-1');
    set.add('Mayur Vihar Phase 1');
  }

  // Anand Vihar (Blue / Pink / RRTS)
  if (norm.contains('anand vihar')) {
    set.add('Anand Vihar');
    set.add('Anand Vihar ISBT');
    set.add('Anand Vihar RRTS');
  }

  // Karkarduma (Blue / Pink)
  if (norm.contains('karkarduma') || norm.contains('karkardooma')) {
    set.add('Karkarduma');
    set.add('Karkarduma Court');
  }

  // Punjabi Bagh West (Green / Pink)
  if (norm.contains('punjabi bagh')) {
    set.add('Punjabi Bagh');
    set.add('Punjabi Bagh West');
  }

  // Kirti Nagar (Blue / Green)
  if (norm.contains('kirti nagar')) set.add('Kirti Nagar');

  // Yamuna Bank (Blue Main / Blue Branch)
  if (norm.contains('yamuna bank')) set.add('Yamuna Bank');

  // New Delhi (Yellow / Airport Express)
  if (norm.contains('new delhi')) set.add('New Delhi');

  // Dwarka Sector 21 (Blue / Airport Express)
  if (norm.contains('dwarka sector 21') || norm.contains('dwarka sec 21')) set.add('Dwarka Sector 21');

  // Dhaula Kuan / South Campus
  if (norm.contains('dhaula kuan') || norm.contains('durgabai deshmukh')) {
    set.add('Dhaula Kuan');
    set.add('Durgabai Deshmukh South Campus');
  }

  // Noida Sec 52 (Blue) <-> Noida Sec 51 (Aqua)
  if (norm.contains('noida sector 52') || norm.contains('noida sec 52') || norm.contains('noida sector 51') || norm.contains('noida sec 51')) {
    set.add('Noida Sector 52');
    set.add('Noida Sector 51');
  }

  // Sikanderpur (Yellow / Rapid Metro)
  if (norm.contains('sikanderpur')) set.add('Sikanderpur');

  // Majestic (Bengaluru Purple/Green Line)
  if (norm.contains('majestic') || norm.contains('kempegowda')) {
    set.add('Nadaprabhu Kempegowda Station Majestic');
    set.add('Nadaprabhu Kempegowda Station, Majestic');
    set.add('Majestic');
  }

  // Mumbai: DN Nagar (Line 1) <-> Andheri West (Line 2A)
  if (norm.contains('dn nagar') || norm.contains('d.n. nagar') || norm.contains('andheri west')) {
    set.add('DN Nagar');
    set.add('D.N. Nagar');
    set.add('Andheri West');
  }

  // Mumbai: Western Express Highway (Line 1) <-> Gundavali (Line 7)
  if (norm.contains('western express highway') || norm.contains('gundavali')) {
    set.add('Western Express Highway');
    set.add('Gundavali');
  }

  // Chennai Central
  if (norm.contains('chennai central') || norm.contains('puratchi thalaivar')) {
    set.add('Puratchi Thalaivar Dr. M.G. Ramachandran Central');
    set.add('Chennai Central');
  }

  // Chennai Alandur
  if (norm.contains('alandur')) {
    set.add('Alandur');
    set.add('Arignar Anna Alandur');
  }

  return set;
}

class MetroRouteCalculator {
  static MetroRoute? findRoute(
    MetroNetwork network,
    String source,
    String destination,
  ) {
    return null;
  }

  static List<MetroRoute> findRoutes(
    MetroNetwork network,
    String source,
    String destination,
  ) {
    return const [];
  }
}

class MetroDataRepository {
  static final List<MetroNetwork> networks = [
    MetroNetwork(
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
      lines: const [
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
    MetroNetwork(
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
      lines: const [
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
    MetroNetwork(
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
      lines: const [
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
    MetroNetwork(
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
      lines: const [
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
    MetroNetwork(
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
      lines: const [
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
    MetroNetwork(
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
      lines: const [
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
    MetroNetwork(
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
      lines: const [
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
    MetroNetwork(
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
      lines: const [
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
    MetroNetwork(
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
      lines: const [
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
    MetroNetwork(
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
      lines: const [
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
    MetroNetwork(
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
      lines: const [
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
    MetroNetwork(
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
      lines: const [
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
    MetroNetwork(
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
      lines: const [
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
    MetroNetwork(
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
      lines: const [
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
    MetroNetwork(
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
      lines: const [
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
