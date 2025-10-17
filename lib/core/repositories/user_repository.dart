import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/user.dart';
import '../models/organization_role.dart';
import '../constants/app_constants.dart';
import '../utils/storage_utils.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Get user by ID
  Future<User?> getUserById(String userId) async {
    try {
      final docSnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();

      if (docSnapshot.exists) {
        return User.fromMap(docSnapshot.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch user: $e');
    }
  }

  // Get user by phone number
  Future<User?> getUserByPhoneNumber(String phoneNumber) async {
    try {
      final querySnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('phoneNo', isEqualTo: phoneNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return User.fromMap(querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch user by phone: $e');
    }
  }

  // Update user
  Future<void> updateUser(String userId, User user) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update(user.copyWith(updatedDate: DateTime.now()).toMap());
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  // Delete user (soft delete)
  Future<void> deleteUser(String userId) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update({
        'status': AppConstants.userStatusInactive,
        'updatedDate': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  // Get user organizations
  Future<List<UserOrganization>> getUserOrganizations(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.organizationsSubcollection)
          .orderBy('joinedDate', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => UserOrganization.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch user organizations: $e');
    }
  }

  // Add user to organization
  Future<void> addUserToOrganization({
    required String userId,
    required String orgId,
    required String orgName,
    required String? orgLogoUrl,
    required int role,
    required String addedBy,
  }) async {
    final batch = _firestore.batch();
    
    try {
      // Get user data
      final user = await getUserById(userId);
      if (user == null) {
        throw Exception('User not found');
      }

      // Add user to organization's user list
      final orgUserRef = _firestore
          .collection(AppConstants.organizationsCollection)
          .doc(orgId)
          .collection(AppConstants.usersSubcollection)
          .doc(userId);

      final orgUser = OrganizationUser(
        userId: userId,
        role: role,
        name: user.name,
        phoneNo: user.phoneNo,
        email: user.email,
        status: AppConstants.userStatusActive,
        addedDate: DateTime.now(),
        updatedDate: DateTime.now(),
        addedBy: addedBy,
        permissions: [],
      );

      batch.set(orgUserRef, orgUser.toMap());

      // Add organization to user's organization list
      final userOrgRef = _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.organizationsSubcollection)
          .doc(orgId);

      final userOrg = UserOrganization(
        orgId: orgId,
        orgName: orgName,
        orgLogoUrl: orgLogoUrl,
        role: role,
        status: AppConstants.userStatusActive,
        joinedDate: DateTime.now(),
        isPrimary: false, // Will be set to true if this is their first org
        permissions: [],
      );

      batch.set(userOrgRef, userOrg.toMap());

      // Update organization user count
      final orgRef = _firestore.collection(AppConstants.organizationsCollection).doc(orgId);
      batch.update(orgRef, {
        'metadata.totalUsers': FieldValue.increment(1),
        'metadata.activeUsers': FieldValue.increment(1),
        'updatedDate': Timestamp.fromDate(DateTime.now()),
      });

      // Update user organization count
      final userRef = _firestore.collection(AppConstants.usersCollection).doc(userId);
      batch.update(userRef, {
        'metadata.totalOrganizations': FieldValue.increment(1),
        'updatedDate': Timestamp.fromDate(DateTime.now()),
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to add user to organization: $e');
    }
  }

  // Remove user from organization
  Future<void> removeUserFromOrganization(String userId, String orgId) async {
    final batch = _firestore.batch();
    
    try {
      // Remove user from organization's user list
      final orgUserRef = _firestore
          .collection(AppConstants.organizationsCollection)
          .doc(orgId)
          .collection(AppConstants.usersSubcollection)
          .doc(userId);

      batch.update(orgUserRef, {
        'status': AppConstants.userStatusInactive,
        'updatedDate': Timestamp.fromDate(DateTime.now()),
      });

      // Remove organization from user's organization list
      final userOrgRef = _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.organizationsSubcollection)
          .doc(orgId);

      batch.update(userOrgRef, {
        'status': AppConstants.userStatusInactive,
        'updatedDate': Timestamp.fromDate(DateTime.now()),
      });

      // Update organization user count
      final orgRef = _firestore.collection(AppConstants.organizationsCollection).doc(orgId);
      batch.update(orgRef, {
        'metadata.activeUsers': FieldValue.increment(-1),
        'updatedDate': Timestamp.fromDate(DateTime.now()),
      });

      // Update user organization count
      final userRef = _firestore.collection(AppConstants.usersCollection).doc(userId);
      batch.update(userRef, {
        'metadata.totalOrganizations': FieldValue.increment(-1),
        'updatedDate': Timestamp.fromDate(DateTime.now()),
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to remove user from organization: $e');
    }
  }

  // Update user role in organization
  Future<void> updateUserRoleInOrganization({
    required String userId,
    required String orgId,
    required int newRole,
    required String updatedBy,
  }) async {
    final batch = _firestore.batch();
    
    try {
      // Update role in organization's user list
      final orgUserRef = _firestore
          .collection(AppConstants.organizationsCollection)
          .doc(orgId)
          .collection(AppConstants.usersSubcollection)
          .doc(userId);

      batch.update(orgUserRef, {
        'role': newRole,
        'updatedDate': Timestamp.fromDate(DateTime.now()),
      });

      // Update role in user's organization list
      final userOrgRef = _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.organizationsSubcollection)
          .doc(orgId);

      batch.update(userOrgRef, {
        'role': newRole,
        'updatedDate': Timestamp.fromDate(DateTime.now()),
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to update user role: $e');
    }
  }

  // Upload user profile photo
  Future<String> uploadUserProfilePhoto(String userId, File photoFile) async {
    return await StorageUtils.uploadUserProfilePhoto(userId, photoFile);
  }

  // Update user profile photo
  Future<void> updateUserProfilePhoto(String userId, String photoUrl) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update({
        'profilePhotoUrl': photoUrl,
        'updatedDate': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to update profile photo: $e');
    }
  }

  // Search users by name or phone
  Future<List<User>> searchUsers({
    required String query,
    int limit = AppConstants.defaultPageSize,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query queryRef = _firestore
          .collection(AppConstants.usersCollection)
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: query + '\uf8ff')
          .limit(limit);

      if (startAfter != null) {
        queryRef = queryRef.startAfterDocument(startAfter);
      }

      final querySnapshot = await queryRef.get();
      
      return querySnapshot.docs
          .map((doc) => User.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to search users: $e');
    }
  }

  // Get all users with pagination
  Future<List<User>> getUsers({
    int limit = AppConstants.defaultPageSize,
    DocumentSnapshot? startAfter,
    String? statusFilter,
  }) async {
    try {
      Query query = _firestore
          .collection(AppConstants.usersCollection)
          .orderBy('createdDate', descending: true);

      if (statusFilter != null && statusFilter.isNotEmpty) {
        query = query.where('status', isEqualTo: statusFilter);
      }

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      query = query.limit(limit);

      final querySnapshot = await query.get();
      
      return querySnapshot.docs
          .map((doc) => User.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch users: $e');
    }
  }

  // Get users by organization
  Future<List<User>> getUsersByOrganization(
    String orgId, {
    String? searchQuery,
    int? roleFilter,
    String? statusFilter,
  }) async {
    try {
      Query query = _firestore.collection(AppConstants.usersCollection);

      if (statusFilter != null) {
        query = query.where('status', isEqualTo: statusFilter);
      }

      final querySnapshot = await query
          .orderBy('createdDate', descending: true)
          .get();

      List<User> users = querySnapshot.docs
          .map((doc) => User.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      // Client-side filtering for organization and role (since we can't query nested arrays directly)
      users = users.where((user) {
        return user.organizations.any((org) => org.orgId == orgId);
      }).toList();

      if (roleFilter != null) {
        users = users.where((user) {
          return user.organizations.any((org) => 
              org.orgId == orgId && org.role == roleFilter);
        }).toList();
      }

      // Client-side filtering for search query
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final lowercaseQuery = searchQuery.toLowerCase();
        users = users.where((user) {
          return user.name.toLowerCase().contains(lowercaseQuery) ||
                 user.email.toLowerCase().contains(lowercaseQuery) ||
                 user.phoneNo.contains(searchQuery);
        }).toList();
      }

      return users;
    } catch (e) {
      throw Exception('Failed to fetch users by organization: $e');
    }
  }
}
