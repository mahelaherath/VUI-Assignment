import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VuiTheme {
  // Brand Colors
  static const Color background = Color(0xFF0F1016);
  static const Color cardBg = Color(0xFF1A1A2E);
  static const Color chatBubbleSera = Color(0xFF1E1F22);
  static const Color chatBubbleYou = Color(0xFF2B2C30);

  // Module-specific Accent Colors
  static const Color moodColor = Color(0xFF7F77DD);      // Sera Purple
  static const Color listeningColor = Color(0xFF10B981); // Emerald Teal
  static const Color sleepColor = Color(0xFF378ADD);     // Soft Blue
  static const Color breathingColor = Color(0xFF1D9E75); // Calming Green
  static const Color crisisColor = Color(0xFFE24B4A);    // Distress Crimson

  // Text Colors
  static const Color textPrimary = Color(0xFFF3F4F6);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);

  // App-wide dark theme
  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: background,
      cardColor: cardBg,
      primaryColor: moodColor,
      colorScheme: const ColorScheme.dark().copyWith(
        primary: moodColor,
        secondary: listeningColor,
        error: crisisColor,
        surface: cardBg,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).copyWith(
        headlineMedium: GoogleFonts.dmSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        bodyLarge: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.4,
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        labelLarge: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textMuted,
          letterSpacing: 0.5,
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: background,
        selectedItemColor: moodColor,
        unselectedItemColor: Color(0x40FFFFFF),
        selectedLabelStyle: TextStyle(fontSize: 10),
        unselectedLabelStyle: TextStyle(fontSize: 10),
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
