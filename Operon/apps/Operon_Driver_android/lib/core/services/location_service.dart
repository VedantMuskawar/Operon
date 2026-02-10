import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_utils/core_utils.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:operon_driver_android/core/models/location_point.dart';
import 'package:operon_driver_android/core/services/presence_service.dart';

class LocationService {
  LocationService({FirebaseDatabase? database})
    : _database = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _database;

  // Hive box for offline location storage
  static const String _locationBoxName = 'locationPoints';
  Box<LocationPoint>? _locationBox;

  final StreamController<DriverLocation> _currentLocationController =
      StreamController<DriverLocation>.broadcast();
  final StreamController<int> _bufferLengthController =
      StreamController<int>.broadcast();

  StreamSubscription<Position>? _subscription;

  String? _uid;
  String? _tripId;
  String _status = 'active';
  String? _vehicleNumber;

  // Distance tracking
  double _totalDistanceMeters = 0.0;
  DriverLocation? _lastLocation;

  // Adaptive sampling state
  bool _isStill = false;
  double? _lastKnownSpeed;
  Timer? _samplingStateDebounceTimer;

  static const double _stillSpeedThreshold = 1.0;
  static const int _movingDistanceFilterMeters = 15;
  static const int _stillDistanceFilterMeters = 75;

  // Presence service for heartbeat
  PresenceService? _presenceService;

  bool get isTracking => _subscription != null;
  int get bufferLength => _locationBox?.length ?? 0;
  double get totalDistance => _totalDistanceMeters;
  Stream<DriverLocation> get currentLocationStream =>
      _currentLocationController.stream;
  Stream<int> get bufferLengthStream => _bufferLengthController.stream;

