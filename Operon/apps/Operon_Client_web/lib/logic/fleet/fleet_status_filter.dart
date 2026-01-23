/// Fleet status filter enum for filtering vehicles on the map.
enum FleetStatusFilter {
  /// Show all vehicles regardless of status.
  all,

  /// Show only vehicles that are moving (speed > 1.0 m/s).
  moving,

  /// Show only vehicles that are idling (speed <= 1.0 m/s but online).
  idling,

  /// Show only vehicles that are offline.
  offline,
}

/// Statistics about fleet status distribution.
class FleetStats {
  const FleetStats({
    required this.moving,
    required this.idling,
    required this.offline,
    required this.total,
  });

  final int moving;
  final int idling;
  final int offline;
  final int total;

  /// Create FleetStats from a list of drivers.
  /// 
  /// [drivers] - List of FleetDriver objects to analyze.
  /// [speedThreshold] - Speed threshold in m/s to distinguish moving from idling (default: 1.0).
  factory FleetStats.fromDrivers(
    List<dynamic> drivers, {
    double speedThreshold = 1.0,
  }) {
    int moving = 0;
    int idling = 0;
    int offline = 0;

    for (final driver in drivers) {
      // Access location and isOffline properties
      // Handle FleetDriver objects (from fleet_bloc.dart)
      double speed = 0.0;
      bool isOffline = false;
      
      // Use dynamic access to handle FleetDriver objects
      try {
        final location = (driver as dynamic).location;
        isOffline = (driver as dynamic).isOffline ?? false;
        speed = (location?.speed ?? 0.0).toDouble();
      } catch (e) {
        // Fallback: try to access as map
        try {
          final location = driver['location'];
          isOffline = driver['isOffline'] ?? false;
          speed = (location?['speed'] ?? location?.speed ?? 0.0).toDouble();
        } catch (_) {
          // Skip invalid entries
          continue;
        }
      }

      if (isOffline) {
        offline++;
      } else if (speed > speedThreshold) {
        moving++;
      } else {
        idling++;
      }
    }

    return FleetStats(
      moving: moving,
      idling: idling,
      offline: offline,
      total: drivers.length,
    );
  }

  FleetStats copyWith({
    int? moving,
    int? idling,
    int? offline,
    int? total,
  }) {
    return FleetStats(
      moving: moving ?? this.moving,
      idling: idling ?? this.idling,
      offline: offline ?? this.offline,
      total: total ?? this.total,
    );
  }
}
