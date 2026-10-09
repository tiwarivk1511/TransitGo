import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/common/modern_background.dart';
import '../../core/theme/theme_controller.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, anim1, anim2) => const HomeScreen(),
            transitionsBuilder: (context, anim1, anim2, child) =>
                FadeTransition(opacity: anim1, child: child),
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final isDark = ThemeController.instance.isDarkMode;
        final bgColor = isDark
            ? const Color(0xFF09090C)
            : const Color(0xFFF2F2F7);
        final logoBg = isDark
            ? const Color(0xFF16161C)
            : const Color(0xFFFFFFFF);
        final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
        final textSecondary = isDark ? Colors.white38 : const Color(0xFF8E8E93);
        final borderCol = isDark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFFE5E5EA);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: ModernBackground(
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Ultra Premium Logo Emblem with Ambient Glow
                      Container(
                        width: 100,
                        height: 100,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: logoBg,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: borderCol, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF0A84FF,
                              ).withValues(alpha: isDark ? 0.25 : 0.12),
                              blurRadius: 36,
                              spreadRadius: 4,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ).animate().scale(
                        duration: 800.ms,
                        curve: Curves.easeOutBack,
                      ),

                      const SizedBox(height: 28),

                      // App Brand Name
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Transit',
                            style: GoogleFonts.inter(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: textPrimary,
                              letterSpacing: -1.2,
                            ),
                          ),
                          Text(
                            'GO',
                            style: GoogleFonts.inter(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0A84FF),
                              letterSpacing: -1.2,
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

                      const SizedBox(height: 6),

                      // Tagline Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF0A84FF,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'INDIAN RAILWAYS & METROS LIVE',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0A84FF),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ).animate().fadeIn(delay: 400.ms),
                    ],
                  ),
                ),

                // Bottom Progress & Version Badge
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF0A84FF),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'v2.5.0 • Powered by HyperLogics InfoTech',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 600.ms),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
