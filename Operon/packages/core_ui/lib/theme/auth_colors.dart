/// Shared color constants for authentication flow across Android and Web apps
library auth_colors;

import 'package:flutter/material.dart';

/// Authentication flow color scheme
/// These colors are used consistently across login, OTP, organization selection, and splash screens
class AuthColors {
  AuthColors._();

  // Primary colors
  static const Color primary = Color(0xFF5D1C19); // Deep Burgundy
  static const Color primaryVariant = Color(0xFF871C1C); // Darker Burgundy
  static const Color secondary = Color(0xFFC5A059); // Muted Gold

  // Background colors
  static const Color background = Color(0xFF121212); // Off-Black
  static const Color backgroundAlt = Color(0xFF141414); // Slightly lighter black
  static const Color surface = Color(0xFF1E1E1E); // Dark Grey

  // Text colors
  static const Color textMain = Color(0xFFE0E0E0); // Platinum
  static const Color textSub = Color(0xFFA1A1A1); // Medium Grey
  static const Color textDisabled = Color(0xFF6B6B6B); // Disabled text

  // Accent colors
  static const Color unselectedTile = Color(0xFFF7ABAB); // Light pink for unselected org tiles
  static const Color error = Color(0xFFFF5252); // Error red
  static const Color success = Color(0xFF4CAF50); // Success green

  // Opacity variants
  static Color primaryWithOpacity(double opacity) => primary.withOpacity(opacity);
  static Color secondaryWithOpacity(double opacity) => secondary.withOpacity(opacity);
  static Color textMainWithOpacity(double opacity) => textMain.withOpacity(opacity);
  static Color textSubWithOpacity(double opacity) => textSub.withOpacity(opacity);
}
