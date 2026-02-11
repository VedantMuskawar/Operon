import 'dart:async';
import 'dart:math' as math;

import 'package:core_ui/core_ui.dart' show AuthColors, darkMapStyle;
import 'package:dash_web/presentation/widgets/scheduled_trip_tile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ScheduleMapView extends StatefulWidget {
  const ScheduleMapView({
    super.key,
    required this.scheduledTrips,
    this.selectedVehicleId,
    this.onTripsUpdated,
  });

  final List<Map<String, dynamic>> scheduledTrips;
  final String? selectedVehicleId;
  final VoidCallback? onTripsUpdated;

  @override
  State<ScheduleMapView> createState() => _ScheduleMapViewState();
}

class _ScheduleMapViewState extends State<ScheduleMapView> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _didFitBoundsOnce = false;

  // Safe fallback if we have 0 trips with coordinates
  static const _initialCamera = CameraPosition(
    target: LatLng(20.5937, 78.9629), // India center
    zoom: 5,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateMarkers();
    });
  }

  @override
  void didUpdateWidget(ScheduleMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scheduledTrips != widget.scheduledTrips ||
        oldWidget.selectedVehicleId != widget.selectedVehicleId) {
      _updateMarkers();
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _updateMarkers() {
    final filteredTrips = widget.selectedVehicleId != null
        ? widget.scheduledTrips.where((trip) {
            final vehicleId = trip['vehicleId'] as String?;
            return vehicleId == widget.selectedVehicleId;
          }).toList()
        : widget.scheduledTrips;

    final markers = <Marker>{};
    final coordinates = <LatLng>[];

    for (int i = 0; i < filteredTrips.length; i++) {
      final trip = filteredTrips[i];
      final coords = _extractCoordinates(trip);
      
      if (coords != null) {
        coordinates.add(coords);
        final tripStatus = trip['tripStatus'] as String? ?? 
                          trip['orderStatus'] as String? ?? 
                          'scheduled';
        
        markers.add(
          Marker(
            markerId: MarkerId('trip_${trip['id'] ?? i}'),
            position: coords,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              _getMarkerHue(tripStatus),
            ),
            infoWindow: InfoWindow(
              title: trip['clientName'] as String? ?? 'N/A',
              snippet: '${trip['vehicleNumber'] ?? 'N/A'} - Slot ${trip['slot'] ?? 'N/A'}',
            ),
            onTap: () => _showTripOverlay(trip),
          ),
        );
      }
    }

    setState(() {
      _markers = markers;
    });

    // Fit bounds to show all markers
    if (coordinates.isNotEmpty && _mapController != null && !_didFitBoundsOnce) {
      _fitBounds(coordinates);
      _didFitBoundsOnce = true;
    }
  }

  LatLng? _extractCoordinates(Map<String, dynamic> trip) {
    // Strategy 1: Check deliveryZone for coordinates
    final deliveryZone = trip['deliveryZone'] as Map<String, dynamic>?;
    if (deliveryZone != null) {
      final lat = deliveryZone['latitude'] as num?;
      final lng = deliveryZone['longitude'] as num?;
      if (lat != null && lng != null) {
        return LatLng(lat.toDouble(), lng.toDouble());
      }
    }

    // Strategy 2: Check trip data directly for lat/lng
    final tripLat = trip['latitude'] as num?;
    final tripLng = trip['longitude'] as num?;
    if (tripLat != null && tripLng != null) {
      return LatLng(tripLat.toDouble(), tripLng.toDouble());
    }

    // Strategy 3: Check clientId and fetch client coordinates
    // Note: This would require fetching client data, which we'll skip for now
    // and rely on deliveryZone coordinates or show warning

    // If no coordinates found, return null (marker won't be created)
    return null;
  }

  double _getMarkerHue(String tripStatus) {
    switch (tripStatus.toLowerCase()) {
      case 'scheduled':
        return BitmapDescriptor.hueRed;
      case 'dispatched':
        return BitmapDescriptor.hueBlue;
      case 'delivered':
        return BitmapDescriptor.hueGreen;
      case 'returned':
        return BitmapDescriptor.hueViolet;
      default:
        return BitmapDescriptor.hueRed;
    }
  }

  void _fitBounds(List<LatLng> coordinates) {
    if (coordinates.isEmpty || _mapController == null) return;

    double minLat = coordinates.first.latitude;
    double maxLat = coordinates.first.latitude;
    double minLng = coordinates.first.longitude;
    double maxLng = coordinates.first.longitude;

    for (final coord in coordinates) {
      minLat = math.min(minLat, coord.latitude);
      maxLat = math.max(maxLat, coord.latitude);
      minLng = math.min(minLng, coord.longitude);
      maxLng = math.max(maxLng, coord.longitude);
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100.0),
    );
  }

  void _showTripOverlay(Map<String, dynamic> trip) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AuthColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AuthColors.textMainWithOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Trip tile content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: ScheduledTripTile(
                    trip: trip,
                    onTripsUpdated: widget.onTripsUpdated,
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Safety check: only render map on web
    if (!kIsWeb) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AuthColors.textMainWithOpacity(0.12)),
        ),
        child: Center(
          child: Text(
            'Map view is only available on web.\n'
            'Current platform: ${defaultTargetPlatform.name}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AuthColors.textMain),
          ),
        ),
      );
    }

    final tripsWithCoords = widget.scheduledTrips.where((trip) {
      return _extractCoordinates(trip) != null;
    }).length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: _initialCamera,
              markers: _markers,
              mapToolbarEnabled: false,
              zoomControlsEnabled: true,
              compassEnabled: true,
              onMapCreated: (controller) {
                _mapController = controller;
                controller.setMapStyle(darkMapStyle);
                // Fit bounds after map is created
                if (!_didFitBoundsOnce) {
                  final coordinates = _markers.map((m) => m.position).toList();
                  if (coordinates.isNotEmpty) {
                    Future.delayed(const Duration(milliseconds: 500), () {
                      _fitBounds(coordinates);
                      _didFitBoundsOnce = true;
                    });
                  }
                }
              },
            ),
          ),
          // Legend showing status colors
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AuthColors.surface.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AuthColors.textMainWithOpacity(0.1),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Trip Status',
                    style: TextStyle(
                      color: AuthColors.textMain,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  _LegendItem(
                    color: AuthColors.error,
                    label: 'Scheduled',
                  ),
                  SizedBox(height: 4),
                  _LegendItem(
                    color: AuthColors.info,
                    label: 'Dispatched',
                  ),
                  SizedBox(height: 4),
                  _LegendItem(
                    color: AuthColors.success,
                    label: 'Delivered',
                  ),
                  SizedBox(height: 4),
                  _LegendItem(
                    color: AuthColors.warning,
                    label: 'Returned',
                  ),
                ],
              ),
            ),
          ),
          // Warning if some trips don't have coordinates
          if (tripsWithCoords < widget.scheduledTrips.length)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AuthColors.warning.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AuthColors.textMain,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.scheduledTrips.length - tripsWithCoords} trip(s) without location data',
                        style: const TextStyle(
                          color: AuthColors.textMain,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: AuthColors.textSub,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
