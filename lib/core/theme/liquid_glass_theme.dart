import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class LiquidGlassTheme {
  // Apple Music Signature Red & Pure OLED Black
  static const Color accentRed = Color(0xFFFA2D48);
  static const Color accentRedLight = Color(0xFFFF375F);
  static const Color darkBackground = Color(0xFF000000); // Pure OLED Black
  static const Color darkSurface = Color(0xFF101116);
  static const Color surfaceCard = Color(0xFF161820);
  
  // Glass Tint Constants
  static const Color glassWhite = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0x99FFFFFF); // 60% opacity
  static const Color textTertiary = Color(0x4DFFFFFF);  // 30% opacity

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBackground,
    primaryColor: accentRed,
    colorScheme: const ColorScheme.dark(
      primary: accentRed,
      secondary: accentRedLight,
      surface: darkSurface,
      surfaceContainerHighest: surfaceCard,
      onPrimary: Colors.white,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
    ),
    cupertinoOverrideTheme: const CupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: accentRed,
      barBackgroundColor: Colors.transparent,
      scaffoldBackgroundColor: darkBackground,
    ),
  );
}
