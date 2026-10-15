/// App Translations Key Registry.
class AppTranslations {
  static const Map<String, Map<String, String>> keys = {
    'en': {
      'app_title': 'TransitGO',
      'app_subtitle': 'Indian Railways & Metros Live',
      'select_language': 'Select Language',
      'choose_preferred_language': 'Choose your preferred language for transit navigation',
      'continue_btn': 'Continue',
      'plan_next_journey': 'Plan your next train journey',
      'find_trains_subtitle': 'Find trains, track live status, and explore metro lines.',
      'plan_a_journey': 'PLAN A JOURNEY',
      'origin_station': 'Origin Station',
      'destination_station': 'Destination Station',
      'swap': 'Swap',
      'find_trains': 'Find Trains',
      'track_a_train': 'Track a train',
      'track_train_subtitle': 'Get live running status by name or number',
      'track_train_btn': 'Track Train',
      'explore_transitgo': 'Explore TransitGo',
      'explore_subtitle': 'Everything you need for your journey',
      'pnr_status': 'PNR Status',
      'pnr_subtitle': 'Check booking & seat status',
      'live_station': 'Live Station',
      'live_station_subtitle': 'Real-time train arrivals',
      'live_radar_map': 'Live Radar Map',
      'radar_subtitle': '2000+ trains on GIS map',
      'coach_position': 'Coach Position',
      'coach_subtitle': 'Platform & rake layout',
      'train_fare': 'Train Fare',
      'fare_subtitle': 'Class & ticket prices',
      'metro_networks': 'Metro Networks',
      'metro_subtitle': 'City lines & fares',
      'station_details': 'Station Details',
      'station_details_subtitle': 'Facilities & helpline',
      'history': 'History',
      'history_subtitle': 'Recent searches',
      'more_features': 'More Features',
      'more_subtitle': 'Settings & tools',
      'settings_language': 'Language / भाषा',
      'change_app_language': 'Change app language',
      'theme_mode': 'Appearance Theme',
      'live_badge': 'LIVE',
    },
  };

  /// Returns translated string or English fallback.
  static String translate(String keyOrText, String langCode) {
    return keys['en']?[keyOrText] ?? keyOrText;
  }
}
