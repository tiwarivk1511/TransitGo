# 🚆 TransitGo — Ultra Premium Apple iOS Themed Indian Railways & Metro Transit Platform

**TransitGo** is a high-performance, cross-platform Flutter application engineered for real-time tracking, GIS mapping, national disruption alerts, PNR enquiries, fare breakdowns, 2D architectural coach seat maps, and urban metro navigation across India. Powered by an **Open Web RailRadar Dual-Engine Architecture** (zero API key required) with **MNTES Scraper Failover** and **Offline-First SQLite Persistence**, TransitGo delivers instant, reliable transit telemetry under any network conditions.

---

## 🌟 Key Highlights & Innovations

- 📡 **National Live GIS Radar Map (`/live-map`)**: Real-time map displaying **2,000+ active trains** across India with rotated directional markers (`bearing` angle), category filters, live search camera focus, and decoded track polyline geometry.
- 🚆 **Live Train Tracking & Corridor Crossings (XING)**: Real-time train telemetry, dual speedometer (Mode 0: Internet Telemetry, Mode 1: Device Onboard Satellite GPS), exact station anchoring (`_trainLatLng`), and RailRadar Corridor Ladder track UI showing same-direction (`↓`) and opposite-direction (`↑`) passing trains.
- 🚨 **National Disruption Alerts (`/trains/exceptions`)**: Real-time national cancellation alerts, rescheduled departure times, route diversions, and station delay board metrics.
- 🚉 **Live Station Traffic Board (`/stations/{code}/live`)**: Arrivals, departures, platform assignments, live status pills (`AT STATION`, `UPCOMING`, `RUNNING`, `NOT STARTED`), and configurable time windows (2h, 4h, 6h, 8h).
- 🛋️ **Aerodynamic Rakes & 2D Seat Maps**: Namo Bharat RRTS / Vande Bharat bullet train rake views and class-specific 2D architectural seat maps (1A First AC with locking door 🔒, 2A, 3A, 3E, SL, EC, CC, 2S, GS) with a direct seat number search tool ("Find Seat #42").
- 🎫 **PNR & Fare Breakdown**: Open web 10-digit PNR enquiry and detailed ticket fare breakdown (base fare, reservation charge, superfast fee, GST/service tax, catering, tatkal charge).
- 🚇 **Indian Metro Transit Systems**: Multi-city metro route planner (Delhi NCR, Mumbai, Bengaluru, Kolkata, Chennai, Hyderabad, etc.), line switch itineraries, fare calculator, interactive GIS map, and high-res PDF map viewer.
- 🎨 **Apple iOS Design System & Theme Engine**: Complete Apple Light (`#F2F2F7` / `#FFFFFF` / `#1C1C1E`) and Dark (`#09090C` / `#16161C` / `#FFFFFF`) mode reactivity with SF Pro / Inter typography and glassmorphic cards.
- 🔥 **Firebase Crashlytics & Remote Config**: Global error handling with `CrashlyticsService` capturing non-fatal and fatal exceptions across all Flutter and Dart platform channels.

---

## 🛠️ Architecture & Tech Stack

| Domain | Technology / Package | Description |
| :--- | :--- | :--- |
| **Framework** | Flutter / Dart | High-performance, cross-platform mobile app framework |
| **Theme Engine** | `ThemeController` | ListenableBuilder at root (`app.dart`) for instant Light/Dark mode toggling |
| **Open Web API Engine** | RailRadar Open Web APIs | Open web REST endpoints requiring **zero API key** for live tracking, map radar, PNR, fare, crossings, and exceptions |
| **Failover Engine** | `NtesSource` / `MntesClient` | Session-aware MNTES HTML scraper with rotating User-Agents, circuit breaking, and cookie management |
| **GIS Mapping** | `flutter_map` + `latlong2` | High-speed vector/raster map rendering with Google Maps Satellite Transit and CartoDB Dark layers |
| **Local Database** | `sqflite` + `OfflineCache` | SQLite caching for station catalog (13,006 stations with City, District, State), recent searches, and favorite trains |
| **Monitoring & Crash Reporting** | `firebase_crashlytics` + `firebase_core` | Automated crash logging and diagnostic exception reporting |
| **Configuration** | `firebase_remote_config` + `flutter_dotenv` | Dynamic parameters and environment configuration |
| **Typography & Icons** | `google_fonts` (Inter) + `cupertino_icons` | Apple Human Interface Guidelines typography and iOS icons |

---

## 📁 Project Structure

