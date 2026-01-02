import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class DeliveryMemoDataSource {
  DeliveryMemoDataSource({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? _initializeFunctions();

  static FirebaseFunctions _initializeFunctions() {
    // Match web app initialization exactly
    return FirebaseFunctions.instanceFor(region: 'us-central1');
  }

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  static const String _scheduleTripsCollection = 'SCHEDULE_TRIPS';
  static const String _deliveryMemosCollection = 'DELIVERY_MEMOS';

  /// Check if a DM already exists for a given scheduleTripId
  Future<bool> dmExistsForScheduleTripId(String scheduleTripId) async {
    final tripSnap = await _firestore
        .collection(_scheduleTripsCollection)
        .where('scheduleTripId', isEqualTo: scheduleTripId)
        .limit(1)
        .get();
    if (tripSnap.docs.isEmpty) return false;
    final data = tripSnap.docs.first.data();
    return data['dmNumber'] != null || data['dmId'] != null;
  }

  /// Generate DM: Calls cloud function to generate DM number and create Order Credit transaction
  /// This ensures DM number is stored in Client Ledger and Order Credit transaction is created
  Future<String> generateDM({
    required String organizationId,
    required String tripId,
    required String scheduleTripId,
    required Map<String, dynamic> tripData,
    required String generatedBy,
  }) async {
    try {
      // Check if DM already exists
      final tripRef = _firestore.collection(_scheduleTripsCollection).doc(tripId);
      final tripSnap = await tripRef.get();
      if (tripSnap.exists) {
        final data = tripSnap.data() as Map<String, dynamic>;
        if (data['dmNumber'] != null) {
          return data['dmId'] as String? ?? 'DM-${data['dmNumber']}';
        }
      }

      // Call cloud function to generate DM
      // This will:
      // 1. Generate DM number
      // 2. Update trip with dmNumber
      // 3. Create Order Credit transaction (for pay_later and pay_on_delivery)
      // 4. Store DM number in Client Ledger
      
      // Serialize tripData: Convert all Timestamp objects to serializable format
      // The cloud_functions package requires JSON-serializable data
      final serializedTripData = _serializeMap(Map<String, dynamic>.from(tripData));

      // Call cloud function - matching web app implementation exactly
      final callable = _functions.httpsCallable('generateDM');

      final result = await callable.call({
        'organizationId': organizationId,
        'tripId': tripId,
        'scheduleTripId': scheduleTripId,
        'tripData': serializedTripData,
        'generatedBy': generatedBy,
      });

      final responseData = result.data as Map<String, dynamic>? ?? {};
      
      // Check if DM generation was successful
      if (responseData['success'] == false) {
        throw Exception(responseData['error'] ?? 'Failed to generate DM');
      }

      // Return dmId from response
      return responseData['dmId'] as String? ?? 
             'DM/${responseData['financialYear']}/${responseData['dmNumber']}';
    } catch (e) {
      throw Exception('Failed to generate DM: $e');
    }
  }

  /// Helper method to recursively serialize nested maps
  /// Handles Timestamp, DateTime, nested Maps, and Lists
  Map<String, dynamic> _serializeMap(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    map.forEach((key, value) {
      if (value == null) {
        result[key] = null;
      } else if (value is Timestamp) {
        result[key] = {
          '_seconds': value.seconds,
          '_nanoseconds': value.nanoseconds,
        };
      } else if (value is DateTime) {
        final ts = Timestamp.fromDate(value);
        result[key] = {
          '_seconds': ts.seconds,
          '_nanoseconds': ts.nanoseconds,
        };
      } else if (value is Map) {
        result[key] = _serializeMap(Map<String, dynamic>.from(value));
      } else if (value is List) {
        // Handle lists recursively
        result[key] = value.map((item) {
          if (item is Timestamp) {
            return {
              '_seconds': item.seconds,
              '_nanoseconds': item.nanoseconds,
            };
          } else if (item is DateTime) {
            final ts = Timestamp.fromDate(item);
            return {
              '_seconds': ts.seconds,
              '_nanoseconds': ts.nanoseconds,
            };
          } else if (item is Map) {
            return _serializeMap(Map<String, dynamic>.from(item));
          } else {
            return item;
          }
        }).toList();
      } else {
        // For primitive types (String, num, bool), keep as-is
        result[key] = value;
      }
    });
    return result;
  }

  /// Fetch delivery memos with optional filters
  Stream<List<Map<String, dynamic>>> watchDeliveryMemos({
    required String organizationId,
    String? status, // 'active' or 'cancelled'
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) {
    try {
      developer.log('watchDeliveryMemos called', name: 'DeliveryMemoDataSource');
      developer.log('organizationId: $organizationId', name: 'DeliveryMemoDataSource');
      developer.log('status: $status', name: 'DeliveryMemoDataSource');
      developer.log('startDate: $startDate', name: 'DeliveryMemoDataSource');
      developer.log('endDate: $endDate', name: 'DeliveryMemoDataSource');
      developer.log('limit: $limit', name: 'DeliveryMemoDataSource');
      developer.log('Collection: $_deliveryMemosCollection', name: 'DeliveryMemoDataSource');

      Query<Map<String, dynamic>> query = _firestore
          .collection(_deliveryMemosCollection)
          .where('organizationId', isEqualTo: organizationId);

      developer.log('Base query created', name: 'DeliveryMemoDataSource');

      // Filter by status if provided
      if (status != null) {
        query = query.where('status', isEqualTo: status);
        developer.log('Status filter applied: $status', name: 'DeliveryMemoDataSource');
      }

      // Filter by date range if provided
      if (startDate != null) {
        final startTimestamp = Timestamp.fromDate(startDate);
        query = query.where('scheduledDate', isGreaterThanOrEqualTo: startTimestamp);
        developer.log('Start date filter applied: $startDate', name: 'DeliveryMemoDataSource');
      }
      if (endDate != null) {
        final endTimestamp = Timestamp.fromDate(endDate.add(const Duration(days: 1)));
        query = query.where('scheduledDate', isLessThan: endTimestamp);
        developer.log('End date filter applied: $endDate', name: 'DeliveryMemoDataSource');
      }

      // Order by scheduled date descending (newest first)
      query = query.orderBy('scheduledDate', descending: true);

      // Limit results if specified (default to 20 for recent items)
      if (limit != null && limit > 0) {
        query = query.limit(limit);
        developer.log('Limit applied: $limit', name: 'DeliveryMemoDataSource');
      }

      developer.log('Query built, returning stream', name: 'DeliveryMemoDataSource');

      return query.snapshots().map((snapshot) {
        developer.log('Snapshot received with ${snapshot.docs.length} documents', name: 'DeliveryMemoDataSource');
        final memos = snapshot.docs.map((doc) {
          final data = doc.data();
          return <String, dynamic>{
            'dmId': doc.id,
            ...data,
          };
        }).toList();
        developer.log('Mapped ${memos.length} delivery memos', name: 'DeliveryMemoDataSource');
        return memos;
      }).handleError((error) {
        developer.log('Stream error: $error', name: 'DeliveryMemoDataSource', error: error);
        developer.log('Error type: ${error.runtimeType}', name: 'DeliveryMemoDataSource');
        throw error;
      });
    } catch (e, stackTrace) {
      developer.log('Exception in watchDeliveryMemos: $e', name: 'DeliveryMemoDataSource', error: e, stackTrace: stackTrace);
      throw Exception('Failed to fetch delivery memos: $e');
    }
  }

  /// Cancel DM: Call cloud function to cancel DM
  /// This updates the DM document status to 'cancelled' and removes dmNumber from trip
  Future<void> cancelDM({
    required String tripId,
    String? dmId,
    required String cancelledBy,
    String? cancellationReason,
  }) async {
    try {
      final callable = _functions.httpsCallable('cancelDM');
      final result = await callable.call({
        'tripId': tripId,
        if (dmId != null) 'dmId': dmId,
        'cancelledBy': cancelledBy,
        if (cancellationReason != null) 'cancellationReason': cancellationReason,
      });

      final responseData = result.data as Map<String, dynamic>? ?? {};
      if (responseData['success'] != true) {
        throw Exception(responseData['message'] ?? 'Failed to cancel DM');
      }
    } catch (e) {
      throw Exception('Failed to cancel DM: $e');
    }
  }

  /// Get returned delivery memos for a specific vehicle from past 3 days
  /// Used for fuel voucher trip linking (optional)
  Future<List<Map<String, dynamic>>> getReturnedDMsForVehicle({
    required String organizationId,
    required String vehicleNumber,
  }) async {
    try {
      // Get date 3 days ago for filtering
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
      final threeDaysAgoTimestamp = Timestamp.fromDate(threeDaysAgo);

      // Simplified query: Only use organizationId, status, and vehicleNumber
      // Filter by date in memory to avoid index requirement
      Query<Map<String, dynamic>> query = _firestore
          .collection(_deliveryMemosCollection)
          .where('organizationId', isEqualTo: organizationId)
          .where('status', isEqualTo: 'returned')
          .where('vehicleNumber', isEqualTo: vehicleNumber);

      final snapshot = await query.get();

      // Map documents to data and filter by date in memory
      final results = snapshot.docs.map((doc) {
        final data = doc.data();
        return <String, dynamic>{
          'dmId': doc.id,
          ...data,
        };
      }).where((item) {
        // Filter by date in memory (last 3 days)
        final scheduledDate = item['scheduledDate'];
        if (scheduledDate == null) return false;
        
        Timestamp? ts;
        if (scheduledDate is Timestamp) {
          ts = scheduledDate;
        } else if (scheduledDate is DateTime) {
          ts = Timestamp.fromDate(scheduledDate);
        } else {
          return false;
        }
        
        return ts.compareTo(threeDaysAgoTimestamp) >= 0;
      }).toList();

      // Sort in memory by scheduledDate (descending - newest first)
      results.sort((a, b) {
        final dateA = a['scheduledDate'];
        final dateB = b['scheduledDate'];
        
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        
        Timestamp? tsA;
        Timestamp? tsB;
        
        if (dateA is Timestamp) {
          tsA = dateA;
        } else if (dateA is DateTime) {
          tsA = Timestamp.fromDate(dateA);
        }
        
        if (dateB is Timestamp) {
          tsB = dateB;
        } else if (dateB is DateTime) {
          tsB = Timestamp.fromDate(dateB);
        }
        
        if (tsA == null && tsB == null) return 0;
        if (tsA == null) return 1;
        if (tsB == null) return -1;
        
        // Descending order (newest first)
        return tsB.compareTo(tsA);
      });

      return results;
    } catch (e) {
      throw Exception('Failed to fetch returned DMs for vehicle: $e');
    }
  }

  /// Update multiple delivery memos with fuel voucher ID (batch update)
  Future<void> updateMultipleDMsWithFuelVoucher({
    required List<String> dmIds,
    required String fuelVoucherId,
  }) async {
    try {
      final batch = _firestore.batch();
      for (final dmId in dmIds) {
        final dmRef = _firestore.collection(_deliveryMemosCollection).doc(dmId);
        batch.update(dmRef, {
          'fuelVoucherId': fuelVoucherId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to update delivery memos with fuel voucher: $e');
    }
  }

  /// Update a single delivery memo with fuel voucher ID
  Future<void> updateDeliveryMemoWithFuelVoucher({
    required String dmId,
    required String fuelVoucherId,
  }) async {
    try {
      await _firestore.collection(_deliveryMemosCollection).doc(dmId).update({
        'fuelVoucherId': fuelVoucherId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update delivery memo with fuel voucher: $e');
    }
  }
}

