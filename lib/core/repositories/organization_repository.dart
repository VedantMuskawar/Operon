import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import '../models/organization.dart';
import '../models/user.dart';
import '../models/subscription.dart';
import '../models/organization_role.dart';
import '../constants/app_constants.dart';
import '../utils/storage_utils.dart';

class OrganizationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Create organization with initial admin user (Direct Firestore - Cloud Functions disabled)
  Future<String> createOrganization({
    required String orgName,
    required String email,
    required String gstNo,
    String? industry,
    String? location,
    required String adminName,
    required String adminPhone,
    required String adminEmail,
    required Subscription subscription,
    Uint8List? logoFile,
    String? logoFileName,
  }) async {
    final batch = _firestore.batch();
    
    try {
      // Generate organization ID
      final orgId = _firestore.collection(AppConstants.organizationsCollection).doc().id;
      
      // Create organization document
      final organization = Organization(
        orgId: orgId,
        orgName: orgName,
        email: email,
        gstNo: gstNo,
        orgLogoUrl: null, // Will be updated after logo upload
        status: AppConstants.orgStatusActive,
        createdDate: DateTime.now(),
        updatedDate: DateTime.now(),
        createdBy: 'system', // Will be updated with actual super admin ID
        metadata: OrganizationMetadata(
          totalUsers: 1,
          activeUsers: 1,
          industry: industry,
          location: location,
        ),
      );

      final orgRef = _firestore.collection(AppConstants.organizationsCollection).doc(orgId);
      batch.set(orgRef, organization.toMap());

      // Upload logo if provided
      String? logoUrl;
      if (logoFile != null) {
        try {
          logoUrl = await _uploadOrganizationLogo(orgId, logoFile, fileName: logoFileName);
          batch.update(orgRef, {'orgLogoUrl': logoUrl});
        } catch (e) {
          print('Warning: Failed to upload logo: $e');
          // Continue without logo
        }
      }

      // Create subscription document
      final subscriptionRef = orgRef
          .collection(AppConstants.subscriptionSubcollection)
          .doc(subscription.subscriptionId);
      batch.set(subscriptionRef, subscription.toMap());

      // Generate user ID
      final userId = _firestore.collection(AppConstants.usersCollection).doc().id;

      // Create user document with phone auth
      final user = User(
        userId: userId,
        name: adminName,
        phoneNo: adminPhone,
        email: adminEmail, // Optional - only for notifications
        profilePhotoUrl: null,
        status: AppConstants.userStatusActive,
        createdDate: DateTime.now(),
        updatedDate: DateTime.now(),
        lastLoginDate: null,
        metadata: UserMetadata(
          totalOrganizations: 1,
          primaryOrgId: orgId,
          notificationPreferences: {
            'sms': true,
            'email': adminEmail.isNotEmpty,
            'push': true,
          },
        ),
        organizations: [
          OrganizationRole(
            orgId: orgId,
            role: AppConstants.adminRole,
            status: AppConstants.userStatusActive,
            joinedDate: DateTime.now(),
            isPrimary: true,
            permissions: ['all'],
          ),
        ],
      );

      final userRef = _firestore.collection(AppConstants.usersCollection).doc(userId);
      batch.set(userRef, user.toMap());

      // Create organization-user relationship in organization
      final orgUser = OrganizationUser(
        userId: userId,
        role: AppConstants.adminRole,
        name: adminName,
        phoneNo: adminPhone,
        email: adminEmail,
        status: AppConstants.userStatusActive,
        addedDate: DateTime.now(),
        updatedDate: DateTime.now(),
        addedBy: 'system',
        permissions: [],
      );

      final orgUserRef = orgRef
          .collection(AppConstants.usersSubcollection)
          .doc(userId);
      batch.set(orgUserRef, orgUser.toMap());

      // Create user-organization relationship
      final userOrg = UserOrganization(
        orgId: orgId,
        orgName: orgName,
        orgLogoUrl: logoUrl,
        role: AppConstants.adminRole,
        status: AppConstants.userStatusActive,
        joinedDate: DateTime.now(),
        isPrimary: true,
        permissions: [],
      );

      final userOrgRef = userRef
          .collection(AppConstants.organizationsSubcollection)
          .doc(orgId);
      batch.set(userOrgRef, userOrg.toMap());

      // Commit batch
      await batch.commit();

      return orgId;
    } catch (e) {
      print('Error in createOrganization: $e');
      throw Exception('Failed to create organization: $e');
    }
  }

  // Get all organizations
  Future<List<Organization>> getOrganizations({
    int limit = AppConstants.defaultPageSize,
    DocumentSnapshot? startAfter,
    String? searchQuery,
    String? statusFilter,
  }) async {
    try {
      Query query = _firestore
          .collection(AppConstants.organizationsCollection);

      // Apply status filter first (simpler query)
      if (statusFilter != null && statusFilter.isNotEmpty) {
        query = query.where('status', isEqualTo: statusFilter);
      }

      // Apply search query (simpler range query)
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query
            .where('orgName', isGreaterThanOrEqualTo: searchQuery)
            .where('orgName', isLessThan: searchQuery + '\uf8ff');
      }

      // Add pagination
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      // Add limit
      query = query.limit(limit);

      final querySnapshot = await query.get();
      
      // Sort in memory to avoid complex index requirements
      final organizations = querySnapshot.docs
          .map((doc) {
            try {
              return Organization.fromMap(doc.data() as Map<String, dynamic>);
            } catch (e) {
              print('Error parsing organization document ${doc.id}: $e');
              return null;
            }
          })
          .where((org) => org != null)
          .cast<Organization>()
          .toList();
      
      // Sort by createdDate descending in memory
      organizations.sort((a, b) => b.createdDate.compareTo(a.createdDate));
      
      return organizations;
    } catch (e) {
      throw Exception('Failed to fetch organizations: $e');
    }
  }

  // Get organization by ID
  Future<Organization?> getOrganizationById(String orgId) async {
    try {
      final docSnapshot = await _firestore
          .collection(AppConstants.organizationsCollection)
          .doc(orgId)
          .get();

      if (docSnapshot.exists) {
        return Organization.fromMap(docSnapshot.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch organization: $e');
    }
  }

  // Update organization
  Future<void> updateOrganization(String orgId, Organization organization) async {
    try {
      await _firestore
          .collection(AppConstants.organizationsCollection)
          .doc(orgId)
          .update(organization.copyWith(updatedDate: DateTime.now()).toMap());
    } catch (e) {
      throw Exception('Failed to update organization: $e');
    }
  }

  // Delete organization (soft delete)
  Future<void> deleteOrganization(String orgId) async {
    try {
      await _firestore
          .collection(AppConstants.organizationsCollection)
          .doc(orgId)
          .update({
        'status': AppConstants.orgStatusInactive,
        'updatedDate': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to delete organization: $e');
    }
  }

  // Update organization with optional logo upload
  Future<void> updateOrganizationWithLogo(
    String orgId,
    Organization organization,
    Uint8List? logoFile,
    {String? logoFileName}
  ) async {
    try {
      final batch = _firestore.batch();
      final orgRef = _firestore.collection(AppConstants.organizationsCollection).doc(orgId);
      
      // Upload logo if provided
      String? logoUrl = organization.orgLogoUrl;
      if (logoFile != null) {
        try {
          logoUrl = await _uploadOrganizationLogo(orgId, logoFile, fileName: logoFileName);
        } catch (e) {
          print('Warning: Failed to upload logo: $e');
          // Continue without logo update
        }
      }
      
      // Update organization with new logo URL if uploaded
      final updatedOrg = organization.copyWith(
        orgLogoUrl: logoUrl,
        updatedDate: DateTime.now(),
      );
      
      batch.update(orgRef, updatedOrg.toMap());
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to update organization: $e');
    }
  }

  // Get organization users
  Future<List<OrganizationUser>> getOrganizationUsers(String orgId) async {
    try {
      final querySnapshot = await _firestore
          .collection(AppConstants.organizationsCollection)
          .doc(orgId)
          .collection(AppConstants.usersSubcollection)
          .orderBy('addedDate', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => OrganizationUser.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch organization users: $e');
    }
  }

  // Get organization subscription
  Future<Subscription?> getOrganizationSubscription(String orgId) async {
    try {
      final querySnapshot = await _firestore
          .collection(AppConstants.organizationsCollection)
          .doc(orgId)
          .collection(AppConstants.subscriptionSubcollection)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return Subscription.fromMap(querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch organization subscription: $e');
    }
  }

  // Update organization subscription
  Future<void> updateOrganizationSubscription(String orgId, Subscription subscription) async {
    try {
      final batch = _firestore.batch();
      
      // Deactivate current subscription
      final currentSubQuery = await _firestore
          .collection(AppConstants.organizationsCollection)
          .doc(orgId)
          .collection(AppConstants.subscriptionSubcollection)
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in currentSubQuery.docs) {
        batch.update(doc.reference, {
          'isActive': false,
          'updatedDate': Timestamp.fromDate(DateTime.now()),
        });
      }

      // Add new subscription
      final subscriptionRef = _firestore
          .collection(AppConstants.organizationsCollection)
          .doc(orgId)
          .collection(AppConstants.subscriptionSubcollection)
          .doc(subscription.subscriptionId);

      batch.set(subscriptionRef, subscription.toMap());

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to update subscription: $e');
    }
  }

  // Upload organization logo (platform-agnostic)
  Future<String> _uploadOrganizationLogo(String orgId, Uint8List? logoBytes, {String? fileName}) async {
    if (logoBytes == null) {
      throw Exception('No logo bytes provided');
    }
    return await StorageUtils.uploadOrganizationLogo(orgId, logoBytes, fileName: fileName);
  }

  // Get dashboard analytics
  Future<Map<String, dynamic>> getDashboardAnalytics() async {
    try {
      final countersSnapshot = await _firestore
          .collection(AppConstants.systemMetadataCollection)
          .doc('counters')
          .get();

      final organizationsSnapshot = await _firestore
          .collection(AppConstants.organizationsCollection)
          .where('status', isEqualTo: AppConstants.orgStatusActive)
          .get();

      final subscriptionsSnapshot = await _firestore
          .collectionGroup(AppConstants.subscriptionSubcollection)
          .where('isActive', isEqualTo: true)
          .get();

      return {
        'totalOrganizations': organizationsSnapshot.docs.length,
        'activeOrganizations': organizationsSnapshot.docs.length,
        'totalSubscriptions': subscriptionsSnapshot.docs.length,
        'activeSubscriptions': subscriptionsSnapshot.docs.length,
        'systemCounters': countersSnapshot.data() ?? {},
      };
    } catch (e) {
      throw Exception('Failed to fetch dashboard analytics: $e');
    }
  }
}
