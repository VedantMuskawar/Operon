import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart' hide LatLng;
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/logic/fleet/animated_marker_manager.dart';
import 'package:dash_web/logic/fleet/fleet_status_filter.dart';
import 'package:dash_web/presentation/utils/marker_generator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart' hide Query;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';

sealed class FleetEvent {
  const FleetEvent();
}

class LoadFleetData extends FleetEvent {
  const LoadFleetData({this.selectedDateTime, this.organizationId});
  final DateTime? selectedDateTime;
  final String? organizationId;
}

class SetDateTime extends FleetEvent {
  const SetDateTime(this.dateTime, this.organizationId);
  final DateTime dateTime;
  final String organizationId;
}

class SetLiveMode extends FleetEvent {
  const SetLiveMode();
}

class SetFilter extends FleetEvent {
  const SetFilter(this.filter);
  final FleetStatusFilter filter;
}

class SelectVehicle extends FleetEvent {
  const SelectVehicle(this.vehicleId);
  final String vehicleId;
}

class ClearVehicleSelection extends FleetEvent {
  const ClearVehicleSelection();
}

class UpdateMarkerTier extends FleetEvent {
  const UpdateMarkerTier(this.tier);
  final MarkerTier tier;
}

class LoadVehicleHistory extends FleetEvent {
  const LoadVehicleHistory({
    required this.vehicleId,
    required this.date,
    required this.organizationId,
  });
  final String vehicleId;
  final DateTime date;
  final String organizationId;
}

class SearchHistoryByTripId extends FleetEvent {
  const SearchHistoryByTripId({
    required this.date,
    required this.vehicleNumber,
    required this.slot,
    required this.organizationId,
  });
  final DateTime date;
  final String vehicleNumber;
  final int slot;
  final String organizationId;
}

class SearchHistoryByDmNumber extends FleetEvent {
  const SearchHistoryByDmNumber({
    required this.dmNumber,
    required this.organizationId,
  });
  final int dmNumber;
  final String organizationId;
}

class _FleetSnapshotUpdated extends FleetEvent {
  const _FleetSnapshotUpdated(this.snapshot);
  final DatabaseEvent snapshot;
}

class _FleetListenerError extends FleetEvent {
  const _FleetListenerError(this.error);
  final Object error;
}

class FleetDriver {
  const FleetDriver({
    required this.uid,
    required this.location,
    required this.isOffline,
    this.batteryLevel,
    this.dailyDistanceKm,
  });

  final String uid;
  final DriverLocation location;
  final bool isOffline;
  final double? batteryLevel;
  final double? dailyDistanceKm;
}

class FleetState extends BaseState {
  const FleetState({
    super.status = ViewStatus.initial,
    this.message,
    this.drivers = const [],
    this.markers = const <Marker>{},
    this.selectedDateTime,
    this.isLiveMode = true,
    this.selectedFilter = FleetStatusFilter.all,
    this.selectedVehicleHistory,
    this.selectedVehicleId,
    this.vehicleNumbers = const {},
    this.historyPolylines = const <Polyline>{},
    this.currentTier = MarkerTier.standard,
  }) : super(message: message);

  final List<FleetDriver> drivers;
  final Set<Marker> markers;
  final DateTime? selectedDateTime;
  final bool isLiveMode;
  final FleetStatusFilter selectedFilter;

  /// Full history points for selected vehicle (for playback).
  final List<DriverLocation>? selectedVehicleHistory;

  /// Selected vehicle ID for live mode zooming (null means show all).
  final String? selectedVehicleId;

  /// Map of driver UID to vehicle number for display.
  final Map<String, String> vehicleNumbers;

  /// Polylines for history routes (to display full path on map).
  final Set<Polyline> historyPolylines;

  /// Current marker tier for LOD system.
  final MarkerTier currentTier;

  @override
  final String? message;

  @override
  FleetState copyWith({
    ViewStatus? status,
    String? message,
    List<FleetDriver>? drivers,
    Set<Marker>? markers,
    DateTime? selectedDateTime,
    bool? isLiveMode,
    FleetStatusFilter? selectedFilter,
    List<DriverLocation>? selectedVehicleHistory,
    String? selectedVehicleId,
    Map<String, String>? vehicleNumbers,
    Set<Polyline>? historyPolylines,
    MarkerTier? currentTier,
  }) {
    return FleetState(
      status: status ?? this.status,
      message: message ?? this.message,
      drivers: drivers ?? this.drivers,
      markers: markers ?? this.markers,
      selectedDateTime: selectedDateTime ?? this.selectedDateTime,
      isLiveMode: isLiveMode ?? this.isLiveMode,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      selectedVehicleHistory:
          selectedVehicleHistory ?? this.selectedVehicleHistory,
      selectedVehicleId: selectedVehicleId ?? this.selectedVehicleId,
      vehicleNumbers: vehicleNumbers ?? this.vehicleNumbers,
      historyPolylines: historyPolylines ?? this.historyPolylines,
      currentTier: currentTier ?? this.currentTier,
    );
  }
}

