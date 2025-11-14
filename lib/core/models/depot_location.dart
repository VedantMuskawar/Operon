import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class DepotLocation extends Equatable {
  final String depotId;
  final double latitude;
  final double longitude;
  final String? label;
  final String? address;
  final bool isPrimary;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DepotLocation({
    required this.depotId,
    required this.latitude,
    required this.longitude,
    this.label,
    this.address,
    this.isPrimary = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DepotLocation.fromDocument(
    String depotId,
    Map<String, dynamic> map,
  ) {
    return DepotLocation(
      depotId: depotId,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      label: map['label'] as String?,
      address: map['address'] as String?,
      isPrimary: map['isPrimary'] as bool? ?? true,
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'depotId': depotId,
      'latitude': latitude,
      'longitude': longitude,
      'label': label,
      'address': address,
      'isPrimary': isPrimary,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  DepotLocation copyWith({
    String? depotId,
    double? latitude,
    double? longitude,
    String? label,
    String? address,
    bool? isPrimary,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DepotLocation(
      depotId: depotId ?? this.depotId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      label: label ?? this.label,
      address: address ?? this.address,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        depotId,
        latitude,
        longitude,
        label,
        address,
        isPrimary,
        createdAt,
        updatedAt,
      ];

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.now();
  }
}

