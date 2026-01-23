/// Geospatial math utilities for fleet management.
/// 
/// Provides functions for bearing interpolation and coordinate interpolation
/// that ensure smooth animations and correct rotation calculations.
class GeoMath {
  /// Calculate the shortest rotation path between two bearings.
  /// 
  /// Prevents vehicles from spinning backwards (e.g., 350° → 10° should rotate
  /// 20° clockwise, not 340° counter-clockwise).
  /// 
  /// Returns the normalized bearing difference in the range [-180, 180].
  /// Positive values indicate clockwise rotation, negative indicates counter-clockwise.
  static double getShortestRotation(double startBearing, double endBearing) {
    // Normalize bearings to 0-360 range
    startBearing = startBearing % 360;
    endBearing = endBearing % 360;
    
    if (startBearing < 0) startBearing += 360;
    if (endBearing < 0) endBearing += 360;
    
    // Calculate both possible rotation paths
    final clockwise = (endBearing - startBearing + 360) % 360;
    final counterClockwise = (startBearing - endBearing + 360) % 360;
    
    // Return the shorter path, with sign indicating direction
    if (clockwise <= counterClockwise) {
      return clockwise <= 180 ? clockwise : clockwise - 360;
    } else {
      return counterClockwise <= 180 ? -counterClockwise : 360 - counterClockwise;
    }
  }

  /// Linear interpolation between two latitude/longitude coordinates.
  /// 
  /// [t] should be in the range [0.0, 1.0], where 0.0 returns [startLat, startLng]
  /// and 1.0 returns [endLat, endLng].
  /// 
  /// Returns a map with 'lat' and 'lng' keys.
  static Map<String, double> lerpLatLng(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
    double t,
  ) {
    // Clamp t to [0, 1]
    t = t.clamp(0.0, 1.0);
    
    return {
      'lat': startLat + (endLat - startLat) * t,
      'lng': startLng + (endLng - startLng) * t,
    };
  }

  /// Linear interpolation between two bearings using shortest rotation path.
  /// 
  /// [t] should be in the range [0.0, 1.0], where 0.0 returns [startBearing]
  /// and 1.0 returns [endBearing].
  /// 
  /// The result is normalized to [0, 360) range.
  static double lerpBearing(double startBearing, double endBearing, double t) {
    // Clamp t to [0, 1]
    t = t.clamp(0.0, 1.0);
    
    // Get shortest rotation path
    final rotation = getShortestRotation(startBearing, endBearing);
    
    // Apply interpolation
    final result = startBearing + rotation * t;
    
    // Normalize to [0, 360)
    return result % 360;
  }
}
