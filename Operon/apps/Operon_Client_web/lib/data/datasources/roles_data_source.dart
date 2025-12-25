import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dash_web/domain/entities/organization_role.dart';

class RolesDataSource {
  RolesDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _rolesRef(String orgId) {
    return _firestore.collection('ORGANIZATIONS').doc(orgId).collection('ROLES');
  }

  Future<List<OrganizationRole>> fetchRoles(String orgId) async {
    final snapshot = await _rolesRef(orgId).orderBy('title').get();
    return snapshot.docs
        .map((doc) => OrganizationRole.fromJson(doc.data(), doc.id))
        .toList();
  }

  Future<void> createRole(String orgId, OrganizationRole role) {
    return _rolesRef(orgId).doc(role.id).set({
      ...role.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateRole(String orgId, OrganizationRole role) {
    return _rolesRef(orgId).doc(role.id).update({
      ...role.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteRole(String orgId, String roleId) {
    return _rolesRef(orgId).doc(roleId).delete();
  }
}
