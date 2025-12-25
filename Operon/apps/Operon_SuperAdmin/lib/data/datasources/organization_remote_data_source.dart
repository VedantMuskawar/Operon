import 'package:cloud_firestore/cloud_firestore.dart';

class OrganizationRemoteDataSource {
  OrganizationRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String organizationsCollection = 'ORGANIZATIONS';
  static const String usersCollection = 'USERS';
  static const String appAccessRolesCollection = 'APP_ACCESS_ROLES';

  Future<String> createOrganization({
    required String name,
    required String industry,
    String? businessId,
    required String creatorUserId,
    required String orgCode,
  }) async {
    final docRef = _firestore.collection(organizationsCollection).doc();
    await docRef.set({
      'org_id': docRef.id,
      'org_code': orgCode,
      'org_name': name,
      'industry': industry,
      if (businessId != null && businessId.isNotEmpty)
        'gst_or_business_id': businessId,
      'created_at': FieldValue.serverTimestamp(),
      'created_by_user': creatorUserId,
    });
    return docRef.id;
  }

  Future<String> createOrUpdateAdmin({
    required String name,
    required String phone,
  }) async {
    final usersCollectionRef = _firestore.collection(usersCollection);
    final existing = await usersCollectionRef
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      final doc = existing.docs.first;
      // Update existing user (this is expected behavior for admin creation)
      await doc.reference.update({
        'name': name,
        'updated_at': FieldValue.serverTimestamp(),
      });
      return doc.id;
    }

    // Create new user - verify phone doesn't exist (double-check for race conditions)
    final doubleCheck = await usersCollectionRef
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();
    
    if (doubleCheck.docs.isNotEmpty) {
      // Phone was added between checks - update existing instead
      final doc = doubleCheck.docs.first;
      await doc.reference.update({
        'name': name,
        'updated_at': FieldValue.serverTimestamp(),
      });
      return doc.id;
    }

    final docRef = usersCollectionRef.doc();
    await docRef.set({
      'name': name,
      'phone': phone,
      'created_at': FieldValue.serverTimestamp(),
      'superadmin': false,
    });
    return docRef.id;
  }

  Future<void> linkUserOrganization({
    required String userId,
    required String userName,
    required String organizationId,
    required String organizationName,
    required String roleInOrg,
    String? appAccessRoleId,
  }) async {
    final userOrgRef = _firestore
        .collection(usersCollection)
        .doc(userId)
        .collection(organizationsCollection)
        .doc(organizationId);

    final orgUserRef = _firestore
        .collection(organizationsCollection)
        .doc(organizationId)
        .collection(usersCollection)
        .doc(userId);

    final userOrgData = {
      'org_id': organizationId,
      'org_name': organizationName,
      'user_name': userName,
      'role_in_org': roleInOrg,
      if (appAccessRoleId != null) 'app_access_role_id': appAccessRoleId,
      'joined_at': FieldValue.serverTimestamp(),
    };

    final orgUserData = {
      'user_id': userId,
      'org_name': organizationName,
      'user_name': userName,
      'role_in_org': roleInOrg,
      if (appAccessRoleId != null) 'app_access_role_id': appAccessRoleId,
      'joined_at': FieldValue.serverTimestamp(),
    };

    await Future.wait([
      userOrgRef.set(userOrgData),
      orgUserRef.set(orgUserData),
    ]);
  }

  Stream<List<OrganizationRecord>> watchOrganizations() {
    return _firestore
        .collection(organizationsCollection)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => OrganizationRecord(
                  id: doc.id,
                  name: doc.data()['org_name'] as String? ?? 'Untitled',
                  industry: doc.data()['industry'] as String? ?? 'Unknown',
                  orgCode: doc.data()['org_code'] as String? ?? '',
                  createdAt:
                      (doc.data()['created_at'] as Timestamp?)?.toDate(),
                ),
              )
              .toList(),
        );
  }

  Future<void> deleteOrganization(String organizationId) async {
    final orgRef = _firestore.collection(organizationsCollection).doc(organizationId);
    final orgUsersRef = orgRef.collection(usersCollection);
    final orgUsersSnapshot = await orgUsersRef.get();

    final batch = _firestore.batch();

    for (final userDoc in orgUsersSnapshot.docs) {
      final userId = userDoc.id;
      final userRef = _firestore.collection(usersCollection).doc(userId);

      // Remove the reference from the user's ORGANIZATIONS subcollection
      final userOrgRef =
          userRef.collection(organizationsCollection).doc(organizationId);
      batch.delete(userOrgRef);

      // Remove the org's reference to the user
      batch.delete(orgUsersRef.doc(userId));

      // Delete the user document itself
      batch.delete(userRef);
    }

    // Finally delete the organization document
    batch.delete(orgRef);

    await batch.commit();
  }

  Future<void> updateOrganization({
    required String organizationId,
    required String name,
    required String industry,
    String? businessId,
  }) async {
    await _firestore.collection(organizationsCollection).doc(organizationId).update({
      'org_name': name,
      'industry': industry,
      'gst_or_business_id': businessId,
    });
  }

  /// Creates the default Admin App Access Role for a new organization
  /// This role has full access (isAdmin = true) and cannot be deleted
  Future<void> createDefaultAdminAppAccessRole(String organizationId) async {
    final adminRoleRef = _firestore
        .collection(organizationsCollection)
        .doc(organizationId)
        .collection(appAccessRolesCollection)
        .doc('admin'); // Fixed ID for admin role

    // Check if admin role already exists
    final existing = await adminRoleRef.get();
    if (existing.exists) {
      return; // Already exists, skip creation
    }

    await adminRoleRef.set({
      'roleId': 'admin',
      'name': 'Admin',
      'description': 'Full access to all features and settings',
      'colorHex': '#FF6B6B', // Red color for admin
      'isAdmin': true,
      'permissions': {
        'sections': {},
        'pages': {},
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

class OrganizationRecord {
  const OrganizationRecord({
    required this.id,
    required this.name,
    required this.industry,
    required this.orgCode,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String industry;
  final String orgCode;
  final DateTime? createdAt;
}

