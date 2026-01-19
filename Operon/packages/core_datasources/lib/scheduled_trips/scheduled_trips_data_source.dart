import 'package:cloud_firestore/cloud_firestore.dart';

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

    return _firestore
        .collection(_collection)
        .where('organizationId', isEqualTo: organizationId)
        .where('driverPhone', isEqualTo: normalizedPhone)
        .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) {
      final trips = snapshot.docs.map((doc) {
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

      trips.sort((a, b) {
        final slotA = a['slot'] as int? ?? 0;
        final slotB = b['slot'] as int? ?? 0;
        return slotA.compareTo(slotB);
      });

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
    String? returnedBy,
    String? returnedByRole,
    bool clearDeliveryInfo = false,
  }) async {
    final updateData = <String, dynamic>{
      'tripStatus': tripStatus,
      // Some parts of the system still rely on orderStatus in trip doc.
      'orderStatus': tripStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };

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

