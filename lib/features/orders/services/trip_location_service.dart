import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/models/trip_location.dart';
import '../repositories/scheduled_order_repository.dart';

class TripLocationService {
  TripLocationService({
    required ScheduledOrderRepository scheduledOrderRepository,
    GeolocatorPlatform? geolocator,
    Duration minimumUploadInterval = const Duration(seconds: 30),
  })  : _repository = scheduledOrderRepository,
        _geolocator = geolocator ?? GeolocatorPlatform.instance,
        _minimumUploadInterval = minimumUploadInterval;

  final ScheduledOrderRepository _repository;
  final GeolocatorPlatform _geolocator;
  final Duration _minimumUploadInterval;

  StreamSubscription<Position>? _subscription;
  DateTime? _lastUploadAt;

  bool get isTracking => _subscription != null;

  Future<bool> ensurePermissions() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    final serviceEnabled = await _geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    var permission = await _geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<bool> startTripLogging({
    required String scheduleId,
    LocationSettings? settings,
  }) async {
    await stopTripLogging();

    if (!await ensurePermissions()) {
      return false;
    }

    final locationSettings = settings ?? _defaultLocationSettings();

    try {
      _subscription = _geolocator
          .getPositionStream(locationSettings: locationSettings)
          .listen(
        (position) {
          final now = DateTime.now();
          if (_lastUploadAt != null &&
              now.difference(_lastUploadAt!) < _minimumUploadInterval) {
            return;
          }

          _lastUploadAt = now;

          final location = TripLocation(
            latitude: position.latitude,
            longitude: position.longitude,
            recordedAt: position.timestamp ?? now,
            altitude: _toNullableDouble(position.altitude),
            speed: _toNullableDouble(position.speed),
            accuracy: _toNullableDouble(position.accuracy),
            heading: _toNullableDouble(position.heading),
            source: 'device',
          );

          unawaited(
            _repository.appendTripLocation(
              scheduleId: scheduleId,
              location: location,
            ),
          );
        },
        onError: (_) async {
          await stopTripLogging();
        },
        cancelOnError: true,
      );
      return true;
    } catch (_) {
      await stopTripLogging();
      return false;
    }
  }

  Future<void> stopTripLogging() async {
    await _subscription?.cancel();
    _subscription = null;
    _lastUploadAt = null;
  }

  LocationSettings _defaultLocationSettings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 30),
        forceLocationManager: false,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );
  }

  double? _toNullableDouble(double? value) {
    if (value == null) {
      return null;
    }
    if (value.isNaN || value.isInfinite) {
      return null;
    }
    return value;
  }
}

