import 'dart:ui';
import 'package:flutter/material.dart';

import '../../core/theme/theme_controller.dart';

/// Ultra-Premium Apple HIG Glassmorphic Container with Frosted Glass Blur (`BackdropFilter`) & OLED Gradients.
class AppleGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double blurSigma;
  final LinearGradient? gradient;
  final Color? backgroundColor;
  final Border? border;
  final VoidCallback? onTap;

  const AppleGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.borderRadius,
    this.blurSigma = 12.0,
    this.gradient,
    this.backgroundColor,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDarkMode;
    final radius = borderRadius ?? BorderRadius.circular(22);

    // Apple HIG Light & OLED Dark Theme Glass Colors
    final defaultBgColor = backgroundColor ??
        (isDark
            ? const Color(0xFF101320).withValues(alpha: 0.82) // OLED Midnight Cyber Glass
            : const Color(0xFFFFFFFF).withValues(alpha: 0.88)); // Apple System White Frosted Glass

    final defaultBorder = border ??
        Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10) // Subtle glowing cyber stroke
              : const Color(0xFFE5E5EA), // Apple Light hairline border
          width: 1.0,
        );

    final cardChild = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: defaultBgColor,
            gradient: gradient ??
                (isDark
                    ? const LinearGradient(
                        colors: [
                          Color(0xFF141726),
                          Color(0xFF0C0E18),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [
                          Color(0xFFFFFFFF),
                          Color(0xFFF7F8FC),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )),
            borderRadius: radius,
            border: defaultBorder,
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withValues(alpha: 0.45) : const Color(0xFF0A84FF).withValues(alpha: 0.06),
                blurRadius: isDark ? 16 : 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (margin != null) {
      return Padding(
        padding: margin!,
        child: onTap != null
            ? Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: radius,
                  child: cardChild,
                ),
              )
            : cardChild,
      );
    }

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: cardChild,
        ),
      );
    }

    return cardChild;
  }
}
