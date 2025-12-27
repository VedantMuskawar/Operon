import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_datasources/core_datasources.dart';

class ScheduledTripsDataSource {
  ScheduledTripsDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _collection = 'SCHEDULE_TRIPS';

  /// Generate unique scheduleTripId: ClientID-OrderID-YYYYMMDD-VehicleID-Slot
  /// Uses shared utility from core_datasources
  String generateScheduleTripId({
    required String clientId,
    required String orderId,
    required DateTime scheduledDate,
    required String vehicleId,
    required int slot,
  }) {
    return ScheduledTripsUtils.generateScheduleTripId(
      clientId: clientId,
      orderId: orderId,
      scheduledDate: scheduledDate,
      vehicleId: vehicleId,
      slot: slot,
    );
  }

  /// Check if slot is available (Date+Vehicle+Slot must be unique)
  /// Uses shared utility from core_datasources
  Future<bool> isSlotAvailable({
    required String organizationId,
    required DateTime scheduledDate,
    required String vehicleId,
    required int slot,
    String? excludeTripId, // Exclude current trip when rescheduling
  }) async {
    return ScheduledTripsUtils.isSlotAvailable(
      firestore: _firestore,
      organizationId: organizationId,
      scheduledDate: scheduledDate,
      vehicleId: vehicleId,
      slot: slot,
      excludeTripId: excludeTripId,
    );
  }

  /// Calculate trip-specific pricing based on fixedQuantityPerTrip
  /// Uses shared utility from core_datasources
  Map<String, dynamic> calculateTripPricing(
    List<dynamic> items, {
    bool includeGstInTotal = true,
  }) {
    return ScheduledTripsUtils.calculateTripPricing(
      items,
      includeGstInTotal: includeGstInTotal,
    );
  }

