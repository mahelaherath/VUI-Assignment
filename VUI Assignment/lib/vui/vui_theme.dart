import 'package:flutter/material.dart';

class VuiTheme {
  // Brand Colors (Strictly matching the visual design markers)
  static const Color background = Color(0xFF0C0D0E);
  static const Color cardBg = Color(0xFF161719);
  static const Color chatBubbleSera = Color(0xFF1E1F22);
  static const Color chatBubbleYou = Color(0xFF2B2C30);
  
  // Module-specific Accent Colors
  static const Color moodColor = Color(0xFF9D8DF4);      // Sera Purple
  static const Color listeningColor = Color(0xFF10B981); // Emerald Teal
  static const Color sleepColor = Color(0xFF3B82F6);     // Soft Blue
  static const Color breathingColor = Color(0xFF10B981); // Calming Green
  static const Color crisisColor = Color(0xFFEF4444);    // Distress Crimson

  // Text Colors
  static const Color textPrimary = Color(0xFFF3F4F6);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);

  // App-wide dark theme
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: background,
      cardColor: cardBg,
      primaryColor: moodColor,
      colorScheme: const ColorScheme.dark().copyWith(
        primary: moodColor,
        secondary: listeningColor,
        error: crisisColor,
        surface: cardBg,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
