/// Trip status enum for SCHEDULE_TRIPS collection.
/// 
/// Represents the current state of a scheduled trip.
enum TripStatus {
  /// Trip is scheduled but not yet dispatched
  scheduled,
  
  /// Trip has been dispatched and is in progress
  dispatched,
  
  /// Trip has been delivered to the customer
  delivered,
  
  /// Trip has been returned (driver returned to base)
  returned,
  
  /// Trip has been cancelled
  cancelled,
}

/// Extension to convert TripStatus to/from string
extension TripStatusExtension on TripStatus {
  String get value {
    switch (this) {
      case TripStatus.scheduled:
        return 'scheduled';
      case TripStatus.dispatched:
        return 'dispatched';
      case TripStatus.delivered:
        return 'delivered';
      case TripStatus.returned:
        return 'returned';
      case TripStatus.cancelled:
        return 'cancelled';
    }
  }

  static TripStatus? fromString(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'scheduled':
        return TripStatus.scheduled;
      case 'dispatched':
        return TripStatus.dispatched;
      case 'delivered':
        return TripStatus.delivered;
      case 'returned':
        return TripStatus.returned;
      case 'cancelled':
        return TripStatus.cancelled;
      default:
        return null;
    }
  }
}
