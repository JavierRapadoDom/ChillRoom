import 'package:flutter/material.dart';

enum SuperInterest { none, music, football, gaming }

class SuperInterestThemeConf {
  final SuperInterest kind;
  final Color primary;
  final Color secondary;
  final Color textOnDark;
  final List<Color> bgGradient;
  final IconData badgeIcon;
  final List<IconData> confettiIcons;

  const SuperInterestThemeConf({
    required this.kind,
    required this.primary,
    required this.secondary,
    required this.textOnDark,
    required this.bgGradient,
    required this.badgeIcon,
    required this.confettiIcons,
  });

  LinearGradient headerOverlay() => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      primary.withOpacity(.18),
      primary.withOpacity(.10),
      Colors.transparent,
      secondary.withOpacity(.74),
    ],
    stops: const [.0, .25, .55, 1],
  );

  RadialGradient backgroundPattern() => RadialGradient(
    radius: 1.2,
    center: const Alignment(-.85, -.95),
    colors: [
      primary.withOpacity(.12),
      Colors.transparent,
    ],
    stops: const [.0, 1],
  );

  static SuperInterestThemeConf fromString(String? raw) {
    switch ((raw ?? 'none').toLowerCase()) {
      case 'music':
        return const SuperInterestThemeConf(
          kind: SuperInterest.music,
          primary: Color(0xFF1DB954),
          secondary: Color(0xFF0E1118),
          textOnDark: Colors.white,
          bgGradient: [Color(0xFF0E1118), Color(0xFF0B0D12)],
          badgeIcon: Icons.music_note_rounded,
          confettiIcons: [Icons.music_note, Icons.audiotrack, Icons.graphic_eq],
        );
      case 'football':
        return const SuperInterestThemeConf(
          kind: SuperInterest.football,
          primary: Color(0xFF2DB84C),
          secondary: Color(0xFF0F1A0F),
          textOnDark: Colors.white,
          bgGradient: [Color(0xFF0F1A0F), Color(0xFF0A120A)],
          badgeIcon: Icons.sports_soccer,
          confettiIcons: [Icons.sports_soccer, Icons.flag, Icons.sports],
        );
      case 'gaming':
        return const SuperInterestThemeConf(
          kind: SuperInterest.gaming,
          primary: Color(0xFF8A5CF6),
          secondary: Color(0xFF141024),
          textOnDark: Colors.white,
          bgGradient: [Color(0xFF151229), Color(0xFF0F0C1E)],
          badgeIcon: Icons.sports_esports,
          confettiIcons: [Icons.sports_esports, Icons.bolt, Icons.memory],
        );
      default:
        return const SuperInterestThemeConf(
          kind: SuperInterest.none,
          primary: Color(0xFFE3A62F),
          secondary: Color(0xFF222222),
          textOnDark: Colors.white,
          bgGradient: [Color(0xFFFFFFFF), Color(0xFFF7F7F7)],
          badgeIcon: Icons.star_rounded,
          confettiIcons: [Icons.star_rate_rounded, Icons.favorite_border, Icons.local_fire_department],
        );
    }
  }
}
