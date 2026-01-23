import 'package:cloud_firestore/cloud_firestore.dart';

class DriverLocation {
  const DriverLocation({
    required this.lat,
    required this.lng,
    required this.bearing,
    required this.speed,
    required this.status,
    required this.timestamp,
  });

  final double lat;
  final double lng;
  final double bearing;
  final double speed;
  final String status;

  /// Milliseconds since epoch.
  final int timestamp;

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lng': lng,
      'bearing': bearing,
      'speed': speed,
      'status': status,
      'timestamp': timestamp,
    };
  }

  factory DriverLocation.fromJson(Map<String, dynamic> json) {
    // Handle timestamp from various sources:
    // 1. Firestore Timestamp object
    // 2. Integer milliseconds (Realtime DB or existing format)
    // 3. createdAt field (Firestore Timestamp)
    int timestampMs = 0;
    
    // Check for Firestore Timestamp in 'timestamp' field
    final timestampValue = json['timestamp'];
    if (timestampValue is Timestamp) {
      timestampMs = timestampValue.millisecondsSinceEpoch;
    } else if (timestampValue is num) {
      timestampMs = timestampValue.toInt();
    } else {
      // Fallback: check for 'createdAt' field (common in Firestore)
      final createdAt = json['createdAt'];
      if (createdAt is Timestamp) {
        timestampMs = createdAt.millisecondsSinceEpoch;
      } else if (createdAt is num) {
        timestampMs = createdAt.toInt();
      }
    }

    return DriverLocation(
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      bearing: (json['bearing'] as num?)?.toDouble() ?? 0.0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? '',
      timestamp: timestampMs,
    );
  }

  DriverLocation copyWith({
    double? lat,
    double? lng,
    double? bearing,
    double? speed,
    String? status,
    int? timestamp,
  }) {
    return DriverLocation(
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      bearing: bearing ?? this.bearing,
      speed: speed ?? this.speed,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

