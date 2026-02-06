import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dash_mobile/domain/entities/organization_user.dart';
import 'package:dash_mobile/domain/exceptions/duplicate_phone_exception.dart';
import 'package:flutter/foundation.dart';

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
    required String roleTitle,
    required String userName,
  }) async {
    await _usersCollection
        .doc(userId)
        .collection('ORGANIZATIONS')
        .doc(orgId)
        .set({
      'org_id': orgId,
      'org_name': orgName,
      'role_in_org': roleTitle,
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
      roleTitle: user.roleTitle,
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

  Future<OrganizationUser?> fetchCurrentUser({
    required String orgId,
    required String userId,
    String? phoneNumber,
  }) async {
    debugPrint('[UsersDataSource] fetchCurrentUser called');
    debugPrint('[UsersDataSource] orgId: $orgId');
    debugPrint('[UsersDataSource] userId: $userId');
    debugPrint('[UsersDataSource] phoneNumber: $phoneNumber');
    debugPrint('[UsersDataSource] Collection path: ORGANIZATIONS/$orgId/USERS');
    
    try {
      final collectionRef = _orgUsersCollection(orgId);
      
      // First try direct lookup by userId (document ID) - for backward compatibility
      debugPrint('[UsersDataSource] Trying document ID lookup: $userId');
      final doc = await collectionRef.doc(userId).get();
      
      debugPrint('[UsersDataSource] Document exists: ${doc.exists}');
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        debugPrint('[UsersDataSource] Found user by document ID');
        debugPrint('[UsersDataSource] Document data[user_name]: ${data['user_name']}');
        debugPrint('[UsersDataSource] Document data[phone]: ${data['phone']}');
        
        final orgUser = OrganizationUser.fromMap(data, doc.id, orgId);
        debugPrint('[UsersDataSource] Created OrganizationUser with name: ${orgUser.name}');
        return orgUser;
      }
      
      // If direct lookup fails and phone number is provided, try querying by phone
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        debugPrint('[UsersDataSource] User not found by document ID, trying phone lookup: $phoneNumber');
        final phoneQuery = await collectionRef
            .where('phone', isEqualTo: phoneNumber)
            .limit(1)
            .get();
        
        debugPrint('[UsersDataSource] Phone query results: ${phoneQuery.docs.length} documents');
        if (phoneQuery.docs.isNotEmpty) {
          final doc = phoneQuery.docs.first;
          final data = doc.data();
          debugPrint('[UsersDataSource] Found user by phone - Document ID: ${doc.id}');
          debugPrint('[UsersDataSource] Found user by phone - user_name: ${data['user_name']}');
          
          final orgUser = OrganizationUser.fromMap(data, doc.id, orgId);
          debugPrint('[UsersDataSource] Created OrganizationUser from phone lookup with name: ${orgUser.name}');
          return orgUser;
        }
      }
      
      // If userId might be Firebase Auth UID, try to find user in USERS collection first
      debugPrint('[UsersDataSource] Trying to resolve Firebase Auth UID in USERS collection');
      debugPrint('[UsersDataSource] Querying USERS collection where uid == $userId');
      final userDoc = await _usersCollection
          .where('uid', isEqualTo: userId)
          .limit(1)
          .get();
      
      debugPrint('[UsersDataSource] USERS collection query results (by uid): ${userDoc.docs.length} documents');
      if (userDoc.docs.isNotEmpty) {
        final actualUserId = userDoc.docs.first.id;
        debugPrint('[UsersDataSource] Found user in USERS collection with document ID: $actualUserId');
        debugPrint('[UsersDataSource] Now querying ORGANIZATIONS/$orgId/USERS/$actualUserId');
        
        final orgUserDoc = await collectionRef.doc(actualUserId).get();
        debugPrint('[UsersDataSource] Organization user document exists: ${orgUserDoc.exists}');
        
        if (orgUserDoc.exists && orgUserDoc.data() != null) {
          final data = orgUserDoc.data()!;
          debugPrint('[UsersDataSource] Found organization user by resolved document ID');
          debugPrint('[UsersDataSource] Document data[user_name]: ${data['user_name']}');
          debugPrint('[UsersDataSource] Document data[phone]: ${data['phone']}');
          
          final orgUser = OrganizationUser.fromMap(data, orgUserDoc.id, orgId);
          debugPrint('[UsersDataSource] Created OrganizationUser with name: ${orgUser.name}');
          return orgUser;
        }
      }
      
      // If phone number is provided, try to find user in USERS collection by phone
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        debugPrint('[UsersDataSource] Trying to resolve user by phone in USERS collection');
        debugPrint('[UsersDataSource] Querying USERS collection where phone == $phoneNumber');
        final phoneUserDoc = await _usersCollection
            .where('phone', isEqualTo: phoneNumber)
            .limit(1)
            .get();
        
        debugPrint('[UsersDataSource] USERS collection query results (by phone): ${phoneUserDoc.docs.length} documents');
        if (phoneUserDoc.docs.isNotEmpty) {
          final actualUserId = phoneUserDoc.docs.first.id;
          final userData = phoneUserDoc.docs.first.data();
          debugPrint('[UsersDataSource] Found user in USERS collection by phone');
          debugPrint('[UsersDataSource] USERS document ID: $actualUserId');
          debugPrint('[UsersDataSource] USERS document data: $userData');
          debugPrint('[UsersDataSource] USERS document data[name]: ${userData['name']}');
          debugPrint('[UsersDataSource] USERS document data[uid]: ${userData['uid']}');
          debugPrint('[UsersDataSource] Now querying ORGANIZATIONS/$orgId/USERS/$actualUserId');
          
          final orgUserDoc = await collectionRef.doc(actualUserId).get();
          debugPrint('[UsersDataSource] Organization user document exists: ${orgUserDoc.exists}');
          
          if (orgUserDoc.exists && orgUserDoc.data() != null) {
            final data = orgUserDoc.data()!;
            debugPrint('[UsersDataSource] Found organization user by phone-resolved document ID');
            debugPrint('[UsersDataSource] Document data[user_name]: ${data['user_name']}');
            debugPrint('[UsersDataSource] Document data[phone]: ${data['phone']}');
            debugPrint('[UsersDataSource] Document data[user_id]: ${data['user_id']}');
            
            final orgUser = OrganizationUser.fromMap(data, orgUserDoc.id, orgId);
            debugPrint('[UsersDataSource] Created OrganizationUser with name: ${orgUser.name}');
            return orgUser;
          }
        }
      }
      
      debugPrint('[UsersDataSource] User not found by any method, returning null');
      return null;
    } catch (e, stackTrace) {
      debugPrint('[UsersDataSource] Error in fetchCurrentUser: $e');
      debugPrint('[UsersDataSource] Stack trace: $stackTrace');
      return null;
    }
  }

  Future<String?> fetchPhoneByEmployeeId({
    required String orgId,
    required String employeeId,
  }) async {
    // First check ORGANIZATIONS/{orgId}/USERS collection
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
      // If phone not in org user, get from USERS collection
      final userId = orgUsersQuery.docs.first.id;
      final userDoc = await _usersCollection.doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        return userData?['phone'] as String?;
      }
    }
    
    // Also check USERS collection directly (in case employee_id is stored there)
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
}

class _UserLookupResult {
  _UserLookupResult({required this.id, required this.isNew});

  final String id;
  final bool isNew;
}

