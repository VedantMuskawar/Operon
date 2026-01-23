/// Exception thrown when a trip is unavailable (cancelled, already started, etc.)
class TripUnavailableException implements Exception {
  TripUnavailableException(this.message, {this.tripId});

  final String message;
  final String? tripId;

  @override
  String toString() => 'TripUnavailableException: $message${tripId != null ? ' (Trip ID: $tripId)' : ''}';
}

/// Exception thrown when a trip document is not found
class TripNotFoundException implements Exception {
  TripNotFoundException(this.message, {this.tripId});

  final String message;
  final String? tripId;

  @override
  String toString() => 'TripNotFoundException: $message${tripId != null ? ' (Trip ID: $tripId)' : ''}';
}
