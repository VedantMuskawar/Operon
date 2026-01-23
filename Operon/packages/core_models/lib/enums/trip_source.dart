/// Source of trip status change.
/// 
/// Indicates whether a trip status change was initiated by the driver or client.
enum TripSource {
  /// Status change initiated by driver (via Driver App)
  driver,
  
  /// Status change initiated by client (via Client App/Web)
  client,
}

/// Extension to convert TripSource to/from string
extension TripSourceExtension on TripSource {
  String get value {
    switch (this) {
      case TripSource.driver:
        return 'driver';
      case TripSource.client:
        return 'client';
    }
  }

  static TripSource? fromString(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'driver':
        return TripSource.driver;
      case 'client':
        return TripSource.client;
      default:
        return null;
    }
  }
}
