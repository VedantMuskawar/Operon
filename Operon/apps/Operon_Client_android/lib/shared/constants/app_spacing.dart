import 'package:flutter/material.dart';

/// Standardized spacing values for consistent layout
/// All spacing should be referenced from here
class AppSpacing {
  AppSpacing._();

  // Padding
  static const double paddingXS = 4.0;
  static const double paddingSM = 8.0;
  static const double paddingMD = 12.0;
  static const double paddingLG = 16.0;
  static const double paddingXL = 20.0;
  static const double paddingXXL = 24.0;
  static const double paddingXXXL = 32.0;
  static const double paddingXXXXL = 48.0;

  // Margins
  static const double marginXS = 4.0;
  static const double marginSM = 8.0;
  static const double marginMD = 12.0;
  static const double marginLG = 16.0;
  static const double marginXL = 20.0;
  static const double marginXXL = 24.0;
  static const double marginXXXL = 32.0;

  // Gaps (for Column/Row spacing)
  static const double gapXS = 4.0;
  static const double gapSM = 6.0;
  static const double gapMD = 12.0;
  static const double gapLG = 16.0;
  static const double gapXL = 24.0;
  static const double gapXXL = 32.0;

  // Standard spacing values
  static const double pagePadding = paddingLG; // 16px
  static const double itemSpacing = paddingMD; // 12px
  static const double listItemSpacing = paddingMD; // 12px
  static const double sectionSpacing = paddingXXL; // 24px
  static const double sectionSpacingLarge = paddingXXXL; // 32px
  
  // Component-specific padding
  static const double buttonPadding = 14.0;
  static const double inputPadding = 12.0;

  // Border Radius
  static const double radiusXS = 6.0;
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 20.0;
  static const double radiusXXL = 24.0;
  static const double radiusRound = 999.0; // For circular elements

  // Standard border radius values
  static const double cardRadius = radiusLG; // 16px
  static const double buttonRadius = radiusLG; // 16px
  static const double inputRadius = radiusMD; // 12px
  static const double chipRadius = radiusSM; // 8px
  static const double dialogRadius = radiusXXL; // 24px

  // Icon Sizes
  static const double iconXS = 12.0;
  static const double iconSM = 16.0;
  static const double iconMD = 20.0;
  static const double iconLG = 24.0;
  static const double iconXL = 32.0;

  // Avatar Sizes
  static const double avatarSM = 32.0;
  static const double avatarMD = 48.0;
  static const double avatarLG = 64.0;
  static const double avatarXL = 80.0;

  // Button Heights
  static const double buttonHeightSM = 36.0;
  static const double buttonHeightMD = 44.0;
  static const double buttonHeightLG = 52.0;

  // Convenience EdgeInsets
  static const EdgeInsets pagePaddingAll = EdgeInsets.all(pagePadding);
  static const EdgeInsets pagePaddingHorizontal = EdgeInsets.symmetric(horizontal: pagePadding);
  static const EdgeInsets pagePaddingVertical = EdgeInsets.symmetric(vertical: pagePadding);
  static const EdgeInsets cardPadding = EdgeInsets.all(paddingXXL);
  static const EdgeInsets cardPaddingSmall = EdgeInsets.all(paddingLG);
}

