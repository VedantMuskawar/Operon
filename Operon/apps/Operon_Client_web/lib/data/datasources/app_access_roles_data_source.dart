import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dash_web/domain/entities/app_access_role.dart';

class AppAccessRolesDataSource {
  AppAccessRolesDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _appAccessRolesRef(String orgId) {
    return _firestore
        .collection('ORGANIZATIONS')
        .doc(orgId)
        .collection('APP_ACCESS_ROLES');
  }

  Future<List<AppAccessRole>> fetchAppAccessRoles(String orgId) async {
    final snapshot = await _appAccessRolesRef(orgId).orderBy('name').get();
    return snapshot.docs
        .map((doc) => AppAccessRole.fromJson(doc.data(), doc.id))
        .toList();
  }

  Future<AppAccessRole?> fetchAppAccessRole(String orgId, String roleId) async {
    final doc = await _appAccessRolesRef(orgId).doc(roleId).get();
    if (!doc.exists) return null;
    return AppAccessRole.fromJson(doc.data()!, doc.id);
  }

  Future<void> createAppAccessRole(String orgId, AppAccessRole role) async {
    await _appAccessRolesRef(orgId).doc(role.id).set({
      ...role.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateAppAccessRole(String orgId, AppAccessRole role) async {
    await _appAccessRolesRef(orgId).doc(role.id).update({
      ...role.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAppAccessRole(String orgId, String roleId) async {
    await _appAccessRolesRef(orgId).doc(roleId).delete();
  }
}
