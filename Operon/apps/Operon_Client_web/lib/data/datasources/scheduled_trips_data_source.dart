import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_datasources/core_datasources.dart' as shared;

/// Web-specific ScheduledTripsDataSource that extends the shared implementation
///
/// This class extends the shared ScheduledTripsDataSource from core_datasources
/// and adds Web-specific methods (getScheduledTripsForOrder, watchScheduledTripsForDate,
/// updateTripStatus with payment fields).
class ScheduledTripsDataSource extends shared.ScheduledTripsDataSource {
  ScheduledTripsDataSource({super.firestore});

  /// Get scheduled trips for an order
  Future<List<Map<String, dynamic>>> getScheduledTripsForOrder(String orderId) async {
    final snapshot = await firestore
        .collection(collection)
        .where('orderId', isEqualTo: orderId)
        .where('isActive', isEqualTo: true)
        .orderBy('scheduledDate', descending: false)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        ...data,
      };
    }).toList();
  }

  /// Watch scheduled trips for a specific date
  Stream<List<Map<String, dynamic>>> watchScheduledTripsForDate({
    required String organizationId,
    required DateTime scheduledDate,
  }) {
    final startOfDay = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return firestore
        .collection(collection)
        .where('organizationId', isEqualTo: organizationId)
        .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
        .limit(500)
        .snapshots()
        .map((snapshot) {
      final allTrips = snapshot.docs.map((doc) {
        final data = doc.data();
        final convertedData = <String, dynamic>{'id': doc.id};
        data.forEach((key, value) {
          if (value is Timestamp) {
            convertedData[key] = value.toDate();
          } else {
            convertedData[key] = value;
          }
        });
        return convertedData;
      }).toList();

      final activeTrips = allTrips.where((trip) {
        final isActive = trip['isActive'] as bool?;
        return isActive != false;
      }).toList();

      activeTrips.sort((a, b) {
        final slotA = a['slot'] as int? ?? 0;
        final slotB = b['slot'] as int? ?? 0;
        return slotA.compareTo(slotB);
      });

      return activeTrips;
    });
  }

  /// Update trip status (Web-specific override with payment fields)
  @override
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
    // Web-specific payment fields (passed via repository, ignored by base)
    List<Map<String, dynamic>>? paymentDetails,
    double? totalPaidOnReturn,
    String? paymentStatus,
    double? remainingAmount,
    List<String>? returnTransactions,
    bool clearPaymentInfo = false,
  }) async {
    await super.updateTripStatus(
      tripId: tripId,
      tripStatus: tripStatus,
      completedAt: completedAt,
      cancelledAt: cancelledAt,
      initialReading: initialReading,
      deliveryPhotoUrl: deliveryPhotoUrl,
      deliveredBy: deliveredBy,
      deliveredByRole: deliveredByRole,
      finalReading: finalReading,
      distanceTravelled: distanceTravelled,
      computedTravelledDistance: computedTravelledDistance,
      returnedBy: returnedBy,
      returnedByRole: returnedByRole,
      clearDeliveryInfo: clearDeliveryInfo,
      source: source,
    );

    final updateData = <String, dynamic>{};

    if (paymentDetails != null) {
      updateData['paymentDetails'] =
          paymentDetails.isEmpty ? FieldValue.delete() : paymentDetails;
    } else if (clearPaymentInfo) {
      updateData['paymentDetails'] = FieldValue.delete();
    }

    if (totalPaidOnReturn != null) {
      updateData['totalPaidOnReturn'] = totalPaidOnReturn;
    } else if (clearPaymentInfo) {
      updateData['totalPaidOnReturn'] = FieldValue.delete();
    }

    if (paymentStatus != null) {
      updateData['paymentStatus'] = paymentStatus;
    } else if (clearPaymentInfo) {
      updateData['paymentStatus'] = FieldValue.delete();
    }

    if (remainingAmount != null) {
      updateData['remainingAmount'] = remainingAmount;
    } else if (clearPaymentInfo) {
      updateData['remainingAmount'] = FieldValue.delete();
    }

    if (returnTransactions != null) {
      updateData['returnTransactions'] =
          returnTransactions.isEmpty ? FieldValue.delete() : returnTransactions;
    } else if (clearPaymentInfo) {
      updateData['returnTransactions'] = FieldValue.delete();
    }

    if (updateData.isNotEmpty) {
      await firestore.collection(collection).doc(tripId).update(updateData);
    }
  }
}
