import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// State for a single marker's animation.
class _MarkerState {
  _MarkerState({
    required this.startPos,
    required this.targetPos,
    required this.startBearing,
    required this.targetBearing,
    required this.startTime,
  });

  LatLng startPos;
  LatLng targetPos;
  double startBearing;
  double targetBearing;
  DateTime startTime;
}

/// Manages smooth animation of fleet markers between position updates.
///
/// Prevents "teleporting" markers by interpolating between the previous and
/// current positions over time. Uses shortest rotation path for bearings
/// to prevent vehicles from spinning backwards.
class AnimatedMarkerManager {
  AnimatedMarkerManager();

  /// Map of driver ID to their current animation state.
  final Map<String, _MarkerState> _markerStates = {};

  /// Expected update interval for smooth interpolation
  static const _updateInterval = Duration(seconds: 5);

  /// Update the target position and bearing for a driver.
  void updateTarget({
    required String id,
    required LatLng newPos,
    required double newBearing,
    required DateTime now,
  }) {
    final existing = _markerStates[id];

    if (existing != null) {
      // Calculate current interpolated position based on time elapsed
      final elapsed = now.difference(existing.startTime).inMilliseconds;
      final t = (elapsed / _updateInterval.inMilliseconds).clamp(0.0, 1.0);

      final interpolated = GeoMath.lerpLatLng(
        existing.startPos.latitude,
        existing.startPos.longitude,
        existing.targetPos.latitude,
        existing.targetPos.longitude,
        t,
      );

      final currentBearing = GeoMath.lerpBearing(
        existing.startBearing,
        existing.targetBearing,
        t,
      );

      // Start new animation segment from where we are now
      existing.startPos = LatLng(interpolated['lat']!, interpolated['lng']!);
      existing.startBearing = currentBearing;
      existing.targetPos = newPos;
      existing.targetBearing = newBearing;
      existing.startTime = now;
    } else {
      // First update
      _markerStates[id] = _MarkerState(
        startPos: newPos,
        targetPos: newPos,
        startBearing: newBearing,
        targetBearing: newBearing,
        startTime: now,
      );
    }
  }

  /// Get interpolated markers based on time.
  ///
  /// [hasDirection] - When true for a driver, marker is rotated by bearing (moving vehicles).
  /// When false or absent, rotation is 0 (idling/stopped/offline).
  Set<Marker> getMarkers({
    required DateTime now,
    required Map<String, BitmapDescriptor> icons,
    required Map<String, String> vehicleNumbers,
    required Map<String, bool> isOffline,
    required Map<String, int> lastUpdatedMins,
    Map<String, bool>? hasDirection,
  }) {
    final markers = <Marker>{};

    for (final entry in _markerStates.entries) {
      final id = entry.key;
      final state = entry.value;

      final elapsed = now.difference(state.startTime).inMilliseconds;
      final t = (elapsed / _updateInterval.inMilliseconds).clamp(0.0, 1.0);

      // Interpolate position
      final interpolated = GeoMath.lerpLatLng(
        state.startPos.latitude,
        state.startPos.longitude,
        state.targetPos.latitude,
        state.targetPos.longitude,
        t,
      );
      final currentPos = LatLng(interpolated['lat']!, interpolated['lng']!);

      // Interpolate bearing
      final currentBearing = GeoMath.lerpBearing(
        state.startBearing,
        state.targetBearing,
        t,
      );

      // Get icon and metadata
      final icon = icons[id];
      final vehicleNumber = vehicleNumbers[id] ?? 'Unknown';
      final offline = isOffline[id] ?? false;
      final mins = lastUpdatedMins[id] ?? 0;
      final useBearing = hasDirection?[id] ?? false;

      if (icon == null) continue;

      final rotation =
          useBearing && currentBearing.isFinite ? (currentBearing % 360) : 0.0;

      markers.add(
        Marker(
          markerId: MarkerId(id),
          position: currentPos,
          icon: icon,
          flat: true,
          anchor: const Offset(
              0.5, 1.0), // Pin marker: anchor at bottom center (pointer tip)
          rotation: rotation,
          alpha: offline ? 0.35 : 1.0,
          infoWindow: InfoWindow(
            title: vehicleNumber,
            snippet:
                offline ? 'Offline • ${mins}m ago' : 'Online • ${mins}m ago',
          ),
        ),
      );
    }

    return markers;
  }

  /// Remove a driver's marker state (e.g., when they go offline or disconnect).
  void removeDriver(String id) {
    _markerStates.remove(id);
  }

  /// Clear all marker states.
  void clear() {
    _markerStates.clear();
  }

  /// Get the number of active markers.
  int get markerCount => _markerStates.length;
}
