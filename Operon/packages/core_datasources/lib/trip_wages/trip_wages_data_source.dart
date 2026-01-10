import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_models/core_models.dart';

class TripWagesDataSource {
  TripWagesDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _collection = 'TRIP_WAGES';

  CollectionReference<Map<String, dynamic>> get _tripWagesRef =>
      _firestore.collection(_collection);

  Future<String> createTripWage(TripWage tripWage) async {
    try {
      final tripWageJson = tripWage.toJson();
      tripWageJson['createdAt'] = FieldValue.serverTimestamp();
      tripWageJson['updatedAt'] = FieldValue.serverTimestamp();

      final docRef = _tripWagesRef.doc();
      await docRef.set(tripWageJson);
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create trip wage: $e');
    }
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
      final doc = await _tripWagesRef.doc(tripWageId).get();
      if (!doc.exists) {
        return null;
      }
      return TripWage.fromJson(doc.data()!, doc.id);
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
      return TripWage.fromJson(doc.data(), doc.id);
    } catch (e) {
      throw Exception('Failed to fetch trip wage by DM ID: $e');
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
      await _tripWagesRef.doc(tripWageId).delete();
    } catch (e) {
      throw Exception('Failed to delete trip wage: $e');
    }
  }
}

