import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'brand_config.dart';

class AppTheme {
  // Compile-time safe default constants (used in static const widgets & fallbacks)
  static const Color primaryNavy = Color(0xFF083B4C); // Deep Arya Teal
  static const Color primaryBlue = Color(0xFF0B4F60); // Secondary Teal
  static const Color primaryTeal = Color(0xFF083B4C);
  static const Color goldAccent = Color(0xFFC58B2B); // Rich Metallic Gold
  static const Color backgroundLight = Color(0xFFF8FAF9); // Off-white
  static const Color surfaceWhite = Colors.white;
  static const Color primaryDark = Color(0xFF041B23); // Deep Black/Teal

  // Dynamic runtime brand colors
  static Color get dynamicPrimary => BrandConfig.primaryColor;
  static Color get dynamicAccent => BrandConfig.accentColor;
  static Color get dynamicBackground => BrandConfig.backgroundColor;

  // Status colors (always paired with text label + icon)
  static const Color statusGreen = Color(0xFF166534); // Confirmed Paid
  static const Color statusYellow = Color(0xFFD97706); // Pending Confirmation
  static const Color statusOrange = Color(0xFFEA580C); // Partial Paid
  static const Color statusRed = Color(0xFFDC2626); // Overdue / Pending
  static const Color statusGrey = Color(0xFF64748B); // Adjusted against advance

  static ThemeData get lightTheme {
    final baseTextTheme = ThemeData.light().textTheme;
    final jakartaTextTheme = GoogleFonts.plusJakartaSansTextTheme(baseTextTheme);

    final primary = BrandConfig.primaryColor;
    final accent = BrandConfig.accentColor;

    return ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      textTheme: jakartaTextTheme,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: accent,
        surface: backgroundLight,
      ),
      scaffoldBackgroundColor: backgroundLight,
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 2,
        shadowColor: Colors.black.withAlpha(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        labelStyle: TextStyle(
          color: const Color(0xFF475569),
          fontWeight: FontWeight.w600,
          fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
