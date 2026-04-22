// lib/utils/theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // ── Colors ────────────────────────────────────────────────────────────────
  static const Color primary        = Color(0xFF0A192F);
  static const Color primaryLight   = Color(0xFF112240);
  static const Color accent         = Color(0xFF64FFDA);
  static const Color accentDim      = Color(0xFF1DE9B6);
  static const Color danger         = Color(0xFFFF5370);
  static const Color warning        = Color(0xFFFFCB6B);
  static const Color success        = Color(0xFFA8FF78);
  static const Color textPrimary    = Color(0xFFCCD6F6);
  static const Color textSecondary  = Color(0xFF8892B0);
  static const Color surface        = Color(0xFF112240);
  static const Color surfaceLight   = Color(0xFF1D3461);
  static const Color cardBg         = Color(0xFF172A45);

  // ── Risk colours ─────────────────────────────────────────────────────────
  static Color riskColor(double score) {
    if (score >= 0.7) return danger;
    if (score >= 0.4) return warning;
    return success;
  }

  static String riskLabel(double score) {
    if (score >= 0.7) return 'HIGH RISK';
    if (score >= 0.4) return 'MEDIUM RISK';
    return 'LOW RISK';
  }

  // ── ThemeData ─────────────────────────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: primary,
    primaryColor: accent,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      secondary: accentDim,
      surface: surface,
      error: danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: textPrimary,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: cardBg,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: accent, width: 1.5),
      ),
      labelStyle: const TextStyle(color: textSecondary),
      hintStyle: const TextStyle(color: textSecondary),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: primaryLight,
      selectedItemColor: accent,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
      displayMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(color: textPrimary),
      bodyMedium: TextStyle(color: textSecondary),
      labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
    ),
    dividerColor: surfaceLight,
    iconTheme: const IconThemeData(color: textSecondary),
  );
}
