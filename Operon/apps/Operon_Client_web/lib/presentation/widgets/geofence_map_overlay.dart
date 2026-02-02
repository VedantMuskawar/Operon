import 'package:core_models/core_models.dart' hide LatLng;
import 'package:core_ui/core_ui.dart' show AuthColors;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GeofenceMapOverlay {
  static Set<Circle> buildCircles(List<Geofence> geofences) {
    final circles = <Circle>{};
    for (final geofence in geofences) {
      if (geofence.type == GeofenceType.circle) {
        // Always show all geofences, but use different colors for active/inactive
        final isActive = geofence.isActive;
        circles.add(
          Circle(
            circleId: CircleId(geofence.id),
            center: LatLng(geofence.centerLat, geofence.centerLng),
            radius: geofence.radiusMeters ?? 0,
            fillColor: isActive
                ? AuthColors.successVariant.withValues(alpha: 0.2)
                : AuthColors.textDisabled.withValues(alpha: 0.1),
            strokeColor: isActive
                ? AuthColors.successVariant
                : AuthColors.textDisabled,
            strokeWidth: isActive ? 2 : 1,
          ),
        );
      }
    }
    return circles;
  }

  static Set<Polygon> buildPolygons(List<Geofence> geofences) {
    final polygons = <Polygon>{};
    for (final geofence in geofences) {
      if (geofence.type == GeofenceType.polygon &&
          geofence.polygonPoints != null &&
          geofence.polygonPoints!.isNotEmpty) {
        // Always show all geofences, but use different colors for active/inactive
        final isActive = geofence.isActive;
        polygons.add(
          Polygon(
            polygonId: PolygonId(geofence.id),
            points: geofence.polygonPoints!
                .map<LatLng>((p) => LatLng(p.latitude, p.longitude))
                .toList(),
            fillColor: isActive
                ? AuthColors.successVariant.withValues(alpha: 0.2)
                : AuthColors.textDisabled.withValues(alpha: 0.1),
            strokeColor: isActive
                ? AuthColors.successVariant
                : AuthColors.textDisabled,
            strokeWidth: isActive ? 2 : 1,
          ),
        );
      }
    }
    return polygons;
  }
}
