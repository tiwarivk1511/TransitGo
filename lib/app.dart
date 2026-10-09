import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/theme/theme_controller.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/startup_error_screen.dart';
import 'services/analytics_service.dart';

class TransitGoApp extends StatelessWidget {
  final String? startupError;

  const TransitGoApp({super.key, this.startupError});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'TransitGo',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeController.instance.themeMode,

          navigatorObservers: [
            if (AnalyticsService.observer != null) AnalyticsService.observer!,
          ],

          // ☀️ APPLE LIGHT THEME
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF2F2F7), // iOS Grouped Light Grey
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF007AFF), // Apple System Blue Light
              secondary: Color(0xFF34C759), // Apple Mint Green Light
              surface: Color(0xFFFFFFFF), // Pure White Glass
              surfaceContainer: Color(0xFFE5E5EA),
              error: Color(0xFFFF3B30), // Apple Red Light
            ),
            textTheme: GoogleFonts.interTextTheme(
              ThemeData.light().textTheme,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFF2F2F7),
              elevation: 0,
              iconTheme: IconThemeData(color: Color(0xFF1C1C1E)),
              systemOverlayStyle: SystemUiOverlayStyle.dark,
              titleTextStyle: TextStyle(
                color: Color(0xFF1C1C1E),
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            cardTheme: CardThemeData(
              color: const Color(0xFFFFFFFF),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFFE5E5EA)),
              ),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: const Color(0xFFFFFFFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            bottomSheetTheme: const BottomSheetThemeData(
              backgroundColor: Color(0xFFFFFFFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
            ),
          ),

          // 🌙 OBSIDIAN MIDNIGHT OLED DARK THEME
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF030305), // Pure OLED Deep Pitch Black
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF0A84FF), // Vivid Electric Blue Pro
              secondary: Color(0xFF30D158), // Neon Mint Emerald Green
              surface: Color(0xFF10121A), // Cyber Glass Card
              surfaceContainer: Color(0xFF181B26), // Elevated Input Surface
              error: Color(0xFFFF375F), // Crimson Rose Red Pro
            ),
            textTheme: GoogleFonts.interTextTheme(
              ThemeData.dark().textTheme,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF030305),
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.white),
              systemOverlayStyle: SystemUiOverlayStyle.light,
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
            cardTheme: CardThemeData(
              color: const Color(0xFF10121A),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: const BorderSide(color: Color(0xFF222638)),
              ),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: const Color(0xFF10121A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xFF222638)),
              ),
            ),
            bottomSheetTheme: const BottomSheetThemeData(
              backgroundColor: Color(0xFF10121A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
            ),
          ),

          home: startupError == null
              ? const SplashScreen()
              : StartupErrorScreen(message: startupError!),
        );
      },
    );
  }
}
