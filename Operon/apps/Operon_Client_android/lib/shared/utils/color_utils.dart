import 'package:flutter/material.dart';

class ColorUtils {
  /// Converts a hex color string to Color object
  /// Supports formats: "#6F4BFF", "6F4BFF", "#FFF", "FFF"
  static Color? hexToColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) {
      return null;
    }

    // Remove # if present
    String hex = hexString.replaceAll('#', '').trim();

    // Handle 3-character hex codes (e.g., "FFF" -> "FFFFFF")
    if (hex.length == 3) {
      hex = hex.split('').map((char) => '$char$char').join();
    }

    // Validate hex string
    if (hex.length != 6 || !RegExp(r'^[0-9A-Fa-f]+$').hasMatch(hex)) {
      return null;
    }

    try {
      return Color(int.parse(hex, radix: 16) + 0xFF000000);
    } catch (e) {
      return null;
    }
  }

  /// Converts hex string to Color, with fallback to default color
  static Color hexToColorWithFallback(String? hexString, Color fallback) {
    return hexToColor(hexString) ?? fallback;
  }

  /// Generates a secondary/accent color from primary color
  /// Lightens the primary color by a certain percentage
  static Color generateSecondaryColor(Color primary, {double lightness = 0.15}) {
    // Convert to HSL, increase lightness, convert back to RGB
    final hsl = HSLColor.fromColor(primary);
    final lighter = hsl.withLightness((hsl.lightness + lightness).clamp(0.0, 1.0));
    return lighter.toColor();
  }
}

