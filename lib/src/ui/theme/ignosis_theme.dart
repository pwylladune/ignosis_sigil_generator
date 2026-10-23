import 'package:flutter/material.dart';

/// Scandinavian Architectural / Minimalist Pen & Ink Palette
class IgnosisTheme {
  // Canvas & Surfaces (soft parchment whites & museum board tones)
  static const Color paperWhite = Color(0xFFF9F9F6);       // Clean archival paper
  static const Color bone = Color(0xFFF4F4F0);             // Background board
  static const Color parchmentSubtle = Color(0xFFEBEBE5); // Inactive border / divider
  static const Color surfaceElevated = Color(0xFFFFFFFF);  // Pure card surface

  // Inks (high precision architectural black & wash tones)
  static const Color sumiInk = Color(0xFF141416);          // Pure deep drafting ink
  static const Color charcoal = Color(0xFF38383E);         // Secondary text / structure
  static const Color pencilGraphite = Color(0xFF71717A);  // Subtle annotations / coordinates
  static const Color wash = Color(0xFFA1A1AA);            // Inactive guides & grids

  // Energetic Accent (Subtle Vermilion & Burn Ochre)
  static const Color vermilion = Color(0xFFC0392B);        // Alchemical red / seal accent
  static const Color cinderAmber = Color(0xFFD97706);      // Active flame / combustion edge
  static const Color lapisBlue = Color(0xFF2563EB);        // Subtle astronomical blue

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bone,
      colorScheme: const ColorScheme.light(
        primary: sumiInk,
        secondary: vermilion,
        surface: surfaceElevated,
        onSurface: sumiInk,
      ),
      fontFamily: '-apple-system',
      appBarTheme: const AppBarTheme(
        backgroundColor: bone,
        foregroundColor: sumiInk,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}
