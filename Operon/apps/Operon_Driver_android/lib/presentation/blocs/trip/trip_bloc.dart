import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:operon_driver_android/core/exceptions/trip_exceptions.dart';
import 'package:operon_driver_android/core/services/background_sync_service.dart';
import 'package:operon_driver_android/core/services/location_service.dart';
import 'package:operon_driver_android/core/utils/polyline_encoder.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

part 'trip_event.dart';
part 'trip_state.dart';

class TripBloc extends BaseBloc<TripEvent, TripState> {
  TripBloc({
    required FirebaseFirestore firestore,
    required LocationService locationService,
    required BackgroundSyncService backgroundSyncService,
    FlutterBackgroundService? backgroundService,
    FirebaseAuth? auth,
  }) : _firestore = firestore,
       _locationService = locationService,
       _backgroundSyncService = backgroundSyncService,
       _backgroundService = backgroundService ?? FlutterBackgroundService(),
       _auth = auth ?? FirebaseAuth.instance,
       super(const TripState()) {
    on<StartTrip>(_onStartTrip);
    on<EndTrip>(_onEndTrip);
  }

  final FirebaseFirestore _firestore;
  final LocationService _locationService;
  final BackgroundSyncService _backgroundSyncService;
  final FlutterBackgroundService _backgroundService;
  final FirebaseAuth _auth;

  // Stream subscription to monitor active trip status changes
  StreamSubscription<DocumentSnapshot>? _tripStatusSubscription;

