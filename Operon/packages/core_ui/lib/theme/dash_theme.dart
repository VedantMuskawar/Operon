import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DashTheme {
  // Use the app's primary color (6F4BFF) as default
  static const Color _defaultPrimary = Color(0xFF6F4BFF);
  static const Color _defaultSecondary = Color(0xFF8F6BFF);

  /// Generates a secondary color from primary by lightening it
  static Color _generateSecondary(Color primary) {
    final hsl = HSLColor.fromColor(primary);
    final lighter = hsl.withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0));
    return lighter.toColor();
  }

  static ThemeData light({Color? accentColor}) {
    final primary = accentColor ?? _defaultPrimary;
    final secondary = accentColor != null ? _generateSecondary(primary) : _defaultSecondary;
    
    // Pure black background - Instagram style
    const scaffoldBackground = Color(0xFF000000);
    const surfaceColor = Color(0xFF0A0A0A);
    
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: primary,
        secondary: secondary,
        surface: surfaceColor,
        onPrimary: Colors.white,
        onSurface: Colors.white,
        background: scaffoldBackground,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      scaffoldBackgroundColor: Colors.transparent, // Let textured background show through
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1B1B2C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE91E63), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE91E63), width: 1.5),
        ),
        labelStyle: const TextStyle(color: Color(0xFFB3B3B3)),
        hintStyle: const TextStyle(color: Color(0xFF616161)),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        elevation: 0,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: Color(0xFF0A0A0A),
        elevation: 0,
      ),
    );
  }
}
