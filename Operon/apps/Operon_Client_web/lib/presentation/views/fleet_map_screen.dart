import 'dart:async';
import 'dart:math' as math;

import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart' show AuthColors;
import 'package:dash_web/features/fleet_map/logic/history_player_controller.dart';
import 'package:dash_web/logic/fleet/fleet_bloc.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/data/repositories/vehicles_repository.dart';
import 'package:dash_web/data/repositories/geofences_repository.dart';
import 'package:dash_web/presentation/utils/marker_generator.dart';
import 'package:dash_web/presentation/widgets/fleet_vehicle_detail_pill.dart';
import 'package:dash_web/presentation/widgets/glass_info_panel.dart';
import 'package:dash_web/presentation/widgets/geofence_map_overlay.dart';
import 'package:dash_web/presentation/widgets/side_vehicle_selector.dart';
import 'package:dash_web/presentation/widgets/history_search_panel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class FleetMapScreen extends StatefulWidget {
  const FleetMapScreen({super.key});

  @override
  State<FleetMapScreen> createState() => _FleetMapScreenState();
}

class _FleetMapScreenState extends State<FleetMapScreen>
    with SingleTickerProviderStateMixin {
  late final FleetBloc _bloc;
  GoogleMapController? _controller;
  bool _didFitBoundsOnce = false;
  late final AnimationController _animationController;
  Set<Marker> _animatedMarkers = {};
  HistoryPlayerController? _historyController;
  Marker? _historyMarker;
  List<Map<String, dynamic>> _vehicles = [];
  Set<Circle> _geofenceCircles = {};
  Set<Polygon> _geofencePolygons = {};

  static const _initialCamera = CameraPosition(
    target: LatLng(20.5937, 78.9629), // India center
    zoom: 5,
  );

  DateTime? _lastAnimationUpdate;
  static const _animationThrottleMs = 33;

  Timer? _zoomDebounceTimer;
  MarkerTier? _currentTier;

  double? _lastZoom;
  Set<Marker> _clusterMarkers = {};
  double? _lastClusterZoom;
  int _lastClusterDriverCount = -1;

  @override
  void initState() {
    super.initState();
    _bloc = FleetBloc();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(
          seconds: 1), // Short duration loop just to trigger frames
    )..repeat();

    _animationController.addListener(_onAnimationUpdate);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orgContext = context.read<OrganizationContextCubit>().state;
      _bloc.add(LoadFleetData(organizationId: orgContext.organization?.id));
      _loadVehicles();
      _loadGeofences();
    });
  }

  void _onAnimationUpdate() {
    if (!mounted) return;

    final now = DateTime.now();
    if (_lastAnimationUpdate != null) {
      final elapsed = now.difference(_lastAnimationUpdate!).inMilliseconds;
      if (elapsed < _animationThrottleMs) return;
    }
    _lastAnimationUpdate = now;

    // Use DateTime.now() for time-based interpolation instead of controller value
    final animatedMarkers = _bloc.getAnimatedMarkers(now);

    if (animatedMarkers.length != _animatedMarkers.length) {
      setState(() => _animatedMarkers = animatedMarkers);
      return;
    }

    final currentIds = _animatedMarkers.map((m) => m.markerId).toSet();
    final newIds = animatedMarkers.map((m) => m.markerId).toSet();

    if (currentIds.length != newIds.length || !currentIds.containsAll(newIds)) {
      setState(() => _animatedMarkers = animatedMarkers);
      return;
    }

    bool positionsChanged = false;
    for (final marker in animatedMarkers) {
      final existing = _animatedMarkers.firstWhere(
        (m) => m.markerId == marker.markerId,
        orElse: () => marker,
      );
      if (existing.position != marker.position ||
          existing.rotation != marker.rotation) {
        positionsChanged = true;
        break;
      }
    }

    if (positionsChanged) {
      setState(() => _animatedMarkers = animatedMarkers);
    }
  }

  @override
  void dispose() {
    _animationController.removeListener(_onAnimationUpdate);
    _animationController.dispose();
    _zoomDebounceTimer?.cancel();
    _controller?.dispose();
    _controller = null;
    _historyController?.dispose();
    _bloc.close();
    super.dispose();
  }

  FleetState? _lastState;
  bool _cameraFitted = false;

  void _handleStateChanges(FleetState state) {
    if (_lastState == state) return;

    final isEmpty = state.drivers.isEmpty;
    final stateChanged = _lastState?.status != state.status ||
        _lastState?.drivers.length != state.drivers.length ||
        _lastState?.selectedVehicleId != state.selectedVehicleId;

    _lastState = state;

    if (stateChanged && !isEmpty && !_cameraFitted && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (state.isLiveMode && state.selectedVehicleId != null) {
          _zoomToVehicle(state.selectedVehicleId!, state.drivers);
        } else {
          _fitToDriversOnce(state.drivers);
        }
        _cameraFitted = true;
      });
    }

    if (state.selectedVehicleId == null &&
        _lastState?.selectedVehicleId != null) {
      _cameraFitted = false;
    }
  }

  Future<void> _zoomToVehicle(
      String vehicleId, List<FleetDriver> drivers) async {
    final controller = _controller;
    if (controller == null) return;

    final driver = drivers.firstWhere(
      (d) => d.uid == vehicleId,
      orElse: () => drivers.first,
    );

    try {
      final location = driver.location;
      final bearing = location.bearing.isFinite ? location.bearing : 0.0;

      // 3D Chase View
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(location.lat, location.lng),
            zoom: 17,
            bearing: bearing,
            tilt: 45,
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> _fitToAllDrivers(List<FleetDriver> drivers) async {
    if (drivers.isEmpty) return;
    final controller = _controller;
    if (controller == null) return;

    try {
      // Reset to Top-Down Orthographic
      await controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _initialCamera.target, // temporary target
          zoom: _initialCamera.zoom,
          tilt: 0,
          bearing: 0,
        ),
      ));

      if (drivers.length == 1) {
        final d = drivers.first.location;
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(d.lat, d.lng), 14),
        );
        return;
      }

      final bounds = _boundsForDrivers(drivers);
      await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 64));
    } catch (_) {}
  }

  Future<void> _fitToDriversOnce(List<FleetDriver> drivers) async {
    if (_didFitBoundsOnce) return;
    _didFitBoundsOnce = true;
    await _fitToAllDrivers(drivers);
  }

  Future<void> _loadVehicles() async {
    try {
      final orgContext = context.read<OrganizationContextCubit>().state;
      final organization = orgContext.organization;
      if (organization == null) return;

      final vehiclesRepo = context.read<VehiclesRepository>();
      final allVehicles = await vehiclesRepo.fetchVehicles(organization.id);
      final activeVehicles = allVehicles.where((v) => v.isActive).toList();

      if (mounted) {
        setState(() {
          _vehicles = activeVehicles
              .map((v) => {
                    'vehicleNumber': v.vehicleNumber,
                    'vehicleId': v.id,
                  })
              .toList();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _vehicles = []);
    }
  }

  Future<void> _loadGeofences() async {
    try {
      final orgContext = context.read<OrganizationContextCubit>().state;
      final organization = orgContext.organization;
      if (organization == null) return;

      final geofencesRepo = context.read<GeofencesRepository>();
      final geofences = await geofencesRepo.fetchGeofences(organization.id);

      if (mounted) {
        setState(() {
          _geofenceCircles = GeofenceMapOverlay.buildCircles(geofences);
          _geofencePolygons = GeofenceMapOverlay.buildPolygons(geofences);
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _geofenceCircles = {};
          _geofencePolygons = {};
        });
    }
  }

  LatLngBounds _boundsForDrivers(List<FleetDriver> drivers) {
    var minLat = double.infinity;
    var minLng = double.infinity;
    var maxLat = -double.infinity;
    var maxLng = -double.infinity;

    for (final d in drivers) {
      minLat = math.min(minLat, d.location.lat);
      minLng = math.min(minLng, d.location.lng);
      maxLat = math.max(maxLat, d.location.lat);
      maxLng = math.max(maxLng, d.location.lng);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _onCameraMove(double zoom) {
    final wasShowingClusters = _lastZoom != null && _lastZoom! < 8;
    _lastZoom = zoom;
    final showClusters = zoom < 8;
    if (showClusters != wasShowingClusters && mounted) {
      setState(() {});
    }

    _zoomDebounceTimer?.cancel();
    _zoomDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      MarkerTier newTier;
      if (zoom < 11) {
        newTier = MarkerTier.nano;
      } else if (zoom < 15) {
        newTier = MarkerTier.standard;
      } else {
        newTier = MarkerTier.detailed;
      }
      if (_currentTier != newTier) {
        _currentTier = newTier;
        _bloc.add(UpdateMarkerTier(newTier));
      }
    });
  }

  /// Overspeed threshold in m/s (80 km/h) - clusters with any vehicle above this show red status ring.
  static const double _overspeedThresholdMs = 80 / 3.6;

  Future<void> _buildClusterMarkers(List<FleetDriver> drivers) async {
    if (drivers.isEmpty) {
      if (mounted) setState(() => _clusterMarkers = {});
      return;
    }
    const gridStep = 0.1;
    final cellToDrivers = <String, List<FleetDriver>>{};
    for (final d in drivers) {
      final cellLat = (d.location.lat / gridStep).floor();
      final cellLng = (d.location.lng / gridStep).floor();
      final key = '${cellLat}_$cellLng';
      cellToDrivers.putIfAbsent(key, () => []).add(d);
    }
    final markers = <Marker>{};
    for (final entry in cellToDrivers.entries) {
      final parts = entry.key.split('_');
      final cellLat = int.parse(parts[0]);
      final cellLng = int.parse(parts[1]);
      final centerLat = (cellLat + 0.5) * gridStep;
      final centerLng = (cellLng + 0.5) * gridStep;
      final clusterDrivers = entry.value;
      final count = clusterDrivers.length;
      final hasAlert = clusterDrivers.any(
        (d) => !d.isOffline && d.location.speed > _overspeedThresholdMs,
      );
      final icon =
          await MarkerGenerator.createClusterIcon(count, hasAlert: hasAlert);
      markers.add(
        Marker(
          markerId: MarkerId('cluster_${entry.key}'),
          position: LatLng(centerLat, centerLng),
          icon: icon,
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }
    if (mounted) setState(() => _clusterMarkers = markers);
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Center(child: Text('Map available only on Web'));
    }

    return BlocProvider.value(
      value: _bloc,
      child: BlocBuilder<FleetBloc, FleetState>(
        builder: (context, state) {
          _handleStateChanges(state);

          final showClusters = _lastZoom != null && _lastZoom! < 8;
          if (showClusters && state.drivers.isNotEmpty) {
            if (_lastClusterZoom != _lastZoom ||
                _lastClusterDriverCount != state.drivers.length) {
              _lastClusterZoom = _lastZoom;
              _lastClusterDriverCount = state.drivers.length;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _buildClusterMarkers(state.drivers);
              });
            }
          } else if (!showClusters) {
            _clusterMarkers = {};
          }

          var markersToDisplay = showClusters
              ? _clusterMarkers
              : (_animatedMarkers.isNotEmpty
                  ? _animatedMarkers
                  : state.markers);

          if (_historyMarker != null) {
            markersToDisplay = Set.from(markersToDisplay)..add(_historyMarker!);
          }

          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                // 1. Google Map
                Positioned.fill(
                  child: GoogleMap(
                    initialCameraPosition: _initialCamera,
                    markers: markersToDisplay,
                    polylines: state.historyPolylines,
                    circles: _geofenceCircles,
                    polygons: _geofencePolygons,
                    mapToolbarEnabled: false,
                    zoomControlsEnabled: false,
                    compassEnabled: false,
                    onMapCreated: (c) {
                      _controller = c;
                      _onCameraMove(_initialCamera.zoom);
                    },
                    onCameraMove: (CameraPosition position) {
                      _onCameraMove(position.zoom);
                    },
                    onTap: (LatLng position) {
                      if (state.selectedVehicleId != null) {
                        _bloc.add(const ClearVehicleSelection());
                        _fitToAllDrivers(state.drivers);
                      }
                    },
                  ),
                ),

                // UI Overlay (Safe Area)
                Positioned.fill(
                  child: SafeArea(
                    child: Stack(
                      children: [
                        // 2. Left Side: Vehicle Selector (Responsive)
                        if (state.isLiveMode)
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            child: SideVehicleSelector(
                              drivers: state.drivers,
                              selectedVehicleId: state.selectedVehicleId,
                              vehicleNumbers: state.vehicleNumbers,
                              onVehicleSelected: (vehicleId) {
                                _bloc.add(SelectVehicle(vehicleId));
                                _zoomToVehicle(vehicleId, state.drivers);
                              },
                              onShowAll: () {
                                _bloc.add(const ClearVehicleSelection());
                                _fitToAllDrivers(state.drivers);
                              },
                            ),
                          ),

                        // 3. Top Center/Left: History Search Panel
                        if (!state.isLiveMode)
                          Positioned(
                            top: 16,
                            left: 16,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 400),
                              child: HistorySearchPanel(
                                vehicles: _vehicles,
                                onSearchByTripId: (date, vehicleNumber, slot) {
                                  final orgContext = context
                                      .read<OrganizationContextCubit>()
                                      .state;
                                  if (orgContext.organization?.id != null) {
                                    _bloc.add(SearchHistoryByTripId(
                                      date: date,
                                      vehicleNumber: vehicleNumber,
                                      slot: slot,
                                      organizationId:
                                          orgContext.organization!.id,
                                    ));
                                    _didFitBoundsOnce = false;
                                  }
                                },
                                onSearchByDmNumber: (dmNumber) {
                                  final orgContext = context
                                      .read<OrganizationContextCubit>()
                                      .state;
                                  if (orgContext.organization?.id != null) {
                                    _bloc.add(SearchHistoryByDmNumber(
                                      dmNumber: dmNumber,
                                      organizationId:
                                          orgContext.organization!.id,
                                    ));
                                    _didFitBoundsOnce = false;
                                  }
                                },
                              ),
                            ),
                          ),

                        // 4. Top Right: Mode Toggle
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GlassPanel(
                                padding: const EdgeInsets.all(4),
                                borderRadius: BorderRadius.circular(12),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _ModeButton(
                                      label: 'Live',
                                      icon: Icons.play_circle_outline,
                                      isSelected: state.isLiveMode,
                                      onTap: () {
                                        if (!state.isLiveMode) {
                                          _bloc.add(const SetLiveMode());
                                          setState(() {
                                            _historyController?.dispose();
                                            _historyController = null;
                                            _historyMarker = null;
                                            _didFitBoundsOnce = false;
                                          });
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    _ModeButton(
                                      label: 'History',
                                      icon: Icons.history,
                                      isSelected: !state.isLiveMode,
                                      onTap: () {
                                        if (state.isLiveMode) {
                                          final orgContext = context
                                              .read<OrganizationContextCubit>()
                                              .state;
                                          if (orgContext.organization?.id !=
                                              null) {
                                            _bloc.add(SetDateTime(
                                              state.selectedDateTime ??
                                                  DateTime.now(),
                                              orgContext.organization!.id,
                                            ));
                                            _didFitBoundsOnce = false;
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 5. Fleet Legend (Top Right below Mode Toggle)
                        if (state.isLiveMode)
                          Positioned(
                            top: 80,
                            right: 16,
                            child: GlassPanel(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  _StatusDot(
                                      color: AuthColors.success,
                                      label: 'Online'),
                                  const SizedBox(width: 12),
                                  _StatusDot(
                                      color: AuthColors.textDisabled,
                                      label: 'Offline'),
                                ],
                              ),
                            ),
                          ),

                        // 6. Bottom Center: Dynamic Island (Vehicle Details)
                        if (state.selectedVehicleId != null && state.isLiveMode)
                          Builder(
                            builder: (context) {
                              final driver = state.drivers.firstWhere(
                                (d) => d.uid == state.selectedVehicleId,
                                orElse: () => state.drivers.first,
                              );
                              final vehicleNum =
                                  state.vehicleNumbers[driver.uid] ??
                                      driver.uid;

                              return FleetVehicleDetailPill(
                                driver: driver,
                                vehicleNumber: vehicleNum,
                                onClose: () {
                                  _bloc.add(const ClearVehicleSelection());
                                  _fitToAllDrivers(state.drivers);
                                },
                              );
                            },
                          ),

                        // 7. Loading Indicator
                        if (state.status == ViewStatus.loading)
                          Positioned(
                            top: 16,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: GlassPanel(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2)),
                                    SizedBox(width: 8),
                                    Text('Loading...',
                                        style: TextStyle(
                                            color: AuthColors.textMain,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
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
        },
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AuthColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AuthColors.textSub,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AuthColors.textSub,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(color: AuthColors.textMain, fontSize: 12)),
      ],
    );
  }
}
