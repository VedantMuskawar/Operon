import 'dart:async';

import 'package:core_models/core_models.dart' show DriverLocation;
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class OrdersMapView extends StatefulWidget {
  const OrdersMapView({super.key});

  @override
  State<OrdersMapView> createState() => _OrdersMapViewState();
}

class _OrdersMapViewState extends State<OrdersMapView> {
  static const _initialCamera = CameraPosition(
    target: LatLng(20.5937, 78.9629),
    zoom: 5,
  );
  static const _staleThreshold = Duration(minutes: 10);

  GoogleMapController? _controller;
  StreamSubscription<DatabaseEvent>? _subscription;

  List<_LiveVehicle> _vehicles = [];
  Set<Marker> _markers = {};
  String? _selectedVehicleId;
  bool _didFitBoundsOnce = false;

  @override
  void initState() {
    super.initState();
    _startLiveListener();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _startLiveListener() {
    _subscription?.cancel();
    _subscription = FirebaseDatabase.instance
        .ref('active_drivers')
        .onValue
        .listen(_handleSnapshot, onError: (_) {
      if (!mounted) return;
      setState(() {
        _vehicles = [];
        _markers = {};
        _selectedVehicleId = null;
        _didFitBoundsOnce = false;
      });
    });
  }

  void _handleSnapshot(DatabaseEvent event) {
    final raw = event.snapshot.value;
    if (raw == null || raw is! Map) {
      if (!mounted) return;
      setState(() {
        _vehicles = [];
        _markers = {};
        _selectedVehicleId = null;
        _didFitBoundsOnce = false;
      });
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final vehicles = <_LiveVehicle>[];

    for (final entry in raw.entries) {
      final uid = entry.key?.toString();
      if (uid == null || uid.isEmpty) continue;

      final value = entry.value;
      if (value is! Map) continue;

      final json = <String, dynamic>{};
      for (final kv in value.entries) {
        final key = kv.key?.toString();
        if (key == null) continue;
        json[key] = kv.value;
      }

      final location = DriverLocation.fromJson(json);
      if (location.lat == 0.0 && location.lng == 0.0) continue;

      final age = Duration(milliseconds: (nowMs - location.timestamp).abs());
      final isOffline = location.timestamp == 0 || age > _staleThreshold;
      final vehicleNumber = _extractVehicleNumber(uid: uid, json: json);

      vehicles.add(
        _LiveVehicle(
          uid: uid,
          vehicleNumber: vehicleNumber,
          location: location,
          isOffline: isOffline,
        ),
      );
    }

    vehicles.sort((a, b) => a.vehicleNumber.compareTo(b.vehicleNumber));

    if (_selectedVehicleId != null &&
        !vehicles.any((v) => v.uid == _selectedVehicleId)) {
      _selectedVehicleId = null;
      _didFitBoundsOnce = false;
    }

    final markers = _buildMarkers(vehicles);

    if (!mounted) return;
    setState(() {
      _vehicles = vehicles;
      _markers = markers;
    });

    if (_selectedVehicleId != null) {
      _zoomToVehicle(_selectedVehicleId!);
    } else if (!_didFitBoundsOnce) {
      _fitToAllVehicles(vehicles);
      _didFitBoundsOnce = true;
    }
  }

  Set<Marker> _buildMarkers(List<_LiveVehicle> vehicles) {
    final markers = <Marker>{};
    for (final vehicle in vehicles) {
      final isSelected = vehicle.uid == _selectedVehicleId;
      final hue = isSelected
          ? BitmapDescriptor.hueViolet
          : (vehicle.isOffline
              ? BitmapDescriptor.hueAzure
              : BitmapDescriptor.hueGreen);

      final bearing =
          vehicle.location.bearing.isFinite ? vehicle.location.bearing : 0.0;
      final rotation = bearing % 360;

      markers.add(
        Marker(
          markerId: MarkerId(vehicle.uid),
          position: LatLng(vehicle.location.lat, vehicle.location.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          alpha: vehicle.isOffline ? 0.4 : 1.0,
          anchor: const Offset(0.5, 1.0),
          rotation: rotation,
          flat: true,
          infoWindow: InfoWindow(
            title: vehicle.vehicleNumber,
            snippet: vehicle.isOffline ? 'Offline' : 'Live',
          ),
        ),
      );
    }
    return markers;
  }

  void _fitToAllVehicles(List<_LiveVehicle> vehicles) {
    final controller = _controller;
    if (controller == null || vehicles.isEmpty) return;

    var minLat = double.infinity;
    var minLng = double.infinity;
    var maxLat = -double.infinity;
    var maxLng = -double.infinity;

    for (final vehicle in vehicles) {
      final lat = vehicle.location.lat;
      final lng = vehicle.location.lng;
      minLat = lat < minLat ? lat : minLat;
      minLng = lng < minLng ? lng : minLng;
      maxLat = lat > maxLat ? lat : maxLat;
      maxLng = lng > maxLng ? lng : maxLng;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 72));
  }

  void _zoomToVehicle(String vehicleId) {
    final controller = _controller;
    if (controller == null || _vehicles.isEmpty) return;
    final vehicle = _vehicles.firstWhere(
      (v) => v.uid == vehicleId,
      orElse: () => _vehicles.first,
    );

    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(vehicle.location.lat, vehicle.location.lng),
          zoom: 16,
          bearing: vehicle.location.bearing.isFinite
              ? vehicle.location.bearing
              : 0.0,
          tilt: 35,
        ),
      ),
    );
  }

  void _selectVehicle(String? vehicleId) {
    setState(() {
      _selectedVehicleId = vehicleId;
      _didFitBoundsOnce = false;
    });

    if (vehicleId == null) {
      _fitToAllVehicles(_vehicles);
      _didFitBoundsOnce = true;
    } else {
      _zoomToVehicle(vehicleId);
    }
  }

  String _extractVehicleNumber({
    required String uid,
    required Map<String, dynamic> json,
  }) {
    final v = json['vehicleNumber'];
    if (v is String && v.trim().isNotEmpty) return v.trim();
    final alt = json['vehicleNo'] ?? json['vehicle_no'] ?? json['plateNumber'];
    if (alt is String && alt.trim().isNotEmpty) return alt.trim();
    final suffix = uid.length > 6 ? uid.substring(uid.length - 6) : uid;
    return 'VH-$suffix';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.paddingLG,
        AppSpacing.paddingLG,
        AppSpacing.paddingLG,
        AppSpacing.paddingXXL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 48,
            child: _vehicles.isEmpty
                ? _EmptyVehiclesPill(onShowAll: _startLiveListener)
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 4),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _VehicleOptionButton(
                          label: 'All',
                          isSelected: _selectedVehicleId == null,
                          isOffline: false,
                          onTap: () => _selectVehicle(null),
                        );
                      }
                      final vehicle = _vehicles[index - 1];
                      return _VehicleOptionButton(
                        label: vehicle.vehicleNumber,
                        isSelected: vehicle.uid == _selectedVehicleId,
                        isOffline: vehicle.isOffline,
                        onTap: () => _selectVehicle(vehicle.uid),
                      );
                    },
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.gapSM),
                    itemCount: _vehicles.length + 1,
                  ),
          ),
          const SizedBox(height: AppSpacing.paddingMD),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusXXL),
                border: Border.all(color: AuthColors.textMainWithOpacity(0.12)),
                color: AuthColors.surface,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GoogleMap(
                      initialCameraPosition: _initialCamera,
                      markers: _markers,
                      style: darkMapStyle,
                      mapToolbarEnabled: false,
                      zoomControlsEnabled: false,
                      compassEnabled: false,
                      myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                      onMapCreated: (controller) async {
                        _controller = controller;
                        if (_vehicles.isNotEmpty &&
                            _selectedVehicleId == null) {
                          _fitToAllVehicles(_vehicles);
                          _didFitBoundsOnce = true;
                        }
                      },
                    ),
                  ),
                  if (_vehicles.isEmpty)
                    const Center(
                      child: Text(
                        'No live vehicles yet',
                        style: TextStyle(
                          color: AuthColors.textSub,
                          fontSize: 14,
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

class _LiveVehicle {
  const _LiveVehicle({
    required this.uid,
    required this.vehicleNumber,
    required this.location,
    required this.isOffline,
  });

  final String uid;
  final String vehicleNumber;
  final DriverLocation location;
  final bool isOffline;
}

class _VehicleOptionButton extends StatelessWidget {
  const _VehicleOptionButton({
    required this.label,
    required this.isSelected,
    required this.isOffline,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isOffline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final baseColor = isOffline ? AuthColors.textDisabled : AuthColors.primary;
    final textColor = isSelected ? AuthColors.background : AuthColors.textMain;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.paddingLG,
          vertical: AppSpacing.paddingSM,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? baseColor
              : AuthColors.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
          border: Border.all(
            color:
                isSelected ? baseColor : AuthColors.textMainWithOpacity(0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isOffline ? AuthColors.textDisabled : AuthColors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.gapXS),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyVehiclesPill extends StatelessWidget {
  const _EmptyVehiclesPill({required this.onShowAll});

  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.paddingLG,
        vertical: AppSpacing.paddingSM,
      ),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AuthColors.textSub),
          const SizedBox(width: AppSpacing.gapSM),
          const Text(
            'Waiting for live vehicles',
            style: TextStyle(
              color: AuthColors.textSub,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: AppSpacing.gapSM),
          GestureDetector(
            onTap: onShowAll,
            child: const Text(
              'Refresh',
              style: TextStyle(
                color: AuthColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
