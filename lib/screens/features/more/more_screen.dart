import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../components/common/feature_intro.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../data/sources/station_source.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDarkMode;
    final bgColor = isDark ? const Color(0xFF09090C) : const Color(0xFFF2F2F7);
    final cardColor = isDark ? const Color(0xFF16161C) : const Color(0xFFFFFFFF);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? Colors.white54 : const Color(0xFF8E8E93);
    final borderCol = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E5EA);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'More',
          style: GoogleFonts.inter(
            color: textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_stars_fill,
              color: isDark ? const Color(0xFFFFD60A) : const Color(0xFF0A84FF),
              size: 18,
            ),
            onPressed: () {
              setState(() {
                ThemeController.instance.toggleTheme();
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          children: [
            FeatureIntro(
              title: 'More for\nyour journey.',
              subtitle: 'Helpful tools and information, all in one place.',
              icon: CupertinoIcons.sparkles,
              accent: const Color(0xFF0A84FF),
            ),

            // APPEARANCE SECTION
            Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 6),
              child: Text(
                'APPEARANCE & THEME',
                style: GoogleFonts.inter(
                  color: textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
            _themeToggleTile(context, cardColor, textPrimary, textSecondary, borderCol, isDark),

            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'SYSTEM & INFO',
                style: GoogleFonts.inter(
                  color: textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
            _tile(
              context,
              CupertinoIcons.info_circle,
              'About TransitGo',
              'Offline-first live railway & metro tracking',
              const Color(0xFF0A84FF),
              cardColor,
              textPrimary,
              textSecondary,
              borderCol,
            ),
            _tile(
              context,
              CupertinoIcons.tray_2_fill,
              'Offline Data',
              '${StationSource.count} stations bundled',
              const Color(0xFF64D2FF),
              cardColor,
              textPrimary,
              textSecondary,
              borderCol,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'SUPPORT & DISCOVER',
                style: GoogleFonts.inter(
                  color: textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
            _tile(
              context,
              CupertinoIcons.star_fill,
              'Rate us',
              'Rate on Play Store',
              const Color(0xFFFFD60A),
              cardColor,
              textPrimary,
              textSecondary,
              borderCol,
            ),
            _tile(
              context,
              CupertinoIcons.share_solid,
              'Share',
              'Invite your friends',
              const Color(0xFF30D158),
              cardColor,
              textPrimary,
              textSecondary,
              borderCol,
            ),
            _tile(
              context,
              CupertinoIcons.shield_fill,
              'Privacy Policy',
              'How we handle your data',
              const Color(0xFF5E5CE6),
              cardColor,
              textPrimary,
              textSecondary,
              borderCol,
            ),
            _tile(
              context,
              CupertinoIcons.question_circle_fill,
              'Help & Support',
              'Facing an issue? Contact us',
              const Color(0xFFFF375F),
              cardColor,
              textPrimary,
              textSecondary,
              borderCol,
            ),
          ],
        ),
      ),
    );
  }

  Widget _themeToggleTile(BuildContext c, Color cardColor, Color textPrimary, Color textSecondary, Color borderCol, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderCol),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFFFFD60A) : const Color(0xFF0A84FF)).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              isDark ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_stars_fill,
              color: isDark ? const Color(0xFFFFD60A) : const Color(0xFF0A84FF),
              size: 20,
            ),
          ),
          title: Text(
            'Theme Mode',
            style: GoogleFonts.inter(
              color: textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          subtitle: Text(
            isDark ? 'Dark OLED Mode Enabled' : 'Light Mode Enabled',
            style: GoogleFonts.inter(color: textSecondary, fontSize: 10),
          ),
          trailing: CupertinoSwitch(
            value: !isDark,
            activeColor: const Color(0xFF0A84FF),
            onChanged: (_) {
              setState(() {
                ThemeController.instance.toggleTheme();
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext c,
    IconData i,
    String t,
    String s,
    Color accent,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderCol,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderCol),
          ),
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 4,
              ),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(i, color: accent, size: 20),
              ),
              title: Text(
                t,
                style: GoogleFonts.inter(
                  color: textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  s,
                  style: GoogleFonts.inter(color: textSecondary, fontSize: 10),
                ),
              ),
              trailing: Icon(
                CupertinoIcons.chevron_right,
                color: textSecondary,
                size: 14,
              ),
              onTap: () {},
            ),
          ),
        ),
      );
}
