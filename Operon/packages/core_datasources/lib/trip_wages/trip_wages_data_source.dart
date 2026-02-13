import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:core_models/core_models.dart';

class TripWagesDataSource {
  TripWagesDataSource({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? _initializeFunctions();

  static FirebaseFunctions _initializeFunctions() {
    // Must match functions region (asia-south1) in functions/src/shared/function-config.ts
    return FirebaseFunctions.instanceFor(region: 'asia-south1');
  }

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  static const String _collection = 'TRIP_WAGES';

  CollectionReference<Map<String, dynamic>> get _tripWagesRef =>
      _firestore.collection(_collection);

  Future<String> createTripWage(TripWage tripWage) async {
    try {
      final docRef = _tripWagesRef.doc();
      final tripWageId = docRef.id;
      
      final tripWageJson = tripWage.toJson();
      // Ensure tripWageId is set to the document ID
      tripWageJson['tripWageId'] = tripWageId;
      tripWageJson['createdAt'] = FieldValue.serverTimestamp();
      tripWageJson['updatedAt'] = FieldValue.serverTimestamp();

      await docRef.set(tripWageJson);
      return tripWageId;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return _createTripWageViaFunction(tripWage);
      }
      throw Exception('Failed to create trip wage: $e');
    } catch (e) {
      throw Exception('Failed to create trip wage: $e');
    }
  }

  Future<String> _createTripWageViaFunction(TripWage tripWage) async {
    try {
      final tripWageJson = tripWage.toJson();
      tripWageJson['tripWageId'] = null;
      tripWageJson.remove('createdAt');
      tripWageJson.remove('updatedAt');

      final callable = _functions.httpsCallable('createTripWage');
      final result = await callable.call({
        'tripWage': _serializeMap(Map<String, dynamic>.from(tripWageJson)),
      });

      final responseData = result.data as Map<String, dynamic>? ?? {};
      final tripWageId = responseData['tripWageId'] as String?;
      if (tripWageId == null || tripWageId.isEmpty) {
        throw Exception('Trip wage creation failed: missing tripWageId');
      }
      return tripWageId;
    } on FirebaseFunctionsException catch (e) {
      final errorCode = e.code;
      final errorMessage = e.message ?? 'Unknown error';
      
      final userFriendlyMessage = _getHTTPSErrorMessage(errorCode, errorMessage);
      throw Exception('Failed to create trip wage: $userFriendlyMessage');
    } catch (e) {
      throw Exception('Failed to create trip wage via function: $e');
    }
  }

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
          }
          return item;
        }).toList();
      } else {
        result[key] = value;
      }
    });
    return result;
  }

  Future<List<TripWage>> fetchTripWages(
    String organizationId, {
    TripWageStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? methodId,
    String? dmId,
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _tripWagesRef
          .where('organizationId', isEqualTo: organizationId);

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      if (methodId != null) {
        query = query.where('methodId', isEqualTo: methodId);
      }

      if (dmId != null) {
        query = query.where('dmId', isEqualTo: dmId);
      }

      if (startDate != null) {
        query = query.where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        final endTimestamp = Timestamp.fromDate(
            endDate.add(const Duration(days: 1)));
        query = query.where('createdAt', isLessThan: endTimestamp);
      }

      query = query.orderBy('createdAt', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => TripWage.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch trip wages: $e');
    }
  }

  Stream<List<TripWage>> watchTripWages(
    String organizationId, {
    TripWageStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? methodId,
    String? dmId,
    int? limit,
  }) {
    Query<Map<String, dynamic>> query = _tripWagesRef
        .where('organizationId', isEqualTo: organizationId);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    if (methodId != null) {
      query = query.where('methodId', isEqualTo: methodId);
    }

    if (dmId != null) {
      query = query.where('dmId', isEqualTo: dmId);
    }

    if (startDate != null) {
      query = query.where('createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    if (endDate != null) {
      final endTimestamp = Timestamp.fromDate(
          endDate.add(const Duration(days: 1)));
      query = query.where('createdAt', isLessThan: endTimestamp);
    }

    query = query.orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => TripWage.fromJson(doc.data(), doc.id))
          .toList();
    });
  }

  Future<TripWage?> getTripWage(String tripWageId) async {
    try {
      if (tripWageId.isEmpty) {
        throw Exception('Trip wage ID cannot be empty');
      }
      final doc = await _tripWagesRef.doc(tripWageId).get();
      if (!doc.exists) {
        return null;
      }
      final tripWage = TripWage.fromJson(doc.data()!, doc.id);
      // If tripWageId in document is empty, update it to the document ID
      if (tripWage.tripWageId.isEmpty || tripWage.tripWageId != doc.id) {
        await _tripWagesRef.doc(doc.id).update({'tripWageId': doc.id});
        // Return updated trip wage with correct tripWageId
        return tripWage.copyWith(tripWageId: doc.id);
      }
      return tripWage;
    } catch (e) {
      throw Exception('Failed to get trip wage: $e');
    }
  }

  Future<TripWage?> fetchTripWageByDmId(String dmId) async {
    try {
      final snapshot = await _tripWagesRef
          .where('dmId', isEqualTo: dmId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final doc = snapshot.docs.first;
      final tripWage = TripWage.fromJson(doc.data(), doc.id);
      // If tripWageId in document is empty, update it to the document ID
      if (tripWage.tripWageId.isEmpty || tripWage.tripWageId != doc.id) {
        await _tripWagesRef.doc(doc.id).update({'tripWageId': doc.id});
        // Return updated trip wage with correct tripWageId
        return tripWage.copyWith(tripWageId: doc.id);
      }
      return tripWage;
    } catch (e) {
      throw Exception('Failed to fetch trip wage by DM ID: $e');
    }
  }

  /// Fetch multiple trip wages by DM IDs in batches (CRITICAL PERFORMANCE METHOD)
  /// Reduces N+1 query problem: instead of 50 queries (one per DM),
  /// this fetches all trip wages in 5 batches (10 DMs per batch)
  /// 
  /// Example: 50 DMs with trip wages = 51 reads (1 DM fetch + 50 wage queries)
  /// vs 6 reads with this method (1 DM fetch + 5 batch wage queries)
  Future<Map<String, TripWage>> fetchTripWagesByDmIds(
    String organizationId,
    List<String> dmIds,
  ) async {
    if (dmIds.isEmpty) return {};

    try {
      final results = <String, TripWage>{};
      
      // Firestore allows max 10 conditions in a single query
      // Batch DM IDs into chunks of 10
      for (int i = 0; i < dmIds.length; i += 10) {
        final endIndex = (i + 10 <= dmIds.length) ? i + 10 : dmIds.length;
        final chunk = dmIds.sublist(i, endIndex);

        final snapshot = await _tripWagesRef
            .where('organizationId', isEqualTo: organizationId)
            .where('dmId', whereIn: chunk)
            .get();

        for (final doc in snapshot.docs) {
          final tripWage = TripWage.fromJson(doc.data(), doc.id);
          // Ensure tripWageId matches document ID
          if (tripWage.tripWageId.isEmpty || tripWage.tripWageId != doc.id) {
            await _tripWagesRef.doc(doc.id).update({'tripWageId': doc.id});
            results[tripWage.dmId] = tripWage.copyWith(tripWageId: doc.id);
          } else {
            results[tripWage.dmId] = tripWage;
          }
        }
      }

      return results;
    } catch (e) {
      throw Exception('Failed to fetch trip wages by DM IDs: $e');
    }
  }

  Future<void> updateTripWage(
    String tripWageId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _tripWagesRef.doc(tripWageId).update(updates);
    } catch (e) {
      throw Exception('Failed to update trip wage: $e');
    }
  }

  Future<void> deleteTripWage(String tripWageId) async {
    try {
      if (tripWageId.isEmpty) {
        throw Exception('Trip wage ID cannot be empty');
      }
      
      // Try direct Firestore delete first
      try {
        await _tripWagesRef.doc(tripWageId).delete();
        return;
      } on FirebaseException catch (e) {
        // If permission denied, fall back to Cloud Function with admin privileges
        if (e.code == 'permission-denied') {
          await _deleteTripWageViaFunction(tripWageId);
          return;
        }
        // For other Firestore errors, also try Cloud Function as fallback
        if (e.code == 'internal' || e.code == 'unavailable') {
          await _deleteTripWageViaFunction(tripWageId);
          return;
        }
        // If document doesn't exist, that's fine - consider it deleted
        if (e.code == 'not-found') {
          return;
        }
        // Re-throw other Firestore errors
        throw Exception('Firestore error: ${e.code} - ${e.message}');
      }
    } catch (e) {
      throw Exception('Failed to delete trip wage: $e');
    }
  }

  Future<void> _deleteTripWageViaFunction(String tripWageId) async {
    try {
      final callable = _functions.httpsCallable('deleteTripWage');
      await callable.call({
        'tripWageId': tripWageId,
      });
    } on FirebaseFunctionsException catch (e) {
      final errorCode = e.code;
      final errorMessage = e.message ?? 'Unknown error';
      
      final userFriendlyMessage = _getHTTPSErrorMessage(errorCode, errorMessage);
      throw Exception('Failed to delete trip wage: $userFriendlyMessage');
    } catch (e) {
      throw Exception('Failed to delete trip wage via function: $e');
    }
  }

  /// Helper method to convert Firebase HTTPS error codes to user-friendly messages
  String _getHTTPSErrorMessage(String errorCode, String errorMessage) {
    switch (errorCode) {
      case 'invalid-argument':
        return 'Invalid data: $errorMessage. Please check the trip wage details.';
      case 'not-found':
        return 'Trip wage not found. It may have already been deleted.';
      case 'failed-precondition':
        return 'Cannot complete this operation: $errorMessage';
      case 'unauthenticated':
        return 'Authentication required. Please log in again.';
      case 'permission-denied':
        return 'You do not have permission to perform this action.';
      case 'internal':
        return 'An internal server error occurred. Please try again later.';
      case 'unavailable':
        return 'The service is temporarily unavailable. Please try again later.';
      case 'deadline-exceeded':
        return 'Request took too long. Please try again.';
      default:
        return 'Error: $errorMessage';
    }
  }
}

