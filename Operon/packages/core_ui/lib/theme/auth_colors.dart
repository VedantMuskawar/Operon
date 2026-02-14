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
  static const Color backgroundAlt =
      Color(0xFF141414); // Slightly lighter black
  static const Color surface = Color(0xFF1E1E1E); // Dark Grey

  // Text colors
    static const Color textMain = Color(0xFFFDF2F2); // Soft Off-White
    static const Color textSub = Color(0xFFF2F2F2); // Light Grey
  static const Color textDisabled = Color(0xFF6B6B6B); // Disabled text

  // Accent colors
  /// Legacy accent – use [primary] or [secondary] for new code. Kept for compatibility.
  static const Color legacyAccent = primary;
  static const Color unselectedTile =
      Color(0xFFF7ABAB); // Light pink for unselected org tiles
  static const Color error = Color(0xFFFF5252); // Error red
  static const Color success = Color(0xFF4CAF50); // Success green
  static const Color successVariant =
      Color(0xFF5AD8A4); // Lighter success green
  static const Color warning =
      Color(0xFFFF9800); // Warning orange (used for people/tiles)
  static const Color info =
      Color(0xFF2196F3); // Info blue (used for operations)
  static const Color accentPurple =
      Color(0xFF9C27B0); // Accent purple (used for documents/status)

  // Utility colors
  static const Color transparent = Colors.transparent;

  // Print/document colors
  static const Color printBlack = Color(0xFF000000);
  static const Color printWhite = Color(0xFFFFFFFF);
  static const Color printGray = Color(0xFF888888);
  static const Color printLightGray = Color(0xFFE0E0E0);
  static const Color printLighterGray = Color(0xFFF1F1F1);
  static const Color printBorderGray = Color(0xFFBBBBBB);
  static const Color printBorderLight = Color(0xFFCCCCCC);
  static const Color printPaper = Color(0xFFF8F8F8);
  static const Color printPaperAlt = Color(0xFFFAFAFA);

  // Opacity variants
  static Color primaryWithOpacity(double opacity) =>
      primary.withOpacity(opacity);
  static Color secondaryWithOpacity(double opacity) =>
      secondary.withOpacity(opacity);
  static Color textMainWithOpacity(double opacity) =>
      textMain.withOpacity(opacity);
  static Color textSubWithOpacity(double opacity) =>
      textSub.withOpacity(opacity);
}

/// Logistics-specific color palette for fleet management UI.
///
/// Provides colors optimized for HUD displays, status indicators,
/// and premium glassmorphism effects.
class LogisticsColors {
  LogisticsColors._();

  /// Navy blue - Brand color for logistics operations
  static const Color navyBlue = Color(0xFF1A237E);

  /// Neon green - Active/online status indicator
  static const Color neonGreen = Color(0xFF00E676);

  /// Burnt orange - Alert/warning status indicator
  static const Color burntOrange = Color(0xFFFF5722);

  /// HUD black - Background color for heads-up displays
  static const Color hudBlack = Color(0xFF212121);

  /// Warning yellow - Pending/warning status
  static const Color warningYellow = Color(0xFFFFC107);

  /// Vehicle status colors for pin markers
  /// Available - Vehicle ready for assignment
  static const Color vehicleAvailable = Color(0xFF2ECC71);

  /// On Trip - Vehicle currently on a trip
  static const Color vehicleOnTrip = Color(0xFF2980B9);

  /// Offline - Vehicle not reporting location (muted slate for dark map contrast)
  static const Color vehicleOffline = Color(0xFF95A5A6);

  /// Idling - Vehicle online but stationary (amber, high-contrast on dark map)
  static const Color vehicleIdlingAmber = Color(0xFFFFB300);

  /// Offline muted slate - Alternative for dark map (0xFF607D8B)
  static const Color vehicleOfflineSlate = Color(0xFF546E7A);

  /// Alert - Vehicle needs attention/issue
  static const Color vehicleAlert = Color(0xFFE74C3C);

  // Opacity variants
  static Color navyBlueWithOpacity(double opacity) =>
      navyBlue.withOpacity(opacity);
  static Color neonGreenWithOpacity(double opacity) =>
      neonGreen.withOpacity(opacity);
  static Color burntOrangeWithOpacity(double opacity) =>
      burntOrange.withOpacity(opacity);
  static Color hudBlackWithOpacity(double opacity) =>
      hudBlack.withOpacity(opacity);
}
