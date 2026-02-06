/// Vellum Design System - Color Reference
/// 
/// This file documents all colors used in the Vellum app.
/// DO NOT modify these values without updating app_theme.dart

library;

import 'package:flutter/material.dart';

/// Light Mode Colors (UI Mode)
class VellumLightColors {
  /// Cream Paper - Main background color
  /// Usage: Scaffold background, main UI surfaces
  static const Color background = Color(0xFFFDF8F0);
  
  /// Coffee Ink - Primary brand color
  /// Usage: Text, icons, AppBar, buttons
  static const Color primary = Color(0xFF4E342E);
  
  /// White - Surface color
  /// Usage: Cards, elevated surfaces
  static const Color surface = Color(0xFFFFFFFF);
  
  /// Coffee Ink - Text on background
  static const Color onBackground = Color(0xFF4E342E);
  
  /// Coffee Ink - Text on surface
  static const Color onSurface = Color(0xFF4E342E);
  
  /// White - Text on primary
  static const Color onPrimary = Color(0xFFFFFFFF);
}

/// Dark Mode Colors (Reading Mode)
class VellumDarkColors {
  /// OLED Black - Main background for reading
  /// Usage: Scaffold background, reduces eye strain
  static const Color background = Color(0xFF000000);
  
  /// Soft White - Primary text color
  /// Usage: Text, icons
  static const Color text = Color(0xFFE0E0E0);
  
  /// Dark Surface - Elevated surfaces
  /// Usage: Cards, dialogs
  static const Color surface = Color(0xFF1A1A1A);
  
  /// Soft White - Primary brand color in dark mode
  static const Color primary = Color(0xFFE0E0E0);
  
  /// OLED Black - Text on primary
  static const Color onPrimary = Color(0xFF000000);
}

/// Earth-tone colors for book covers
/// These are randomly assigned when a book is added
class VellumBookCoverColors {
  static const List<String> earthTones = [
    '#8D6E63', // Medium Brown
    '#5D4037', // Dark Brown
    '#795548', // Brown
    '#6D4C41', // Deep Brown
    '#4E342E', // Coffee Brown (matches primary)
    '#A1887F', // Light Brown
    '#BCAAA4', // Beige
    '#8B7355', // Tan
    '#7B6B5D', // Taupe
    '#9E8B7E', // Warm Gray
  ];
  
  /// Get a Color object from hex string
  static Color fromHex(String hexString) {
    return Color(int.parse(hexString.replaceFirst('#', '0xFF')));
  }
  
  /// Get all colors as Color objects
  static List<Color> get allColors {
    return earthTones.map((hex) => fromHex(hex)).toList();
  }
}

/// Typography Colors
class VellumTypographyColors {
  /// Primary text color (light mode)
  static const Color primaryText = Color(0xFF4E342E);
  
  /// Secondary text color (light mode) - 60% opacity
  static const Color secondaryText = Color(0x994E342E);
  
  /// Disabled text color (light mode) - 38% opacity
  static const Color disabledText = Color(0x614E342E);
  
  /// Primary text color (dark mode)
  static const Color primaryTextDark = Color(0xFFE0E0E0);
  
  /// Secondary text color (dark mode) - 60% opacity
  static const Color secondaryTextDark = Color(0x99E0E0E0);
  
  /// Disabled text color (dark mode) - 38% opacity
  static const Color disabledTextDark = Color(0x61E0E0E0);
}

/// Semantic Colors (for feedback, alerts, etc.)
class VellumSemanticColors {
  /// Success color
  static const Color success = Color(0xFF4CAF50);
  
  /// Error color
  static const Color error = Color(0xFFD32F2F);
  
  /// Warning color
  static const Color warning = Color(0xFFFFA726);
  
  /// Info color
  static const Color info = Color(0xFF2196F3);
}

/// Usage Examples:
/// 
/// ```dart
/// // Using in a widget
/// Container(
///   color: VellumLightColors.background,
///   child: Text(
///     'Hello',
///     style: TextStyle(color: VellumLightColors.primary),
///   ),
/// )
/// 
/// // Using book cover colors
/// final coverColor = VellumBookCoverColors.fromHex('#8D6E63');
/// 
/// // Getting all cover colors
/// final allCovers = VellumBookCoverColors.allColors;
/// ```
