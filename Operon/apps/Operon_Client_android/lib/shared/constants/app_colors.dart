import 'package:core_ui/theme/auth_colors.dart';
import 'package:flutter/material.dart';

/// Centralized color definitions for the app
/// All colors should be referenced from here to ensure consistency
class AppColors {
  AppColors._();

  // Background Colors
  static const Color background =
      AuthColors.background; // Pure black - Instagram style
  static const Color surface = AuthColors.surface; // Slightly lighter for cards
  static const Color surfaceElevated =
      AuthColors.backgroundAlt; // Elevated surfaces
  static const Color drawerBackground =
      AuthColors.background; // Drawer background

  // Primary Colors
  static const Color primary = AuthColors.primary; // Primary accent color
  static const Color primaryLight = AuthColors.secondary;
  static const Color primaryDark = AuthColors.primaryVariant;

  // Text Colors
  static const Color textPrimary = AuthColors.textMain;
  static const Color textSecondary =
      AuthColors.textSub; // Colors.white70 equivalent
  static const Color textTertiary =
      AuthColors.textDisabled; // Colors.white54 equivalent
  static const Color textDisabled =
      AuthColors.textDisabled; // Colors.white38 equivalent

  // Border Colors
    static Color borderDefault = AuthColors.textMain.withValues(alpha: 0.1);
    static Color borderLight = AuthColors.textMain.withValues(alpha: 0.05);
    static Color borderMedium = AuthColors.textMain.withValues(alpha: 0.15);
    static Color borderPrimary = primary.withValues(alpha: 0.3);

  // Card/Surface Colors
  static const Color cardBackground = AuthColors.surface;
  static const Color cardBackgroundElevated = AuthColors.backgroundAlt;
  static const Color cardBackgroundHover = AuthColors.backgroundAlt;

  // Status Colors
  static const Color success = AuthColors.successVariant;
  static const Color warning = AuthColors.warning;
  static const Color error = AuthColors.error;
  static const Color info = AuthColors.info;

  // Overlay Colors
    static Color overlayLight = AuthColors.background.withValues(alpha: 0.3);
    static Color overlayMedium = AuthColors.background.withValues(alpha: 0.5);
    static Color overlayDark = AuthColors.background.withValues(alpha: 0.7);

  // Input Colors
  static const Color inputBackground = AuthColors.backgroundAlt;
  static const Color inputBorder = AuthColors.textSub;
  static const Color inputFocused = primary;

  // Divider Colors
    static Color divider = AuthColors.textMain.withValues(alpha: 0.1);
    static Color dividerLight = AuthColors.textMain.withValues(alpha: 0.05);

  // Legacy color mappings (for gradual migration)
  static const Color legacyDarkGray = AuthColors.background;
  static const Color legacyPanel = AuthColors.backgroundAlt;
  static const Color legacyCard = AuthColors.surface;
  static const Color legacySurface = AuthColors.backgroundAlt;
}
