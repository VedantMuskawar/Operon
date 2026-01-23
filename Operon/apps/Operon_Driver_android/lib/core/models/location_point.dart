import 'package:hive/hive.dart';

part 'location_point.g.dart';

/// Hive model for storing location points locally (offline-first pattern)
/// This allows GPS points to be saved immediately without network dependency
@HiveType(typeId: 0)
class LocationPoint extends HiveObject {
  @HiveField(0)
  final double lat;

  @HiveField(1)
  final double lng;

  @HiveField(2)
  final double? bearing;

  @HiveField(3)
  final double? speed;

  @HiveField(4)
  final String status;

  @HiveField(5)
  final int timestamp;

  @HiveField(6)
  final String tripId;

  @HiveField(7)
  final String uid;

  @HiveField(8)
  final bool synced; // Whether this point has been synced to RTDB

  LocationPoint({
    required this.lat,
    required this.lng,
    this.bearing,
    this.speed,
    required this.status,
    required this.timestamp,
    required this.tripId,
    required this.uid,
    this.synced = false,
  });

  /// Convert to JSON for RTDB upload
  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lng': lng,
      if (bearing != null) 'bearing': bearing,
      if (speed != null) 'speed': speed,
      'status': status,
      'timestamp': timestamp,
    };
  }

  /// Create from DriverLocation (from core_models)
  factory LocationPoint.fromDriverLocation({
    required double lat,
    required double lng,
    double? bearing,
    double? speed,
    required String status,
    required int timestamp,
    required String tripId,
    required String uid,
  }) {
    return LocationPoint(
      lat: lat,
      lng: lng,
      bearing: bearing,
      speed: speed,
      status: status,
      timestamp: timestamp,
      tripId: tripId,
      uid: uid,
      synced: false,
    );
  }
}
