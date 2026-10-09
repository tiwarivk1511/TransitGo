import 'dart:ui';
import 'package:flutter/material.dart';

import '../../core/theme/theme_controller.dart';

/// Ultra-Modern Apple HIG Ambient Mesh Gradient Background with Glowing Ambient Light Orbs & Glassmorphic Depth.
class ModernBackground extends StatelessWidget {
  final Widget child;

  const ModernBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDarkMode;

    return Stack(
      children: [
        // Base Ambient Gradient Mesh
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? const LinearGradient(
                      colors: [
                        Color(0xFF030408), // Cyber Deep Pitch Black
                        Color(0xFF090C18), // Deep Space Midnight Blue
                        Color(0xFF0F0D20), // Subtle Deep Indigo Purple
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [
                        Color(0xFFF4F5FB), // Apple Light Soft Sky
                        Color(0xFFEBF1FD), // Light Cyber Ice Blue
                        Color(0xFFF3F0FD), // Light Lavender Fog
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
            ),
          ),
        ),

        // Glowing Ambient Orb 1 (Top Left)
        Positioned(
          top: -60,
          left: -60,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? const Color(0xFF0A84FF).withValues(alpha: 0.18) // Electric Blue Glow
                  : const Color(0xFF007AFF).withValues(alpha: 0.15),
            ),
          ),
        ),

        // Glowing Ambient Orb 2 (Top Right)
        Positioned(
          top: 120,
          right: -80,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? const Color(0xFF5E5CE6).withValues(alpha: 0.15) // Deep Indigo Glow
                  : const Color(0xFF5856D6).withValues(alpha: 0.12),
            ),
          ),
        ),

        // Glowing Ambient Orb 3 (Bottom Left)
        Positioned(
          bottom: -80,
          left: -40,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? const Color(0xFF30D158).withValues(alpha: 0.08) // Mint Green Glow
                  : const Color(0xFF34C759).withValues(alpha: 0.08),
            ),
          ),
        ),

        // Frosted Glass Blur Layer over Glowing Ambient Orbs
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: const SizedBox.expand(),
          ),
        ),

        // Content Body
        Positioned.fill(
          child: child,
        ),
      ],
    );
  }
}
