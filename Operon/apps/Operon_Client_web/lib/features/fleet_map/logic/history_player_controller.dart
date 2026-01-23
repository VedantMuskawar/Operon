import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:dash_web/features/fleet_map/models/timeline_segment.dart';
import 'package:flutter/foundation.dart';

/// Controller for DVR-style history playback of vehicle location data.
/// 
/// Manages playback state, timeline scrubbing, and speed control for
/// visualizing historical vehicle movements on the map.
class HistoryPlayerController extends ChangeNotifier {
  HistoryPlayerController({
    List<DriverLocation>? historyPoints,
  }) : _historyPoints = historyPoints ?? [] {
    if (_historyPoints.isNotEmpty) {
      _historyPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _currentTime = DateTime.fromMillisecondsSinceEpoch(_historyPoints.first.timestamp);
      _startTime = _currentTime;
      _endTime = DateTime.fromMillisecondsSinceEpoch(_historyPoints.last.timestamp);
    }
  }

  /// Full sorted list of historical location points.
  List<DriverLocation> _historyPoints;
  List<DriverLocation> get historyPoints => List.unmodifiable(_historyPoints);

  /// Current timestamp being visualized.
  DateTime _currentTime = DateTime.now();
  DateTime get currentTime => _currentTime;

  /// Start of the timeline (first location timestamp).
  DateTime? _startTime;
  DateTime? get startTime => _startTime;

  /// End of the timeline (last location timestamp).
  DateTime? _endTime;
  DateTime? get endTime => _endTime;

  /// Whether playback is currently active.
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  /// Playback speed multiplier (1.0 = real-time, 2.0 = 2x speed, etc.).
  double _playbackSpeed = 1.0;
  double get playbackSpeed => _playbackSpeed;

  /// Internal timer for playback updates.
  Timer? _playbackTimer;

  /// Speed threshold in m/s to distinguish moving from stopped.
  static const double _speedThreshold = 1.0;

  /// Update history points and reset playback.
  void setHistoryPoints(List<DriverLocation> points) {
    _historyPoints = List.from(points);
    if (_historyPoints.isNotEmpty) {
      _historyPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _currentTime = DateTime.fromMillisecondsSinceEpoch(_historyPoints.first.timestamp);
      _startTime = _currentTime;
      _endTime = DateTime.fromMillisecondsSinceEpoch(_historyPoints.last.timestamp);
    }
    pause();
    notifyListeners();
  }

  /// Start playback.
  void play() {
    if (_isPlaying) return;
    if (_historyPoints.isEmpty) return;
    if (_endTime != null && _currentTime.isAfter(_endTime!)) {
      // If at end, restart from beginning
      seekTo(_startTime!);
    }

    _isPlaying = true;
    _startPlaybackTimer();
    notifyListeners();
  }

  /// Pause playback.
  void pause() {
    if (!_isPlaying) return;
    _isPlaying = false;
    _playbackTimer?.cancel();
    _playbackTimer = null;
    notifyListeners();
  }

  /// Toggle play/pause.
  void togglePlayPause() {
    if (_isPlaying) {
      pause();
    } else {
      play();
    }
  }

  /// Set playback speed (1.0, 2.0, or 5.0).
  void setSpeed(double speed) {
    if (speed != 1.0 && speed != 2.0 && speed != 5.0) {
      // Round to nearest valid speed
      if (speed < 1.5) {
        speed = 1.0;
      } else if (speed < 3.5) {
        speed = 2.0;
      } else {
        speed = 5.0;
      }
    }
    _playbackSpeed = speed;
    if (_isPlaying) {
      _playbackTimer?.cancel();
      _startPlaybackTimer();
    }
    notifyListeners();
  }

  /// Cycle through speed options (1x -> 2x -> 5x -> 1x).
  void cycleSpeed() {
    if (_playbackSpeed == 1.0) {
      setSpeed(2.0);
    } else if (_playbackSpeed == 2.0) {
      setSpeed(5.0);
    } else {
      setSpeed(1.0);
    }
  }

  /// Seek to a specific timestamp.
  void seekTo(DateTime time) {
    _currentTime = time;
    if (_endTime != null && _currentTime.isAfter(_endTime!)) {
      _currentTime = _endTime!;
      pause();
    }
    if (_startTime != null && _currentTime.isBefore(_startTime!)) {
      _currentTime = _startTime!;
    }
    notifyListeners();
  }

  /// Seek backward by specified duration.
  void seekBackward(Duration duration) {
    final newTime = _currentTime.subtract(duration);
    seekTo(newTime);
  }

