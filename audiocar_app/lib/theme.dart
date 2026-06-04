import 'package:flutter/material.dart';

/// Paleta do cockpit AUDIOCAR.
class CockpitColors {
  static const Color background = Color(0xFF0B0E13);
  static const Color panel = Color(0xFF141A22);
  static const Color accent = Color(0xFF18A0FB);
  static const Color accentSoft = Color(0xFF1F4E79);
  static const Color redline = Color(0xFFE53935);
  static const Color textPrimary = Color(0xFFF2F5F8);
  static const Color textMuted = Color(0xFF8A97A6);
  static const Color gaugeTrack = Color(0xFF232C38);
}

ThemeData buildAudioCarTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: CockpitColors.background,
    colorScheme: const ColorScheme.dark(
      primary: CockpitColors.accent,
      surface: CockpitColors.panel,
    ),
    fontFamily: 'Roboto',
    useMaterial3: true,
  );
}
