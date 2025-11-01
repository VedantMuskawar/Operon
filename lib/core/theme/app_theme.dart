import 'package:flutter/material.dart';

class AppTheme {
  // PaveBoard EXACT colors (matching design-system.css)
  static const Color primaryColor = Color(0xFF667EEA); // PaveBoard primary blue
  static const Color secondaryColor = Color(0xFF764BA2); // PaveBoard secondary purple
  static const Color accentColor = Color(0xFFFBBF24); // PaveBoard amber accent
  static const Color backgroundColor = Color(0xFF1A1A1A); // --color-bg-primary
  static const Color surfaceColor = Color(0xFF1F2937); // --color-bg-secondary
  static const Color cardColor = Color(0xFF374151); // --color-bg-tertiary
  static const Color errorColor = Color(0xFFEF4444); // Red
  static const Color successColor = Color(0xFF10B981); // PaveBoard success green
  static const Color warningColor = Color(0xFFF59E0B); // Amber
  static const Color infoColor = Color(0xFF3B82F6); // Blue
  static const Color textPrimaryColor = Color(0xFFF9FAFB); // --color-text-primary
  static const Color textSecondaryColor = Color(0xFFD1D5DB); // --color-text-secondary
  static const Color textTertiaryColor = Color(0xFF9CA3AF); // --color-text-tertiary
  static const Color borderColor = Color(0xFF374151); // --color-border-primary
  static const Color borderSecondaryColor = Color(0xFF4B5563); // --color-border-secondary
  static const Color borderTertiaryColor = Color(0xFF6B7280); // --color-border-tertiary

  // Section-specific colors for dashboard (PaveBoard exact colors)
  static const Color ordersSectionColor = Color(0xFF3B82F6); // Blue - Orders And Vehicle
  static const Color productionSectionColor = Color(0xFF10B981); // Green - Production & Labour
  static const Color financialSectionColor = Color(0xFF8B5CF6); // Purple - Financial Management
  static const Color procurementSectionColor = Color(0xFFF59E0B); // Orange - Procurement Management

  // Responsive breakpoints (matching PaveBoard)
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 1024.0;
  static const double desktopBreakpoint = 1280.0;

  // Spacing scale (PaveBoard-inspired)
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacing2xl = 48.0;

  // Border radius scale
  static const double radiusSm = 6.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;
  static const double radiusXl = 16.0;
  static const double radius2xl = 24.0;

  // Animation durations (PaveBoard-inspired)
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  static const Duration animationSlowest = Duration(milliseconds: 800);

  // Animation curves
  static const Curve animationCurve = Curves.easeInOut;
  static const Curve animationCurveBounce = Curves.elasticOut;

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        background: backgroundColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimaryColor,
        onBackground: textPrimaryColor,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: textPrimaryColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimaryColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor.withValues(alpha: 0.8), // Semi-transparent like PaveBoard
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x14FFFFFF)), // rgba(255,255,255,0.08)
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: borderColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor.withValues(alpha: 0.5), // Semi-transparent like PaveBoard
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Increased from 8 to 12
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        labelStyle: const TextStyle(color: textSecondaryColor),
        hintStyle: const TextStyle(color: textTertiaryColor),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: textPrimaryColor,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: textPrimaryColor,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: TextStyle(
          color: textPrimaryColor,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: TextStyle(
          color: textPrimaryColor,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: TextStyle(
          color: textPrimaryColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: TextStyle(
          color: textPrimaryColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: textPrimaryColor,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: textPrimaryColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: TextStyle(
          color: textPrimaryColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: textPrimaryColor,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: textPrimaryColor,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: textSecondaryColor,
          fontSize: 12,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderColor,
        thickness: 1,
      ),
      iconTheme: const IconThemeData(
        color: textPrimaryColor,
        size: 24,
      ),
    );
  }

  // Custom shadows for depth with enhanced glow effects
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get buttonShadow => [
    BoxShadow(
      color: primaryColor.withValues(alpha: 0.3),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get glowShadow => [
    BoxShadow(
      color: primaryColor.withValues(alpha: 0.2),
      blurRadius: 20,
      offset: const Offset(0, 0),
      spreadRadius: 2,
    ),
  ];

  // PaveBoard EXACT gradients
  static LinearGradient get primaryGradient => const LinearGradient(
    colors: [Color(0xFF667EEA), Color(0xFF764BA2)], // Exact PaveBoard gradient
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // PaveBoard title gradient: from-blue-400 via-purple-400 to-cyan-400
  static LinearGradient get titleGradient => const LinearGradient(
    colors: [Color(0xFF60A5FA), Color(0xFFC084FC), Color(0xFF22D3EE)], // blue-400 → purple-400 → cyan-400
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static LinearGradient get accentGradient => const LinearGradient(
    colors: [accentColor, secondaryColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get successGradient => const LinearGradient(
    colors: [successColor, Color(0xFF06B6D4)], // Green to Cyan
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get heroGradient => const LinearGradient(
    colors: [primaryColor, secondaryColor, accentColor], // 3-color gradient
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get cardGradient => LinearGradient(
    colors: [cardColor, cardColor.withValues(alpha: 0.8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get glassGradient => LinearGradient(
    colors: [
      surfaceColor.withValues(alpha: 0.9),
      surfaceColor.withValues(alpha: 0.7),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Section-specific gradients (PaveBoard exact gradients)
  static LinearGradient get ordersSectionGradient => LinearGradient(
    colors: [
      ordersSectionColor.withValues(alpha: 0.1),
      ordersSectionColor.withValues(alpha: 0.05),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get productionSectionGradient => LinearGradient(
    colors: [
      productionSectionColor.withValues(alpha: 0.1),
      productionSectionColor.withValues(alpha: 0.05),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get financialSectionGradient => LinearGradient(
    colors: [
      financialSectionColor.withValues(alpha: 0.1),
      financialSectionColor.withValues(alpha: 0.05),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get procurementSectionGradient => LinearGradient(
    colors: [
      procurementSectionColor.withValues(alpha: 0.1),
      procurementSectionColor.withValues(alpha: 0.05),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Background gradient layers (PaveBoard-style)
  static LinearGradient get backgroundGradient1 => const LinearGradient(
    colors: [Color(0xFF1A1A1A), Color(0xFF000000), Color(0xFF1A1A1A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient get backgroundGradient2 => LinearGradient(
    colors: [
      const Color(0xFF1E293B).withValues(alpha: 0.3),
      Colors.transparent,
      const Color(0xFF374151).withValues(alpha: 0.3),
    ],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static LinearGradient get backgroundGradient3 => LinearGradient(
    colors: [
      Colors.black.withValues(alpha: 0.2),
      Colors.transparent,
      const Color(0xFF1E293B).withValues(alpha: 0.2),
    ],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  // Helper methods for responsive design
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  static int getGridColumns(BuildContext context) {
    if (isMobile(context)) return 2;
    if (isTablet(context)) return 2;
    return 4;
  }

  static double getResponsivePadding(BuildContext context) {
    if (isMobile(context)) return spacingMd;
    return spacingLg;
  }

  static double getResponsiveGap(BuildContext context) {
    if (isMobile(context)) return spacingMd;
    if (isTablet(context)) return spacingLg;
    return spacingXl;
  }

  // Orb animation durations (mobile optimized)
  static Duration getOrbAnimationDuration(BuildContext context, int orbIndex) {
    if (isMobile(context)) {
      // Reduced complexity on mobile
      return Duration(seconds: 15 + (orbIndex * 5));
    }
    return Duration(seconds: 20 + (orbIndex * 5));
  }
}
