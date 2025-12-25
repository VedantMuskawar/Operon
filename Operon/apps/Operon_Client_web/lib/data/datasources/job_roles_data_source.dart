import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dash_web/domain/entities/organization_job_role.dart';

class JobRolesDataSource {
  JobRolesDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _jobRolesRef(String orgId) {
    return _firestore
        .collection('ORGANIZATIONS')
        .doc(orgId)
        .collection('JOB_ROLES');
  }

  Future<List<OrganizationJobRole>> fetchJobRoles(String orgId) async {
    final snapshot = await _jobRolesRef(orgId).orderBy('title').get();
    return snapshot.docs
        .map((doc) => OrganizationJobRole.fromJson(doc.data(), doc.id))
        .toList();
  }

  Future<OrganizationJobRole?> fetchJobRole(String orgId, String jobRoleId) async {
    final doc = await _jobRolesRef(orgId).doc(jobRoleId).get();
    if (!doc.exists) return null;
    return OrganizationJobRole.fromJson(doc.data()!, doc.id);
  }

  Future<List<OrganizationJobRole>> fetchJobRolesByIds(
    String orgId,
    List<String> jobRoleIds,
  ) async {
    if (jobRoleIds.isEmpty) return [];
    
    // Firestore 'in' queries are limited to 10 items
    // Split into batches if needed
    final List<OrganizationJobRole> roles = [];
    for (var i = 0; i < jobRoleIds.length; i += 10) {
      final batch = jobRoleIds.skip(i).take(10).toList();
      final snapshot = await _jobRolesRef(orgId)
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      roles.addAll(
        snapshot.docs.map(
          (doc) => OrganizationJobRole.fromJson(doc.data(), doc.id),
        ),
      );
    }
    return roles;
  }

  Future<void> createJobRole(String orgId, OrganizationJobRole jobRole) async {
    await _jobRolesRef(orgId).doc(jobRole.id).set({
      ...jobRole.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateJobRole(String orgId, OrganizationJobRole jobRole) async {
    await _jobRolesRef(orgId).doc(jobRole.id).update({
      ...jobRole.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteJobRole(String orgId, String jobRoleId) async {
    await _jobRolesRef(orgId).doc(jobRoleId).delete();
  }
}