  /// Get location settings based on current movement state
  /// Adaptive sampling: Reduces GPS frequency when vehicle is still to save battery
  LocationSettings _getLocationSettings() {
    if (_isStill) {
      // Vehicle is still: Use lower frequency to save battery
      return const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: _stillDistanceFilterMeters,
      );
    }
    // Vehicle is moving: Use normal frequency (10m filter) for accurate tracking
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: _movingDistanceFilterMeters,
    );
  }

  /// Restart location stream with updated settings (for adaptive sampling)
  void _restartLocationStream() {
    if (_subscription == null || _uid == null || _tripId == null) return;

    debugPrint(
      '[LocationService] Restarting location stream: isStill=$_isStill',
    );

    // Cancel existing subscription
    _subscription?.cancel();

    // Start new stream with updated settings
    final settings = _getLocationSettings();
    _subscription = Geolocator.getPositionStream(locationSettings: settings)
        .listen(
          (position) async {
            try {
              await _onPosition(position);
            } catch (e, st) {
              debugPrint('[LocationService] position handling failed: $e');
              debugPrintStack(stackTrace: st);
            }
          },
          onError: (e, st) {
            debugPrint('[LocationService] Geolocator stream error: $e');
            debugPrintStack(stackTrace: st is StackTrace ? st : null);
          },
        );
  }

  Future<void> startTracking({
    required String uid,
    required String tripId,
    String status = 'active',
    String? vehicleNumber,
  }) async {
    if (isTracking) {
      await stopTracking(flush: false);
    }

    _uid = uid;
    _tripId = tripId;
    _status = status;
    _vehicleNumber = vehicleNumber;

    // Reset distance tracking for new trip
    _totalDistanceMeters = 0.0;
    _lastLocation = null;

    // Initialize Hive box for this trip
    try {
      _locationBox = await Hive.openBox<LocationPoint>(_locationBoxName);
      debugPrint('[LocationService] Hive box opened for trip $tripId');
    } catch (e) {
      debugPrint('[LocationService] Failed to open Hive box: $e');
      // Continue anyway - RTDB writes will still work
    }

    await _ensureLocationPermissions();

    // Start with moving assumption (high frequency)
    _isStill = false;
    _lastKnownSpeed = null;

    // Start with high-frequency sampling (moving assumption)
    final settings = _getLocationSettings();

    _subscription = Geolocator.getPositionStream(locationSettings: settings)
        .listen(
          (position) async {
            try {
              await _onPosition(position);
            } catch (e, st) {
              debugPrint('[LocationService] position handling failed: $e');
              debugPrintStack(stackTrace: st);
            }
          },
          onError: (e, st) {
            debugPrint('[LocationService] Geolocator stream error: $e');
            debugPrintStack(stackTrace: st is StackTrace ? st : null);
          },
        );

    // Start presence service for heartbeat
    _presenceService?.stop();
    _presenceService = PresenceService(uid: uid, database: _database);
    _presenceService!.start();
  }

  Future<void> stopTracking({bool flush = true}) async {
    final sub = _subscription;
    final uidToRemove = _uid; // Capture uid before clearing

    _subscription = null;
    await sub?.cancel();

    // Cancel adaptive sampling debounce timer
    _samplingStateDebounceTimer?.cancel();
    _samplingStateDebounceTimer = null;

    // Reset adaptive sampling state
    _isStill = false;
    _lastKnownSpeed = null;

    // Stop presence service
    _presenceService?.stop();
    _presenceService?.dispose();
    _presenceService = null;

    // Remove location data from Realtime Database to mark driver as offline
    // This ensures fleet map shows driver as offline when tracking stops
    if (uidToRemove != null) {
      try {
        await _database.ref(FirestorePaths.activeDriver(uidToRemove)).remove();
        debugPrint(
          '[LocationService] Removed location data from RTDB for uid: $uidToRemove',
        );
      } catch (e) {
        debugPrint(
          '[LocationService] Failed to remove location data from RTDB: $e',
        );
        // Continue - tracking is stopped even if RTDB cleanup fails
      }
    }

    // Note: flush is no longer needed for Firestore writes
    // Location points are stored in Hive and synced by BackgroundSyncService
    // But we keep the parameter for API compatibility

    _uid = null;
    _tripId = null;
    _status = 'active';
    _vehicleNumber = null;
    // Note: We don't reset _totalDistanceMeters here because it should be
    // read by the caller before stopping, or reset when startTracking is called again.

    // Don't close the Hive box - BackgroundSyncService may still need it
    // The box will be managed by the sync service
  }

  Future<void> _onPosition(Position position) async {
    final uid = _uid;
    final tripId = _tripId;
    if (uid == null || tripId == null) return;

    final location = DriverLocation(
      lat: position.latitude,
      lng: position.longitude,
      bearing: position.heading,
      speed: position.speed,
      status: _status,
      timestamp: position.timestamp.millisecondsSinceEpoch,
    );

    // Adaptive sampling: Update state based on speed
    // Threshold: 1.0 m/s = 3.6 km/h (walking speed)
    final currentSpeed = position.speed; // m/s
    final wasStill = _isStill;
    final newIsStill = currentSpeed < _stillSpeedThreshold;

    // Update state (debounced to avoid rapid toggles)
    if (newIsStill != wasStill) {
      _lastKnownSpeed = currentSpeed;
      // Debounce state change to avoid rapid stream restarts
      _samplingStateDebounceTimer?.cancel();
      _samplingStateDebounceTimer = Timer(const Duration(seconds: 5), () {
        // Only change state if speed has been consistent for 5 seconds
        if (_lastKnownSpeed != null) {
          final consistentStill = _lastKnownSpeed! < _stillSpeedThreshold;
          if (consistentStill != _isStill && _subscription != null) {
            _isStill = consistentStill;
            _restartLocationStream();
          }
        }
      });
    } else {
      _lastKnownSpeed = currentSpeed;
    }

    // Calculate incremental distance (with 10m noise filter)
    final lastLoc = _lastLocation;
    if (lastLoc != null) {
      final distanceMeters = Geolocator.distanceBetween(
        lastLoc.lat,
        lastLoc.lng,
        location.lat,
        location.lng,
      );
      // Only add distance if > 10 meters to filter GPS jitter while parked
      if (distanceMeters > 10.0) {
        _totalDistanceMeters += distanceMeters;
      }
    }
    _lastLocation = location;

    // Public stream for UI (map follow, debug overlay, etc.)
    if (!_currentLocationController.isClosed) {
      _currentLocationController.add(location);
    }

    // 1) Live Push: RTDB (active driver location) - keep for real-time tracking
    try {
      // Include vehicleNumber in RTDB update if available
      final locationData = location.toJson();
      if (_vehicleNumber != null && _vehicleNumber!.isNotEmpty) {
        locationData['vehicleNumber'] = _vehicleNumber;
      }
      await _database.ref(FirestorePaths.activeDriver(uid)).set(locationData);
    } catch (e) {
      debugPrint('[LocationService] Failed to write to RTDB: $e');
      // Continue - will be synced later
    }

    // 2) Black Box: Write to Hive immediately (offline-first pattern)
    // This ensures no data loss even if network drops
    try {
      final locationPoint = LocationPoint.fromDriverLocation(
        lat: location.lat,
        lng: location.lng,
        bearing: location.bearing,
        speed: location.speed,
        status: location.status,
        timestamp: location.timestamp,
        tripId: tripId,
        uid: uid,
      );

      await _locationBox?.add(locationPoint);

      // Update buffer length stream
      if (!_bufferLengthController.isClosed) {
        _bufferLengthController.add(_locationBox?.length ?? 0);
      }
    } catch (e) {
      debugPrint('[LocationService] Failed to write to Hive: $e');
      // Continue - RTDB write succeeded, sync service will handle
    }
  }

  /// Get all unsynced location points for a trip
  /// Used by BackgroundSyncService to batch upload
  Future<List<LocationPoint>> getUnsyncedPoints(String tripId) async {
    if (_locationBox == null) {
      try {
        _locationBox = await Hive.openBox<LocationPoint>(_locationBoxName);
      } catch (e) {
        debugPrint('[LocationService] Failed to open Hive box for reading: $e');
        return [];
      }
    }

    final allPoints = _locationBox!.values.toList();
    return allPoints
        .where((point) => point.tripId == tripId && !point.synced)
        .toList();
  }

  Future<void> _ensureLocationPermissions() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw StateError('Location services are disabled.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw StateError('Location permissions are denied.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw StateError('Location permissions are permanently denied.');
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _samplingStateDebounceTimer?.cancel();
    _samplingStateDebounceTimer = null;
    _presenceService?.stop();
    _presenceService?.dispose();
    _presenceService = null;
    _currentLocationController.close();
    _bufferLengthController.close();
    // Don't close Hive box here - BackgroundSyncService manages it
  }
}
