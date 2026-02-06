import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Light Mode Colors (Elegant Vellum)
  static const Color lightBackground = Color(0xFFF9F7F2); // Warm Off-White
  static const Color lightPrimary = Color(0xFF2D2D2D); // Soft Charcoal (Ink)
  static const Color lightSecondary = Color(0xFFC07C5D); // Muted Terracotta
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightOnSurface = Color(0xFF2D2D2D);

  // Dark Mode Colors (Deep Midnight)
  static const Color darkBackground = Color(0xFF121212); // Deep Matte Black
  static const Color darkPrimary = Color(0xFFE6E1E5); // Soft Platinum
  static const Color darkSecondary = Color(0xFFD4AF37); // Antique Gold
  static const Color darkSurface = Color(0xFF1E1E1E); // Dark Grey Surface
  static const Color darkOnSurface = Color(0xFFE6E1E5); // Soft Platinum text

  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: lightPrimary,
        secondary: lightSecondary,
        surface: lightSurface,
        onSurface: lightOnSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        outline: Color(0xFF79747E),
        surfaceVariant: Color(0xFFE7E0EC),
        onSurfaceVariant: Color(0xFF49454F),
      ),
      
      // Typography
      textTheme: _buildTextTheme(lightOnSurface),
      
      appBarTheme: AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: lightPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.libreBaskerville(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: lightPrimary,
        ),
      ),
      
      cardTheme: const CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      
      elevatedButtonTheme: _buttonTheme(lightPrimary, Colors.white),
      filledButtonTheme: _filledButtonTheme(lightPrimary, Colors.white),
      outlinedButtonTheme: _outlinedButtonTheme(lightPrimary),
      inputDecorationTheme: _inputDecorationTheme(lightOnSurface),
    );
  }

  // Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: darkSecondary, // Gold as primary interaction color for luxury feel
        secondary: darkPrimary,
        surface: darkSurface,
        onSurface: darkOnSurface,
        onPrimary: Colors.black, // Text on Gold should be dark
        onSecondary: darkBackground,
        outline: Color(0xFF938F99),
        surfaceVariant: Color(0xFF49454F),
        onSurfaceVariant: Color(0xFFCAC4D0),
      ),
      
      textTheme: _buildTextTheme(darkOnSurface),
      
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkOnSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.libreBaskerville(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: darkOnSurface,
        ),
      ),
      
      cardTheme: const CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Color(0xFF333333)),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      
      elevatedButtonTheme: _buttonTheme(darkSecondary, Colors.black),
      filledButtonTheme: _filledButtonTheme(darkSecondary, Colors.black),
      outlinedButtonTheme: _outlinedButtonTheme(darkSecondary),
      inputDecorationTheme: _inputDecorationTheme(darkOnSurface),
    );
  }

  static TextTheme _buildTextTheme(Color color) {
    return TextTheme(
      displayLarge: GoogleFonts.libreBaskerville(fontSize: 32, fontWeight: FontWeight.bold, color: color),
      displayMedium: GoogleFonts.libreBaskerville(fontSize: 28, fontWeight: FontWeight.bold, color: color),
      displaySmall: GoogleFonts.libreBaskerville(fontSize: 24, fontWeight: FontWeight.bold, color: color),
      headlineLarge: GoogleFonts.libreBaskerville(fontSize: 22, fontWeight: FontWeight.w600, color: color),
      headlineMedium: GoogleFonts.libreBaskerville(fontSize: 20, fontWeight: FontWeight.w600, color: color),
      headlineSmall: GoogleFonts.libreBaskerville(fontSize: 18, fontWeight: FontWeight.w600, color: color),
      titleLarge: GoogleFonts.libreBaskerville(fontSize: 16, fontWeight: FontWeight.w600, color: color),
      titleMedium: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w500, color: color),
      bodyLarge: GoogleFonts.lato(fontSize: 16, color: color),
      bodyMedium: GoogleFonts.lato(fontSize: 14, color: color.withOpacity(0.8)),
      bodySmall: GoogleFonts.lato(fontSize: 12, color: color.withOpacity(0.6)),
      labelLarge: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w600, color: color),
    );
  }

  static ElevatedButtonThemeData _buttonTheme(Color bg, Color validText) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: validText,
        textStyle: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }
  
  static FilledButtonThemeData _filledButtonTheme(Color bg, Color validText) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: validText,
        textStyle: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(Color color) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.5)),
        textStyle: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static InputDecorationTheme _inputDecorationTheme(Color color) {
    return InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color.withOpacity(0.2))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color.withOpacity(0.2))),
      filled: true,
      fillColor: color.withOpacity(0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: GoogleFonts.lato(color: color.withOpacity(0.4)),
    );
  }
}
