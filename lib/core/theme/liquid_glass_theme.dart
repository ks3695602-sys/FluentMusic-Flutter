import 'package:flutter/material.dart';

class LiquidGlassTheme {
  static const Color darkBackground = Color(0xFF090A0F);
  static const Color darkSurface = Color(0xFF13151F);
  static const Color glassWhite = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);
  static const Color accentNeon = Color(0xFF6C5CE7);
  static const Color accentCyan = Color(0xFF00CEC9);
  static const Color textPrimary = Color(0xFFF1F2F6);
  static const Color textSecondary = Color(0xFFA4B0BE);

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: accentNeon,
      secondary: accentCyan,
      surface: darkSurface,
      surfaceContainerHighest: Color(0xFF1E2130),
      onPrimary: Colors.white,
      onSurface: textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
  );
}
