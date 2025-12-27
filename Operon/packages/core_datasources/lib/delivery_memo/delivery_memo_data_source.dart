import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class DeliveryMemoDataSource {
  DeliveryMemoDataSource({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

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
      final callable = _functions.httpsCallable('generateDM');
      
      // Serialize tripData: Convert all Timestamp objects to serializable format
      // The cloud_functions package requires JSON-serializable data
      final serializedTripData = _serializeMap(Map<String, dynamic>.from(tripData));

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
}

