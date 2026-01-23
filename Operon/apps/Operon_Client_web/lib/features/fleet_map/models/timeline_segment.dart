/// Status of a timeline segment (moving or stopped).
enum TimelineStatus {
  /// Vehicle is moving (speed > threshold).
  moving,

  /// Vehicle is stopped/idling (speed <= threshold).
  stopped,
}

/// Represents a segment of time in the vehicle history timeline.
/// 
/// Used to visualize periods when the vehicle was moving vs stopped
/// on the history playback timeline.
class TimelineSegment {
  const TimelineSegment({
    required this.start,
    required this.end,
    required this.status,
  });

  /// Start timestamp of this segment.
  final DateTime start;

  /// End timestamp of this segment.
  final DateTime end;

  /// Status during this segment (moving or stopped).
  final TimelineStatus status;

  /// Duration of this segment.
  Duration get duration => end.difference(start);

  @override
  String toString() => 'TimelineSegment($start -> $end, $status)';
}
