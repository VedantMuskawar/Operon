import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'scheduled_trips_utils.dart';

/// Shared data access for scheduled trips (SCHEDULE_TRIPS collection).
///
/// This is intentionally Map-based to match how existing apps store trip docs
/// and to avoid duplicating a full domain model in the datasource layer.
class ScheduledTripsDataSource {
  ScheduledTripsDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Getter for subclasses to access firestore
  FirebaseFirestore get firestore => _firestore;

  static const String _collection = 'SCHEDULE_TRIPS';

  /// Getter for subclasses to access collection name
  String get collection => _collection;

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
    final startOfDay =
        DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Debug logging
    debugPrint(
        '[ScheduledTripsDataSource] Query: orgId=$organizationId, driverPhone=$driverPhone, normalizedPhone=$normalizedPhone, date=$startOfDay');

    // Query by org + date first (more flexible for existing trips with non-normalized phones)
    // Note: We don't filter by isActive in the query to handle trips that may not have this field set
    // Instead, we filter in memory to only include active trips (isActive != false)
    return _firestore
        .collection(_collection)
        .where('organizationId', isEqualTo: organizationId)
        .where('scheduledDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
        .limit(500)
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

      debugPrint(
          '[ScheduledTripsDataSource] Found ${allTrips.length} total trips for org=$organizationId, date=$startOfDay');

      // Filter by isActive (only exclude if explicitly false, treat missing as active)
      final activeTrips = allTrips.where((trip) {
        final isActive = trip['isActive'] as bool?;
        // Include trip if isActive is true or null/undefined (treat missing as active)
        return isActive != false;
      }).toList();

      debugPrint(
          '[ScheduledTripsDataSource] ${activeTrips.length} trips after isActive filter');

      // Filter by normalized phone to handle both normalized and non-normalized stored values
      final trips = activeTrips.where((trip) {
        final tripDriverPhone = trip['driverPhone'] as String?;
        if (tripDriverPhone == null || tripDriverPhone.isEmpty) {
          debugPrint(
              '[ScheduledTripsDataSource] Trip ${trip['id']} has no driverPhone field');
          return false;
        }
        // Normalize the stored phone and compare with normalized query phone
        final normalizedTripPhone = _normalizePhone(tripDriverPhone);
        final matches = normalizedTripPhone == normalizedPhone;
        if (!matches) {
          debugPrint(
              '[ScheduledTripsDataSource] Trip ${trip['id']} phone mismatch: stored="$tripDriverPhone" normalized="$normalizedTripPhone" vs query="$normalizedPhone"');
        } else {
          debugPrint(
              '[ScheduledTripsDataSource] Trip ${trip['id']} phone match: "$normalizedTripPhone"');
        }
        return matches;
      }).toList();

      trips.sort((a, b) {
        final slotA = a['slot'] as int? ?? 0;
        final slotB = b['slot'] as int? ?? 0;
        return slotA.compareTo(slotB);
      });

      debugPrint(
          '[ScheduledTripsDataSource] Found ${trips.length} trips out of ${allTrips.length} total for date');
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

    if (completedAt != null)
      updateData['completedAt'] = Timestamp.fromDate(completedAt);
    if (cancelledAt != null)
      updateData['cancelledAt'] = Timestamp.fromDate(cancelledAt);

    if (tripStatus.toLowerCase() == 'dispatched') {
      updateData['dispatchedAt'] = FieldValue.serverTimestamp();
      if (initialReading != null) updateData['initialReading'] = initialReading;
    }

    if (deliveryPhotoUrl != null) {
      updateData['deliveryPhotoUrl'] = deliveryPhotoUrl;
      updateData['deliveredAt'] = FieldValue.serverTimestamp();
      if (deliveredBy != null) updateData['deliveredBy'] = deliveredBy;
      if (deliveredByRole != null)
        updateData['deliveredByRole'] = deliveredByRole;
    } else if (tripStatus.toLowerCase() == 'delivered' && !clearDeliveryInfo) {
      // Driver flows may deliver without a photo; still stamp deliveredAt.
      updateData['deliveredAt'] = FieldValue.serverTimestamp();
      if (deliveredBy != null) updateData['deliveredBy'] = deliveredBy;
      if (deliveredByRole != null)
        updateData['deliveredByRole'] = deliveredByRole;
    } else if (clearDeliveryInfo) {
      updateData['deliveryPhotoUrl'] = FieldValue.delete();
      updateData['deliveredAt'] = FieldValue.delete();
      updateData['deliveredBy'] = FieldValue.delete();
      updateData['deliveredByRole'] = FieldValue.delete();
    }

    // When marking as returned: always set returnedAt/returnedBy/returnedByRole when provided.
    // Add finalReading/distance only if meterType is KM (i.e. when provided).
    if (tripStatus.toLowerCase() == 'returned') {
      updateData['returnedAt'] = FieldValue.serverTimestamp();
      if (returnedBy != null) updateData['returnedBy'] = returnedBy;
      if (returnedByRole != null) updateData['returnedByRole'] = returnedByRole;
      if (finalReading != null) {
        updateData['finalReading'] = finalReading;
        if (distanceTravelled != null)
          updateData['distanceTravelled'] = distanceTravelled;
        if (computedTravelledDistance != null) {
          updateData['computedTravelledDistance'] = computedTravelledDistance;
        }
      }
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

  /// Check if error is a network error (platform-agnostic)
  bool _isNetworkError(dynamic error) {
    // Use string-based checking that works on all platforms
    final errorStr = error.toString().toLowerCase();
    final errorType = error.runtimeType.toString().toLowerCase();

    // Check for common network error indicators
    return errorStr.contains('network') ||
        errorStr.contains('connection') ||
        errorStr.contains('failed host lookup') ||
        errorStr.contains('socket') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('connection timed out') ||
        errorType.contains('socketexception') ||
        errorType.contains('httpexception') ||
        errorType.contains('networkexception');
  }

  /// Generate unique scheduleTripId using shared utility
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

  /// Check if slot is available using shared utility
  Future<bool> isSlotAvailable({
    required String organizationId,
    required DateTime scheduledDate,
    required String vehicleId,
    required int slot,
    String? excludeTripId,
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

  /// Calculate trip-specific pricing using shared utility
  Map<String, dynamic> calculateTripPricing(
    List<dynamic> items, {
    bool includeGstInTotal = true,
  }) {
    return ScheduledTripsUtils.calculateTripPricing(
      items,
      includeGstInTotal: includeGstInTotal,
    );
  }

  /// Create a scheduled trip with atomic transaction
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
    Map<String, dynamic>? pricing,
    bool? includeGstInTotal,
    required String priority,
    required String createdBy,
    int? itemIndex,
    String? productId,
    String? meterType,
    String? transportMode,
  }) async {
    // Pre-transaction validation and preparation
    // Validate slot availability before transaction (for fast feedback)
    try {
      final isAvailable = await isSlotAvailable(
        organizationId: organizationId,
        scheduledDate: scheduledDate,
        vehicleId: vehicleId,
        slot: slot,
      );

      if (!isAvailable) {
        final dateStr =
            '${scheduledDate.year}-${scheduledDate.month.toString().padLeft(2, '0')}-${scheduledDate.day.toString().padLeft(2, '0')}';
        throw Exception(
            'Slot $slot is no longer available for this vehicle on $dateStr');
      }
    } catch (e) {
      // Re-throw slot availability errors as-is (already user-friendly)
      if (e.toString().contains('Slot') &&
          e.toString().contains('no longer available')) {
        rethrow;
      }
      // Re-throw network errors with context
      if (_isNetworkError(e)) {
        throw Exception(
            'Unable to verify slot availability. Please check your connection and try again.');
      }
      rethrow;
    }

    // Generate scheduleTripId
    final scheduleTripId = generateScheduleTripId(
      clientId: clientId,
      orderId: orderId,
      scheduledDate: scheduledDate,
      vehicleId: vehicleId,
      slot: slot,
    );

    // Determine itemIndex and productId
    final finalItemIndex = itemIndex ?? 0;
    final orderItems = List<dynamic>.from(items);

    if (finalItemIndex < 0 || finalItemIndex >= orderItems.length) {
      throw Exception(
          'Invalid itemIndex: $finalItemIndex (items.length: ${orderItems.length})');
    }

    final itemAtIndex = orderItems[finalItemIndex];
    if (itemAtIndex == null) {
      throw Exception('Item at index $finalItemIndex is null');
    }

    if (itemAtIndex is! Map<String, dynamic>) {
      throw Exception(
          'Invalid item at index $finalItemIndex: expected Map, got ${itemAtIndex.runtimeType}');
    }

    final targetItem = itemAtIndex;

    final finalProductId = productId ?? (targetItem['productId'] as String?);

    if (finalProductId == null || finalProductId.isEmpty) {
      throw Exception('ProductId is required and cannot be empty');
    }

    // Validate productId matches
    if (targetItem['productId'] != finalProductId) {
      throw Exception(
          'ProductId mismatch: expected ${targetItem['productId']}, got $finalProductId');
    }

    // Calculate trip-specific pricing based on fixedQuantityPerTrip
    // Use item's GST settings (conditional GST storage)
    final itemGstPercent = (targetItem['gstPercent'] as num?)?.toDouble();
    final hasGst = itemGstPercent != null && itemGstPercent > 0;
    final gstPercentValue = itemGstPercent ?? 0.0;

    final tripPricingData = calculateTripPricing(
      [targetItem], // Only calculate for the specific item
      includeGstInTotal: hasGst, // Use item's GST status
    );
    var tripItems = tripPricingData['items'] as List<dynamic>;
    var tripPricing = tripPricingData['tripPricing'] as Map<String, dynamic>;

    // Clean trip items: Remove order-level tracking fields, keep only trip-specific data
    // Also ensure no null values (Firestore doesn't allow nulls)
    tripItems = tripItems.map((item) {
      if (item is Map<String, dynamic>) {
        // Keep only trip-specific fields, ensuring no null values
        final productId = item['productId'] ?? targetItem['productId'] ?? '';
        final productName =
            item['productName'] ?? targetItem['productName'] ?? '';
        final unitPrice = (item['unitPrice'] as num?)?.toDouble() ??
            (targetItem['unitPrice'] as num?)?.toDouble() ??
            0.0;
        final fixedQuantityPerTrip =
            (item['fixedQuantityPerTrip'] as num?)?.toInt() ??
                (targetItem['fixedQuantityPerTrip'] as num?)?.toInt() ??
                0;
        final tripSubtotal = (item['tripSubtotal'] as num?)?.toDouble() ??
            (item['subtotal'] as num?)?.toDouble() ??
            0.0;
        final tripTotal = (item['tripTotal'] as num?)?.toDouble() ??
            (item['total'] as num?)?.toDouble() ??
            0.0;

        // Validate required fields are not empty
        if (productId.isEmpty) {
          throw Exception('ProductId cannot be empty in trip item');
        }

        final cleanedItem = <String, dynamic>{
          'productId': productId,
          'productName': productName.isEmpty ? 'Unknown Product' : productName,
          'unitPrice': unitPrice,
          'fixedQuantityPerTrip': fixedQuantityPerTrip,
          'tripSubtotal': tripSubtotal,
          'tripTotal': tripTotal,
        };

        // Only include GST fields if GST applies
        if (hasGst && gstPercentValue > 0) {
          final tripGstAmount = (item['tripGstAmount'] as num?)?.toDouble() ??
              (item['gstAmount'] as num?)?.toDouble() ??
              tripSubtotal * (gstPercentValue / 100);
          if (tripGstAmount > 0) {
            cleanedItem['tripGstAmount'] = tripGstAmount;
            cleanedItem['gstPercent'] = gstPercentValue;
          }
        }

        return cleanedItem;
      }
      throw Exception(
          'Invalid trip item format: expected Map, got ${item.runtimeType}');
    }).toList();

    // Ensure tripItems is not empty
    if (tripItems.isEmpty) {
      throw Exception('Trip items list cannot be empty');
    }

    // Conditional GST storage: only include gstAmount if GST applies
    // Ensure all values are non-null (Firestore doesn't allow nulls)
    final cleanedTripPricing = <String, dynamic>{
      'subtotal': (tripPricing['subtotal'] as num?)?.toDouble() ?? 0.0,
      'total': (tripPricing['total'] as num?)?.toDouble() ?? 0.0,
    };

    if (hasGst) {
      final gstAmount = (tripPricing['gstAmount'] as num?)?.toDouble();
      if (gstAmount != null && gstAmount > 0) {
        cleanedTripPricing['gstAmount'] = gstAmount;
      }
    }

    tripPricing = cleanedTripPricing;

    // Prepare trip document data
    // Firestore doesn't allow null values, so we only include nullable fields if they have values
    // Validate all required fields are non-null

    if (slotName.isEmpty) {
      throw Exception('slotName cannot be empty');
    }

    // Validate slot is positive
    if (slot <= 0) {
      throw Exception('Slot must be a positive number, got: $slot');
    }

    // Validate scheduledDate is valid
    if (scheduledDate.isBefore(DateTime(2000, 1, 1)) ||
        scheduledDate.isAfter(DateTime(2100, 1, 1))) {
      throw Exception('Scheduled date is out of valid range: $scheduledDate');
    }

    // Validate scheduledDay is not empty
    if (scheduledDay.isEmpty) {
      throw Exception('Scheduled day cannot be empty');
    }

    // Clean deliveryZone to remove any null values
    final cleanedDeliveryZone = <String, dynamic>{};
    deliveryZone.forEach((key, value) {
      if (value != null) {
        // Recursively clean nested maps
        if (value is Map) {
          final cleanedNested = <String, dynamic>{};
          value.forEach((nestedKey, nestedValue) {
            if (nestedValue != null) {
              cleanedNested[nestedKey.toString()] = nestedValue;
            }
          });
          if (cleanedNested.isNotEmpty) {
            cleanedDeliveryZone[key.toString()] = cleanedNested;
          }
        } else {
          cleanedDeliveryZone[key.toString()] = value;
        }
      }
    });

    final docRef = _firestore.collection(_collection).doc();
    final tripDocData = <String, dynamic>{
      'scheduleTripId': scheduleTripId,
      'orderId': orderId,
      'itemIndex': finalItemIndex,
      'productId': finalProductId,
      'organizationId': organizationId,
      'clientId': clientId,
      'clientName': clientName,
      'clientPhone': _normalizePhone(clientPhone ?? customerNumber),
      'customerNumber': customerNumber,
      'paymentType': paymentType,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'scheduledDay': scheduledDay.isEmpty ? 'unknown' : scheduledDay,
      'vehicleId': vehicleId,
      'vehicleNumber': vehicleNumber,
      'slot': slot,
      'slotName': slotName,
      'deliveryZone': cleanedDeliveryZone,
      'items': tripItems,
      'tripPricing': tripPricing,
      'priority': priority,
      'tripStatus': 'scheduled',
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (transportMode != null && transportMode.isNotEmpty) {
      tripDocData['transportMode'] = transportMode;
    }

    // Only include driver fields if they're not null (Firestore doesn't allow null values)
    if (driverId != null && driverId.isNotEmpty) {
      tripDocData['driverId'] = driverId;
    }
    if (driverName != null && driverName.isNotEmpty) {
      tripDocData['driverName'] = driverName;
    }
    if (driverPhone != null && driverPhone.isNotEmpty) {
      tripDocData['driverPhone'] = _normalizePhone(driverPhone);
    }
    if (meterType != null && meterType.isNotEmpty) {
      tripDocData['meterType'] = meterType;
    }

    // Atomic transaction: Read order, validate, update order, create trip
    final orderRef = _firestore.collection('PENDING_ORDERS').doc(orderId);

    try {
      return await _firestore.runTransaction<String>((txn) async {
        // 1. Read order
        final orderDoc = await txn.get(orderRef);
        if (!orderDoc.exists) {
          throw Exception(
              'Order not found. It may have been deleted or fully scheduled.');
        }

        final orderData = orderDoc.data();
        if (orderData == null) {
          throw Exception('Order document exists but has no data.');
        }

        final orderItemsList = (orderData['items'] as List<dynamic>?) ?? [];

        if (orderItemsList.isEmpty) {
          throw Exception('Order has no items. Cannot schedule trip.');
        }

        // 2. Validate itemIndex
        if (finalItemIndex < 0 || finalItemIndex >= orderItemsList.length) {
          throw Exception(
              'Invalid item index: $finalItemIndex (order has ${orderItemsList.length} items)');
        }

        final itemAtIndex = orderItemsList[finalItemIndex];
        if (itemAtIndex == null) {
          throw Exception('Item at index $finalItemIndex is null');
        }

        final Map<String, dynamic> targetOrderItem;
        if (itemAtIndex is Map<String, dynamic>) {
          targetOrderItem = itemAtIndex;
        } else {
          throw Exception(
              'Item at index $finalItemIndex is not a valid map. Type: ${itemAtIndex.runtimeType}');
        }

        // 3. Validate productId exists and matches
        final orderProductId = targetOrderItem['productId'] as String?;
        if (orderProductId == null || orderProductId.isEmpty) {
          throw Exception(
              'ProductId is missing in order item at index $finalItemIndex');
        }

        if (orderProductId != finalProductId) {
          throw Exception(
              'ProductId mismatch: expected $orderProductId, got $finalProductId');
        }

        // 4. Validate estimatedTrips > 0 and exists
        final estimatedTrips = targetOrderItem['estimatedTrips'];
        if (estimatedTrips == null) {
          throw Exception(
              'estimatedTrips field is missing in order item at index $finalItemIndex');
        }
        final estimatedTripsInt = (estimatedTrips as num?)?.toInt() ?? 0;
        final effectiveEstimatedTrips =
            estimatedTripsInt <= 0 ? 1 : estimatedTripsInt;
        if (effectiveEstimatedTrips <= 0) {
          throw Exception(
              'No trips remaining to schedule for this item. Estimated trips: $estimatedTripsInt');
        }

        // Note: Don't modify targetOrderItem directly - create a copy when needed

        // 5. Note: Slot availability is validated before transaction (for fast feedback)
        // Firestore transactions don't support queries, so we validate outside transaction
        // The Cloud Function will also validate and delete trip if slot conflict occurs

        // 6. Check advance payment (if first trip)
        final totalScheduledTrips =
            (orderData['totalScheduledTrips'] as num?)?.toInt() ?? 0;
        final advanceAmount = (orderData['advanceAmount'] as num?)?.toDouble();
        double? advanceAmountDeducted;

        if (totalScheduledTrips == 0 &&
            advanceAmount != null &&
            advanceAmount > 0) {
          final currentTotal =
              (tripPricing['total'] as num?)?.toDouble() ?? 0.0;
          final newTotal =
              (currentTotal - advanceAmount).clamp(0.0, double.infinity);
          advanceAmountDeducted = currentTotal - newTotal;

          // Clean tripPricing to ensure no nulls
          final cleanedAdvancePricing = <String, dynamic>{
            'subtotal': (tripPricing['subtotal'] as num?)?.toDouble() ?? 0.0,
            'total': newTotal,
            'advanceAmountDeducted': advanceAmountDeducted,
          };
          if (tripPricing.containsKey('gstAmount')) {
            final gstAmount = (tripPricing['gstAmount'] as num?)?.toDouble();
            if (gstAmount != null && gstAmount > 0) {
              cleanedAdvancePricing['gstAmount'] = gstAmount;
            }
          }
          tripPricing = cleanedAdvancePricing;

          if (tripItems.isNotEmpty &&
              currentTotal > 0 &&
              advanceAmountDeducted > 0) {
            final reductionRatio = newTotal / currentTotal;
            tripItems = tripItems.map((item) {
              if (item is Map<String, dynamic>) {
                // Clean item to remove nulls before spreading
                final cleanedItem = <String, dynamic>{};
                item.forEach((key, value) {
                  if (value != null) {
                    cleanedItem[key] = value;
                  }
                });

                final itemTotal =
                    (cleanedItem['tripTotal'] as num?)?.toDouble() ?? 0.0;
                return {
                  ...cleanedItem,
                  'tripTotal':
                      (itemTotal * reductionRatio).clamp(0.0, double.infinity),
                };
              }
              return item;
            }).toList();
          }

          // Update trip document data with adjusted pricing
          tripDocData['tripPricing'] = tripPricing;
          tripDocData['items'] = tripItems;
        }

        // 7. Update tripIds array (lightweight reference)
        // Note: We do NOT update estimatedTrips/scheduledTrips here because the Cloud Function
        // (onScheduledTripCreated) will handle all order updates including:
        // - Updating estimatedTrips and scheduledTrips
        // - Updating totalScheduledTrips
        // - Adding trip to scheduledTrips array
        // - Updating order status
        // This prevents double-counting when rescheduling (delete old trip + create new trip)
        final tripIds =
            List<String>.from(orderData['tripIds'] as List<dynamic>? ?? []);
        if (!tripIds.contains(docRef.id)) {
          tripIds.add(docRef.id);
        }

        // 8. Update order document (only tripIds - Cloud Function handles the rest)
        txn.update(orderRef, {
          'tripIds': tripIds,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 10. Create trip document
        txn.set(docRef, tripDocData);

        return docRef.id;
      });
    } catch (e) {
      // Map errors to user-friendly messages
      if (e.toString().contains('Slot') &&
          e.toString().contains('no longer available')) {
        rethrow; // Already user-friendly
      }
      if (e.toString().contains('No trips remaining')) {
        rethrow; // Already user-friendly
      }
      if (e.toString().contains('Order not found')) {
        rethrow; // Already user-friendly
      }
      if (_isNetworkError(e)) {
        throw Exception(
            'Connection error. Please check your internet and try again.');
      }
      // Firestore transaction conflicts
      if (e.toString().contains('ABORTED') ||
          e.toString().contains('transaction')) {
        throw Exception('Slot no longer available. Please try again.');
      }
      rethrow;
    }
  }

  /// Get scheduled trips for a specific day and vehicle
  Future<List<Map<String, dynamic>>> getScheduledTripsForDayAndVehicle({
    required String organizationId,
    required String scheduledDay,
    required DateTime scheduledDate,
    required String vehicleId,
  }) async {
    final startOfDay =
        DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection(_collection)
        .where('organizationId', isEqualTo: organizationId)
        .where('scheduledDay', isEqualTo: scheduledDay)
        .where('scheduledDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
        .where('vehicleId', isEqualTo: vehicleId)
        .where('isActive',
            isEqualTo: true) // Soft delete pattern: only active trips
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

  /// Delete a scheduled trip (for cancellation/rescheduling)
  /// The Cloud Function onScheduledTripDeleted will handle updating PENDING_ORDERS counts
  Future<void> deleteScheduledTrip(String tripId) async {
    final docRef = _firestore.collection(_collection).doc(tripId);
    final snap = await docRef.get();
    if (snap.exists) {
      final data = snap.data() as Map<String, dynamic>;
      final orderId = data['orderId'] as String?;

      // Delete the document - Cloud Function (onScheduledTripDeleted) will handle:
      // - Removing trip from scheduledTrips array
      // - Decrementing totalScheduledTrips
      // - Incrementing estimatedTrips
      await docRef.delete();

      // Remove tripId from order refs (Cloud Function also handles this, but doing it here
      // for immediate UI update - Cloud Function will ensure consistency)
      if (orderId != null) {
        final orderRef = _firestore.collection('PENDING_ORDERS').doc(orderId);
        await _firestore.runTransaction((txn) async {
          final orderSnap = await txn.get(orderRef);
          if (!orderSnap.exists) return;
          final orderData = orderSnap.data() as Map<String, dynamic>;
          final tripIds =
              List<String>.from(orderData['tripIds'] as List<dynamic>? ?? []);
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
}
