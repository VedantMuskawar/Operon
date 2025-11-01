import 'package:flutter/material.dart';

class AppTheme {
  // PaveBoard-inspired dark theme colors (matching web app)
  static const Color primaryColor = Color(0xFF667EEA); // PaveBoard primary blue
  static const Color secondaryColor = Color(0xFF764BA2); // PaveBoard secondary purple
  static const Color accentColor = Color(0xFFFBBF24); // PaveBoard amber accent
  static const Color backgroundColor = Color(0xFF1A1A1A); // PaveBoard primary background
  static const Color surfaceColor = Color(0xFF1F2937); // PaveBoard secondary background
  static const Color cardColor = Color(0xFF374151); // PaveBoard tertiary background
  static const Color errorColor = Color(0xFFEF4444); // Red
  static const Color successColor = Color(0xFF10B981); // PaveBoard success green
  static const Color warningColor = Color(0xFFF59E0B); // Amber
  static const Color infoColor = Color(0xFF3B82F6); // Blue
  static const Color textPrimaryColor = Color(0xFFF9FAFB); // PaveBoard primary text
  static const Color textSecondaryColor = Color(0xFFD1D5DB); // PaveBoard secondary text
  static const Color textTertiaryColor = Color(0xFF9CA3AF); // PaveBoard tertiary text
  static const Color borderColor = Color(0xFF374151); // PaveBoard primary border
  static const Color borderSecondaryColor = Color(0xFF4B5563); // PaveBoard secondary border
  static const Color borderTertiaryColor = Color(0xFF6B7280); // PaveBoard tertiary border

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimaryColor,
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
        color: cardColor,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // Mobile-optimized radius
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), // Mobile-friendly padding
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // Mobile-optimized radius
          ),
          minimumSize: const Size(double.infinity, 48), // Touch-friendly minimum size
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: borderColor),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), // Mobile-friendly padding
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // Mobile-optimized radius
          ),
          minimumSize: const Size(double.infinity, 48), // Touch-friendly minimum size
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Mobile-optimized radius
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Mobile-optimized radius
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Mobile-optimized radius
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Mobile-optimized radius
          borderSide: const BorderSide(color: errorColor),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), // Mobile-friendly padding
        labelStyle: const TextStyle(color: textSecondaryColor),
        hintStyle: const TextStyle(color: textSecondaryColor),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: textPrimaryColor,
          fontSize: 28, // Mobile-optimized size
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: textPrimaryColor,
          fontSize: 24, // Mobile-optimized size
          fontWeight: FontWeight.bold,
        ),
        displaySmall: TextStyle(
          color: textPrimaryColor,
          fontSize: 20, // Mobile-optimized size
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: TextStyle(
          color: textPrimaryColor,
          fontSize: 18, // Mobile-optimized size
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: TextStyle(
          color: textPrimaryColor,
          fontSize: 16, // Mobile-optimized size
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: TextStyle(
          color: textPrimaryColor,
          fontSize: 14, // Mobile-optimized size
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
      blurRadius: 8, // Mobile-optimized blur
      offset: const Offset(0, 2), // Mobile-optimized offset
    ),
  ];

  static List<BoxShadow> get buttonShadow => [
    BoxShadow(
      color: primaryColor.withValues(alpha: 0.3),
      blurRadius: 6, // Mobile-optimized blur
      offset: const Offset(0, 2), // Mobile-optimized offset
    ),
  ];

  static List<BoxShadow> get glowShadow => [
    BoxShadow(
      color: primaryColor.withValues(alpha: 0.2),
      blurRadius: 15, // Mobile-optimized blur
      offset: const Offset(0, 0),
      spreadRadius: 1, // Mobile-optimized spread
    ),
  ];

  // Modern gradient backgrounds (Stripe/Linear inspired)
  static LinearGradient get primaryGradient => const LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)], // blue-500 to purple-600
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get accentGradient => const LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)], // green-500 to emerald-600
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
}



