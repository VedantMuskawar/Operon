import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Shared data access for scheduled trips (SCHEDULE_TRIPS collection).
///
/// This is intentionally Map-based to match how existing apps store trip docs
/// and to avoid duplicating a full domain model in the datasource layer.
class ScheduledTripsDataSource {
  ScheduledTripsDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _collection = 'SCHEDULE_TRIPS';

  /// Watch trips for a driver (by phone) on a specific date.
  ///
  /// The query uses:
  /// - organizationId (equality)
  /// - driverPhone (equality)
  /// - scheduledDate (day range)
  ///
  /// Note: this may require a composite Firestore index depending on your rules.
  Stream<List<Map<String, dynamic>>> watchDriverScheduledTripsForDate({
    required String organizationId,
    required String driverPhone,
    required DateTime scheduledDate,
  }) {
    final normalizedPhone = _normalizePhone(driverPhone);
    final startOfDay = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Debug logging
    debugPrint('[ScheduledTripsDataSource] Query: orgId=$organizationId, driverPhone=$driverPhone, normalizedPhone=$normalizedPhone, date=$startOfDay');

    // Query by org + date first (more flexible for existing trips with non-normalized phones)
    // Note: We don't filter by isActive in the query to handle trips that may not have this field set
    // Instead, we filter in memory to only include active trips (isActive != false)
    return _firestore
        .collection(_collection)
        .where('organizationId', isEqualTo: organizationId)
        .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) {
      final allTrips = snapshot.docs.map((doc) {
        final data = doc.data();
        final converted = <String, dynamic>{'id': doc.id};

        // Convert Timestamp fields to DateTime for easier UI usage.
        data.forEach((key, value) {
          if (value is Timestamp) {
            converted[key] = value.toDate();
          } else {
            converted[key] = value;
          }
        });

        return converted;
      }).toList();

      debugPrint('[ScheduledTripsDataSource] Found ${allTrips.length} total trips for org=$organizationId, date=$startOfDay');

      // Filter by isActive (only exclude if explicitly false, treat missing as active)
      final activeTrips = allTrips.where((trip) {
        final isActive = trip['isActive'] as bool?;
        // Include trip if isActive is true or null/undefined (treat missing as active)
        return isActive != false;
      }).toList();

      debugPrint('[ScheduledTripsDataSource] ${activeTrips.length} trips after isActive filter');

      // Filter by normalized phone to handle both normalized and non-normalized stored values
      final trips = activeTrips.where((trip) {
        final tripDriverPhone = trip['driverPhone'] as String?;
        if (tripDriverPhone == null || tripDriverPhone.isEmpty) {
          debugPrint('[ScheduledTripsDataSource] Trip ${trip['id']} has no driverPhone field');
          return false;
        }
        // Normalize the stored phone and compare with normalized query phone
        final normalizedTripPhone = _normalizePhone(tripDriverPhone);
        final matches = normalizedTripPhone == normalizedPhone;
        if (!matches) {
          debugPrint('[ScheduledTripsDataSource] Trip ${trip['id']} phone mismatch: stored="$tripDriverPhone" normalized="$normalizedTripPhone" vs query="$normalizedPhone"');
        } else {
          debugPrint('[ScheduledTripsDataSource] Trip ${trip['id']} phone match: "$normalizedTripPhone"');
        }
        return matches;
      }).toList();

      trips.sort((a, b) {
        final slotA = a['slot'] as int? ?? 0;
        final slotB = b['slot'] as int? ?? 0;
        return slotA.compareTo(slotB);
      });

      debugPrint('[ScheduledTripsDataSource] Found ${trips.length} trips out of ${allTrips.length} total for date');
      return trips;
    });
  }

  Future<void> updateTripStatus({
    required String tripId,
    required String tripStatus,
    DateTime? completedAt,
    DateTime? cancelledAt,
    double? initialReading,
    String? deliveryPhotoUrl,
    String? deliveredBy,
    String? deliveredByRole,
    double? finalReading,
    double? distanceTravelled,
    double? computedTravelledDistance,
    String? returnedBy,
    String? returnedByRole,
    bool clearDeliveryInfo = false,
    String? source,
  }) async {
    final updateData = <String, dynamic>{
      'tripStatus': tripStatus,
      // Some parts of the system still rely on orderStatus in trip doc.
      'orderStatus': tripStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Write source field if provided ('driver' or 'client')
    // This field is critical for "No Partial Recovery" logic - tracking only starts via driver action
    if (source != null) {
      updateData['source'] = source;
    }

    if (completedAt != null) updateData['completedAt'] = Timestamp.fromDate(completedAt);
    if (cancelledAt != null) updateData['cancelledAt'] = Timestamp.fromDate(cancelledAt);

    if (initialReading != null) {
      updateData['initialReading'] = initialReading;
      updateData['dispatchedAt'] = FieldValue.serverTimestamp();
    }

    if (deliveryPhotoUrl != null) {
      updateData['deliveryPhotoUrl'] = deliveryPhotoUrl;
      updateData['deliveredAt'] = FieldValue.serverTimestamp();
      if (deliveredBy != null) updateData['deliveredBy'] = deliveredBy;
      if (deliveredByRole != null) updateData['deliveredByRole'] = deliveredByRole;
    } else if (tripStatus.toLowerCase() == 'delivered' && !clearDeliveryInfo) {
      // Driver flows may deliver without a photo; still stamp deliveredAt.
      updateData['deliveredAt'] = FieldValue.serverTimestamp();
      if (deliveredBy != null) updateData['deliveredBy'] = deliveredBy;
      if (deliveredByRole != null) updateData['deliveredByRole'] = deliveredByRole;
    } else if (clearDeliveryInfo) {
      updateData['deliveryPhotoUrl'] = FieldValue.delete();
      updateData['deliveredAt'] = FieldValue.delete();
      updateData['deliveredBy'] = FieldValue.delete();
      updateData['deliveredByRole'] = FieldValue.delete();
    }

    if (finalReading != null) {
      updateData['finalReading'] = finalReading;
      updateData['returnedAt'] = FieldValue.serverTimestamp();
      if (distanceTravelled != null) updateData['distanceTravelled'] = distanceTravelled;
      if (computedTravelledDistance != null) {
        updateData['computedTravelledDistance'] = computedTravelledDistance;
      }
      if (returnedBy != null) updateData['returnedBy'] = returnedBy;
      if (returnedByRole != null) updateData['returnedByRole'] = returnedByRole;
    }

    // If reverting statuses, remove fields that shouldn’t exist.
    if (tripStatus == 'scheduled' || tripStatus == 'pending') {
      updateData['initialReading'] = FieldValue.delete();
      updateData['dispatchedAt'] = FieldValue.delete();
      updateData['dispatchedBy'] = FieldValue.delete();
      updateData['dispatchedByRole'] = FieldValue.delete();
    }

    if (tripStatus == 'scheduled' ||
        tripStatus == 'pending' ||
        tripStatus == 'dispatched') {
      updateData['deliveryPhotoUrl'] = FieldValue.delete();
      updateData['deliveredAt'] = FieldValue.delete();
      updateData['deliveredBy'] = FieldValue.delete();
      updateData['deliveredByRole'] = FieldValue.delete();
    }

    if (tripStatus == 'scheduled' ||
        tripStatus == 'pending' ||
        tripStatus == 'dispatched' ||
        tripStatus == 'delivered') {
      updateData['finalReading'] = FieldValue.delete();
      updateData['returnedAt'] = FieldValue.delete();
      updateData['distanceTravelled'] = FieldValue.delete();
      updateData['computedTravelledDistance'] = FieldValue.delete();
      updateData['returnedBy'] = FieldValue.delete();
      updateData['returnedByRole'] = FieldValue.delete();
    }

    await _firestore.collection(_collection).doc(tripId).update(updateData);
  }

  String _normalizePhone(String input) {
    // Keep '+' to preserve E.164, strip whitespace/symbols.
    return input.replaceAll(RegExp(r'[^0-9+]'), '');
  }
}

