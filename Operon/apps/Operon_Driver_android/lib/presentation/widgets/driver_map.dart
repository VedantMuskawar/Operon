import 'dart:async';

import 'package:core_models/core_models.dart' hide LatLng;
import 'package:core_ui/core_ui.dart' show darkMapStyle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:operon_driver_android/core/services/location_service.dart';
import 'package:operon_driver_android/core/utils/path_simplifier.dart';
import 'package:operon_auth_flow/operon_auth_flow.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DriverMap extends StatefulWidget {
  const DriverMap({
    super.key,
    required this.locationService,
    required this.myLocationEnabled,
    required this.myLocationButtonEnabled,
    required this.showPath,
    this.deliveryPointIndex,
    this.historicalPath,
    this.tripId,
    this.onPathLengthChanged,
  });

  final LocationService locationService;
  final bool myLocationEnabled;
  final bool myLocationButtonEnabled;
  final bool showPath;
  final int? deliveryPointIndex;
  final List<LatLng>? historicalPath;
  final ValueChanged<int>? onPathLengthChanged;
  final String? tripId; // Used to reset path when trip changes

  @override
  State<DriverMap> createState() => _DriverMapState();
}

class _DriverMapState extends State<DriverMap> {
  GoogleMapController? _controller;
  StreamSubscription? _locationSub;
  final List<LatLng> _pathPoints = <LatLng>[];
  String? _currentTripId;
  Set<Circle> _geofenceCircles = {};
  Set<Polygon> _geofencePolygons = {};

  // Fallback until we receive the first location update.
  static const _initialCamera = CameraPosition(
    target: LatLng(20.5937, 78.9629), // India center (safe fallback)
    zoom: 5,
  );

