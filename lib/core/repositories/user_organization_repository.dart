import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_constants.dart';

class UserOrganizationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get user organizations with full details
  Future<List<Map<String, dynamic>>> getUserOrganizations(String userId) async {
    final userRef = _firestore.collection(AppConstants.usersCollection).doc(userId);
    final docSnapshot = await userRef.get();
    
    if (!docSnapshot.exists) {
      return [];
    }
    
    final userData = docSnapshot.data()!;
    final organizations = userData['organizations'] as List<dynamic>? ?? [];
    
    // Get organization details for each organization
    List<Map<String, dynamic>> orgDetails = [];
    for (var org in organizations) {
      if (org['status'] == AppConstants.orgStatusActive) {
        final orgRef = _firestore.collection(AppConstants.organizationsCollection).doc(org['orgId']);
        final orgSnapshot = await orgRef.get();
        
        if (orgSnapshot.exists) {
          final orgData = orgSnapshot.data()!;
          orgDetails.add({
            'orgId': org['orgId'],
            'orgName': orgData['orgName'],
            'orgLogoUrl': orgData['orgLogoUrl'],
            'role': org['role'],
            'status': org['status'],
            'joinedDate': org['joinedDate'],
            'isPrimary': org['isPrimary'] ?? false,
            'permissions': org['permissions'] ?? [],
          });
        }
      }
    }
    
    return orgDetails;
  }

  // Check if user is Super Admin
  bool isSuperAdmin(User firebaseUser) {
    String cleanPhoneNumber = firebaseUser.phoneNumber?.replaceAll(RegExp(r'[^\d]'), '') ?? '';
    String authorizedNumber = AppConstants.superAdminPhoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    String authorizedMobileNumber = authorizedNumber.substring(authorizedNumber.length - 10);
    return cleanPhoneNumber == authorizedMobileNumber;
  }

  // Get user document
  Future<Map<String, dynamic>?> getUserDocument(String userId) async {
    final docSnapshot = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .get();
    
    return docSnapshot.exists ? docSnapshot.data() : null;
  }

  // Set primary organization
  Future<void> setPrimaryOrganization(String userId, String orgId) async {
    final userRef = _firestore.collection(AppConstants.usersCollection).doc(userId);
    
    // Update all organizations to set isPrimary to false
    final userDoc = await userRef.get();
    if (userDoc.exists) {
      final userData = userDoc.data()!;
      final organizations = userData['organizations'] as List<dynamic>? ?? [];
      
      List<Map<String, dynamic>> updatedOrganizations = [];
      for (var org in organizations) {
        updatedOrganizations.add({
          ...org,
          'isPrimary': org['orgId'] == orgId,
        });
      }
      
      await userRef.update({
        'organizations': updatedOrganizations,
        'metadata.primaryOrgId': orgId,
        'updatedDate': Timestamp.fromDate(DateTime.now()),
      });
    }
  }
}
