import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_colors.dart';

class DashTheme {
  // Use AuthColors from Unified Login Page as the default color scheme
  static ThemeData light({Color? accentColor}) {
    // Use AuthColors for consistency with Unified Login Page
    const scaffoldBackground = AuthColors.background; // Color(0xFF121212) - Off-Black
    const surfaceColor = AuthColors.surface; // Color(0xFF1E1E1E) - Dark Grey
    
    // Use AuthColors primary and secondary, or allow override via accentColor
    final primary = accentColor ?? AuthColors.primary; // Deep Burgundy (0xFF5D1C19)
    final secondary = AuthColors.secondary; // Muted Gold (0xFFC5A059)
    final primaryVariant = AuthColors.primaryVariant; // Darker Burgundy (0xFF871C1C)
    
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      // Primary colors - using AuthColors from Unified Login Page
      primary: primary,
      onPrimary: AuthColors.textMain, // Platinum white
      primaryContainer: primaryVariant,
      onPrimaryContainer: AuthColors.textMain,
      // Secondary colors - using AuthColors Muted Gold
      secondary: secondary,
      onSecondary: AuthColors.textMain,
      secondaryContainer: surfaceColor,
      onSecondaryContainer: AuthColors.textMain,
      // Tertiary colors (same as secondary to avoid blue)
      tertiary: secondary,
      onTertiary: AuthColors.textMain,
      tertiaryContainer: surfaceColor,
      onTertiaryContainer: AuthColors.textMain,
      // Error colors - using AuthColors error red
      error: AuthColors.error,
      onError: Colors.white,
      errorContainer: surfaceColor,
      onErrorContainer: Colors.white,
      // Surface colors - all set to our dark colors from AuthColors
      surface: surfaceColor,
      onSurface: AuthColors.textMain,
      surfaceContainerHighest: surfaceColor,
      surfaceContainerHigh: surfaceColor,
      surfaceContainer: surfaceColor,
      surfaceContainerLow: surfaceColor,
      surfaceContainerLowest: scaffoldBackground,
      surfaceDim: scaffoldBackground,
      surfaceBright: surfaceColor,
      // Inverse colors
      inverseSurface: scaffoldBackground,
      onInverseSurface: AuthColors.textMain,
      inversePrimary: primary,
      // Outline colors - using AuthColors text colors
      outline: AuthColors.textSub,
      outlineVariant: AuthColors.textDisabled,
      // Shadow
      shadow: Colors.black,
      scrim: Colors.black,
    );
    
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
    );
    return base.copyWith(
      colorScheme: colorScheme,
      // Explicitly override all background-related properties
      canvasColor: scaffoldBackground,
      cardColor: surfaceColor,
      // Roboto includes ₹ (U+20B9); fallback on all styles avoids "Noto fonts" missing-character warning.
      textTheme: _withFontFallback(
        GoogleFonts.robotoTextTheme(base.textTheme).apply(
          bodyColor: AuthColors.textMain,
          displayColor: AuthColors.textMain,
        ),
      ),
      scaffoldBackgroundColor: scaffoldBackground, // Use AuthColors.background instead of transparent
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AuthColors.textMain),
        titleTextStyle: GoogleFonts.roboto(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AuthColors.textMain,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AuthColors.textMain.withOpacity(0.1),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AuthColors.textMain.withOpacity(0.1),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AuthColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AuthColors.error, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AuthColors.textSub),
        hintStyle: const TextStyle(color: AuthColors.textSub),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AuthColors.textMain.withOpacity(0.1)),
        ),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AuthColors.textMain.withOpacity(0.1)),
        ),
        elevation: 0,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AuthColors.backgroundAlt,
        elevation: 0,
      ),
    );
  }

  /// Applies fontFamilyFallback so symbols like ₹ render when primary font lacks them.
  static TextTheme _withFontFallback(TextTheme theme) {
    const fallback = ['Roboto'];
    return TextTheme(
      displayLarge: theme.displayLarge?.copyWith(fontFamilyFallback: fallback),
      displayMedium: theme.displayMedium?.copyWith(fontFamilyFallback: fallback),
      displaySmall: theme.displaySmall?.copyWith(fontFamilyFallback: fallback),
      headlineLarge: theme.headlineLarge?.copyWith(fontFamilyFallback: fallback),
      headlineMedium: theme.headlineMedium?.copyWith(fontFamilyFallback: fallback),
      headlineSmall: theme.headlineSmall?.copyWith(fontFamilyFallback: fallback),
      titleLarge: theme.titleLarge?.copyWith(fontFamilyFallback: fallback),
      titleMedium: theme.titleMedium?.copyWith(fontFamilyFallback: fallback),
      titleSmall: theme.titleSmall?.copyWith(fontFamilyFallback: fallback),
      bodyLarge: theme.bodyLarge?.copyWith(fontFamilyFallback: fallback),
      bodyMedium: theme.bodyMedium?.copyWith(fontFamilyFallback: fallback),
      bodySmall: theme.bodySmall?.copyWith(fontFamilyFallback: fallback),
      labelLarge: theme.labelLarge?.copyWith(fontFamilyFallback: fallback),
      labelMedium: theme.labelMedium?.copyWith(fontFamilyFallback: fallback),
      labelSmall: theme.labelSmall?.copyWith(fontFamilyFallback: fallback),
    );
  }
}
