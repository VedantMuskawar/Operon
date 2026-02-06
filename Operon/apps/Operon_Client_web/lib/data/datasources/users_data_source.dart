import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dash_web/domain/entities/organization_user.dart';
import 'package:dash_web/domain/exceptions/duplicate_phone_exception.dart';

class UsersDataSource {
  UsersDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('USERS');

  CollectionReference<Map<String, dynamic>> _orgUsersCollection(String orgId) {
    return _firestore
        .collection('ORGANIZATIONS')
        .doc(orgId)
        .collection('USERS');
  }

  Future<List<OrganizationUser>> fetchOrgUsers(String orgId) async {
    final snapshot = await _orgUsersCollection(orgId)
        .orderBy('user_name')
        .limit(500)
        .get();
    return snapshot.docs
        .map(
          (doc) => OrganizationUser.fromMap(doc.data(), doc.id, orgId),
        )
        .toList();
  }

  Future<_UserLookupResult> _findOrCreateUserDoc({
    required String phone,
    required String userName,
    String? preferredUserId,
    bool allowUpdate = true,
  }) async {
    // Check for existing user with this phone number
    final existing = await _usersCollection
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();
    
    if (existing.docs.isNotEmpty) {
      final existingDoc = existing.docs.first;
      final existingUserId = existingDoc.id;
      
      // If preferredUserId is provided and it's different from existing user, throw error
      if (preferredUserId != null && 
          preferredUserId.isNotEmpty && 
          preferredUserId != existingUserId) {
        throw DuplicatePhoneNumberException(phone, existingUserId);
      }
      
      // If allowUpdate is false, throw error (strict mode - no reusing existing users)
      if (!allowUpdate) {
        throw DuplicatePhoneNumberException(phone, existingUserId);
      }
      
      // Otherwise, return existing user
      return _UserLookupResult(id: existingUserId, isNew: false);
    }

    // No existing user found, create new one
    final ref = preferredUserId != null && preferredUserId.isNotEmpty
        ? _usersCollection.doc(preferredUserId)
        : _usersCollection.doc();
    
    // Double-check the document doesn't exist (in case preferredUserId was provided)
    if (preferredUserId != null && preferredUserId.isNotEmpty) {
      final docCheck = await ref.get();
      if (docCheck.exists) {
        final existingPhone = docCheck.data()?['phone'] as String?;
        if (existingPhone != null && existingPhone != phone) {
          // Document exists with different phone - check if that phone is already taken
          final phoneCheck = await _usersCollection
              .where('phone', isEqualTo: phone)
              .limit(1)
              .get();
          if (phoneCheck.docs.isNotEmpty) {
            throw DuplicatePhoneNumberException(phone, phoneCheck.docs.first.id);
          }
        }
      }
    }
    
    await ref.set({
      'phone': phone,
      'name': userName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return _UserLookupResult(id: ref.id, isNew: true);
  }

  Future<void> _ensureOrgMembership({
    required String userId,
    required String orgId,
    required String orgName,
    String? appAccessRoleName,
    required String userName,
  }) async {
    await _usersCollection
        .doc(userId)
        .collection('ORGANIZATIONS')
        .doc(orgId)
        .set({
      'org_id': orgId,
      'org_name': orgName,
      if (appAccessRoleName != null) 'role_in_org': appAccessRoleName,
      'user_name': userName,
      'joined_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> upsertOrgUser({
    required String orgId,
    required String orgName,
    required OrganizationUser user,
  }) async {
    // Determine if this is a create (new user) or update (existing user)
    final isUpdate = user.id.isNotEmpty;
    
    // If updating, check if phone number is being changed to an existing one
    if (isUpdate) {
      final existingUserDoc = await _usersCollection.doc(user.id).get();
      if (existingUserDoc.exists) {
        final existingPhone = existingUserDoc.data()?['phone'] as String?;
        // If phone is being changed, check if new phone already exists
        if (existingPhone != null && existingPhone != user.phone) {
          final phoneCheck = await _usersCollection
              .where('phone', isEqualTo: user.phone)
              .limit(1)
              .get();
          if (phoneCheck.docs.isNotEmpty) {
            final conflictingUserId = phoneCheck.docs.first.id;
            if (conflictingUserId != user.id) {
              throw DuplicatePhoneNumberException(user.phone, conflictingUserId);
            }
          }
        }
      }
    }
    
    // allowUpdate: true so existing users (e.g. in another org) can be added to this org (multi-org membership)
    final lookup = await _findOrCreateUserDoc(
      phone: user.phone,
      userName: user.name,
      preferredUserId: user.id.isEmpty ? null : user.id,
      allowUpdate: true,
    );

    await _orgUsersCollection(orgId).doc(lookup.id).set({
      ...user.toMap(),
      'user_id': lookup.id,
      'org_name': orgName,
      'updated_at': FieldValue.serverTimestamp(),
      if (lookup.isNew) 'created_at': FieldValue.serverTimestamp(),
      if (lookup.isNew) 'joined_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _ensureOrgMembership(
      userId: lookup.id,
      orgId: orgId,
      orgName: orgName,
      appAccessRoleName: user.appAccessRole?.name,
      userName: user.name,
    );
  }

  Future<void> removeOrgUser({
    required String orgId,
    required String userId,
  }) async {
    await _orgUsersCollection(orgId).doc(userId).delete();
    await _usersCollection
        .doc(userId)
        .collection('ORGANIZATIONS')
        .doc(orgId)
        .delete();
  }

  Future<String?> fetchPhoneByEmployeeId({
    required String orgId,
    required String employeeId,
  }) async {
    final orgUsersQuery = await _orgUsersCollection(orgId)
        .where('employee_id', isEqualTo: employeeId)
        .limit(1)
        .get();
    
    if (orgUsersQuery.docs.isNotEmpty) {
      final userData = orgUsersQuery.docs.first.data();
      final phone = userData['phone'] as String?;
      if (phone != null && phone.isNotEmpty) {
        return phone;
      }
      final userId = orgUsersQuery.docs.first.id;
      final userDoc = await _usersCollection.doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        return userData?['phone'] as String?;
      }
    }
    
    final usersQuery = await _usersCollection
        .where('employee_id', isEqualTo: employeeId)
        .limit(1)
        .get();
    
    if (usersQuery.docs.isNotEmpty) {
      final userData = usersQuery.docs.first.data();
      return userData['phone'] as String?;
    }
    
    return null;
  }

  Future<OrganizationUser?> fetchCurrentUser({
    required String orgId,
    required String userId,
    String? phoneNumber,
  }) async {
    try {
      // First try direct lookup by userId (document ID)
      final doc = await _orgUsersCollection(orgId).doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return OrganizationUser.fromMap(doc.data()!, doc.id, orgId);
      }
      
      // If direct lookup fails and phone number is provided, try querying by phone
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        final query = await _orgUsersCollection(orgId)
            .where('phone', isEqualTo: phoneNumber)
            .limit(1)
            .get();
        
        if (query.docs.isNotEmpty) {
          final doc = query.docs.first;
          return OrganizationUser.fromMap(doc.data(), doc.id, orgId);
        }
      }
      
      // If userId might be Firebase Auth UID, try to find user in USERS collection first
      final userDoc = await _usersCollection
          .where('uid', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (userDoc.docs.isNotEmpty) {
        final actualUserId = userDoc.docs.first.id;
        final orgUserDoc = await _orgUsersCollection(orgId).doc(actualUserId).get();
        if (orgUserDoc.exists && orgUserDoc.data() != null) {
          return OrganizationUser.fromMap(orgUserDoc.data()!, orgUserDoc.id, orgId);
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
}

class _UserLookupResult {
  _UserLookupResult({required this.id, required this.isNew});

  final String id;
  final bool isNew;
}