  @override
  void initState() {
    super.initState();
    _loadGeofences();

    // If historical path is provided, use it instead of live stream
    if (widget.historicalPath != null && widget.historicalPath!.isNotEmpty) {
      _pathPoints.addAll(widget.historicalPath!);
      // Center camera on historical path
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _centerOnPath();
      });
      return;
    }

    // Otherwise, listen to live location stream
    _currentTripId = widget.tripId;
    DateTime? _lastCameraUpdate;
    _locationSub = widget.locationService.currentLocationStream.listen((loc) async {
      final controller = _controller;
      if (controller == null) return;

      // Reset path if trip changed
      if (widget.tripId != null && widget.tripId != _currentTripId) {
        _pathPoints.clear();
        _currentTripId = widget.tripId;
        widget.onPathLengthChanged?.call(0);
      }

      final point = LatLng(loc.lat, loc.lng);

      // Build a simple trail so the driver sees a line "following" them.
      // Keep it lightweight by only adding points when we moved a bit.
      final last = _pathPoints.isNotEmpty ? _pathPoints.last : null;
      bool pathUpdated = false;
      if (last == null) {
        _pathPoints.add(point);
        pathUpdated = true;
      } else {
        final meters = Geolocator.distanceBetween(
          last.latitude,
          last.longitude,
          point.latitude,
          point.longitude,
        );
        if (meters >= 3) {
          _pathPoints.add(point);
          pathUpdated = true;
          // Prevent unbounded memory growth on long shifts using path simplification.
          // This preserves the trip start and current position while reducing memory usage.
          if (_pathPoints.length > 1500) {
            final simplified = PathSimplifier.simplifyPath(_pathPoints, 5.0);
            _pathPoints.clear();
            _pathPoints.addAll(simplified);
            // Note: deliveryPointIndex adjustment is handled by parent
            // (parent should track relative to current path, not absolute)
          }
        }
      }

      // Only trigger rebuild if path actually changed
      if (pathUpdated && mounted) {
        setState(() {});
        // Notify parent of path length change
        widget.onPathLengthChanged?.call(_pathPoints.length);
      }

      // Throttle camera updates to reduce BLASTBufferQueue warnings
      // Update camera max once per second to prevent rendering overload
      final now = DateTime.now();
      if (_lastCameraUpdate == null ||
          now.difference(_lastCameraUpdate!).inMilliseconds >= 1000) {
        _lastCameraUpdate = now;
        final camera = CameraUpdate.newCameraPosition(
          CameraPosition(
            target: point,
            zoom: 17,
            bearing: (loc.bearing).isFinite ? loc.bearing : 0,
            tilt: 0,
          ),
        );

        try {
          await controller.animateCamera(camera);
        } catch (_) {
          // Camera animation can fail if map is not ready; ignore.
        }
      }
    });
  }

  void _centerOnPath() {
    final controller = _controller;
    if (controller == null || _pathPoints.isEmpty) return;

    final first = _pathPoints.first;
    final bounds = LatLngBounds(
      southwest: LatLng(
        _pathPoints.map((p) => p.latitude).reduce((a, b) => a < b ? a : b),
        _pathPoints.map((p) => p.longitude).reduce((a, b) => a < b ? a : b),
      ),
      northeast: LatLng(
        _pathPoints.map((p) => p.latitude).reduce((a, b) => a > b ? a : b),
        _pathPoints.map((p) => p.longitude).reduce((a, b) => a > b ? a : b),
      ),
    );

    try {
      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    } catch (_) {
      // Fallback to first point if bounds calculation fails
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: first, zoom: 15),
        ),
      );
    }
  }

  @override
  void didUpdateWidget(DriverMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If trip ID changed, reset path for new trip
    if (widget.tripId != null && widget.tripId != oldWidget.tripId) {
      _pathPoints.clear();
      _currentTripId = widget.tripId;
      widget.onPathLengthChanged?.call(0);
    }
    
    // If historical path changed, update path points
    if (widget.historicalPath != null &&
        widget.historicalPath != oldWidget.historicalPath) {
      _pathPoints.clear();
      _pathPoints.addAll(widget.historicalPath!);
      if (mounted) {
        setState(() {});
        _centerOnPath();
      }
    }
    // If switching from historical to live (or vice versa), reset path
    if ((widget.historicalPath == null) != (oldWidget.historicalPath == null)) {
      _pathPoints.clear();
      if (widget.historicalPath != null) {
        _pathPoints.addAll(widget.historicalPath!);
        if (mounted) {
          setState(() {});
          _centerOnPath();
        }
      } else {
        // Switching to live - reset trip tracking
        _currentTripId = widget.tripId;
        widget.onPathLengthChanged?.call(0);
      }
    }
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _locationSub = null;
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final polylines = <Polyline>{};

    if (widget.showPath && _pathPoints.length >= 2) {
      final deliveryIndex = widget.deliveryPointIndex;

      if (deliveryIndex != null && deliveryIndex >= 0 && deliveryIndex < _pathPoints.length) {
        // Two separate polylines: orange before delivery, blue after
        // Pre-delivery polyline (orange) - includes delivery point to avoid gap
        polylines.add(
          Polyline(
            polylineId: const PolylineId('driver_path_pre_delivery'),
            points: List<LatLng>.unmodifiable(
              _pathPoints.sublist(0, deliveryIndex + 1),
            ),
            width: 6,
            color: AuthColors.warning,
          ),
        );

        // Post-delivery polyline (blue) - starts with delivery point
        polylines.add(
          Polyline(
            polylineId: const PolylineId('driver_path_post_delivery'),
            points: List<LatLng>.unmodifiable(
              _pathPoints.sublist(deliveryIndex),
            ),
            width: 6,
            color: AuthColors.info,
          ),
        );
      } else {
        // Single orange polyline (no delivery yet)
        polylines.add(
          Polyline(
            polylineId: const PolylineId('driver_path'),
            points: List<LatLng>.unmodifiable(_pathPoints),
            width: 6,
            color: AuthColors.warning,
          ),
        );
      }
    }

    return GoogleMap(
      initialCameraPosition: _initialCamera,
      myLocationEnabled: widget.myLocationEnabled,
      myLocationButtonEnabled: widget.myLocationButtonEnabled,
      compassEnabled: true,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      polylines: polylines,
      circles: _geofenceCircles,
      polygons: _geofencePolygons,
      onMapCreated: (controller) {
        _controller = controller;
        // Set dark map style
        controller.setMapStyle(darkMapStyle);
        // If we have historical path, center on it
        if (widget.historicalPath != null && widget.historicalPath!.isNotEmpty) {
          _centerOnPath();
        }
      },
    );
  }

  Future<void> _loadGeofences() async {
    try {
      // Get organization ID from context
      final orgContext = context.read<OrganizationContextCubit>();
      final organization = orgContext.state.organization;
      if (organization == null) return;

      final firestore = FirebaseFirestore.instance;
      final geofencesSnapshot = await firestore
          .collection('ORGANIZATIONS')
          .doc(organization.id)
          .collection('GEOFENCES')
          .get();

      final geofences = geofencesSnapshot.docs
          .map((doc) => Geofence.fromMap(doc.data(), doc.id))
          .toList();

      if (mounted) {
        setState(() {
          _geofenceCircles = _buildCircles(geofences);
          _geofencePolygons = _buildPolygons(geofences);
        });
      }
    } catch (e) {
      debugPrint('[DriverMap] Failed to load geofences: $e');
      if (mounted) {
        setState(() {
          _geofenceCircles = {};
          _geofencePolygons = {};
        });
      }
    }
  }

  Set<Circle> _buildCircles(List<Geofence> geofences) {
    final circles = <Circle>{};
    for (final geofence in geofences) {
      if (geofence.type == GeofenceType.circle) {
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

  Set<Polygon> _buildPolygons(List<Geofence> geofences) {
    final polygons = <Polygon>{};
    for (final geofence in geofences) {
      if (geofence.type == GeofenceType.polygon &&
          geofence.polygonPoints != null &&
          geofence.polygonPoints!.isNotEmpty) {
        final isActive = geofence.isActive;
        polygons.add(
          Polygon(
            polygonId: PolygonId(geofence.id),
            points: geofence.polygonPoints!
                .map((p) => LatLng(p.latitude, p.longitude))
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