  Future<void> _onStartTrip(StartTrip event, Emitter<TripState> emit) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));

    final user = _auth.currentUser;
    if (user == null) {
      emit(
        state.copyWith(status: ViewStatus.failure, message: 'Not signed in.'),
      );
      return;
    }

    try {
      // Prevent Android 13+ crash: starting a foreground service requires
      // permission to post notifications.
      final notif = await Permission.notification.status;
      if (!notif.isGranted) {
        emit(
          state.copyWith(
            status: ViewStatus.failure,
            message:
                'Notification permission is required to start trip tracking.',
          ),
        );
        return;
      }

      // Background location is required for reliable tracking.
      final bgLoc = await Permission.locationAlways.status;
      if (!bgLoc.isGranted) {
        emit(
          state.copyWith(
            status: ViewStatus.failure,
            message:
                'Location "Always" permission is required to start trip tracking.',
          ),
        );
        return;
      }

      // Rule #1: Single Source of Truth & Transactions
      // Wrap trip start in transaction to prevent "split-brain" states
      String? vehicleNumber;
      await _firestore.runTransaction((transaction) async {
        // Step 1: Read SCHEDULE_TRIPS document
        final scheduleTripRef = _firestore
            .collection('SCHEDULE_TRIPS')
            .doc(event.tripId);
        final scheduleTripSnap = await transaction.get(scheduleTripRef);

        // Step 2: Validate trip availability
        if (!scheduleTripSnap.exists) {
          throw TripNotFoundException(
            'Trip not found. It may have been cancelled or deleted.',
            tripId: event.tripId,
          );
        }

        final scheduleTripData =
            scheduleTripSnap.data() as Map<String, dynamic>;
        final tripStatus =
            (scheduleTripData['tripStatus'] as String?)?.toLowerCase() ?? '';
        final isActive = scheduleTripData['isActive'] as bool? ?? true;
        final orderStatus =
            (scheduleTripData['orderStatus'] as String?)?.toLowerCase() ?? '';
        final source =
            scheduleTripData['source'] as String?; // 'driver' or 'client'

        // Extract vehicle number for RTDB location updates
        vehicleNumber = scheduleTripData['vehicleNumber'] as String?;

        // Check if trip is cancelled or inactive
        if (tripStatus == 'cancelled' || !isActive) {
          throw TripUnavailableException(
            'Trip has been cancelled and is no longer available.',
            tripId: event.tripId,
          );
        }

        // Check if trip is already delivered or returned (cannot restart these)
        if (tripStatus == 'delivered' ||
            tripStatus == 'returned' ||
            orderStatus == 'delivered' ||
            orderStatus == 'returned') {
          throw TripUnavailableException(
            'Trip has already been completed.',
            tripId: event.tripId,
          );
        }

        // CRITICAL: If trip was dispatched by client (source == 'client'), prevent tracking
        // This enforces "No Partial Recovery" - if client dispatches, tracking must NOT start
        final isAlreadyDispatched =
            tripStatus == 'dispatched' || orderStatus == 'dispatched';
        if (isAlreadyDispatched && source == 'client') {
          throw TripUnavailableException(
            'Trip was dispatched by HQ. Tracking cannot be started. This trip is marked as manual/untracked.',
            tripId: event.tripId,
          );
        }

        // If trip is already dispatched by driver, check if tracking is active
        // If tracking is not active, allow restarting it (handles case where status was updated but tracking failed)
        if (isAlreadyDispatched && _locationService.isTracking) {
          // Trip is dispatched and tracking is already active - don't restart
          throw TripUnavailableException(
            'Trip tracking is already active.',
            tripId: event.tripId,
          );
        }
        // If dispatched by driver but tracking not active, continue to start tracking

        // Step 3: Atomically update SCHEDULE_TRIPS and create trips document
        final now = DateTime.now().millisecondsSinceEpoch;

        // Update SCHEDULE_TRIPS status to dispatched (only if not already dispatched)
        if (!isAlreadyDispatched) {
          transaction.update(scheduleTripRef, {
            'tripStatus': 'dispatched',
            'orderStatus': 'dispatched', // Keep both for compatibility
            'dispatchedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'source': 'driver', // Mark as dispatched by driver
          });
        } else {
          // Already dispatched by driver - just update timestamp and ensure source is 'driver'
          transaction.update(scheduleTripRef, {
            'updatedAt': FieldValue.serverTimestamp(),
            'source':
                'driver', // Ensure source is set to driver when starting tracking
          });
        }

        // Create/update trips document
        final trip = Trip(
          id: event.tripId,
          driverId: user.uid,
          clientId: event.clientId,
          status: 'active',
          startTime: now,
          endTime: null,
        );

        final tripsRef = _firestore.collection('trips').doc(event.tripId);
        transaction.set(tripsRef, trip.toJson(), SetOptions(merge: true));
      });

      // Step 4: Only after successful transaction, start location tracking
      final now = DateTime.now().millisecondsSinceEpoch;
      final trip = Trip(
        id: event.tripId,
        driverId: user.uid,
        clientId: event.clientId,
        status: 'active',
        startTime: now,
        endTime: null,
      );

      // Start location tracking first; then bring up the foreground service.
      await _locationService.startTracking(
        uid: user.uid,
        tripId: event.tripId,
        status: trip.status,
        vehicleNumber: vehicleNumber,
      );

      _backgroundSyncService.setTripActive(true);

      // Start service in foreground mode (configured in main.dart).
      // Avoid extra toggles that can trigger multiple startForeground calls.
      await _backgroundService.startService();

      await WakelockPlus.enable();

      // #region agent log
      try {
        final logFile = File(
          '/Users/vedantreddymuskawar/Operon/.cursor/debug.log',
        );
        final logData = {
          'location': 'trip_bloc.dart:187',
          'message': 'Before emit success state',
          'data': {'isClosed': isClosed, 'tripId': trip.id},
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'sessionId': 'debug-session',
          'runId': 'run2',
          'hypothesisId': 'G',
        };
        logFile.writeAsStringSync(
          '${jsonEncode(logData)}\n',
          mode: FileMode.append,
        );
      } catch (_) {}
      // #endregion
      emit(
        state.copyWith(
          status: ViewStatus.success,
          activeTrip: trip,
          isTracking: true,
        ),
      );
      // #region agent log
      try {
        final logFile = File(
          '/Users/vedantreddymuskawar/Operon/.cursor/debug.log',
        );
        final logData = {
          'location': 'trip_bloc.dart:195',
          'message': 'After emit success state',
          'data': {'isClosed': isClosed},
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'sessionId': 'debug-session',
          'runId': 'run2',
          'hypothesisId': 'G',
        };
        logFile.writeAsStringSync(
          '${jsonEncode(logData)}\n',
          mode: FileMode.append,
        );
      } catch (_) {}
      // #endregion

      // Start monitoring trip status for external changes (e.g., dispatch undo from client app)
      _watchActiveTripStatus(trip.id);
    } on TripUnavailableException catch (e) {
      debugPrint(
        '[TripBloc] StartTrip failed: Trip unavailable - ${e.message}',
      );
      _stopWatchingTripStatus(); // Ensure no subscription is left running
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: e.message,
          activeTrip: null,
          isTracking: false,
        ),
      );
    } on TripNotFoundException catch (e) {
      debugPrint('[TripBloc] StartTrip failed: Trip not found - ${e.message}');
      _stopWatchingTripStatus(); // Ensure no subscription is left running
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: e.message,
          activeTrip: null,
          isTracking: false,
        ),
      );
    } catch (e, st) {
      debugPrint('[TripBloc] StartTrip failed: $e');
      debugPrintStack(stackTrace: st);

      // Best-effort cleanup to avoid leaving trackers running.
      try {
        await _locationService.stopTracking(flush: false);
      } catch (_) {}
      try {
        _backgroundService.invoke('stopService');
      } catch (_) {}
      _stopWatchingTripStatus(); // Ensure no subscription is left running

      // Provide user-friendly error message
      final errorMessage = e is Exception
          ? e.toString()
          : 'Failed to start trip tracking. Please try again.';
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: errorMessage,
          activeTrip: null,
          isTracking: false,
        ),
      );
    }
  }

  Future<void> _onEndTrip(EndTrip event, Emitter<TripState> emit) async {
    // #region agent log
    final logData = {
      'location': 'trip_bloc.dart:226',
      'message': '_onEndTrip called',
      'data': {
        'isClosed': isClosed,
        'activeTripId': state.activeTrip?.id,
        'isTracking': state.isTracking,
      },
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'sessionId': 'debug-session',
      'runId': 'run1',
      'hypothesisId': 'B',
    };
    try {
      final logFile = File(
        '/Users/vedantreddymuskawar/Operon/.cursor/debug.log',
      );
      logFile.writeAsStringSync(
        '${logFile.existsSync() ? logFile.readAsStringSync() : ""}${jsonEncode(logData)}\n',
        mode: FileMode.append,
      );
    } catch (_) {}
    // #endregion
    final currentTrip = state.activeTrip;
    if (currentTrip == null) return;

    emit(state.copyWith(status: ViewStatus.loading, message: null));
    // #region agent log
    final logData2 = {
      'location': 'trip_bloc.dart:234',
      'message': '_onEndTrip emit loading',
      'data': {'isClosed': isClosed},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'sessionId': 'debug-session',
      'runId': 'run1',
      'hypothesisId': 'B',
    };
    try {
      final logFile = File(
        '/Users/vedantreddymuskawar/Operon/.cursor/debug.log',
      );
      logFile.writeAsStringSync(
        '${logFile.existsSync() ? logFile.readAsStringSync() : ""}${jsonEncode(logData2)}\n',
        mode: FileMode.append,
      );
    } catch (_) {}
    // #endregion

    try {
      final endTime = DateTime.now().millisecondsSinceEpoch;
      final completedTrip = currentTrip.copyWith(
        status: 'completed',
        endTime: endTime,
      );

      // Stop location tracking
      await _locationService.stopTracking(flush: true);

      _backgroundSyncService.setTripActive(false);

      // Rule #3: Cost-Optimized History (Polyline Strategy)
      // During the trip: Location points are buffered in Hive (local storage)
      // On EndTrip: Compress all points to a single polyline string and save to Firestore
      // This avoids costly Firestore writes during the trip (90%+ cost reduction)
      try {
        // Get location points from BackgroundSyncService (from Hive)
        final locationPoints = await _backgroundSyncService
            .getLocationPointsForTrip(currentTrip.id);

        if (locationPoints.isNotEmpty) {
          // Convert LocationPoint to DriverLocation
          final driverLocations = locationPoints.map((point) {
            return DriverLocation(
              lat: point.lat,
              lng: point.lng,
              bearing: point.bearing ?? 0.0,
              speed: point.speed ?? 0.0,
              status: point.status,
              timestamp: point.timestamp,
            );
          }).toList();

          // Compress to polyline (single string, ~1-2 bytes per point vs ~24 bytes raw)
          final encoded = PolylineEncoder.encodePath(driverLocations);
          final polyline = encoded['polyline'] as String;
          final pointCount = encoded['pointCount'] as int;
          final distanceMeters = encoded['distanceMeters'] as double;

          // Save to SCHEDULE_TRIPS document (single write on EndTrip)
          await _firestore
              .collection('SCHEDULE_TRIPS')
              .doc(currentTrip.id)
              .update({
                'routePolyline': polyline,
                'routePointCount': pointCount,
                'routeDistance': distanceMeters,
                'updatedAt': FieldValue.serverTimestamp(),
              });

          debugPrint(
            '[TripBloc] Saved polyline: $pointCount points, ${polyline.length} chars, ${distanceMeters.toStringAsFixed(2)}m',
          );
        } else {
          debugPrint(
            '[TripBloc] No location points found for trip ${currentTrip.id}',
          );
        }
      } catch (e, st) {
        debugPrint('[TripBloc] Failed to compress and save polyline: $e');
        debugPrintStack(stackTrace: st);
        // Continue - trip completion is more important than polyline
      }

      // Update trips collection
      await _firestore
          .collection('trips')
          .doc(completedTrip.id)
          .set(completedTrip.toJson(), SetOptions(merge: true));

      await WakelockPlus.disable();

      _backgroundService.invoke('stopService');

      // Stop monitoring trip status
      _stopWatchingTripStatus();

      emit(
        state.copyWith(
          status: ViewStatus.success,
          activeTrip: completedTrip,
          isTracking: false,
        ),
      );
    } catch (e, st) {
      debugPrint('[TripBloc] EndTrip failed: $e');
      debugPrintStack(stackTrace: st);

      // Stop watching even if end trip failed
      _stopWatchingTripStatus();

      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: 'Failed to end trip tracking.',
        ),
      );
    }
  }

  /// Monitor the active trip's status in Firestore for external changes.
  ///
  /// **CRITICAL: This method ONLY stops tracking, NEVER starts it.**
  /// Tracking can ONLY be initiated via the `StartTrip` event (user action).
  /// This enforces "No Partial Recovery" - if Client dispatches remotely,
  /// tracking must NOT auto-start.
  ///
  /// Behavior:
  /// - If trip status reverts from tracking state (dispatched/delivered/returned)
  ///   to non-tracking state (scheduled), automatically calls `EndTrip()`.
  /// - If Client dispatches trip (source == 'client'), prevents auto-tracking
  ///   and marks trip as manual dispatch.
  /// - NEVER calls `startTracking()` or `StartTrip` event.
  void _watchActiveTripStatus(String tripId) {
    // Cancel any existing subscription
    _stopWatchingTripStatus();

    _tripStatusSubscription = _firestore
        .collection('SCHEDULE_TRIPS')
        .doc(tripId)
        .snapshots()
        .listen(
          (snapshot) {
            // Check if bloc is still open before processing
            if (isClosed) {
              debugPrint(
                '[TripBloc] Bloc is closed, ignoring trip status update',
              );
              return;
            }

            // If trip document doesn't exist, it was deleted/cancelled
            if (!snapshot.exists) {
              debugPrint(
                '[TripBloc] Trip $tripId was deleted or cancelled, stopping tracking',
              );
              if (!isClosed && state.isTracking) {
                add(const EndTrip());
              }
              return;
            }

            final data = snapshot.data();
            if (data == null) return;

            final tripStatus =
                (data['tripStatus'] as String?)?.toLowerCase() ?? '';
            final orderStatus =
                (data['orderStatus'] as String?)?.toLowerCase() ?? '';
            final isActive = data['isActive'] as bool? ?? true;
            final source = data['source'] as String?; // 'driver' or 'client'

            // Check if trip was cancelled
            if (!isActive || tripStatus == 'cancelled') {
              debugPrint(
                '[TripBloc] Trip $tripId was cancelled, stopping tracking',
              );
              if (!isClosed && state.isTracking) {
                add(const EndTrip());
              }
              return;
            }

            // CRITICAL: Check if status changed to dispatched with source == 'client'
            // This means Client manually dispatched the trip - DO NOT start tracking
            // This enforces "No Partial Recovery" - tracking is exclusive to local StartTrip event
            // NEVER start tracking here - only stop if already active (safety check)
            if (tripStatus == 'dispatched' && source == 'client') {
              debugPrint(
                '[TripBloc] Trip $tripId was dispatched by client (source=client). Marking as manual dispatch. Tracking will NOT start.',
              );
              // Update state to mark as manual dispatch
              if (!isClosed) {
                emit(
                  state.copyWith(
                    lastStatusChangeSource: 'client',
                    isManualDispatch: true,
                    message: 'Trip dispatched by HQ. Tracking not started.',
                  ),
                );
              }
              // If tracking is active, stop it (shouldn't happen, but safety check)
              if (state.isTracking && !isClosed) {
                debugPrint(
                  '[TripBloc] Warning: Tracking was active when client dispatched. Stopping tracking.',
                );
                add(const EndTrip());
              }
              return;
            }

            // If status changed to dispatched with source == 'driver', this is normal
            // Only update source tracking, don't interfere with tracking
            if (tripStatus == 'dispatched' && source == 'driver') {
              if (!isClosed) {
                emit(
                  state.copyWith(
                    lastStatusChangeSource: 'driver',
                    isManualDispatch: false,
                  ),
                );
              }
            }

            // Only process tracking state changes if we have an active trip and tracking is active
            if (state.activeTrip == null || !state.isTracking) {
              return;
            }

            // If trip status is no longer in a tracking state, stop tracking
            // This handles the case where Client App undoes dispatch (dispatched -> scheduled)
            // NOTE: This ONLY stops tracking - it NEVER starts tracking
            final isTrackingState =
                tripStatus == 'dispatched' ||
                tripStatus == 'delivered' ||
                tripStatus == 'returned' ||
                orderStatus == 'dispatched' ||
                orderStatus == 'delivered' ||
                orderStatus == 'returned';

            if (!isTrackingState) {
              debugPrint(
                '[TripBloc] Trip $tripId status changed from tracking state to $tripStatus, stopping tracking',
              );
              // ONLY stop tracking - NEVER start it
              if (!isClosed) {
                add(const EndTrip());
              }
            }
          },
          onError: (error) {
            debugPrint('[TripBloc] Error watching trip status: $error');
            // Don't stop tracking on stream errors - might be temporary network issues
          },
          cancelOnError: false, // Don't cancel subscription on errors
        );
  }

  /// Stop monitoring trip status changes
  void _stopWatchingTripStatus() {
    _tripStatusSubscription?.cancel();
    _tripStatusSubscription = null;
  }

  @override
  Future<void> close() {
    _stopWatchingTripStatus();
    return super.close();
  }
}
