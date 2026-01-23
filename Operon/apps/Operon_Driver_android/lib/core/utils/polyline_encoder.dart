import 'package:core_models/core_models.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';

/// Utility for encoding and decoding location paths using Google Polyline Algorithm
/// This dramatically reduces storage costs compared to storing raw coordinates
class PolylineEncoder {
  /// Encode a list of DriverLocation points to a polyline string
  /// Returns the encoded polyline string and metadata
  static Map<String, dynamic> encodePath(List<DriverLocation> locations) {
    if (locations.isEmpty) {
      return {
        'polyline': '',
        'pointCount': 0,
        'distanceMeters': 0.0,
      };
    }

    // Convert to list of LatLng pairs
    final coordinates = locations
        .map((loc) => [loc.lat, loc.lng])
        .toList(growable: false);

    // Encode using Google Polyline Algorithm
    final polyline = encodePolyline(coordinates);

    // Calculate total distance using Haversine formula
    double totalDistance = 0.0;
    for (int i = 1; i < locations.length; i++) {
      final prev = locations[i - 1];
      final curr = locations[i];
      final distance = Geolocator.distanceBetween(
        prev.lat,
        prev.lng,
        curr.lat,
        curr.lng,
      );
      totalDistance += distance;
    }

    return {
      'polyline': polyline,
      'pointCount': locations.length,
      'distanceMeters': totalDistance,
    };
  }

  /// Decode a polyline string back to a list of coordinates
  /// Returns list of [lat, lng] pairs
  static List<List<double>> decodePath(String polyline) {
    if (polyline.isEmpty) {
      return [];
    }

    try {
      final decoded = decodePolyline(polyline);
      // Convert List<List<num>> to List<List<double>>
      return decoded.map((coord) => coord.map((n) => n.toDouble()).toList()).toList();
    } catch (e) {
      return [];
    }
  }

  /// Convert decoded coordinates to DriverLocation objects
  /// Note: This loses some data (bearing, speed) as polyline only stores lat/lng
  static List<DriverLocation> decodeToDriverLocations(
    String polyline, {
    String status = 'active',
    int startTimestamp = 0,
  }) {
    final coordinates = decodePath(polyline);
    final locations = <DriverLocation>[];

    for (int i = 0; i < coordinates.length; i++) {
      final coord = coordinates[i];
      locations.add(DriverLocation(
        lat: coord[0],
        lng: coord[1],
        bearing: 0.0, // Default value since polyline doesn't store bearing
        speed: 0.0, // Default value since polyline doesn't store speed
        status: status,
        timestamp: startTimestamp + (i * 1000), // Approximate timestamps
      ));
    }

    return locations;
  }
}
