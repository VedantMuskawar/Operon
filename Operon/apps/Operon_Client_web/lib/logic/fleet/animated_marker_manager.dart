import 'dart:convert';

import 'package:core_utils/core_utils.dart';
import 'package:flutter/foundation.dart';
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

  /// Update the target position and bearing for a driver.
  /// 
  /// If the driver already has an animation state, the start position is set
  /// to the current interpolated position to prevent jumps.
  void updateTarget({
    required String id,
    required LatLng newPos,
    required double newBearing,
    double? animationProgress,
  }) {
    final existing = _markerStates[id];
    
    if (existing != null && animationProgress != null && animationProgress > 0) {
      // Update from current interpolated position to prevent jumps
      final interpolated = GeoMath.lerpLatLng(
        existing.startPos.latitude,
        existing.startPos.longitude,
        existing.targetPos.latitude,
        existing.targetPos.longitude,
        animationProgress.clamp(0.0, 1.0),
      );
      existing.startPos = LatLng(interpolated['lat']!, interpolated['lng']!);
      existing.startBearing = GeoMath.lerpBearing(
        existing.startBearing,
        existing.targetBearing,
        animationProgress.clamp(0.0, 1.0),
      );
    } else if (existing == null) {
      // First update: start and target are the same (no animation yet)
      _markerStates[id] = _MarkerState(
        startPos: newPos,
        targetPos: newPos,
        startBearing: newBearing,
        targetBearing: newBearing,
        startTime: DateTime.now(),
      );
      return;
    }

    // Update target to new position
    existing.targetPos = newPos;
    existing.targetBearing = newBearing;
    existing.startTime = DateTime.now();
  }

  /// Get interpolated markers based on animation progress.
  /// 
  /// [animationValue] should be in range [0.0, 1.0] from AnimationController.
  /// [icons] maps driver ID to their marker icon.
  /// [vehicleNumbers] maps driver ID to vehicle number string.
  /// [isOffline] maps driver ID to offline status.
  /// [lastUpdatedMins] maps driver ID to minutes since last update.
  Set<Marker> getMarkers({
    required double animationValue,
    required Map<String, BitmapDescriptor> icons,
    required Map<String, String> vehicleNumbers,
    required Map<String, bool> isOffline,
    required Map<String, int> lastUpdatedMins,
  }) {
    final markers = <Marker>{};
    final t = animationValue.clamp(0.0, 1.0);

    for (final entry in _markerStates.entries) {
      final id = entry.key;
      final state = entry.value;

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

      if (icon == null) continue;

      markers.add(
        Marker(
          markerId: MarkerId(id),
          position: currentPos,
          icon: icon,
          flat: true,
          anchor: const Offset(0.5, 1.0), // Pin marker: anchor at bottom center (pointer tip)
          rotation: currentBearing.isFinite ? (currentBearing % 360) : 0.0,
          alpha: offline ? 0.35 : 1.0,
          infoWindow: InfoWindow(
            title: vehicleNumber,
            snippet: offline ? 'Offline • ${mins}m ago' : 'Online • ${mins}m ago',
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