class FleetBloc extends BaseBloc<FleetEvent, FleetState> {
  FleetBloc({
    FirebaseDatabase? database,
    this.databaseUrl,
    FirebaseFirestore? firestore,
  })  : _databaseOverride = database,
        _firestore = firestore ?? FirebaseFirestore.instance,
        super(const FleetState()) {
    on<LoadFleetData>(_onLoad);
    on<SetDateTime>(_onSetDateTime);
    on<SetLiveMode>(_onSetLiveMode);
    on<SetFilter>(_onSetFilter);
    on<SelectVehicle>(_onSelectVehicle);
    on<ClearVehicleSelection>(_onClearVehicleSelection);
    on<LoadVehicleHistory>(_onLoadVehicleHistory);
    on<SearchHistoryByTripId>(_onSearchHistoryByTripId);
    on<SearchHistoryByDmNumber>(_onSearchHistoryByDmNumber);
    on<UpdateMarkerTier>(_onUpdateMarkerTier);
    on<_FleetSnapshotUpdated>(_onSnapshotUpdated);
    on<_FleetListenerError>(_onListenerError);
  }

  final FirebaseDatabase? _databaseOverride;
  final String? databaseUrl;
  final FirebaseFirestore _firestore;

  StreamSubscription<DatabaseEvent>? _sub;
  final Map<String, BitmapDescriptor> _badgeCache =
      <String, BitmapDescriptor>{};
  final Map<String, Future<BitmapDescriptor>> _badgeInFlight =
      <String, Future<BitmapDescriptor>>{};
  final AnimatedMarkerManager _animatedMarkerManager = AnimatedMarkerManager();

  // Store driver metadata for marker generation
  final Map<String, String> _vehicleNumbers = {};
  final Map<String, bool> _isOffline = {};
  final Map<String, int> _lastUpdatedMins = {};
  final Map<String, MovementState> _movementStates = {};
  // Map driver UID to icon (for getMarkers lookup)
  final Map<String, BitmapDescriptor> _iconMap = <String, BitmapDescriptor>{};

  static const _staleThreshold = Duration(minutes: 10);