```text
TransitGo/
├── android/                   # Android native configuration, Gradle scripts, and google-services.json
├── assets/
│   ├── data/
│   │   └── stations.json      # Offline catalog of 13,006 Indian stations with City, District & State
│   └── images/                # Brand assets and rake imagery
├── lib/
│   ├── app.dart               # Root MaterialApp configuration with ListenableBuilder Theme Engine
│   ├── main.dart              # Entry point with Firebase & Crashlytics initialization
│   ├── components/            # Reusable UI widgets & components
│   │   ├── coach/             # Aerodynamic rake views & 2D architectural coach seat maps
│   │   ├── common/            # Error box, loading indicators, dual speedometer card
│   │   ├── station/           # Theme-aware station autocomplete input dropdowns
│   │   └── train/             # Corridor ladder crossings view & train search autocomplete
│   ├── core/
│   │   ├── cache/             # SQLite cache, recent search history, and favorite trains
│   │   ├── theme/             # ThemeController (Light/Dark mode listener)
│   │   └── utils/             # Permission helpers, responsive layout helpers
│   ├── data/
│   │   ├── models/            # Data models (Train, Station, PNR, Fare, Coach, Traffic, Metro)
│   │   └── sources/           # RailRadarSource, NtesSource, StationSource, LiveStreamSource
│   ├── screens/               # Core Feature Screens
│   │   ├── features/
│   │   │   ├── alerts/        # National Service Disruptions & Exceptions Screen
│   │   │   ├── coach/         # Coach Position & Seat Map Explorer Screen
│   │   │   ├── fare/          # Train Fare Breakdown Screen
│   │   │   ├── history/       # Search History & Favorite Trains Screen
│   │   │   ├── live_traffic/  # Station Live Traffic Board Screen
│   │   │   ├── metro/         # Indian Metro Transit, Interactive Map & PDF Viewer
│   │   │   ├── pnr/           # PNR Enquiry & Passenger Status Screen
│   │   │   ├── schedule/      # National Live Radar Map Screen (2,000+ trains live)
│   │   │   └── station_info/  # Station Details, Helplines & Map Area Screen
│   │   ├── home/              # Apple iOS Bento Dashboard Screen
│   │   ├── splash/            # Splash Screen
│   │   ├── train_details/     # Live Train Tracking, Timeline & Crossing Tabs Screen
│   │   ├── train_map/         # Train GIS Map with animated pulse marker & speedometer
│   │   └── train_search/      # Trains Between Stations Search Screen
│   └── services/              # Business logic services (Train, Fare, PNR, Coach, Metro, Crashlytics)
└── pubspec.yaml               # Project dependencies & assets manifest
```

---

## ⚡ Core Feature Deep Dive

### 1. 📡 National Live Radar Map (`schedule_screen.dart`)
- Powered by `https://railradar.in/app/v1/live-map`.
- Plots **2,000+ active trains** across India on Google Maps Satellite Transit or CartoDB Dark layers.
- Custom train markers rotated according to exact `bearing` angle in degrees.
- Instant search camera focus for any train number or station code.
- Decodes route `encodedPolyline` to render the full track path on the map.

### 2. 🚆 Live Train Tracking & GIS Map (`train_details_screen.dart`, `train_map_screen.dart`)
- Real-time running status, current location, arrival/departure delays, and platform assignments.
- Exact station coordinate anchoring (`_trainLatLng`) when halted or at station, with smooth 3-second lerp animations when running.
- Dual Speedometer (`live_speed_card.dart`) supporting Mode 0 (Internet Telemetry) and Mode 1 (Device Onboard Satellite GPS).

### 3. 🔀 RailRadar Corridor Crossings (XING) (`train_crossing_view.dart`)
- RailRadar Corridor Ladder track UI displaying same-direction (`↓`) and opposite-direction (`↑`) passing trains along with current train location (`YOU`).

### 4. 🚨 National Disruption Alerts (`alerts_screen.dart`)
- Live national service alerts powered by `https://railradar.in/app/v1/trains/exceptions`.
- Summary metrics for Fully Cancelled, Partially Cancelled, Rescheduled, and Diverted trains.
- Filter chips and real-time train number/name search.

### 5. 🛋️ Aerodynamic Rakes & 2D Seat Maps (`coach_screen.dart`, `coach_seat_map_view.dart`)
- Aerodynamic Namo Bharat RRTS and Vande Bharat bullet train rake visualizers.
- Architectural class-specific seat maps for 1A, 2A, 3A, 3E, SL, EC, CC, 2S, GS.
- Direct seat number finder tool ("Find Seat #42") with smooth auto-scrolling to the target berth.

### 6. 🚇 Indian Metro Transit Systems (`metro_networks_screen.dart`)
- Multi-city route planner (Delhi NCR, Mumbai, Bengaluru, Kolkata, Chennai, Hyderabad, etc.).
- Calculates Fastest Route, Minimum Transfers, and Alternate Corridors.
- Interactive GIS map viewer and high-res PDF system map viewer.

---

## ⚙️ Getting Started & Installation

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (^3.12.2 or higher)
- [Android Studio](https://developer.android.com/studio) or VS Code with Flutter extension
- Java JDK 17

### Installation Steps

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/TransitGo.git
   cd TransitGo
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase & Local Environment:**
   - Place `google-services.json` inside the `android/app/` directory.
   - Place `.env.local` in the project root directory.

4. **Run the Application:**
   ```bash
   flutter run
   ```

---

## 🎨 Theme & Accessibility Design System

TransitGo strictly adheres to **Apple's Human Interface Guidelines**:
- **Light Mode**: Scaffold Background `#F2F2F7`, Card Background `#FFFFFF`, Primary Text `#1C1C1E`, Secondary Text `#636366` (WebAIM AAA contrast compliant).
- **Dark Mode**: Scaffold Background `#09090C`, Card Background `#16161C`, Primary Text `#FFFFFF`, Secondary Text `Colors.white54`.
- **System Accent**: Apple Blue `#0A84FF`, Green `#30D158`, Red `#FF375F`, Orange `#FF9F0A`.

---

## 📜 License & Acknowledgments

- **Data Sources**: Open Web APIs, MNTES Client Scraper, OpenStreetMap, CartoDB, and Google Maps Transit Tiles.
- **Iconography**: Apple Cupertino Icons (`cupertino_icons`).
