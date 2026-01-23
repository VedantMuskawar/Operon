import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/widgets.dart';

/// Service for managing driver presence and heartbeat in Firebase Realtime Database.
/// 
/// Writes a heartbeat timestamp every 60 seconds and handles app lifecycle
/// to set offline status when the app is detached.
class PresenceService with WidgetsBindingObserver {
  PresenceService({
    required this.uid,
    FirebaseDatabase? database,
  }) : _database = database ?? FirebaseDatabase.instance;

  final String uid;
  final FirebaseDatabase _database;

  Timer? _heartbeatTimer;
  bool _isActive = false;

  /// Start the presence service.
  /// 
  /// Begins writing heartbeat timestamps every 60 seconds and observes
  /// app lifecycle for offline detection.
  void start() {
    if (_isActive) return;

    _isActive = true;
    WidgetsBinding.instance.addObserver(this);

    // Write initial heartbeat
    _writeHeartbeat();

    // Start periodic heartbeat (every 60 seconds)
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _writeHeartbeat(),
    );
  }

  /// Stop the presence service.
  /// 
  /// Stops the heartbeat timer and removes lifecycle observer.
  void stop() {
    if (!_isActive) return;

    _isActive = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    WidgetsBinding.instance.removeObserver(this);

    // Attempt "last gasp" write to set offline status
    _writeOfflineStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached || state == AppLifecycleState.paused) {
      // Attempt to write offline status when app is detached/paused
      _writeOfflineStatus();
    } else if (state == AppLifecycleState.resumed && _isActive) {
      // Resume heartbeat when app comes back
      _writeHeartbeat();
    }
  }

  /// Write heartbeat timestamp to Firebase Realtime Database.
  void _writeHeartbeat() {
    if (!_isActive) return;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      _database.ref('active_drivers/$uid/last_seen').set(now);
    } catch (e) {
      // Log error but don't crash the app
      debugPrint('PresenceService: Failed to write heartbeat: $e');
    }
  }

  /// Write offline status to Firebase Realtime Database.
  /// 
  /// This is called when the app is detached or the service is stopped.
  void _writeOfflineStatus() {
    try {
      // Update the status field in the location data if it exists
      _database.ref('active_drivers/$uid/status').set('offline');
    } catch (e) {
      // Log error but don't crash the app
      debugPrint('PresenceService: Failed to write offline status: $e');
    }
  }

  /// Dispose the service.
  /// 
  /// Call this when the service is no longer needed.
  void dispose() {
    stop();
  }
}
