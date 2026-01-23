import 'package:cloud_firestore/cloud_firestore.dart';
import '../enums/geofence_event_type.dart';

class GeofenceEvent {
  const GeofenceEvent({
    required this.id,
    required this.organizationId,
    required this.geofenceId,
    required this.userId,
    required this.eventType,
    required this.latitude,
    required this.longitude,
    this.vehicleNumber,
    this.tripId,
    this.timestamp,
  });

  final String id;
  final String organizationId;
  final String geofenceId;
  final String userId;
  final GeofenceEventType eventType;
  final double latitude;
  final double longitude;
  final String? vehicleNumber;
  final String? tripId;
  final DateTime? timestamp;

  factory GeofenceEvent.fromMap(Map<String, dynamic> map, String id) {
    return GeofenceEvent(
      id: id,
      organizationId: map['organization_id'] as String? ?? '',
      geofenceId: map['geofence_id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      eventType: GeofenceEventType.values.firstWhere(
        (e) => e.name == map['event_type'],
        orElse: () => GeofenceEventType.entered,
      ),
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      vehicleNumber: map['vehicle_number'] as String?,
      tripId: map['trip_id'] as String?,
      timestamp: (map['timestamp'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organization_id': organizationId,
      'geofence_id': geofenceId,
      'user_id': userId,
      'event_type': eventType.name,
      'latitude': latitude,
      'longitude': longitude,
      if (vehicleNumber != null) 'vehicle_number': vehicleNumber,
      if (tripId != null) 'trip_id': tripId,
      if (timestamp != null) 'timestamp': Timestamp.fromDate(timestamp!),
    };
  }

  GeofenceEvent copyWith({
    String? id,
    String? organizationId,
    String? geofenceId,
    String? userId,
    GeofenceEventType? eventType,
    double? latitude,
    double? longitude,
    String? vehicleNumber,
    String? tripId,
    DateTime? timestamp,
  }) {
    return GeofenceEvent(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      geofenceId: geofenceId ?? this.geofenceId,
      userId: userId ?? this.userId,
      eventType: eventType ?? this.eventType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      tripId: tripId ?? this.tripId,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
