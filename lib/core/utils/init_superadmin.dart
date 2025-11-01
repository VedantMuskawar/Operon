import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../constants/app_constants.dart';
import '../../firebase_options.dart';

/// Initialization script for setting up SuperAdmin organization and first SuperAdmin user
/// 
/// Usage:
/// 1. First login with SuperAdmin phone number (+919876543210) to create Firebase Auth user
/// 2. Get the Firebase Auth UID from Firebase Console
/// 3. Run this script with the UID
/// 4. Login again - should work perfectly
class SuperAdminInitializer {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialize Firebase and create all SuperAdmin data
  Future<void> initializeSuperAdmin(String firebaseAuthUid) async {
    try {
      print('🚀 Initializing SuperAdmin setup...');
      print('🔑 Using Firebase Auth UID: $firebaseAuthUid');
      
      // Initialize all collections
      await _createSuperAdminOrganization();
      await _createSuperAdminUser(firebaseAuthUid);
      await _createSuperAdminConfig();
      await _createSystemMetadata();
      await _createSuperAdminOrgUser(firebaseAuthUid);
      
      print('\n🎉 SuperAdmin initialization completed successfully!');
      print('📱 You can now login with phone number: +919876543210');
      
    } catch (e) {
      print('❌ Error during SuperAdmin initialization: $e');
      rethrow;
    }
  }

  /// Create SuperAdmin organization
  Future<void> _createSuperAdminOrganization() async {
    print('🏢 Creating SuperAdmin organization...');
    
    final orgData = {
      'orgId': AppConstants.superAdminOrgId,
      'orgName': AppConstants.superAdminOrgName,
      'emailId': 'admin@operon.com',
      'phoneNo': '+919876543210',
      'gstNo': '',
      'orgLogoUrl': null,
      'status': AppConstants.orgStatusActive,
      'createdDate': Timestamp.now(),
      'updatedDate': Timestamp.now(),
      'createdBy': 'system',
      'metadata': {
        'totalUsers': 1,
        'activeUsers': 1,
        'isSuperAdminOrg': true,
        'industry': 'Technology',
        'location': 'India',
        'address': {
          'street': '',
          'city': '',
          'state': '',
          'pincode': '',
          'country': 'India'
        }
      },
      'subscription': {
        'tier': AppConstants.subscriptionTierEnterprise,
        'subscriptionType': 'lifetime',
        'startDate': Timestamp.now(),
        'endDate': null,
        'userLimit': 999,
        'status': AppConstants.subscriptionStatusActive
      }
    };

    await _firestore
        .collection(AppConstants.organizationsCollection)
        .doc(AppConstants.superAdminOrgId)
        .set(orgData);
    
    print('✅ SuperAdmin organization created');
  }

  /// Create SuperAdmin user document
  Future<void> _createSuperAdminUser(String firebaseAuthUid) async {
    print('👤 Creating SuperAdmin user document...');
    
    final userData = {
      'userId': firebaseAuthUid,
      'name': 'Super Admin',
      'phoneNo': '+919876543210',
      'email': 'admin@operon.com',
      'profilePhotoUrl': null,
      'status': AppConstants.userStatusActive,
      'createdDate': Timestamp.now(),
      'updatedDate': Timestamp.now(),
      'lastLoginDate': null,
      'metadata': {
        'totalOrganizations': 1,
        'primaryOrgId': AppConstants.superAdminOrgId,
        'notificationPreferences': {
          'email': true,
          'push': true,
          'sms': true
        }
      },
      'organizations': [
        {
          'orgId': AppConstants.superAdminOrgId,
          'role': AppConstants.superAdminRole,
          'status': AppConstants.orgStatusActive,
          'joinedDate': Timestamp.now(),
          'isPrimary': true,
          'permissions': ['all']
        }
      ]
    };

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(firebaseAuthUid)
        .set(userData);
    
    print('✅ SuperAdmin user document created');
  }

  /// Create SuperAdmin configuration
  Future<void> _createSuperAdminConfig() async {
    print('⚙️ Creating SuperAdmin configuration...');
    
    final configData = {
      'defaultUserLimit': 10,
      'defaultSubscriptionTier': AppConstants.subscriptionTierBasic,
      'allowedDomains': <String>[],
      'systemSettings': {
        'maintenanceMode': false,
        'maintenanceMessage': '',
        'allowNewOrganizations': true,
        'requireEmailVerification': false,
        'requirePhoneVerification': true
      },
      'featureFlags': {
        'enableAnalytics': true,
        'enableNotifications': true,
        'enableMultiOrg': true,
        'enableSubscriptions': true
      },
      'securitySettings': {
        'maxLoginAttempts': 5,
        'sessionTimeout': 3600,
        'requireStrongPassword': false,
        'allowedCountryCodes': ['+91']
      },
      'updatedDate': Timestamp.now(),
      'updatedBy': 'system'
    };

    await _firestore
        .collection(AppConstants.superadminConfigCollection)
        .doc('settings')
        .set(configData);
    
    print('✅ SuperAdmin configuration created');
  }

  /// Create system metadata
  Future<void> _createSystemMetadata() async {
    print('📊 Creating system metadata...');
    
    final metadataData = {
      'totalOrganizations': 1,
      'totalUsers': 1,
      'activeOrganizations': 1,
      'activeUsers': 1,
      'totalSuperAdmins': 1,
      'lastUpdated': Timestamp.now(),
      'systemVersion': '1.0.0',
      'databaseVersion': '1.0.0'
    };

    await _firestore
        .collection(AppConstants.systemMetadataCollection)
        .doc('stats')
        .set(metadataData);
    
    print('✅ System metadata created');
  }

  /// Create SuperAdmin user in organization subcollection
  Future<void> _createSuperAdminOrgUser(String firebaseAuthUid) async {
    print('👥 Creating SuperAdmin user in organization...');
    
    final orgUserData = {
      'userId': firebaseAuthUid,
      'name': 'Super Admin',
      'phoneNo': '+919876543210',
      'email': 'admin@operon.com',
      'role': AppConstants.superAdminRole,
      'status': AppConstants.userStatusActive,
      'addedDate': Timestamp.now(),
      'updatedDate': Timestamp.now(),
      'addedBy': 'system',
      'permissions': ['all']
    };

    await _firestore
        .collection(AppConstants.organizationsCollection)
        .doc(AppConstants.superAdminOrgId)
        .collection(AppConstants.usersSubcollection)
        .doc(firebaseAuthUid)
        .set(orgUserData);
    
    print('✅ SuperAdmin user added to organization');
  }
}

/// Standalone function to run the initialization
/// Call this from main.dart or run as a separate script
Future<void> initializeSuperAdminData(String firebaseAuthUid) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final initializer = SuperAdminInitializer();
  await initializer.initializeSuperAdmin(firebaseAuthUid);
}

/// Example usage:
/// 
/// ```dart
/// void main() async {
///   // Replace with actual Firebase Auth UID
///   const firebaseAuthUid = 'uRlsu5TXCnZhNjedSPpQLQujd5L2';
///   await initializeSuperAdminData(firebaseAuthUid);
/// }
/// ```
