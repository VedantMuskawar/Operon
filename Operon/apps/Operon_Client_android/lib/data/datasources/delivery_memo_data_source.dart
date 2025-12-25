import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryMemoDataSource {
  DeliveryMemoDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _organizationsCollection = 'ORGANIZATIONS';
  static const String _scheduleTripsCollection = 'SCHEDULE_TRIPS';
  static const String _fyCollection = 'DM';

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

  /// Generate DM: stamp dmNumber/dmId on the trip; no DELIVERY_MEMOS document
  Future<String> generateDM({
    required String organizationId,
    required String tripId,
    required String scheduleTripId,
    required Map<String, dynamic> tripData,
    required String generatedBy,
  }) async {
    // If already set, return existing
    final tripRef = _firestore.collection(_scheduleTripsCollection).doc(tripId);
    final tripSnap = await tripRef.get();
    if (tripSnap.exists) {
      final data = tripSnap.data() as Map<String, dynamic>;
      if (data['dmNumber'] != null) {
        return data['dmId'] as String? ?? 'DM-${data['dmNumber']}';
      }
    }

    // Compute next DM number using org FY counter
    final scheduledDate = (tripData['scheduledDate'] as Timestamp).toDate();
    final financialYear = _getFinancialYear(scheduledDate);
    final fyRef = _firestore
        .collection(_organizationsCollection)
        .doc(organizationId)
        .collection(_fyCollection)
        .doc(financialYear);

    return await _firestore.runTransaction((txn) async {
      final fySnap = await txn.get(fyRef);
      int currentDMNumber = 0;
      if (fySnap.exists) {
        currentDMNumber = (fySnap.data()?['currentDMNumber'] as num?)?.toInt() ?? 0;
    } else {
        txn.set(fyRef, {
          'currentDMNumber': 0,
          'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      final newDMNumber = currentDMNumber + 1;
      final dmIdValue = 'DM/$financialYear/$newDMNumber';

      txn.update(fyRef, {
        'currentDMNumber': newDMNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      txn.update(tripRef, {
        'dmNumber': newDMNumber,
        'dmId': dmIdValue,
        'dmGeneratedAt': FieldValue.serverTimestamp(),
        'dmGeneratedBy': generatedBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return dmIdValue;
    });
  }

  /// Cancel DM: Remove DM fields from trip document
  /// Note: DM numbers are NOT reused - the counter continues incrementing
  /// This allows cancelled DM numbers to serve as audit trail records
  Future<void> cancelDM({
    required String tripId,
    required String cancelledBy,
  }) async {
    final tripRef = _firestore.collection(_scheduleTripsCollection).doc(tripId);
    
    // Check if trip exists and has DM
    final tripSnap = await tripRef.get();
    if (!tripSnap.exists) {
      throw Exception('Trip not found');
    }

    final tripData = tripSnap.data();
    if (tripData == null || tripData['dmNumber'] == null) {
      throw Exception('No DM found for this trip');
    }

    // Remove DM fields from trip
    await tripRef.update({
        'dmNumber': FieldValue.delete(),
        'dmId': FieldValue.delete(),
      'dmGeneratedAt': FieldValue.delete(),
      'dmGeneratedBy': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
  }

  String _getFinancialYear(DateTime date) {
    final year = date.month >= 4 ? date.year : date.year - 1;
    final nextYear = year + 1;
    final startShort = (year % 100).toString().padLeft(2, '0');
    final endShort = (nextYear % 100).toString().padLeft(2, '0');
    return 'FY$startShort$endShort';
  }
}

