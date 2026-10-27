import 'package:flutter/material.dart';

class AppleTheme {
  // Apple Palette
  static const Color backgroundDark = Color(0xFF0D0E12);
  static const Color surfaceDark = Color(0xFF161820);
  static const Color cardDark = Color(0x991E212D);
  static const Color borderDark = Color(0x33FFFFFF);
  
  static const Color accentBlue = Color(0xFF0A84FF);
  static const Color accentPurple = Color(0xFFBF5AF2);
  static const Color accentIndigo = Color(0xFF5E5CE6);
  static const Color accentTeal = Color(0xFF64D2FF);
  static const Color accentGreen = Color(0xFF30D158);
  static const Color accentOrange = Color(0xFFFF9F0A);
  static const Color accentRed = Color(0xFFFF453A);
  
  static const Color textPrimary = Color(0xFFF5F5F7);
  static const Color textSecondary = Color(0xFF98989F);
  static const Color textTertiary = Color(0xFF636366);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundDark,
      primaryColor: accentBlue,
      fontFamily: 'SF Pro Display', // Falls back smoothly to platform default
      colorScheme: const ColorScheme.dark(
        primary: accentBlue,
        secondary: accentPurple,
        surface: surfaceDark,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderDark, width: 0.5),
        ),
      ),
    );
  }
}
