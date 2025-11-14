import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/user.dart' as app_user;
import '../../../core/repositories/config_repository.dart';

class AuthRepository {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ConfigRepository _configRepository = ConfigRepository();

  // Check if phone number is valid (10 digits)
  bool isValidPhoneNumber(String phoneNumber) {
    String cleanInput = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    return cleanInput.length == 10;
  }

  // Send OTP to phone number
  Future<void> sendOTP(String phoneNumber) async {
    if (!isValidPhoneNumber(phoneNumber)) {
      throw Exception('Please enter a valid 10-digit phone number');
    }

    // Format phone number for Firebase (ensure it has +91 prefix)
    String formattedPhoneNumber = phoneNumber.startsWith('+91') 
        ? phoneNumber 
        : '+91$phoneNumber';

    // For development, use test phone numbers to bypass reCAPTCHA
    if (_isTestPhoneNumber(formattedPhoneNumber)) {
      print('Using test phone number: $formattedPhoneNumber');
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhoneNumber,
        verificationCompleted: (firebase_auth.PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (firebase_auth.FirebaseAuthException e) {
          // Enhanced error handling for real phone numbers
          String errorMessage = 'Verification failed';
          
          switch (e.code) {
            case 'invalid-phone-number':
              errorMessage = 'Invalid phone number format';
              break;
            case 'too-many-requests':
              errorMessage = 'Too many requests. Please try again later';
              break;
            case 'quota-exceeded':
              errorMessage = 'SMS quota exceeded. Please try again later';
              break;
            case 'captcha-check-failed':
              errorMessage = 'reCAPTCHA verification failed. Please try again';
              break;
            case 'missing-phone-number':
              errorMessage = 'Phone number is required';
              break;
            case 'invalid-verification-code':
              errorMessage = 'Invalid verification code';
              break;
            case 'invalid-verification-id':
              errorMessage = 'Invalid verification ID';
              break;
            default:
              errorMessage = 'Verification failed: ${e.message}';
          }
          
          throw Exception(errorMessage);
        },
        codeSent: (String verificationId, int? resendToken) {
          // Store verification ID for later use
          _verificationId = verificationId;
          _resendToken = resendToken;
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        // Add timeout for real phone numbers
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      throw Exception('Failed to send OTP: ${e.toString()}');
    }
  }

  // Check if phone number is a test number (for development)
  bool _isTestPhoneNumber(String phoneNumber) {
    // Firebase test phone numbers for development
    const testNumbers = [
      '+919876543210', // Super Admin test number
      '+1234567890',   // Generic test number
    ];
    return testNumbers.contains(phoneNumber);
  }

  String? _verificationId;
  int? _resendToken;

  // Verify OTP and sign in
  Future<firebase_auth.User?> verifyOTPAndSignIn(String otp) async {
    if (_verificationId == null) {
      throw Exception('No verification ID found. Please request OTP again.');
    }

    try {
      firebase_auth.PhoneAuthCredential credential = firebase_auth.PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      firebase_auth.UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      // Verify user exists in USERS collection and has organization access
      await _verifyUserAccess(userCredential.user!);
      
      // Update last login date
      await _updateLastLoginDate(userCredential.user!);
      
      return userCredential.user;
    } catch (e) {
      throw Exception('Invalid OTP: ${e.toString()}');
    }
  }

  // Verify user has access to at least one organization
  Future<void> _verifyUserAccess(firebase_auth.User firebaseUser) async {
    print('🔍 Checking user access for UID: ${firebaseUser.uid}');
    print('🔍 Phone number: ${firebaseUser.phoneNumber}');
    
    final userRef = _firestore.collection(AppConstants.usersCollection).doc(firebaseUser.uid);
    var docSnapshot = await userRef.get();
    
    print('🔍 Document exists: ${docSnapshot.exists}');
    
    if (!docSnapshot.exists) {
      print('🔍 Trying phone number lookup...');
      // Try phone number lookup for pre-created users
      final phoneQuery = await _firestore
          .collection(AppConstants.usersCollection)
          .where('phoneNo', isEqualTo: firebaseUser.phoneNumber)
          .limit(1)
          .get();
      
      if (phoneQuery.docs.isEmpty) {
        print('❌ User document not found in USERS collection');
        throw Exception('User not found. Please contact your administrator.');
      }
      
      print('🔍 Found user by phone number, migrating to correct UID...');
      // Migrate user document to correct UID
      await _migrateUserDocument(phoneQuery.docs.first, firebaseUser.uid);
      docSnapshot = await userRef.get();
    }
    
    final userData = docSnapshot.data()!;
    print('🔍 User data: ${userData.toString()}');
    
    final organizations = userData['organizations'] as List<dynamic>? ?? [];
    print('🔍 Organizations found: ${organizations.length}');
    
    if (organizations.isEmpty) {
      throw Exception('No organization access found. Please contact your administrator.');
    }
    
    // Check if user has at least one active organization
    bool hasActiveOrg = false;
    for (var org in organizations) {
      if (org['status'] == AppConstants.orgStatusActive) {
        hasActiveOrg = true;
        break;
      }
    }
    
    if (!hasActiveOrg) {
      throw Exception('No active organization access. Please contact your administrator.');
    }
    
    print('✅ User access verified successfully');
  }

  // Update last login date
  Future<void> _updateLastLoginDate(firebase_auth.User firebaseUser) async {
    final userRef = _firestore.collection(AppConstants.usersCollection).doc(firebaseUser.uid);
    await userRef.update({
      'lastLoginDate': Timestamp.fromDate(DateTime.now()),
      'updatedDate': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Get current user
  firebase_auth.User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    _verificationId = null;
    _resendToken = null;
  }

  // Check if user is authenticated
  bool isAuthenticated() {
    return _auth.currentUser != null;
  }

  // Stream of auth state changes
  Stream<firebase_auth.User?> get authStateChanges => _auth.authStateChanges();

  // Get user document from Firestore
  Future<Map<String, dynamic>?> getUserDocument(String userId) async {
    final docSnapshot = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .get();
    
    return docSnapshot.exists ? docSnapshot.data() : null;
  }

  // Check if user is Super Admin
  bool isSuperAdmin(firebase_auth.User firebaseUser) {
    // This method is not used in the current flow
    // SuperAdmin status is determined in the auth bloc based on user's organizations
    // Return false as a fallback - the actual determination happens in auth bloc
    return false;
  }

  // Get user organizations
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

  // Migrate user document from old ID to Firebase Auth UID
  Future<void> _migrateUserDocument(
    DocumentSnapshot oldDoc,
    String newUid,
  ) async {
    try {
      print('🔄 Migrating user document from ${oldDoc.id} to $newUid');
      
      final data = oldDoc.data() as Map<String, dynamic>;
      data['userId'] = newUid;
      data['updatedDate'] = Timestamp.fromDate(DateTime.now());
      
      // Create new document with correct UID
      await _firestore.collection(AppConstants.usersCollection).doc(newUid).set(data);
      
      // Delete old document
      await oldDoc.reference.delete();
      
      print('✅ User document migrated successfully');
    } catch (e) {
      print('❌ Error migrating user document: $e');
      throw Exception('Failed to migrate user data: $e');
    }
  }

  // Initialize SUPERADMIN_CONFIG collection if it doesn't exist
  Future<void> _initializeCollectionsIfNeeded() async {
    try {
      await _configRepository.ensureSuperAdminConfigExists();
    } catch (e) {
      // Log error but don't throw - this shouldn't prevent login
      print('Warning: Failed to initialize collections: $e');
    }
  }
}
