import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:operon_driver_android/domain/entities/organization_user.dart';
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
}
