import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_utils/core_utils.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:operon_driver_android/core/models/location_point.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service that syncs location points from Hive to RTDB in the background
/// Implements the "Black Box" pattern: writes to local storage first, syncs later
class BackgroundSyncService {
  BackgroundSyncService({
    FirebaseDatabase? database,
    Connectivity? connectivity,
    FirebaseFirestore? firestore,
  }) : _database = database ?? FirebaseDatabase.instance,
       _connectivity = connectivity ?? Connectivity(),
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseDatabase _database;
  final Connectivity _connectivity;
  final FirebaseFirestore _firestore;

  static const String _locationBoxName = 'locationPoints';
  static const Duration _activeSyncInterval = Duration(seconds: 60);
  static const Duration _idleSyncInterval = Duration(minutes: 5);
  Box<LocationPoint>? _locationBox;

  Timer? _syncTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;
  bool _isTripActive = false;

  /// Start the sync service
  /// Runs sync every 60 seconds and when network is restored
  Future<void> start() async {
    debugPrint('[BackgroundSyncService] Starting sync service...');

    // Initialize Hive box
    try {
      _locationBox = await Hive.openBox<LocationPoint>(_locationBoxName);
      debugPrint('[BackgroundSyncService] Hive box opened');
    } catch (e) {
      debugPrint('[BackgroundSyncService] Failed to open Hive box: $e');
      return;
    }

    _startSyncTimer();

    // Sync when network is restored
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        debugPrint(
          '[BackgroundSyncService] Network restored, triggering sync...',
        );
        _syncUnsyncedPoints();
      }
    });

    // Initial sync
    _syncUnsyncedPoints();
  }

  void setTripActive(bool isActive) {
    if (_isTripActive == isActive) return;
    _isTripActive = isActive;
    _startSyncTimer();

    if (!isActive) {
      _syncUnsyncedPoints();
    }
  }

  /// Stop the sync service
  void stop() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    debugPrint('[BackgroundSyncService] Sync service stopped');
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    final interval = _isTripActive ? _activeSyncInterval : _idleSyncInterval;
    _syncTimer = Timer.periodic(interval, (_) {
      _syncUnsyncedPoints();
    });
  }

  /// Sync all unsynced location points to RTDB
  Future<void> _syncUnsyncedPoints() async {
    if (_isSyncing) {
      debugPrint(
        '[BackgroundSyncService] Sync already in progress, skipping...',
      );
      return;
    }

    if (_locationBox == null) {
      try {
        _locationBox = await Hive.openBox<LocationPoint>(_locationBoxName);
      } catch (e) {
        debugPrint('[BackgroundSyncService] Failed to open Hive box: $e');
        return;
      }
    }

    // Check network connectivity
    final connectivityResults = await _connectivity.checkConnectivity();
    if (connectivityResults.every(
      (result) => result == ConnectivityResult.none,
    )) {
      debugPrint(
        '[BackgroundSyncService] No network connection, skipping sync...',
      );
      return;
    }

    _isSyncing = true;

    try {
      // Get all unsynced points, grouped by tripId and uid
      final allPoints = _locationBox!.values.toList();
      final unsyncedPoints = allPoints.where((point) => !point.synced).toList();

      if (unsyncedPoints.isEmpty) {
        if (!_isTripActive) {
          debugPrint(
            '[BackgroundSyncService] No unsynced points (idle), skipping',
          );
          return;
        }
        debugPrint('[BackgroundSyncService] No unsynced points to sync');
        return;
      }

      debugPrint(
        '[BackgroundSyncService] Found ${unsyncedPoints.length} unsynced points',
      );

      // Group by (uid, tripId) for batch upload
      final groupedPoints = <String, List<LocationPoint>>{};
      for (final point in unsyncedPoints) {
        final key = '${point.uid}_${point.tripId}';
        groupedPoints.putIfAbsent(key, () => []).add(point);
      }

      // Upload each group
      int totalSynced = 0;
      for (final entry in groupedPoints.entries) {
        final points = entry.value;
        if (points.isEmpty) continue;

        final firstPoint = points.first;
        final uid = firstPoint.uid;
        final tripId = firstPoint.tripId;

        try {
          // Fetch vehicleNumber from SCHEDULE_TRIPS for this trip
          String? vehicleNumber;
          try {
            final tripDoc = await _firestore
                .collection('SCHEDULE_TRIPS')
                .doc(tripId)
                .get();
            if (tripDoc.exists) {
              final tripData = tripDoc.data();
              vehicleNumber = tripData?['vehicleNumber'] as String?;
            }
          } catch (e) {
            debugPrint(
              '[BackgroundSyncService] Failed to fetch vehicleNumber: $e',
            );
            // Continue without vehicleNumber
          }

          // Upload to RTDB: trips/{tripId}/locations/{timestamp}
          // Also update activeDriver/{uid} with the latest point
          // NOTE: We ONLY write to RTDB during active trips (for live tracking)
          // We do NOT write to Firestore history during trips - polyline is saved on EndTrip only
          final latestPoint = points.last;

          // Update active driver location (latest point)
          // Include vehicleNumber if available
          final locationData = latestPoint.toJson();
          if (vehicleNumber != null && vehicleNumber.isNotEmpty) {
            locationData['vehicleNumber'] = vehicleNumber;
          }
          await _database
              .ref(FirestorePaths.activeDriver(uid))
              .set(locationData);

          // Store historical points in RTDB trips/{tripId}/locations (for live tracking only)
          // Batch write all points
          final updates = <String, dynamic>{};
          for (final point in points) {
            final locationKey = 'trips/$tripId/locations/${point.timestamp}';
            updates[locationKey] = point.toJson();
          }

          if (updates.isNotEmpty) {
            await _database.ref().update(updates);
          }

          // Delete synced points from Hive
          // Note: synced field is final, so we just delete the points
          for (final point in points) {
            await point.delete();
            totalSynced++;
          }

          debugPrint(
            '[BackgroundSyncService] Synced ${points.length} points for trip $tripId',
          );
        } catch (e) {
          debugPrint(
            '[BackgroundSyncService] Failed to sync points for trip $tripId: $e',
          );
          // Continue with next group
        }
      }

      debugPrint(
        '[BackgroundSyncService] Sync completed: $totalSynced points synced',
      );
    } catch (e, st) {
      debugPrint('[BackgroundSyncService] Sync failed: $e');
      debugPrintStack(stackTrace: st);
    } finally {
      _isSyncing = false;
    }
  }

  /// Get all location points for a trip (for polyline compression in Rule #3)
  Future<List<LocationPoint>> getLocationPointsForTrip(String tripId) async {
    if (_locationBox == null) {
      try {
        _locationBox = await Hive.openBox<LocationPoint>(_locationBoxName);
      } catch (e) {
        debugPrint('[BackgroundSyncService] Failed to open Hive box: $e');
        return [];
      }
    }

    return _locationBox!.values
        .where((point) => point.tripId == tripId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// Dispose resources
  void dispose() {
    stop();
    // Don't close Hive box - LocationService may still need it
  }
}