  Future<void> _onLoad(LoadFleetData event, Emitter<FleetState> emit) async {
    final selectedDateTime = event.selectedDateTime ?? state.selectedDateTime;
    final organizationId = event.organizationId;
    final isLive = selectedDateTime == null ||
        selectedDateTime
            .isAfter(DateTime.now().subtract(const Duration(seconds: 5)));

    emit(state.copyWith(
      status: ViewStatus.loading,
      message: null,
      selectedDateTime: selectedDateTime,
      isLiveMode: isLive,
    ));

    // Historical mode: query Firestore
    if (!isLive && organizationId != null) {
      // When !isLive is true, selectedDateTime is guaranteed to be non-null
      // (because isLive = false only when selectedDateTime != null && is in the past)
      // Flow analysis confirms selectedDateTime is non-null here
      await _loadHistoricalLocations(emit, selectedDateTime, organizationId);
      return;
    }

    // Live mode: listen to RTDB
    // Safety check: RTDB only works on web for now.
    if (!kIsWeb) {
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: 'Realtime Database is only supported on web.\n'
              'Current platform: ${defaultTargetPlatform.name}',
        ),
      );
      return;
    }

    // Listen to RTDB updates.
    await _sub?.cancel();
    try {
      // On web, the SDK needs a fully qualified databaseURL (with https://).
      // Even if FirebaseOptions has databaseURL, explicitly passing it avoids
      // "Cannot parse Firebase url" issues when the default URL isn't derived.
      final app = Firebase.app();
      final url = (databaseUrl ?? app.options.databaseURL)?.trim();
      final resolvedUrl = (url != null && url.isNotEmpty)
          ? url
          : 'https://operonappsuite-default-rtdb.firebaseio.com';

      final db = _databaseOverride ??
          FirebaseDatabase.instanceFor(app: app, databaseURL: resolvedUrl);

      _sub = db.ref('active_drivers').onValue.listen(
            (e) => add(_FleetSnapshotUpdated(e)),
            onError: (e) =>
                add(_FleetListenerError(e is Object ? e : Exception('$e'))),
          );
    } on MissingPluginException catch (e) {
      // This usually means the app wasn't fully restarted after adding the plugin,
      // or you're running on a platform where the plugin isn't registered/supported.
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: _missingPluginHelpMessage(e),
        ),
      );
      return;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Cannot parse Firebase url')) {
        emit(
          state.copyWith(
            status: ViewStatus.failure,
            message: [
              'Realtime Database URL is not configured.',
              'Fix: add `databaseURL` to web FirebaseOptions (Firebase Console → Realtime Database → database URL).',
              '',
              'Example:',
              'databaseURL: https://operonappsuite-default-rtdb.firebaseio.com',
              '',
              'Details: $msg',
            ].join('\n'),
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: 'Fleet listener setup failed: $e',
        ),
      );
      return;
    }

    emit(state.copyWith(status: ViewStatus.success));
  }

  Future<void> _onSetDateTime(
      SetDateTime event, Emitter<FleetState> emit) async {
    await _onLoad(
        LoadFleetData(
            selectedDateTime: event.dateTime,
            organizationId: event.organizationId),
        emit);
  }

  Future<void> _onSetLiveMode(
      SetLiveMode event, Emitter<FleetState> emit) async {
    emit(state.copyWith(
      selectedFilter: FleetStatusFilter.all,
      selectedVehicleId: null,
      historyPolylines: const <Polyline>{}, // Clear polylines when switching to live mode
    ));
    await _onLoad(const LoadFleetData(), emit);
  }

  Future<void> _onSetFilter(SetFilter event, Emitter<FleetState> emit) async {
    emit(state.copyWith(selectedFilter: event.filter));
    // Re-generate markers with new filter
    final filteredMarkers = _getFilteredMarkers(
      state.markers,
      event.filter,
      state.drivers,
    );
    emit(state.copyWith(markers: filteredMarkers));
  }

  Future<void> _onSelectVehicle(
      SelectVehicle event, Emitter<FleetState> emit) async {
    emit(state.copyWith(selectedVehicleId: event.vehicleId));
  }

  Future<void> _onClearVehicleSelection(
      ClearVehicleSelection event, Emitter<FleetState> emit) async {
    emit(state.copyWith(selectedVehicleId: null));
  }

  /// Resolve vehicle number to vehicleId by querying VEHICLES collection.
  Future<String?> _resolveVehicleId({
    required String vehicleNumber,
    required String organizationId,
  }) async {
    try {
      final normalized = vehicleNumber.trim().replaceAll(RegExp(r'\s+'), '');
      final snapshot = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('VEHICLES')
          .where('vehicleNumber', isEqualTo: normalized)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id;
      }
    } catch (e) {
      // Log error but don't throw
      debugPrint('Error resolving vehicle ID: $e');
    }
    return null;
  }

  /// Search history by Date/Vehicle/Slot (Schedule Trip ID components).
  Future<void> _onSearchHistoryByTripId(
    SearchHistoryByTripId event,
    Emitter<FleetState> emit,
  ) async {
    emit(state.copyWith(
      status: ViewStatus.loading,
      isLiveMode: false,
      selectedDateTime: event.date,
    ));

    try {
      // Resolve vehicle number to vehicleId
      final vehicleId = await _resolveVehicleId(
        vehicleNumber: event.vehicleNumber,
        organizationId: event.organizationId,
      );

      if (vehicleId == null || vehicleId.isEmpty) {
        emit(state.copyWith(
          status: ViewStatus.failure,
          message: 'Vehicle not found: ${event.vehicleNumber}',
          drivers: const [],
          markers: const <Marker>{},
        ));
        return;
      }

      // Query SCHEDULE_TRIPS by Date/Vehicle/Slot
      final startOfDay = DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
      );
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final tripsSnapshot = await _firestore
          .collection('SCHEDULE_TRIPS')
          .where('organizationId', isEqualTo: event.organizationId)
          .where('scheduledDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
          .where('vehicleId', isEqualTo: vehicleId)
          .where('slot', isEqualTo: event.slot)
          .get();

      if (tripsSnapshot.docs.isEmpty) {
        emit(state.copyWith(
          status: ViewStatus.success,
          drivers: const [],
          markers: const <Marker>{},
          historyPolylines: const <Polyline>{},
          message: 'No trip found for the specified Date/Vehicle/Slot',
        ));
        return;
      }

      // Load history for the matching trip(s)
      await _loadHistoryForTrips(emit, tripsSnapshot.docs, event.date);
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to search history: $e',
      ));
    }
  }

  /// Search history by DM number.
  Future<void> _onSearchHistoryByDmNumber(
    SearchHistoryByDmNumber event,
    Emitter<FleetState> emit,
  ) async {
    emit(state.copyWith(
      status: ViewStatus.loading,
      isLiveMode: false,
    ));

    try {
      // Query SCHEDULE_TRIPS by DM number
      // Try both int and string in case of type mismatch
      var query = _firestore
          .collection('SCHEDULE_TRIPS')
          .where('organizationId', isEqualTo: event.organizationId);

      // Try int first (most common)
      var tripsSnapshot =
          await query.where('dmNumber', isEqualTo: event.dmNumber).get();

      // If no results, try as string
      if (tripsSnapshot.docs.isEmpty) {
        tripsSnapshot = await query
            .where('dmNumber', isEqualTo: event.dmNumber.toString())
            .get();
      }

      if (tripsSnapshot.docs.isEmpty) {
        emit(state.copyWith(
          status: ViewStatus.success,
          drivers: const [],
          markers: const <Marker>{},
          historyPolylines: const <Polyline>{},
          message: 'No trip found for DM number: ${event.dmNumber}',
        ));
        return;
      }

      // Get the scheduled date from the first trip
      final firstTrip = tripsSnapshot.docs.first.data();
      final scheduledDate =
          (firstTrip['scheduledDate'] as Timestamp?)?.toDate() ??
              DateTime.now();

      // Load history for the matching trip(s)
      await _loadHistoryForTrips(emit, tripsSnapshot.docs, scheduledDate);
    } catch (e, st) {
      debugPrint('[FleetBloc] Error searching by DM number: $e');
      debugPrintStack(stackTrace: st);
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to search history by DM number: $e',
      ));
    }
  }

  /// Load history for specific trip documents and display on map.
  /// Decode polyline string to DriverLocation list
  /// Uses approximate timestamps based on trip start/end times
  List<DriverLocation> _decodePolylineToLocations(
    String polyline,
    int startTimestamp,
    int endTimestamp,
  ) {
    if (polyline.isEmpty) return [];

    try {
      // decodePolyline returns List<List<num>>, convert to List<List<double>>
      final decoded = decodePolyline(polyline);
      if (decoded.isEmpty) return [];

      final locations = <DriverLocation>[];
      final pointCount = decoded.length;

      // Distribute timestamps evenly across the polyline points
      for (int i = 0; i < pointCount; i++) {
        final timestamp = pointCount > 1
            ? startTimestamp +
                ((endTimestamp - startTimestamp) * i ~/ (pointCount - 1))
            : startTimestamp;

        locations.add(DriverLocation(
          lat: decoded[i][0].toDouble(),
          lng: decoded[i][1].toDouble(),
          bearing: 0.0, // Polyline doesn't store bearing
          speed: 0.0, // Polyline doesn't store speed
          status: 'active',
          timestamp: timestamp,
        ));
      }

      return locations;
    } catch (e) {
      debugPrint('[FleetBloc] Failed to decode polyline: $e');
      return [];
    }
  }

  /// Load locations from trip document (routePolyline or history subcollection)
  Future<List<DriverLocation>> _loadTripLocations(
    DocumentSnapshot<Map<String, dynamic>> tripDoc,
  ) async {
    final tripData = tripDoc.data();

    // Try new polyline format first
    final routePolyline = tripData?['routePolyline'] as String?;
    if (routePolyline != null && routePolyline.isNotEmpty) {
      // Get trip timestamps for approximate location timestamps
      final dispatchedAt = tripData?['dispatchedAt'] as Timestamp?;
      final deliveredAt = tripData?['deliveredAt'] as Timestamp?;
      final returnedAt = tripData?['returnedAt'] as Timestamp?;

      // Use available timestamps, fallback to current time if missing
      final startTimestamp = dispatchedAt?.millisecondsSinceEpoch ??
          (tripData?['scheduledDate'] as Timestamp?)?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch;
      final endTimestamp = returnedAt?.millisecondsSinceEpoch ??
          deliveredAt?.millisecondsSinceEpoch ??
          startTimestamp + const Duration(hours: 2).inMilliseconds;

      final locations = _decodePolylineToLocations(
          routePolyline, startTimestamp, endTimestamp);
      if (locations.isNotEmpty) {
        return locations;
      }
    }

    // Fallback to legacy history subcollection
    try {
      final historySnapshot = await _firestore
          .collection('SCHEDULE_TRIPS')
          .doc(tripDoc.id)
          .collection('history')
          .orderBy('createdAt', descending: false)
          .get();

      final allLocations = <DriverLocation>[];
      for (final historyDoc in historySnapshot.docs) {
        final historyData = historyDoc.data();
        final locations = historyData['locations'] as List<dynamic>?;
        if (locations != null) {
          for (final locJson in locations) {
            try {
              final loc =
                  DriverLocation.fromJson(Map<String, dynamic>.from(locJson));
              allLocations.add(loc);
            } catch (_) {
              // Skip invalid entries
            }
          }
        }
      }
      return allLocations;
    } catch (e) {
      debugPrint('[FleetBloc] Failed to load history subcollection: $e');
      return [];
    }
  }

  Future<void> _loadHistoryForTrips(
    Emitter<FleetState> emit,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> tripDocs,
    DateTime targetTime,
  ) async {
    try {
      final targetMs = targetTime.millisecondsSinceEpoch;
      final drivers = <FleetDriver>[];
      final markers = <Marker>{};
      final polylines = <Polyline>{};

      // For each trip, query history and find location at target time
      for (int tripIndex = 0; tripIndex < tripDocs.length; tripIndex++) {
        final tripDoc = tripDocs[tripIndex];
        final tripData = tripDoc.data();
        final driverId = tripData['driverId'] as String?;
        final vehicleNumber = tripData['vehicleNumber'] as String? ?? 'Unknown';

        if (driverId == null || driverId.isEmpty) continue;

        // Load locations from routePolyline (new) or history subcollection (legacy)
        final allLocations = await _loadTripLocations(tripDoc);

        if (allLocations.isEmpty) {
          continue;
        }

        // Create polyline from all locations to show full route
        if (allLocations.length > 1) {
          final polylinePoints = allLocations
              .map<LatLng>((loc) => LatLng(loc.lat, loc.lng))
              .toList();
          polylines.add(
            Polyline(
              polylineId: PolylineId('trip_${tripDoc.id}'),
              points: polylinePoints,
              color: AuthColors.primary.withOpacity(0.7),
              width: 4,
              patterns: const [],
            ),
          );
        }

        // Sort by timestamp
        allLocations.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        // Find location at target time or last known before
        DriverLocation? selectedLocation;
        for (int i = allLocations.length - 1; i >= 0; i--) {
          if (allLocations[i].timestamp <= targetMs) {
            selectedLocation = allLocations[i];
            break;
          }
        }

        // If no location before target time, use first location (closest we have)
        selectedLocation ??= allLocations.first;

        final isOffline = (targetMs - selectedLocation.timestamp).abs() >
            _staleThreshold.inMilliseconds;
        final bearing =
            selectedLocation.bearing.isFinite ? selectedLocation.bearing : 0.0;
        final speed = selectedLocation.speed.toDouble();

        final movementState = _computeMovementState(
          isOffline: isOffline,
          speed: speed,
          engineOn: null,
        );

        final markerIcon = await _getVehicleBadge(
          vehicleNumber: vehicleNumber,
          isOffline: isOffline,
          bearing: bearing,
          timestamp: selectedLocation.timestamp,
          tier: state.currentTier,
          speed: speed,
        );

        drivers.add(
          FleetDriver(
            uid: driverId,
            location: selectedLocation,
            isOffline: isOffline,
          ),
        );

        final useBearing = movementState == MovementState.moving;
        final rotation = useBearing && bearing.isFinite ? (bearing % 360) : 0.0;

        markers.add(
          Marker(
            markerId: MarkerId(driverId),
            position: LatLng(selectedLocation.lat, selectedLocation.lng),
            icon: markerIcon,
            flat: true,
            anchor: const Offset(0.5, 1.0),
            rotation: rotation,
            alpha: isOffline ? 0.35 : 1.0,
            infoWindow: InfoWindow(
              title: vehicleNumber,
              snippet: isOffline ? 'Offline' : 'Online',
            ),
          ),
        );
      }

      // Apply filter to markers
      final filteredMarkers = _getFilteredMarkers(
        markers,
        state.selectedFilter,
        drivers,
      );

      emit(state.copyWith(
        status: ViewStatus.success,
        drivers: drivers,
        markers: filteredMarkers,
        historyPolylines: polylines,
        message: drivers.isEmpty
            ? 'No vehicle locations found for selected search'
            : null,
      ));
    } catch (e, st) {
      debugPrint('[FleetBloc] Error loading history: $e');
      debugPrintStack(stackTrace: st);
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to load history for trips: $e',
      ));
    }
  }

  /// Load full history for a single vehicle for playback.
  Future<void> _onLoadVehicleHistory(
    LoadVehicleHistory event,
    Emitter<FleetState> emit,
  ) async {
    emit(state.copyWith(status: ViewStatus.loading));

    try {
      final startOfDay = DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
      );
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Find trips for this vehicle on the selected date
      final tripsSnapshot = await _firestore
          .collection('SCHEDULE_TRIPS')
          .where('organizationId', isEqualTo: event.organizationId)
          .where('scheduledDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      final allLocations = <DriverLocation>[];

      // Collect all history points from all trips for this vehicle
      for (final tripDoc in tripsSnapshot.docs) {
        final tripData = tripDoc.data();
        final driverId = tripData['driverId'] as String?;

        // Check if this trip belongs to the selected vehicle
        if (driverId != event.vehicleId) continue;

        // Load locations from routePolyline (new) or history subcollection (legacy)
        final tripLocations = await _loadTripLocations(tripDoc);
        allLocations.addAll(tripLocations);
      }

      // Sort by timestamp
      allLocations.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      emit(state.copyWith(
        status: ViewStatus.success,
        selectedVehicleHistory: allLocations,
        message: allLocations.isEmpty
            ? 'No history found for selected vehicle'
            : null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to load vehicle history: $e',
      ));
    }
  }

  /// Filter markers based on selected filter and apply ghost mode.
  Set<Marker> _getFilteredMarkers(
    Set<Marker> markers,
    FleetStatusFilter filter,
    List<FleetDriver> drivers,
  ) {
    if (filter == FleetStatusFilter.all) {
      return markers;
    }

    // Create a map of driver UID to driver for quick lookup
    final driverMap = <String, FleetDriver>{};
    for (final driver in drivers) {
      driverMap[driver.uid] = driver;
    }

    final filteredMarkers = <Marker>{};
    const speedThreshold = 1.0; // m/s

    for (final marker in markers) {
      final driverId = marker.markerId.value;
      final driver = driverMap[driverId];

      if (driver == null) {
        // If driver not found, keep marker but ghost it
        filteredMarkers.add(
          Marker(
            markerId: marker.markerId,
            position: marker.position,
            icon: marker.icon,
            alpha: 0.2,
            anchor: marker.anchor,
            rotation: marker.rotation,
            flat: marker.flat,
            infoWindow: marker.infoWindow,
          ),
        );
        continue;
      }

      final location = driver.location;
      final speed = location.speed;
      final isOffline = driver.isOffline;

      bool shouldShow = false;
      switch (filter) {
        case FleetStatusFilter.all:
          shouldShow = true;
          break;
        case FleetStatusFilter.moving:
          shouldShow = !isOffline && speed > speedThreshold;
          break;
        case FleetStatusFilter.idling:
          shouldShow = !isOffline && speed <= speedThreshold;
          break;
        case FleetStatusFilter.offline:
          shouldShow = isOffline;
          break;
      }

      // Apply ghost mode: matching markers get full alpha, others get 0.2
      final alpha = shouldShow ? marker.alpha : 0.2;
      filteredMarkers.add(
        Marker(
          markerId: marker.markerId,
          position: marker.position,
          icon: marker.icon,
          alpha: alpha,
          anchor: marker.anchor,
          rotation: marker.rotation,
          flat: marker.flat,
          infoWindow: marker.infoWindow,
        ),
      );
    }

    return filteredMarkers;
  }

  Future<void> _loadHistoricalLocations(
    Emitter<FleetState> emit,
    DateTime targetTime,
    String organizationId,
  ) async {
    try {
      // Get all trips for the selected date
      final startOfDay =
          DateTime(targetTime.year, targetTime.month, targetTime.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final tripsSnapshot = await _firestore
          .collection('SCHEDULE_TRIPS')
          .where('organizationId', isEqualTo: organizationId)
          .where('scheduledDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      if (tripsSnapshot.docs.isEmpty) {
        emit(state.copyWith(
          status: ViewStatus.success,
          drivers: const [],
          markers: const <Marker>{},
          message: 'No trips found for selected date',
        ));
        return;
      }

      final targetMs = targetTime.millisecondsSinceEpoch;
      final drivers = <FleetDriver>[];
      final markers = <Marker>{};

      // For each trip, query history and find location at target time
      for (final tripDoc in tripsSnapshot.docs) {
        final tripData = tripDoc.data();
        final driverId = tripData['driverId'] as String?;
        final vehicleNumber = tripData['vehicleNumber'] as String? ?? 'Unknown';

        if (driverId == null || driverId.isEmpty) continue;

        // Query history subcollection
        final historySnapshot = await _firestore
            .collection('SCHEDULE_TRIPS')
            .doc(tripDoc.id)
            .collection('history')
            .orderBy('createdAt', descending: false)
            .get();

        // Collect all locations from history
        final allLocations = <DriverLocation>[];
        for (final historyDoc in historySnapshot.docs) {
          final historyData = historyDoc.data();
          final locations = historyData['locations'] as List<dynamic>?;
          if (locations != null) {
            for (final locJson in locations) {
              try {
                final loc =
                    DriverLocation.fromJson(Map<String, dynamic>.from(locJson));
                allLocations.add(loc);
              } catch (_) {
                // Skip invalid entries
              }
            }
          }
        }

        if (allLocations.isEmpty) continue;

        // Sort by timestamp
        allLocations.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        // Find location at target time or last known before
        DriverLocation? selectedLocation;
        for (int i = allLocations.length - 1; i >= 0; i--) {
          if (allLocations[i].timestamp <= targetMs) {
            selectedLocation = allLocations[i];
            break;
          }
        }

        // If no location before target time, use first location (closest we have)
        selectedLocation ??= allLocations.first;

        final isOffline = (targetMs - selectedLocation.timestamp).abs() >
            _staleThreshold.inMilliseconds;
        final bearing =
            selectedLocation.bearing.isFinite ? selectedLocation.bearing : 0.0;
        final speed = selectedLocation.speed.toDouble();

        final movementState = _computeMovementState(
          isOffline: isOffline,
          speed: speed,
          engineOn: null,
        );

        final markerIcon = await _getVehicleBadge(
          vehicleNumber: vehicleNumber,
          isOffline: isOffline,
          bearing: bearing,
          timestamp: selectedLocation.timestamp,
          tier: state.currentTier,
          speed: speed,
        );

        drivers.add(
          FleetDriver(
            uid: driverId,
            location: selectedLocation,
            isOffline: isOffline,
          ),
        );

        final useBearing = movementState == MovementState.moving;
        final rotation = useBearing && bearing.isFinite ? (bearing % 360) : 0.0;

        markers.add(
          Marker(
            markerId: MarkerId(driverId),
            position: LatLng(selectedLocation.lat, selectedLocation.lng),
            icon: markerIcon,
            flat: true,
            anchor: const Offset(
                0.5, 1.0), // Pin marker: anchor at bottom center (pointer tip)
            rotation: rotation,
            alpha: isOffline ? 0.35 : 1.0,
            infoWindow: InfoWindow(
              title: vehicleNumber,
              snippet: isOffline ? 'Offline' : 'Online',
            ),
          ),
        );
      }

      // Apply filter to markers
      final filteredMarkers = _getFilteredMarkers(
        markers,
        state.selectedFilter,
        drivers,
      );

      emit(state.copyWith(
        status: ViewStatus.success,
        drivers: drivers,
        markers: filteredMarkers,
        message: drivers.isEmpty
            ? 'No vehicle locations found for selected time'
            : null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to load historical locations: $e',
      ));
    }
  }

  Future<void> _onUpdateMarkerTier(
    UpdateMarkerTier event,
    Emitter<FleetState> emit,
  ) async {
    // Only update if tier actually changed
    if (state.currentTier == event.tier) return;

    // Clear badge cache and marker generator cache when tier changes
    _badgeCache.clear();
    _badgeInFlight.clear();
    _iconMap.clear();
    MarkerGenerator.clearMarkerCache();

    // Update tier in state
    emit(state.copyWith(currentTier: event.tier));

    // Regenerate markers with new tier
    if (state.drivers.isNotEmpty) {
      await _regenerateMarkersForCurrentTier(emit, event.tier);
    }
  }

  /// Regenerate all markers with the specified tier.
  Future<void> _regenerateMarkersForCurrentTier(
      Emitter<FleetState> emit, MarkerTier tier) async {
    final markers = <Marker>{};

    for (final driver in state.drivers) {
      final vehicleNumber = state.vehicleNumbers[driver.uid] ?? driver.uid;
      final isOffline = driver.isOffline;
      final bearing =
          driver.location.bearing.isFinite ? driver.location.bearing : 0.0;
      final speed = driver.location.speed.toDouble();

      final movementState = _computeMovementState(
        isOffline: isOffline,
        speed: speed,
        engineOn: null,
      );
      _movementStates[driver.uid] = movementState;

      final markerIcon = await _getVehicleBadge(
        vehicleNumber: vehicleNumber,
        isOffline: isOffline,
        bearing: bearing,
        timestamp: driver.location.timestamp,
        tier: tier,
        speed: speed,
      );

      // Update icon map for animated markers
      _iconMap[driver.uid] = markerIcon;

      final useBearing = movementState == MovementState.moving;
      final rotation = useBearing && bearing.isFinite ? (bearing % 360) : 0.0;

      markers.add(
        Marker(
          markerId: MarkerId(driver.uid),
          position: LatLng(driver.location.lat, driver.location.lng),
          icon: markerIcon,
          flat: true,
          anchor: const Offset(0.5, 1.0),
          rotation: rotation,
          alpha: isOffline ? 0.35 : 1.0,
          infoWindow: InfoWindow(
            title: vehicleNumber,
            snippet: isOffline ? 'Offline' : 'Online',
          ),
        ),
      );
    }

    // Apply current filter
    final filteredMarkers = _getFilteredMarkers(
      markers,
      state.selectedFilter,
      state.drivers,
    );

    emit(state.copyWith(markers: filteredMarkers));
  }

  Future<void> _onListenerError(
    _FleetListenerError event,
    Emitter<FleetState> emit,
  ) async {
    final err = event.error;
    if (err is MissingPluginException) {
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: _missingPluginHelpMessage(err),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: ViewStatus.failure,
        message: 'Fleet listener error: $err',
      ),
    );
  }

  String _missingPluginHelpMessage(MissingPluginException e) {
    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
    return [
      'Realtime Database plugin is not registered on $platform.',
      'This commonly happens if you added `firebase_database` and only hot-reloaded.',
      '',
      'Fix:',
      '- Fully stop the app (end `flutter run`) and start again.',
      if (kIsWeb) '- Run on Chrome (`flutter run -d chrome`).',
      if (!kIsWeb)
        '- If you are running desktop/mobile, ensure FlutterFire is configured for that platform and do a full rebuild.',
      '',
      'Details: ${e.message ?? e.toString()}',
    ].join('\n');
  }

  Future<void> _onSnapshotUpdated(
    _FleetSnapshotUpdated event,
    Emitter<FleetState> emit,
  ) async {
    // #region agent log
    _debugLog('fleet_bloc.dart:607', '_onSnapshotUpdated called',
        {'hasRaw': event.snapshot.snapshot.value != null}, 'A');
    // #endregion
    final raw = event.snapshot.snapshot.value;
    if (raw == null) {
      // #region agent log
      _debugLog('fleet_bloc.dart:612', 'Raw snapshot is null', {}, 'A');
      // #endregion
      emit(state.copyWith(drivers: const [], markers: const <Marker>{}));
      return;
    }

    if (raw is! Map) {
      // #region agent log
      _debugLog('fleet_bloc.dart:617', 'Raw is not Map',
          {'type': raw.runtimeType.toString()}, 'A');
      // #endregion
      emit(
        state.copyWith(
          message: 'Unexpected active_drivers payload: ${raw.runtimeType}',
        ),
      );
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final drivers = <FleetDriver>[];
    final currentDriverIds = <String>{};

    for (final entry in raw.entries) {
      final uid = entry.key?.toString();
      if (uid == null || uid.isEmpty) continue;

      currentDriverIds.add(uid);

      final value = entry.value;
      if (value is! Map) continue;

      // Firebase returns Map<dynamic, dynamic>; normalize to Map<String, dynamic>.
      final json = <String, dynamic>{};
      for (final kv in value.entries) {
        final k = kv.key?.toString();
        if (k == null) continue;
        json[k] = kv.value;
      }

      final loc = DriverLocation.fromJson(json);
      final age = Duration(milliseconds: (nowMs - loc.timestamp).abs());
      final isOffline = age > _staleThreshold;

      final vehicleNumber = _extractVehicleNumber(uid: uid, json: json);
      final bearing = loc.bearing.isFinite ? loc.bearing : 0.0;
      final speed = loc.speed.toDouble();
      final battery = (json['battery'] ?? json['batteryLevel']) as num?;
      final distance = (json['dailyDistance'] ??
          json['daily_distance'] ??
          json['distance']) as num?;
      final engineOnRaw = json['engineOn'] ?? json['engine_on'];
      final bool? engineOn = engineOnRaw == null
          ? null
          : (engineOnRaw == true || engineOnRaw == 'true');

      // Compute movement state for marker rotation (moving = use bearing, else 0)
      final movementState = _computeMovementState(
        isOffline: isOffline,
        speed: speed,
        engineOn: engineOn,
      );
      _movementStates[uid] = movementState;

      // Get marker icon and cache it for animated marker manager (icon is cached internally)
      final icon = await _getVehicleBadge(
        vehicleNumber: vehicleNumber,
        isOffline: isOffline,
        bearing: bearing,
        timestamp: loc.timestamp,
        tier: state.currentTier,
        speed: speed,
        engineOn: engineOn,
      );

      // Store icon in UID-keyed map for getMarkers lookup
      _iconMap[uid] = icon;

      drivers.add(
        FleetDriver(
          uid: uid,
          location: loc,
          isOffline: isOffline,
          batteryLevel: battery?.toDouble(),
          dailyDistanceKm: distance?.toDouble(),
        ),
      );

      // Store metadata for marker generation
      _vehicleNumbers[uid] = vehicleNumber;
      _isOffline[uid] = isOffline;
      _lastUpdatedMins[uid] = (age.inSeconds / 60).floor();

      // Update animated marker manager with new target position
      _animatedMarkerManager.updateTarget(
        id: uid,
        newPos: LatLng(loc.lat, loc.lng),
        newBearing: loc.bearing.isFinite ? loc.bearing : 0.0,
        now: DateTime.now(),
      );
    }

    // Clean up icons and metadata for drivers no longer in snapshot
    final removedDriverIds = _iconMap.keys.toSet().difference(currentDriverIds);
    for (final removedId in removedDriverIds) {
      _iconMap.remove(removedId);
      _vehicleNumbers.remove(removedId);
      _isOffline.remove(removedId);
      _movementStates.remove(removedId);
      _lastUpdatedMins.remove(removedId);
      _animatedMarkerManager.removeDriver(removedId);
    }

    final hasDirection = {
      for (final e in _movementStates.entries)
        e.key: e.value == MovementState.moving,
    };

    // Generate markers with current animation progress
    // The screen's AnimationController triggers updates which call getAnimatedMarkers
    final animatedMarkers = _animatedMarkerManager.getMarkers(
      now: DateTime.now(),
      icons: _iconMap,
      vehicleNumbers: _vehicleNumbers,
      isOffline: _isOffline,
      lastUpdatedMins: _lastUpdatedMins,
      hasDirection: hasDirection,
    );

    // Apply filter to markers
    final filteredMarkers = _getFilteredMarkers(
      animatedMarkers,
      state.selectedFilter,
      drivers,
    );

    emit(
      state.copyWith(
        status: ViewStatus.success,
        drivers: drivers,
        markers: filteredMarkers,
        vehicleNumbers: Map<String, String>.from(_vehicleNumbers),
      ),
    );
  }

  String _extractVehicleNumber({
    required String uid,
    required Map<String, dynamic> json,
  }) {
    // If you start writing `vehicleNumber` into RTDB along with location updates,
    // the fleet map will automatically show it.
    final v = json['vehicleNumber'];
    if (v is String && v.trim().isNotEmpty) return v.trim();

    // Backward/alternate keys.
    final alt = json['vehicleNo'] ?? json['vehicle_no'] ?? json['plateNumber'];
    if (alt is String && alt.trim().isNotEmpty) return alt.trim();

    // Fallback: short UID (last 6) so markers remain readable.
    final suffix = uid.length > 6 ? uid.substring(uid.length - 6) : uid;
    return 'VH-$suffix';
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
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

  /// Speed threshold for moving vs idling: 5 km/h = 1.39 m/s
  static const double _speedThresholdMovingMs = 1.39;

  MovementState _computeMovementState({
    required bool isOffline,
    required double speed,
    bool? engineOn,
  }) {
    if (isOffline) return MovementState.offline;
    if (engineOn == false) return MovementState.stopped;
    if (speed > _speedThresholdMovingMs) return MovementState.moving;
    return MovementState.idling;
  }

  Future<BitmapDescriptor> _getVehicleBadge({
    required String vehicleNumber,
    required bool isOffline,
    required double bearing,
    required int timestamp,
    MarkerTier? tier,
    double speed = 0.0,
    bool? engineOn,
    VehicleType vehicleType = VehicleType.van,
  }) async {
    // Use current tier from state if not provided
    final currentTier = tier ?? state.currentTier;

    // Compute MovementState
    final MovementState movementState;
    if (isOffline) {
      movementState = MovementState.offline;
    } else if (engineOn == false) {
      movementState = MovementState.stopped;
    } else if (speed > _speedThresholdMovingMs) {
      movementState = MovementState.moving;
    } else {
      movementState = MovementState.idling;
    }

    final subtitle = isOffline
        ? _formatTimeAgo(DateTime.fromMillisecondsSinceEpoch(timestamp))
        : null;
    final speedKmh = speed * 3.6;
    final speedLabel = (currentTier == MarkerTier.detailed &&
            movementState == MovementState.moving)
        ? '${speedKmh.toStringAsFixed(0)} km/h'
        : null;

    final key =
        '${currentTier.name}|${movementState.name}|${vehicleType.name}|$vehicleNumber|$subtitle|$speedLabel';
    final cached = _badgeCache[key];
    if (cached != null) return cached;

    final inFlight = _badgeInFlight[key];
    if (inFlight != null) return inFlight;

    final fut = MarkerGenerator.createMarker(
      text: vehicleNumber,
      movementState: movementState,
      vehicleType: vehicleType,
      tier: currentTier,
      subtitle: subtitle,
      speedLabel: speedLabel,
    ).then((icon) {
      _badgeCache[key] = icon;
      _badgeInFlight.remove(key);
      return icon;
    });

    _badgeInFlight[key] = fut;
    return fut;
  }

  /// Get markers with animation progress.
  ///
  /// Called by the screen's AnimationController listener to update marker positions
  /// smoothly between RTDB updates.
  Set<Marker> getAnimatedMarkers(DateTime now) {
    final hasDirection = {
      for (final e in _movementStates.entries)
        e.key: e.value == MovementState.moving,
    };
    final markers = _animatedMarkerManager.getMarkers(
      now: now,
      icons: _iconMap,
      vehicleNumbers: _vehicleNumbers,
      isOffline: _isOffline,
      lastUpdatedMins: _lastUpdatedMins,
      hasDirection: hasDirection,
    );

    // Apply current filter
    return _getFilteredMarkers(
      markers,
      state.selectedFilter,
      state.drivers,
    );
  }

  void _debugLog(String location, String message, Map<String, dynamic> data,
      String level) {
    if (kDebugMode) {
      debugPrint('[$level] $location: $message ${data.isNotEmpty ? data : ""}');
    }
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    _sub = null;
    _badgeCache.clear();
    _badgeInFlight.clear();
    _animatedMarkerManager.clear();
    _vehicleNumbers.clear();
    _isOffline.clear();
    _lastUpdatedMins.clear();
    _movementStates.clear();
    _iconMap.clear();
    MarkerGenerator.clearMarkerCache();
    return super.close();
  }
}
