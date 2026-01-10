import 'package:flutter/material.dart';

/// Centralized color definitions for the app
/// All colors should be referenced from here to ensure consistency
class AppColors {
  AppColors._();

  // Background Colors
  static const Color background = Color(0xFF000000); // Pure black - Instagram style
  static const Color surface = Color(0xFF0A0A0A); // Slightly lighter for cards
  static const Color surfaceElevated = Color(0xFF111111); // Elevated surfaces
  static const Color drawerBackground = Color(0xFF0A0A0A); // Drawer background

  // Primary Colors
  static const Color primary = Color(0xFF6F4BFF); // Primary accent color
  static const Color primaryLight = Color(0xFF8F6BFF);
  static const Color primaryDark = Color(0xFF5A3BE0);

  // Text Colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB3B3B3); // Colors.white70 equivalent
  static const Color textTertiary = Color(0xFF8A8A8A); // Colors.white54 equivalent
  static const Color textDisabled = Color(0xFF616161); // Colors.white38 equivalent

  // Border Colors
  static Color borderDefault = Colors.white.withOpacity(0.1);
  static Color borderLight = Colors.white.withOpacity(0.05);
  static Color borderMedium = Colors.white.withOpacity(0.15);
  static Color borderPrimary = primary.withOpacity(0.3);

  // Card/Surface Colors
  static const Color cardBackground = Color(0xFF0A0A0A);
  static const Color cardBackgroundElevated = Color(0xFF111111);
  static const Color cardBackgroundHover = Color(0xFF131324);

  // Status Colors
  static const Color success = Color(0xFF5AD8A4);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFE91E63);
  static const Color info = Color(0xFF2196F3);

  // Overlay Colors
  static Color overlayLight = Colors.black.withOpacity(0.3);
  static Color overlayMedium = Colors.black.withOpacity(0.5);
  static Color overlayDark = Colors.black.withOpacity(0.7);

  // Input Colors
  static const Color inputBackground = Color(0xFF1B1B2C);
  static const Color inputBorder = Color(0xFF2A2A3A);
  static const Color inputFocused = primary;

  // Divider Colors
  static Color divider = Colors.white.withOpacity(0.1);
  static Color dividerLight = Colors.white.withOpacity(0.05);

  // Legacy color mappings (for gradual migration)
  static const Color legacyDarkGray = Color(0xFF010104);
  static const Color legacyPanel = Color(0xFF0B0B12);
  static const Color legacyCard = Color(0xFF11111B);
  static const Color legacySurface = Color(0xFF1B1B2C);
}

