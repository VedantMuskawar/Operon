import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Path simplification using Ramer-Douglas-Peucker algorithm.
/// 
/// Reduces the number of points in a polyline while preserving the overall
/// shape. Always preserves the first point (trip start) and last point
/// (current position) to maintain trip integrity.
class PathSimplifier {
  /// Simplifies a path using the Ramer-Douglas-Peucker algorithm.
  /// 
  /// [points] - The list of LatLng points to simplify
  /// [tolerance] - Maximum distance (in meters) a point can be from the
  ///               simplified line before it's kept. Typical value: 5.0 meters.
  /// 
  /// Returns a simplified list that preserves the first and last points.
  static List<LatLng> simplifyPath(List<LatLng> points, double tolerance) {
    if (points.length <= 2) {
      return List<LatLng>.from(points);
    }

    // Always preserve first and last points
    final first = points.first;
    final last = points.last;

    // Recursively simplify
    final simplified = _rdpRecursive(points, tolerance);

    // Ensure first and last are preserved (RDP should do this, but be explicit)
    if (simplified.isEmpty) {
      return [first, last];
    }

    if (simplified.first != first) {
      simplified.insert(0, first);
    }
    if (simplified.last != last) {
      simplified.add(last);
    }

    return simplified;
  }

  /// Recursive implementation of Ramer-Douglas-Peucker algorithm.
  static List<LatLng> _rdpRecursive(List<LatLng> points, double tolerance) {
    if (points.length <= 2) {
      return List<LatLng>.from(points);
    }

    final first = points.first;
    final last = points.last;

    // Find the point with maximum distance from the line segment
    double maxDistance = 0.0;
    int maxIndex = 0;

    for (int i = 1; i < points.length - 1; i++) {
      final distance = _pointToLineDistance(points[i], first, last);
      if (distance > maxDistance) {
        maxDistance = distance;
        maxIndex = i;
      }
    }

    // If max distance is greater than tolerance, recursively simplify
    if (maxDistance > tolerance) {
      // Recursively simplify both halves
      final left = _rdpRecursive(points.sublist(0, maxIndex + 1), tolerance);
      final right = _rdpRecursive(points.sublist(maxIndex), tolerance);

      // Combine results (remove duplicate point at maxIndex)
      final result = <LatLng>[];
      result.addAll(left);
      if (right.length > 1) {
        result.addAll(right.sublist(1)); // Skip first point (duplicate)
      }
      return result;
    } else {
      // All points are within tolerance, return only endpoints
      return [first, last];
    }
  }

  /// Calculate the perpendicular distance from a point to a line segment.
  /// 
  /// Returns distance in meters.
  static double _pointToLineDistance(
    LatLng point,
    LatLng lineStart,
    LatLng lineEnd,
  ) {
    // If line segment is degenerate (start == end), return distance to point
    if (lineStart.latitude == lineEnd.latitude &&
        lineStart.longitude == lineEnd.longitude) {
      return Geolocator.distanceBetween(
        point.latitude,
        point.longitude,
        lineStart.latitude,
        lineStart.longitude,
      );
    }

    // Calculate distance using cross product method
    // This gives the perpendicular distance from point to line segment
    final A = point.latitude - lineStart.latitude;
    final B = point.longitude - lineStart.longitude;
    final C = lineEnd.latitude - lineStart.latitude;
    final D = lineEnd.longitude - lineStart.longitude;

    final dot = A * C + B * D;
    final lenSq = C * C + D * D;
    final param = lenSq != 0 ? dot / lenSq : -1;

    // Clamp to line segment
    double xx, yy;
    if (param < 0) {
      xx = lineStart.latitude;
      yy = lineStart.longitude;
    } else if (param > 1) {
      xx = lineEnd.latitude;
      yy = lineEnd.longitude;
    } else {
      xx = lineStart.latitude + param * C;
      yy = lineStart.longitude + param * D;
    }

    // Calculate distance in meters
    return Geolocator.distanceBetween(
      point.latitude,
      point.longitude,
      xx,
      yy,
    );
  }
}
