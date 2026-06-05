import 'package:flutter/material.dart';

/// Paleta do cockpit AUDIOCAR — branco com dourado.
class CockpitColors {
  static const Color background = Color(0xFFF6F3EC); // off-white quente
  static const Color panel = Color(0xFFFFFFFF); // cartões brancos
  static const Color accent = Color(0xFFC2972E); // dourado
  static const Color accentSoft = Color(0xFFE8D7A8); // dourado claro
  static const Color gold = Color(0xFFC2972E);
  static const Color goldDeep = Color(0xFF9C7A1C);
  static const Color redline = Color(0xFFC0392B);
  static const Color textPrimary = Color(0xFF211E16); // quase preto
  static const Color textMuted = Color(0xFF8C8572); // marrom suave
  static const Color gaugeTrack = Color(0xFFEAE4D6); // trilha clara
}

ThemeData buildAudioCarTheme() {
  return ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: CockpitColors.background,
    colorScheme: const ColorScheme.light(
      primary: CockpitColors.accent,
      onPrimary: Colors.white,
      secondary: CockpitColors.accent,
      secondaryContainer: CockpitColors.accentSoft,
      onSecondaryContainer: CockpitColors.textPrimary,
      surface: CockpitColors.panel,
      onSurface: CockpitColors.textPrimary,
    ),
    fontFamily: 'Roboto',
    useMaterial3: true,
  );
}
