class Trip {
  const Trip({
    required this.id,
    required this.driverId,
    required this.clientId,
    required this.status,
    required this.startTime,
    this.endTime,
    this.computedTravelledDistance,
  });

  final String id;
  final String driverId;
  final String clientId;
  final String status;

  /// Milliseconds since epoch.
  final int startTime;

  /// Milliseconds since epoch.
  final int? endTime;

  /// Total distance traveled in meters, computed incrementally from GPS locations.
  final double? computedTravelledDistance;

  Map<String, dynamic> toJson() {
    return {
      'driverId': driverId,
      'clientId': clientId,
      'status': status,
      'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      if (computedTravelledDistance != null) 'computedTravelledDistance': computedTravelledDistance,
    };
  }

  factory Trip.fromJson(Map<String, dynamic> json, String id) {
    return Trip(
      id: id,
      driverId: json['driverId'] as String? ?? '',
      clientId: json['clientId'] as String? ?? '',
      status: json['status'] as String? ?? '',
      startTime: (json['startTime'] as num?)?.toInt() ?? 0,
      endTime: (json['endTime'] as num?)?.toInt(),
      computedTravelledDistance: (json['computedTravelledDistance'] as num?)?.toDouble(),
    );
  }

  Trip copyWith({
    String? id,
    String? driverId,
    String? clientId,
    String? status,
    int? startTime,
    int? endTime,
    double? computedTravelledDistance,
  }) {
    return Trip(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      clientId: clientId ?? this.clientId,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      computedTravelledDistance: computedTravelledDistance ?? this.computedTravelledDistance,
    );
  }
}

