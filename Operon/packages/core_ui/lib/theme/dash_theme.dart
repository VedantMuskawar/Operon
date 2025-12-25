import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DashTheme {
  static const Color _defaultPrimary = Color(0xFF6C63FF);
  static const Color _defaultSecondary = Color(0xFF8F9FF8);

  /// Generates a secondary color from primary by lightening it
  static Color _generateSecondary(Color primary) {
    final hsl = HSLColor.fromColor(primary);
    final lighter = hsl.withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0));
    return lighter.toColor();
  }

  static ThemeData light({Color? accentColor}) {
    final primary = accentColor ?? _defaultPrimary;
    final secondary = accentColor != null ? _generateSecondary(primary) : _defaultSecondary;
    
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: primary,
        secondary: secondary,
        surface: const Color(0xFF020205),
        onPrimary: Colors.white,
        onSurface: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFF020205),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: Colors.white.withOpacity(0.04),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
    );
  }
}
