import 'package:cloud_firestore/cloud_firestore.dart';
import '../enums/geofence_type.dart';

class Geofence {
  const Geofence({
    required this.id,
    required this.organizationId,
    required this.locationId,
    required this.name,
    required this.type,
    required this.centerLat,
    required this.centerLng,
    this.radiusMeters,
    this.polygonPoints,
    this.notificationRecipientIds = const [],
    this.isActive = true,
    this.metadata,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String organizationId;
  final String locationId;
  final String name;
  final GeofenceType type;
  final double centerLat;
  final double centerLng;
  final double? radiusMeters; // For circle type
  final List<LatLng>? polygonPoints; // For polygon type
  final List<String> notificationRecipientIds;
  final bool isActive;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Geofence.fromMap(Map<String, dynamic> map, String id) {
    final polygonPointsData = map['polygon_points'] as List<dynamic>?;
    final List<LatLng>? polygonPoints;
    if (polygonPointsData != null) {
      polygonPoints = polygonPointsData
          .map((point) => LatLng(
                (point['lat'] as num).toDouble(),
                (point['lng'] as num).toDouble(),
              ))
          .toList();
    } else {
      polygonPoints = null;
    }

    final recipientIds = map['notification_recipient_ids'] as List<dynamic>?;
    final List<String> notificationRecipientIds = recipientIds != null
        ? recipientIds.map((id) => id.toString()).toList()
        : [];

    return Geofence(
      id: id,
      organizationId: map['organization_id'] as String? ?? '',
      locationId: map['location_id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      type: GeofenceType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => GeofenceType.circle,
      ),
      centerLat: (map['center_lat'] as num?)?.toDouble() ?? 0.0,
      centerLng: (map['center_lng'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (map['radius_meters'] as num?)?.toDouble(),
      polygonPoints: polygonPoints,
      notificationRecipientIds: notificationRecipientIds,
      isActive: map['is_active'] as bool? ?? true,
      metadata: map['metadata'] as Map<String, dynamic>?,
      createdAt: (map['created_at'] as Timestamp?)?.toDate(),
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organization_id': organizationId,
      'location_id': locationId,
      'name': name,
      'type': type.name,
      'center_lat': centerLat,
      'center_lng': centerLng,
      if (radiusMeters != null) 'radius_meters': radiusMeters,
      if (polygonPoints != null)
        'polygon_points': polygonPoints!.map((point) => {
              'lat': point.latitude,
              'lng': point.longitude,
            }).toList(),
      'notification_recipient_ids': notificationRecipientIds,
      'is_active': isActive,
      if (metadata != null) 'metadata': metadata,
      if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updated_at': Timestamp.fromDate(updatedAt!),
    };
  }

  Geofence copyWith({
    String? id,
    String? organizationId,
    String? locationId,
    String? name,
    GeofenceType? type,
    double? centerLat,
    double? centerLng,
    double? radiusMeters,
    List<LatLng>? polygonPoints,
    List<String>? notificationRecipientIds,
    bool? isActive,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Geofence(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      locationId: locationId ?? this.locationId,
      name: name ?? this.name,
      type: type ?? this.type,
      centerLat: centerLat ?? this.centerLat,
      centerLng: centerLng ?? this.centerLng,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      polygonPoints: polygonPoints ?? this.polygonPoints,
      notificationRecipientIds: notificationRecipientIds ?? this.notificationRecipientIds,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Simple LatLng class for polygon points
class LatLng {
  const LatLng(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}
