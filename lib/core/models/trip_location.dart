import 'package:cloud_firestore/cloud_firestore.dart';

class TripLocation {
  TripLocation({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.id,
    this.altitude,
    this.speed,
    this.accuracy,
    this.heading,
    this.source,
  });

  final String? id;
  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final double? altitude;
  final double? speed;
  final double? accuracy;
  final double? heading;
  final String? source;

  factory TripLocation.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return TripLocation(
      id: snapshot.id,
      latitude: _parseDouble(data['latitude']),
      longitude: _parseDouble(data['longitude']),
      recordedAt: _parseTimestamp(data['recordedAt']),
      altitude: _parseNullableDouble(data['altitude']),
      speed: _parseNullableDouble(data['speed']),
      accuracy: _parseNullableDouble(data['accuracy']),
      heading: _parseNullableDouble(data['heading']),
      source: data['source'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'recordedAt': Timestamp.fromDate(recordedAt),
      if (altitude != null) 'altitude': altitude,
      if (speed != null) 'speed': speed,
      if (accuracy != null) 'accuracy': accuracy,
      if (heading != null) 'heading': heading,
      if (source != null && source!.isNotEmpty) 'source': source,
    };
  }

  TripLocation copyWith({
    double? latitude,
    double? longitude,
    DateTime? recordedAt,
    double? altitude,
    double? speed,
    double? accuracy,
    double? heading,
    String? source,
  }) {
    return TripLocation(
      id: id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      recordedAt: recordedAt ?? this.recordedAt,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      accuracy: accuracy ?? this.accuracy,
      heading: heading ?? this.heading,
      source: source ?? this.source,
    );
  }

  static double _parseDouble(dynamic value, {double fallback = 0}) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value') ?? fallback;
  }

  static double? _parseNullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value');
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}


