import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared utility functions for scheduled trips operations
/// These methods are used by both Android and Web apps to ensure consistency
class ScheduledTripsUtils {
  ScheduledTripsUtils._(); // Private constructor to prevent instantiation

  static const String scheduleTripsCollection = 'SCHEDULE_TRIPS';

  /// Generate unique scheduleTripId: ClientID-OrderID-YYYYMMDD-VehicleID-Slot
  /// Format: CLIENTID-ORDERID-YYYYMMDD-VEHICLEID-SLOT
  /// Example: CLIENT123-ORDER456-20240115-VEH001-1
  static String generateScheduleTripId({
    required String clientId,
    required String orderId,
    required DateTime scheduledDate,
    required String vehicleId,
    required int slot,
  }) {
    // Format date as YYYYMMDD
    final year = scheduledDate.year.toString();
    final month = scheduledDate.month.toString().padLeft(2, '0');
    final day = scheduledDate.day.toString().padLeft(2, '0');
    final dateStr = '$year$month$day';
    
    return '${clientId.toUpperCase()}-${orderId.toUpperCase()}-$dateStr-${vehicleId.toUpperCase()}-$slot';
  }

  /// Check if slot is available (Date+Vehicle+Slot must be unique)
  /// Returns true if slot is available, false if already booked
  /// 
  /// [excludeTripId] - Optional trip ID to exclude from check (useful when rescheduling)
  static Future<bool> isSlotAvailable({
    required FirebaseFirestore firestore,
    required String organizationId,
    required DateTime scheduledDate,
    required String vehicleId,
    required int slot,
    String? excludeTripId,
  }) async {
    final startOfDay = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    var query = firestore
        .collection(scheduleTripsCollection)
        .where('organizationId', isEqualTo: organizationId)
        .where('vehicleId', isEqualTo: vehicleId)
        .where('slot', isEqualTo: slot)
        .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
        .where('isActive', isEqualTo: true); // Soft delete pattern: only active trips

    final snapshot = await query.get();

    // Filter by tripStatus in memory and exclude current trip if provided
    final conflictingTrips = snapshot.docs.where((doc) {
      final status = doc.data()['tripStatus'] as String?;
      final isActiveStatus = status == 'scheduled' || status == 'in_progress';
      final isNotExcluded = excludeTripId == null || doc.id != excludeTripId;
      return isActiveStatus && isNotExcluded;
    }).toList();

    return conflictingTrips.isEmpty;
  }

  /// Calculate trip-specific pricing based on fixedQuantityPerTrip
  /// 
  /// Takes a list of items and calculates pricing for each item based on
  /// the fixedQuantityPerTrip field, then returns the updated items with
  /// trip-level pricing fields and a summary tripPricing object.
  /// 
  /// Returns a map with:
  /// - 'items': List of items with tripSubtotal, tripGstAmount, tripTotal fields
  /// - 'tripPricing': Map with subtotal, gstAmount, total
  static Map<String, dynamic> calculateTripPricing(
    List<dynamic> items, {
    bool includeGstInTotal = true,
  }) {
    double totalSubtotal = 0.0;
    double totalGstAmount = 0.0;
    double totalAmount = 0.0;

    // Calculate pricing for each item based on fixedQuantityPerTrip
    final tripItems = items.map((item) {
      if (item is! Map<String, dynamic>) return item;

      final fixedQty = (item['fixedQuantityPerTrip'] as num?)?.toInt() ?? 0;
      final unitPrice = (item['unitPrice'] as num?)?.toDouble() ?? 0.0;
      final gstPercent = (item['gstPercent'] as num?)?.toDouble();

      // Calculate trip-specific pricing
      final subtotal = fixedQty * unitPrice;
      final gstAmount =
          includeGstInTotal && gstPercent != null ? subtotal * (gstPercent / 100) : 0.0;
      final total = subtotal + gstAmount;

      totalSubtotal += subtotal;
      totalGstAmount += gstAmount;
      totalAmount += total;

      return {
        ...item,
        'tripSubtotal': subtotal,
        'tripGstAmount': gstAmount,
        'tripTotal': total,
      };
    }).toList();

    return {
      'items': tripItems,
      'tripPricing': {
        'subtotal': totalSubtotal,
        'gstAmount': totalGstAmount,
        'total': totalAmount,
      },
    };
  }
}