  /// Create a scheduled trip
  Future<String> createScheduledTrip({
    required String organizationId,
    required String orderId,
    required String clientId,
    required String clientName,
    required String customerNumber,
    String? clientPhone,
    required String paymentType,
    required DateTime scheduledDate,
    required String scheduledDay,
    required String vehicleId,
    required String vehicleNumber,
    required String? driverId,
    required String? driverName,
    required String? driverPhone,
    required int slot,
    required String slotName,
    required Map<String, dynamic> deliveryZone,
    required List<dynamic> items,
    required Map<String, dynamic> pricing,
    required bool includeGstInTotal,
    required String priority,
    required String createdBy,
  }) async {
    // Validate slot availability before creating
    final isAvailable = await isSlotAvailable(
      organizationId: organizationId,
      scheduledDate: scheduledDate,
      vehicleId: vehicleId,
      slot: slot,
    );

    if (!isAvailable) {
      final dateStr = '${scheduledDate.year}-${scheduledDate.month.toString().padLeft(2, '0')}-${scheduledDate.day.toString().padLeft(2, '0')}';
      throw Exception('Slot $slot is already booked for this vehicle on $dateStr');
    }

    // Generate scheduleTripId
    final scheduleTripId = generateScheduleTripId(
      clientId: clientId,
      orderId: orderId,
      scheduledDate: scheduledDate,
      vehicleId: vehicleId,
      slot: slot,
    );

    // Calculate trip-specific pricing based on fixedQuantityPerTrip
    // Guard GST consistency: if order snapshot carries includeGstInTotal, enforce match
    final orderIncludeGst = pricing['includeGstInTotal'] as bool?;
    if (orderIncludeGst != null && orderIncludeGst != includeGstInTotal) {
      throw Exception(
        'GST flag mismatch: order includeGstInTotal=$orderIncludeGst, trip includeGstInTotal=$includeGstInTotal',
      );
    }

    // Calculate trip-specific pricing based on fixedQuantityPerTrip
    final tripPricingData =
        calculateTripPricing(items, includeGstInTotal: includeGstInTotal);
    var tripItems = tripPricingData['items'] as List<dynamic>;
    var tripPricing = tripPricingData['tripPricing'] as Map<String, dynamic>;

    // Final guard: if GST is excluded, ensure no GST amounts persist
    if (!includeGstInTotal) {
      final cleanedItems = <dynamic>[];
      for (final item in tripItems) {
        if (item is Map<String, dynamic>) {
          cleanedItems.add({
            ...item,
            'tripGstAmount': 0.0,
            'tripTotal': (item['tripSubtotal'] as num?)?.toDouble() ?? 0.0,
          });
        } else {
          cleanedItems.add(item);
        }
      }
      tripItems = cleanedItems;
      tripPricing = {
        ...tripPricing,
        'gstAmount': 0.0,
        'total': (tripPricing['subtotal'] as num?)?.toDouble() ?? 0.0,
      };
    }

    // Check if this is the first trip and deduct advance payment if applicable
    final orderRef = _firestore.collection('PENDING_ORDERS').doc(orderId);
    final orderDoc = await orderRef.get();
    double? advanceAmountDeducted;
    
    if (orderDoc.exists) {
      final orderData = orderDoc.data();
      final totalScheduledTrips = (orderData?['totalScheduledTrips'] as num?)?.toInt() ?? 0;
      final advanceAmount = (orderData?['advanceAmount'] as num?)?.toDouble();
      
      // If this is the first trip (totalScheduledTrips === 0) and order has advance payment
      if (totalScheduledTrips == 0 && advanceAmount != null && advanceAmount > 0) {
        final currentTotal = (tripPricing['total'] as num?)?.toDouble() ?? 0.0;
        // Deduct advance amount from trip total (ensure it doesn't go negative)
        final newTotal = (currentTotal - advanceAmount).clamp(0.0, double.infinity);
        advanceAmountDeducted = currentTotal - newTotal; // Store how much was actually deducted
        
        // Update tripPricing total
        tripPricing = {
          ...tripPricing,
          'total': newTotal,
          'advanceAmountDeducted': advanceAmountDeducted, // Store for reference
        };
        
        // Also update item-level trip totals proportionally
        if (tripItems.isNotEmpty && currentTotal > 0 && advanceAmountDeducted > 0) {
          final reductionRatio = newTotal / currentTotal;
          tripItems = tripItems.map((item) {
            if (item is Map<String, dynamic>) {
              final itemTotal = (item['tripTotal'] as num?)?.toDouble() ?? 0.0;
              return {
                ...item,
                'tripTotal': (itemTotal * reductionRatio).clamp(0.0, double.infinity),
              };
            }
            return item;
          }).toList();
        }
      }
    }

    final docRef = _firestore.collection(_collection).doc();
    
    await docRef.set({
      'scheduleTripId': scheduleTripId,
      'orderId': orderId,
      'organizationId': organizationId,
      'clientId': clientId,
      'clientName': clientName,
      'clientPhone': _normalizePhone(clientPhone ?? customerNumber),
      'customerNumber': customerNumber,
      'paymentType': paymentType,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'scheduledDay': scheduledDay,
      'vehicleId': vehicleId,
      'vehicleNumber': vehicleNumber,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'slot': slot,
      'slotName': slotName,
      'deliveryZone': deliveryZone,
      'items': tripItems, // Items with trip-specific pricing
      'tripPricing': tripPricing, // Trip-specific pricing (subtotal, gstAmount, total)
      'pricing': pricing, // keep order pricing snapshot if needed
      'includeGstInTotal': includeGstInTotal,
      'priority': priority,
      'tripStatus': 'scheduled',
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Append tripId to order (lightweight ref list), and bump counts
        // Note: totalScheduledTrips is updated by Cloud Function (onScheduledTripCreated)
        // We only update tripIds here for quick reference
        // Reuse orderRef that was already fetched above
        await _firestore.runTransaction((txn) async {
          final snap = await txn.get(orderRef);
          if (!snap.exists) return;
          final data = snap.data() as Map<String, dynamic>;
          final tripIds = List<String>.from(data['tripIds'] as List<dynamic>? ?? []);
          if (!tripIds.contains(docRef.id)) {
            tripIds.add(docRef.id);
          }
          // DO NOT increment totalScheduledTrips here - Cloud Function handles it
          txn.update(orderRef, {
            'tripIds': tripIds,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });

    return docRef.id;
  }

  /// Update trip with reschedule reason before deleting
  Future<void> updateTripRescheduleReason({
    required String tripId,
    required String reason,
  }) async {
    await _firestore.collection(_collection).doc(tripId).update({
      'rescheduleReason': reason,
      'rescheduledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete a scheduled trip (for cancellation)
  Future<void> deleteScheduledTrip(String tripId) async {
    final docRef = _firestore.collection(_collection).doc(tripId);
    final snap = await docRef.get();
    if (snap.exists) {
      final data = snap.data() as Map<String, dynamic>;
      final orderId = data['orderId'] as String?;
      await docRef.delete();

      // Remove tripId from order refs
      // Note: totalScheduledTrips is updated by Cloud Function (onScheduledTripDeleted)
      if (orderId != null) {
        final orderRef = _firestore.collection('PENDING_ORDERS').doc(orderId);
        await _firestore.runTransaction((txn) async {
          final orderSnap = await txn.get(orderRef);
          if (!orderSnap.exists) return;
          final orderData = orderSnap.data() as Map<String, dynamic>;
          final tripIds = List<String>.from(orderData['tripIds'] as List<dynamic>? ?? []);
          tripIds.remove(tripId);
          // DO NOT decrement totalScheduledTrips here - Cloud Function handles it
          txn.update(orderRef, {
            'tripIds': tripIds,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
      }
    }
  }

  /// Get scheduled trips for a specific day and vehicle
  Future<List<Map<String, dynamic>>> getScheduledTripsForDayAndVehicle({
    required String organizationId,
    required String scheduledDay,
    required DateTime scheduledDate,
    required String vehicleId,
  }) async {
    final startOfDay = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection(_collection)
        .where('organizationId', isEqualTo: organizationId)
        .where('scheduledDay', isEqualTo: scheduledDay)
        .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
        .where('vehicleId', isEqualTo: vehicleId)
        .get();
    
    // Filter by tripStatus in memory to avoid complex index
    final filteredDocs = snapshot.docs.where((doc) {
      final status = doc.data()['tripStatus'] as String?;
      return status == 'scheduled' || status == 'in_progress';
    }).toList();

    return filteredDocs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        ...data,
      };
    }).toList();
  }

  /// Get scheduled trips for an order
  Future<List<Map<String, dynamic>>> getScheduledTripsForOrder(String orderId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('orderId', isEqualTo: orderId)
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

  /// Update trip status
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
    List<Map<String, dynamic>>? paymentDetails,
    double? totalPaidOnReturn,
    String? paymentStatus,
    double? remainingAmount,
    List<String>? returnTransactions,
    bool clearPaymentInfo = false,
  }) async {
    final updateData = <String, dynamic>{
      'tripStatus': tripStatus,
      'orderStatus': tripStatus, // Keep both for compatibility
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (completedAt != null) {
      updateData['completedAt'] = Timestamp.fromDate(completedAt);
    }

    if (cancelledAt != null) {
      updateData['cancelledAt'] = Timestamp.fromDate(cancelledAt);
    }

    if (initialReading != null) {
      updateData['initialReading'] = initialReading;
      updateData['dispatchedAt'] = FieldValue.serverTimestamp();
    }

    if (deliveryPhotoUrl != null) {
      updateData['deliveryPhotoUrl'] = deliveryPhotoUrl;
      updateData['deliveredAt'] = FieldValue.serverTimestamp();
      if (deliveredBy != null) {
        updateData['deliveredBy'] = deliveredBy;
      }
      if (deliveredByRole != null) {
        updateData['deliveredByRole'] = deliveredByRole;
      }
    }

    if (finalReading != null) {
      updateData['finalReading'] = finalReading;
      updateData['returnedAt'] = FieldValue.serverTimestamp();
      if (distanceTravelled != null) {
        updateData['distanceTravelled'] = distanceTravelled;
      }
      if (returnedBy != null) {
        updateData['returnedBy'] = returnedBy;
      }
      if (returnedByRole != null) {
        updateData['returnedByRole'] = returnedByRole;
      }
    }

    // Payment info (for return payments)
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

    // If reverting from dispatched, remove dispatch-related fields
    if (tripStatus == 'scheduled' || tripStatus == 'pending') {
      updateData['initialReading'] = FieldValue.delete();
      updateData['dispatchedAt'] = FieldValue.delete();
      updateData['dispatchedBy'] = FieldValue.delete();
      updateData['dispatchedByRole'] = FieldValue.delete();
    }

    // If reverting from delivered, remove delivery-related fields
    if (tripStatus == 'scheduled' || tripStatus == 'pending' || tripStatus == 'dispatched') {
      updateData['deliveryPhotoUrl'] = FieldValue.delete();
      updateData['deliveredAt'] = FieldValue.delete();
      updateData['deliveredBy'] = FieldValue.delete();
      updateData['deliveredByRole'] = FieldValue.delete();
    }

    // If reverting from returned, remove return-related fields
    if (tripStatus == 'scheduled' || tripStatus == 'pending' || tripStatus == 'dispatched' || tripStatus == 'delivered') {
      updateData['finalReading'] = FieldValue.delete();
      updateData['returnedAt'] = FieldValue.delete();
      updateData['distanceTravelled'] = FieldValue.delete();
      updateData['returnedBy'] = FieldValue.delete();
      updateData['returnedByRole'] = FieldValue.delete();
    }

    await _firestore.collection(_collection).doc(tripId).update(updateData);
  }

  /// Watch scheduled trips for a specific date
  Stream<List<Map<String, dynamic>>> watchScheduledTripsForDate({
    required String organizationId,
    required DateTime scheduledDate,
  }) {
    final startOfDay = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _firestore
        .collection(_collection)
        .where('organizationId', isEqualTo: organizationId)
        .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) {
      final trips = snapshot.docs.map((doc) {
        final data = doc.data();
        // Convert Firestore Timestamp to DateTime for proper serialization
        // This matches the web app implementation and ensures compatibility with cloud functions
        final convertedData = <String, dynamic>{
          'id': doc.id,
        };
        
        // Convert all Timestamp fields to DateTime
        data.forEach((key, value) {
          if (value is Timestamp) {
            convertedData[key] = value.toDate();
          } else {
            convertedData[key] = value;
          }
        });
        
        return convertedData;
      }).toList();
      
      // Sort by slot
      trips.sort((a, b) {
        final slotA = a['slot'] as int? ?? 0;
        final slotB = b['slot'] as int? ?? 0;
        return slotA.compareTo(slotB);
      });
      
      return trips;
    });
  }

  String _normalizePhone(String input) {
    return input.replaceAll(RegExp(r'[^0-9+]'), '');
  }
}

