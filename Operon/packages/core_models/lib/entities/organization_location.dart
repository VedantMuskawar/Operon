import 'package:cloud_firestore/cloud_firestore.dart';

class OrganizationLocation {
  const OrganizationLocation({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.isPrimary = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String organizationId;
  final String name;
  final double latitude;
  final double longitude;
  final String? address;
  final bool isPrimary;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory OrganizationLocation.fromMap(Map<String, dynamic> map, String id) {
    return OrganizationLocation(
      id: id,
      organizationId: map['organization_id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      address: map['address'] as String?,
      isPrimary: map['is_primary'] as bool? ?? false,
      createdAt: _parseTimestamp(map['created_at']),
      updatedAt: _parseTimestamp(map['updated_at']),
    );
  }

  static DateTime? _parseTimestamp(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is Map && v['_seconds'] != null) {
      final s = (v['_seconds'] as num).toInt();
      return DateTime.fromMillisecondsSinceEpoch(s * 1000);
    }
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'organization_id': organizationId,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      if (address != null) 'address': address,
      'is_primary': isPrimary,
      if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updated_at': Timestamp.fromDate(updatedAt!),
    };
  }

  OrganizationLocation copyWith({
    String? id,
    String? organizationId,
    String? name,
    double? latitude,
    double? longitude,
    String? address,
    bool? isPrimary,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrganizationLocation(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
