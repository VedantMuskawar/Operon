import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_constants.dart';
import '../models/dm_template.dart';

class DmTemplateRepository {
  DmTemplateRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String organizationId) {
    return _firestore
        .collection(AppConstants.organizationsCollection)
        .doc(organizationId)
        .collection(AppConstants.dmTemplatesSubcollection);
  }

  Future<DmTemplate?> fetchTemplate({
    required String organizationId,
    String templateId = 'default',
  }) async {
    final snapshot = await _collection(organizationId).doc(templateId).get();
    if (!snapshot.exists) {
      return null;
    }
    return DmTemplate.fromFirestore(snapshot);
  }

  Stream<DmTemplate?> watchTemplate({
    required String organizationId,
    String templateId = 'default',
  }) {
    return _collection(organizationId).doc(templateId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return DmTemplate.fromFirestore(doc);
    });
  }

  Future<void> saveTemplate(DmTemplate template) async {
    final docRef =
        _collection(template.organizationId).doc(template.id.isEmpty ? 'default' : template.id);
    await docRef.set(
      template.toFirestore(),
      SetOptions(merge: true),
    );
  }

  Future<void> deleteTemplate({
    required String organizationId,
    required String templateId,
  }) {
    return _collection(organizationId).doc(templateId).delete();
  }
}


