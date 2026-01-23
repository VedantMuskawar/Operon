/// Utility functions for working with trip status from SCHEDULE_TRIPS collection.
/// 
/// This module standardizes on reading only `tripStatus` field (no `orderStatus` fallback)
/// to ensure consistency across the driver app.
library;

/// Gets the trip status from a trip map.
/// 
/// Only reads from `tripStatus` field in SCHEDULE_TRIPS collection.
/// Returns 'scheduled' as default if `tripStatus` is null or empty.
/// 
/// **Important:** This function does NOT check `orderStatus` field.
/// All UI components should use this helper for consistent status reading.
String getTripStatus(Map<String, dynamic> trip) {
  final tripStatus = trip['tripStatus']?.toString();
  if (tripStatus == null || tripStatus.isEmpty) {
    return 'scheduled';
  }
  return tripStatus.toLowerCase();
}