  /// Seek forward by specified duration.
  void seekForward(Duration duration) {
    final newTime = _currentTime.add(duration);
    seekTo(newTime);
  }

  /// Get the location at the current time (interpolated if needed).
  DriverLocation? getLocationAtTime(DateTime time) {
    if (_historyPoints.isEmpty) return null;
    if (_historyPoints.length == 1) return _historyPoints.first;

    // Find the closest location points before and after the target time
    DriverLocation? before;
    DriverLocation? after;

    for (final loc in _historyPoints) {
      final locTime = DateTime.fromMillisecondsSinceEpoch(loc.timestamp);
      if (locTime.isBefore(time) || locTime.isAtSameMomentAs(time)) {
        before = loc;
      } else if (locTime.isAfter(time)) {
        after = loc;
        break;
      }
    }

    // If we have an exact match
    if (before != null && before.timestamp == time.millisecondsSinceEpoch) {
      return before;
    }

    // If we're before the first point, return first
    if (before == null) return _historyPoints.first;

    // If we're after the last point, return last
    if (after == null) return _historyPoints.last;

    // Interpolate between before and after
    return _interpolateLocation(before, after, time);
  }

  /// Get the current location (at currentTime).
  DriverLocation? get currentLocation => getLocationAtTime(_currentTime);

  /// Get timeline segments for visualization (moving vs stopped periods).
  List<TimelineSegment> getSegments() {
    if (_historyPoints.length < 2) {
      if (_historyPoints.isEmpty) return [];
      final point = _historyPoints.first;
      final time = DateTime.fromMillisecondsSinceEpoch(point.timestamp);
      return [
        TimelineSegment(
          start: time,
          end: time.add(const Duration(minutes: 1)),
          status: point.speed > _speedThreshold
              ? TimelineStatus.moving
              : TimelineStatus.stopped,
        ),
      ];
    }

    final segments = <TimelineSegment>[];
    TimelineStatus? currentStatus;
    DateTime? segmentStart;

    for (int i = 0; i < _historyPoints.length; i++) {
      final point = _historyPoints[i];
      final time = DateTime.fromMillisecondsSinceEpoch(point.timestamp);
      final status = point.speed > _speedThreshold
          ? TimelineStatus.moving
          : TimelineStatus.stopped;

      if (currentStatus == null) {
        // First point
        currentStatus = status;
        segmentStart = time;
      } else if (currentStatus != status) {
        // Status changed, create segment
        if (segmentStart != null) {
          segments.add(TimelineSegment(
            start: segmentStart,
            end: time,
            status: currentStatus,
          ));
        }
        currentStatus = status;
        segmentStart = time;
      }
    }

    // Add final segment
    if (segmentStart != null && _historyPoints.isNotEmpty) {
      final lastTime = DateTime.fromMillisecondsSinceEpoch(
        _historyPoints.last.timestamp,
      );
      segments.add(TimelineSegment(
        start: segmentStart,
        end: lastTime,
        status: currentStatus!,
      ));
    }

    return segments;
  }

  /// Interpolate location between two points.
  DriverLocation _interpolateLocation(
    DriverLocation before,
    DriverLocation after,
    DateTime targetTime,
  ) {
    final beforeTime = before.timestamp;
    final afterTime = after.timestamp;
    final targetTimeMs = targetTime.millisecondsSinceEpoch;

    if (beforeTime == afterTime) return before;

    final t = (targetTimeMs - beforeTime) / (afterTime - beforeTime);
    final clampedT = t.clamp(0.0, 1.0);

    return DriverLocation(
      lat: before.lat + (after.lat - before.lat) * clampedT,
      lng: before.lng + (after.lng - before.lng) * clampedT,
      bearing: before.bearing + (after.bearing - before.bearing) * clampedT,
      speed: before.speed + (after.speed - before.speed) * clampedT,
      status: before.status,
      timestamp: targetTimeMs,
    );
  }

  /// Start the playback timer.
  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    // Update every 100ms for smooth playback
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isPlaying) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      final elapsed = now.difference(_lastUpdateTime);
      final scaledElapsed = elapsed * _playbackSpeed;

      _currentTime = _currentTime.add(scaledElapsed);
      _lastUpdateTime = now;

      // Check if we've reached the end
      if (_endTime != null && _currentTime.isAfter(_endTime!)) {
        _currentTime = _endTime!;
        pause();
      }

      notifyListeners();
    });
    _lastUpdateTime = DateTime.now();
  }

  DateTime _lastUpdateTime = DateTime.now();

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }
}
