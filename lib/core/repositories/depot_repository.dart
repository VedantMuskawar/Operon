import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_constants.dart';
import '../models/depot_location.dart';

class DepotRepository {
  DepotRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String orgId) {
    return _firestore
        .collection(AppConstants.organizationsCollection)
        .doc(orgId)
        .collection(AppConstants.depotsSubcollection);
  }

  Future<DepotLocation?> fetchPrimaryDepot(String orgId) async {
    final querySnapshot = await _collection(orgId)
        .orderBy('updatedAt', descending: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return null;
    }

    final doc = querySnapshot.docs.first;
    return DepotLocation.fromDocument(doc.id, doc.data());
  }

  Future<DepotLocation?> fetchDepotById(
    String orgId,
    String depotId,
  ) async {
    final docSnapshot = await _collection(orgId).doc(depotId).get();
    if (!docSnapshot.exists || docSnapshot.data() == null) {
      return null;
    }

    return DepotLocation.fromDocument(depotId, docSnapshot.data()!);
  }

  Future<DepotLocation> saveDepot(
    String orgId,
    DepotLocation depot,
  ) async {
    final collection = _collection(orgId);
    final docId = depot.depotId.isEmpty ? 'primary' : depot.depotId;
    final docRef = collection.doc(docId);
    final now = DateTime.now();

    final payload = depot.copyWith(
      depotId: docId,
      updatedAt: now,
    );

    await docRef.set(payload.toMap());
    return payload;
  }

  Future<void> deleteDepot(String orgId, String depotId) async {
    await _collection(orgId).doc(depotId).delete();
  }
}


