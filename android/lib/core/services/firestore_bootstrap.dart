import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Centralizes Firestore client bootstrapping so we can tune caches and
/// capture lightweight telemetry before the rest of the app starts.
class FirestoreBootstrap {
  FirestoreBootstrap._();

  static bool _initialized = false;
  static StreamSubscription<void>? _syncSubscription;
  static final ValueNotifier<DateTime?> lastSyncTime =
      ValueNotifier<DateTime?>(null);

  /// Ensures Firestore is configured with sensible defaults for mobile.
  ///
  /// Idempotent – safe to call multiple times.
  static Future<void> ensureInitialized() async {
    if (_initialized) return;

    final firestore = FirebaseFirestore.instance;

    // Tuned persistence: enable offline cache and expand cache size so the
    // client can serve recent client/order lists without hitting the network.
    firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Track sync cadence – useful to detect stalls or excessive churn.
    _syncSubscription = firestore.snapshotsInSync().listen((_) {
      final now = DateTime.now();
      lastSyncTime.value = now;
      if (kDebugMode) {
        debugPrint('Firestore synced at ${now.toIso8601String()}');
      }
    });

    _initialized = true;
  }

  /// Cancels diagnostics listeners (primarily for test tear-down).
  static Future<void> dispose() async {
    await _syncSubscription?.cancel();
    _syncSubscription = null;
    _initialized = false;
  }
}

