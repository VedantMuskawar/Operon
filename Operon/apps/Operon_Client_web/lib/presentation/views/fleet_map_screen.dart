import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart' show AuthColors, darkMapStyle;
import 'package:dash_web/features/fleet_map/logic/history_player_controller.dart';
import 'package:dash_web/features/fleet_map/widgets/history_playback_sheet.dart';
import 'package:dash_web/logic/fleet/fleet_bloc.dart';
import 'package:dash_web/logic/fleet/fleet_status_filter.dart';
import 'package:dash_web/presentation/utils/marker_generator.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/data/repositories/vehicles_repository.dart';
import 'package:dash_web/data/repositories/geofences_repository.dart';
import 'package:dash_web/presentation/widgets/glass_info_panel.dart';
import 'package:dash_web/presentation/widgets/history_search_panel.dart';
import 'package:dash_web/presentation/widgets/search_pill.dart';
import 'package:dash_web/presentation/widgets/vehicle_selector_bar.dart';
import 'package:dash_web/presentation/widgets/geofence_map_overlay.dart';
import 'package:core_models/core_models.dart' hide LatLng;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

// #region agent log
import 'dart:html' as html;
void _debugLog(String location, String message, Map<String, dynamic> data, String hypothesisId) {
  if (kIsWeb) {
    try {
      final payload = jsonEncode({
        'location': location,
        'message': message,
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'sessionId': 'debug-session',
        'runId': 'run1',
        'hypothesisId': hypothesisId,
      });
      html.HttpRequest.request(
        'http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a',
        method: 'POST',
        requestHeaders: {'Content-Type': 'application/json'},
        sendData: payload,
      ).catchError((_) => html.HttpRequest());
    } catch (_) {}
  }
}
// #endregion

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
  String? _selectedVehicleId;
  Marker? _historyMarker;
  List<Map<String, dynamic>> _vehicles = [];
  String? _selectedMarkerVehicleId; // For showing vehicle detail bottom sheet
  Set<Circle> _geofenceCircles = {};
  Set<Polygon> _geofencePolygons = {};

  // Safe fallback if we have 0 drivers.
  static const _initialCamera = CameraPosition(
    target: LatLng(20.5937, 78.9629), // India center (safe fallback)
    zoom: 5,
  );

  // Throttle animation updates to 30fps (every ~33ms) instead of 60fps
  DateTime? _lastAnimationUpdate;
  static const _animationThrottleMs = 33; // ~30fps

  // Zoom-based LOD system
  Timer? _zoomDebounceTimer;
  MarkerTier? _currentTier;

  @override
  void initState() {
    super.initState();
    _bloc = FleetBloc();
    
    // Initialize animation controller for smooth marker interpolation
    // Duration matches RTDB update frequency (~5 seconds)
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(); // Continuously loop the animation
    
    // Listen to animation updates to refresh marker positions
    _animationController.addListener(_onAnimationUpdate);
    
    // Load initial data after first frame to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orgContext = context.read<OrganizationContextCubit>().state;
      _bloc.add(LoadFleetData(organizationId: orgContext.organization?.id));
      _loadVehicles();
      _loadGeofences();
    });
  }

  void _onAnimationUpdate() {
    if (!mounted) return;
    
    // Throttle updates to reduce setState frequency
    final now = DateTime.now();
    if (_lastAnimationUpdate != null) {
      final elapsed = now.difference(_lastAnimationUpdate!).inMilliseconds;
      if (elapsed < _animationThrottleMs) return;
    }
    _lastAnimationUpdate = now;
    
    // Update markers with current animation progress
    final animatedMarkers = _bloc.getAnimatedMarkers(_animationController.value);
    
    // Optimize comparison: check count first, then do deep comparison only if needed
    if (animatedMarkers.length != _animatedMarkers.length) {
      setState(() {
        _animatedMarkers = animatedMarkers;
      });
      return;
    }
    
    // Only do expensive comparison if counts match
    // Compare marker IDs instead of full marker objects
    final currentIds = _animatedMarkers.map((m) => m.markerId).toSet();
    final newIds = animatedMarkers.map((m) => m.markerId).toSet();
    
    if (currentIds != newIds) {
      setState(() {
        _animatedMarkers = animatedMarkers;
      });
      return;
    }
    
    // If IDs match, check if positions changed (most common case)
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
      setState(() {
        _animatedMarkers = animatedMarkers;
      });
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

  // Track last state to avoid unnecessary callbacks
  FleetState? _lastState;
  bool _cameraFitted = false;

  void _handleStateChanges(FleetState state) {
    // Only handle changes if state actually changed
    if (_lastState == state) return;
    
    final isEmpty = state.drivers.isEmpty;
    final stateChanged = _lastState?.status != state.status ||
        _lastState?.drivers.length != state.drivers.length ||
        _lastState?.selectedVehicleId != state.selectedVehicleId;
    
    _lastState = state;
    
    // Fit camera after first non-empty load (only once)
    if (stateChanged && !isEmpty && !_cameraFitted && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // If a vehicle is selected, zoom to it; otherwise fit all
        if (state.isLiveMode && state.selectedVehicleId != null) {
          _zoomToVehicle(state.selectedVehicleId!, state.drivers);
        } else {
          _fitToDriversOnce(state.drivers);
        }
        _cameraFitted = true;
      });
    }
    
    // Reset camera fitted flag when switching modes or clearing selection
    if (state.selectedVehicleId == null && _lastState?.selectedVehicleId != null) {
      _cameraFitted = false;
    }
  }

  void _updateHistoryMarker() {
    if (_historyController == null || _controller == null) return;

    final location = _historyController!.currentLocation;
    if (location == null) return;

    // Only update if position actually changed
    final newPosition = LatLng(location.lat, location.lng);
    if (_historyMarker != null && 
        _historyMarker!.position == newPosition &&
        _historyMarker!.rotation == (location.bearing.isFinite ? (location.bearing % 360) : 0.0)) {
      return; // No change, skip update
    }

    setState(() {
      _historyMarker = Marker(
        markerId: const MarkerId('history_vehicle'),
        position: newPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure,
        ),
        flat: true,
        anchor: const Offset(0.5, 0.5),
        rotation: location.bearing.isFinite ? (location.bearing % 360) : 0.0,
        infoWindow: const InfoWindow(
          title: '',
          snippet: '',
        ), // Disable default InfoWindow
      );
    });

    // Center camera on history marker (throttled)
    _controller!.animateCamera(
      CameraUpdate.newLatLngZoom(newPosition, 15),
    );
  }

  Future<void> _fitToDriversOnce(List<FleetDriver> drivers) async {
    if (_didFitBoundsOnce) return;
    if (drivers.isEmpty) return;

    final controller = _controller;
    if (controller == null) return;

    _didFitBoundsOnce = true;

    try {
      if (drivers.length == 1) {
        final d = drivers.first.location;
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(d.lat, d.lng), 14),
        );
        return;
      }

      final bounds = _boundsForDrivers(drivers);
      await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 64));
    } catch (_) {
      // Map might not be ready; ignore.
    }
  }

  Future<void> _zoomToVehicle(String vehicleId, List<FleetDriver> drivers) async {
    final controller = _controller;
    if (controller == null) return;

    final driver = drivers.firstWhere(
      (d) => d.uid == vehicleId,
      orElse: () => drivers.first,
    );

    try {
      final location = driver.location;
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(location.lat, location.lng), 16),
      );
    } catch (_) {
      // Map might not be ready; ignore.
    }
  }

  Future<void> _fitToAllDrivers(List<FleetDriver> drivers) async {
    if (drivers.isEmpty) return;

    final controller = _controller;
    if (controller == null) return;

    try {
      if (drivers.length == 1) {
        final d = drivers.first.location;
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(d.lat, d.lng), 14),
        );
        return;
      }

      final bounds = _boundsForDrivers(drivers);
      await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 64));
    } catch (_) {
      // Map might not be ready; ignore.
    }
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
          _vehicles = activeVehicles.map((v) => {
            'vehicleNumber': v.vehicleNumber,
            'vehicleId': v.id,
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _vehicles = [];
        });
      }
    }
  }

  Future<void> _loadGeofences() async {
    try {
      final orgContext = context.read<OrganizationContextCubit>().state;
      final organization = orgContext.organization;
      if (organization == null) return;

      final geofencesRepo = context.read<GeofencesRepository>();
      // Load all geofences (active and inactive) to always show them on map
      final geofences = await geofencesRepo.fetchGeofences(organization.id);

      if (mounted) {
        setState(() {
          _geofenceCircles = GeofenceMapOverlay.buildCircles(geofences);
          _geofencePolygons = GeofenceMapOverlay.buildPolygons(geofences);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _geofenceCircles = {};
          _geofencePolygons = {};
        });
      }
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

  /// Handle camera movement with debouncing to update marker tier.
  void _onCameraMove(double zoom) {
    // Cancel existing debounce timer
    _zoomDebounceTimer?.cancel();

    // Start new debounce timer (300ms delay)
    _zoomDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;

      // Determine tier based on zoom level
      MarkerTier newTier;
      if (zoom < 11) {
        newTier = MarkerTier.nano;
      } else if (zoom < 15) {
        newTier = MarkerTier.standard;
      } else {
        newTier = MarkerTier.detailed;
      }

      // Only dispatch event if tier actually changed
      if (_currentTier != newTier) {
        _currentTier = newTier;
        _bloc.add(UpdateMarkerTier(newTier));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Safety check: only render map on web (not macOS/desktop).
    if (!kIsWeb) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AuthColors.textMainWithOpacity(0.12)),
        ),
        child: Center(
          child: Text(
            'Fleet map is only available on web.\n'
            'Current platform: ${defaultTargetPlatform.name}',
            textAlign: TextAlign.center,
            style: TextStyle(color: AuthColors.textMain),
          ),
        ),
      );
    }

    return BlocProvider.value(
      value: _bloc,
      child: BlocBuilder<FleetBloc, FleetState>(
        builder: (context, state) {
          // Handle camera fitting and history controller initialization
          // Use a separate effect to avoid calling addPostFrameCallback in build
          _handleStateChanges(state);
          
          // Use animated markers if available, otherwise fall back to state markers
          var markersToDisplay = _animatedMarkers.isNotEmpty
              ? _animatedMarkers
              : state.markers;

          // Add history marker if available
          if (_historyMarker != null) {
            markersToDisplay = Set.from(markersToDisplay)..add(_historyMarker!);
          }

          // Initialize history controller when history is loaded
          if (state.selectedVehicleHistory != null &&
              _historyController == null &&
              _selectedVehicleId != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _historyController = HistoryPlayerController(
                  historyPoints: state.selectedVehicleHistory!,
                );
                _historyController!.addListener(_updateHistoryMarker);
                _updateHistoryMarker();
              });
            });
          }

          // Calculate fleet stats for filter bar
          final stats = FleetStats.fromDrivers(state.drivers);

          return Container(
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
                    markers: markersToDisplay,
                    polylines: state.historyPolylines,
                    circles: _geofenceCircles,
                    polygons: _geofencePolygons,
                    mapToolbarEnabled: false,
                    zoomControlsEnabled: false,
                    compassEnabled: true,
                    onMapCreated: (c) {
                      _controller = c;
                      // Set dark map style after map is created (required for web)
                      c.setMapStyle(darkMapStyle);
                      // Initialize tier based on initial zoom
                      _onCameraMove(_initialCamera.zoom);
                    },
                    onCameraMove: (CameraPosition position) {
                      _onCameraMove(position.zoom);
                    },
                    onTap: (LatLng position) {
                      // Deselect vehicle when tapping map
                      if (_selectedVehicleId != null) {
                        setState(() {
                          _selectedVehicleId = null;
                          _historyController?.dispose();
                          _historyController = null;
                          _historyMarker = null;
                        });
                      }
                      // Close vehicle detail bottom sheet
                      if (_selectedMarkerVehicleId != null) {
                        setState(() {
                          _selectedMarkerVehicleId = null;
                        });
                      }
                    },
                  ),
                ),
                // Search pill at top center (positioned after map for proper z-index)
                // Material wrapper ensures proper hit testing and blocks map interaction
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Material(
                      color: Colors.transparent,
                      elevation: 8,
                      child: SearchPill(
                        onTap: () {
                          // TODO: Implement search functionality
                        },
                      ),
                    ),
                  ),
                ),
                // Vehicle selector for live mode only (no filter bar in history mode)
                if (state.isLiveMode)
                  Positioned(
                    top: 64,
                    left: 0,
                    right: 0,
                    child: VehicleSelectorBar(
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
                // History search panel for history mode
                if (!state.isLiveMode)
                  Positioned(
                    top: 120,
                    left: 16,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: HistorySearchPanel(
                        vehicles: _vehicles,
                        onSearchByTripId: (date, vehicleNumber, slot) {
                          final orgContext =
                              context.read<OrganizationContextCubit>().state;
                          if (orgContext.organization?.id != null) {
                            _bloc.add(SearchHistoryByTripId(
                              date: date,
                              vehicleNumber: vehicleNumber,
                              slot: slot,
                              organizationId: orgContext.organization!.id,
                            ));
                            _didFitBoundsOnce = false;
                          }
                        },
                        onSearchByDmNumber: (dmNumber) {
                          final orgContext =
                              context.read<OrganizationContextCubit>().state;
                          if (orgContext.organization?.id != null) {
                            _bloc.add(SearchHistoryByDmNumber(
                              dmNumber: dmNumber,
                              organizationId: orgContext.organization!.id,
                            ));
                            _didFitBoundsOnce = false;
                          }
                        },
                      ),
                    ),
                  ),
                // Fleet legend with glass effect
                Positioned(
                  top: 16,
                  left: 16,
                  child: GlassPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: _FleetLegendContent(
                      online: stats.moving + stats.idling,
                      offline: stats.offline,
                      status: state.status,
                    ),
                  ),
                ),
                // Mode toggle switch (Live/History)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Material(
                    color: Colors.transparent,
                    child: GlassPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: _ModeToggleSwitch(
                        isLiveMode: state.isLiveMode,
                        onLiveSelected: () {
                          // Switch to Live mode
                          setState(() {
                            _selectedVehicleId = null;
                            _historyController?.dispose();
                            _historyController = null;
                            _historyMarker = null;
                          });
                          _bloc.add(const SetLiveMode());
                          _didFitBoundsOnce = false;
                        },
                        onHistorySelected: () {
                          // Switch to History mode
                          final orgContext =
                              context.read<OrganizationContextCubit>().state;
                          if (orgContext.organization?.id != null) {
                            // Set default date to today if none selected
                            final dateTime = state.selectedDateTime ?? DateTime.now();
                            _bloc.add(SetDateTime(
                              dateTime,
                              orgContext.organization!.id,
                            ));
                            _didFitBoundsOnce = false;
                          }
                        },
                      ),
                    ),
                  ),
                ),
                if (state.status == ViewStatus.loading)
                  Positioned(
                    top: 80,
                    right: 16,
                    child: IgnorePointer(
                      ignoring: true, // Loading indicator shouldn't block but also shouldn't be interactive
                      child: GlassPanel(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: const _LoadingContent(),
                      ),
                    ),
                  ),
                if (state.message != null && state.message!.isNotEmpty)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: IgnorePointer(
                      ignoring: true, // Message is not interactive
                      child: GlassPanel(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Text(
                          state.message!,
                          style: TextStyle(
                            color: AuthColors.textMain,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                // History playback sheet (for trip playback if needed)
                if (!state.isLiveMode &&
                    _historyController != null &&
                    state.selectedDateTime != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      ignoring: false,
                      child: HistoryPlaybackSheet(
                        controller: _historyController!,
                        selectedDate: state.selectedDateTime!,
                        onDateSelected: (dateTime) {
                          // Date selection handled by search panel now
                        },
                        onClose: () {
                          setState(() {
                            _selectedVehicleId = null;
                            _historyController?.dispose();
                            _historyController = null;
                            _historyMarker = null;
                          });
                          // Return to live mode
                          _bloc.add(const SetLiveMode());
                        },
                      ),
                    ),
                  ),
                // Vehicle detail bottom sheet (replaces default InfoWindow)
                if (_selectedMarkerVehicleId != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Material(
                      color: Colors.transparent,
                      child: _VehicleDetailBottomSheet(
                        vehicleId: _selectedMarkerVehicleId!,
                        drivers: state.drivers,
                        vehicleNumbers: state.vehicleNumbers,
                        onClose: () {
                          setState(() {
                            _selectedMarkerVehicleId = null;
                          });
                        },
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

class _FleetLegendContent extends StatelessWidget {
  const _FleetLegendContent({
    required this.online,
    required this.offline,
    required this.status,
  });

  final int online;
  final int offline;
  final ViewStatus status;

  @override
  Widget build(BuildContext context) {
    final text = status == ViewStatus.failure
        ? 'Fleet unavailable'
        : 'Online: $online • Offline: $offline';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.local_shipping_outlined,
          color: AuthColors.textMain,
          size: 18,
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            color: AuthColors.textMain,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _LoadingContent extends StatelessWidget {
  const _LoadingContent();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AuthColors.primary),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Syncing…',
          style: TextStyle(
            color: AuthColors.textMain,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}


/// Mode toggle button to switch between Live and History modes.
class _ModeToggleSwitch extends StatelessWidget {
  const _ModeToggleSwitch({
    required this.isLiveMode,
    required this.onLiveSelected,
    required this.onHistorySelected,
  });

  final bool isLiveMode;
  final VoidCallback onLiveSelected;
  final VoidCallback onHistorySelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // History button
        _ModeButton(
          label: 'History',
          icon: Icons.history,
          isSelected: !isLiveMode,
          onTap: onHistorySelected,
        ),
        const SizedBox(width: 8),
        // Live button
        _ModeButton(
          label: 'Live',
          icon: Icons.play_circle_outline,
          isSelected: isLiveMode,
          onTap: onLiveSelected,
        ),
      ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AuthColors.primary
                : AuthColors.surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AuthColors.primary
                  : AuthColors.textMainWithOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? AuthColors.surface : AuthColors.textMain,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AuthColors.surface : AuthColors.textMain,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vehicle detail bottom sheet that replaces the default InfoWindow.
/// Shows vehicle information in a compact, non-blocking format.
class _VehicleDetailBottomSheet extends StatelessWidget {
  const _VehicleDetailBottomSheet({
    required this.vehicleId,
    required this.drivers,
    required this.vehicleNumbers,
    required this.onClose,
  });

  final String vehicleId;
  final List<FleetDriver> drivers;
  final Map<String, String> vehicleNumbers;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final driver = drivers.firstWhere(
      (d) => d.uid == vehicleId,
      orElse: () => drivers.first,
    );
    final vehicleNumber = vehicleNumbers[vehicleId] ?? 
        (vehicleId.length > 8 
            ? '${vehicleId.substring(0, 4)}...${vehicleId.substring(vehicleId.length - 4)}'
            : vehicleId);
    final location = driver.location;
    final speed = location.speed;
    final isOffline = driver.isOffline;

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AuthColors.textMainWithOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: AuthColors.textMain.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with close button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AuthColors.textMainWithOpacity(0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    vehicleNumber,
                    style: const TextStyle(
                      color: AuthColors.textMain,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onClose,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        color: AuthColors.textSub,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Vehicle details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isOffline
                            ? AuthColors.textDisabled.withOpacity(0.2)
                            : AuthColors.success.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isOffline ? 'Offline' : 'Online',
                        style: TextStyle(
                          color: isOffline
                              ? AuthColors.textDisabled
                              : AuthColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DetailRow(
                  label: 'Speed',
                  value: '${(speed * 3.6).toStringAsFixed(1)} km/h',
                ),
                const SizedBox(height: 8),
                _DetailRow(
                  label: 'Last Updated',
                  value: _formatTimestamp(location.timestamp),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  String _formatTimestamp(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AuthColors.textSub,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AuthColors.textMain,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DateTimePickerPill extends StatefulWidget {
  const _DateTimePickerPill({
    required this.selectedDateTime,
    required this.isLiveMode,
    required this.onDateTimeSelected,
    required this.onLiveModeSelected,
  });

  final DateTime? selectedDateTime;
  final bool isLiveMode;
  final ValueChanged<DateTime> onDateTimeSelected;
  final VoidCallback onLiveModeSelected;

  @override
  State<_DateTimePickerPill> createState() => _DateTimePickerPillState();
}

class _DateTimePickerPillState extends State<_DateTimePickerPill> {
  Future<void> _selectDateTime() async {
    final now = DateTime.now();
    final initialDate = widget.selectedDateTime ?? now;
    
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      helpText: 'Select date',
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );

    if (time == null) return;

    final selectedDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    // Don't allow future times
    if (selectedDateTime.isAfter(now)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot select future time')),
        );
      }
      return;
    }

    widget.onDateTimeSelected(selectedDateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.isLiveMode 
          ? 'Click to view historical locations' 
          : 'Click to change date/time',
      child: InkWell(
        onTap: widget.isLiveMode ? _selectDateTime : _selectDateTime,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isLiveMode ? Icons.location_on : Icons.history,
                color: AuthColors.textMain,
                size: 18,
              ),
              const SizedBox(width: 10),
              if (widget.isLiveMode)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Live',
                      style: TextStyle(
                        color: AuthColors.textMain,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.access_time,
                      color: AuthColors.textSub,
                      size: 14,
                    ),
                  ],
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.selectedDateTime != null
                          ? DateFormat('MMM dd, HH:mm').format(widget.selectedDateTime!)
                          : 'Select time',
                      style: TextStyle(
                        color: AuthColors.textMain,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              const SizedBox(width: 8),
              if (!widget.isLiveMode)
                InkWell(
                  onTap: widget.onLiveModeSelected,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Tooltip(
                      message: 'Switch to live mode',
                      child: Icon(
                        Icons.refresh,
                        color: AuthColors.textMain,
                        size: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

