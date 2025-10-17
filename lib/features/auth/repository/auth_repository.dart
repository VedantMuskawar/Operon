import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/user.dart' as app_user;
import '../../../core/repositories/config_repository.dart';

class AuthRepository {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ConfigRepository _configRepository = ConfigRepository();

  // Check if phone number is authorized for Super Admin
  bool isAuthorizedPhoneNumber(String phoneNumber) {
    // Remove any formatting and compare
    String cleanInput = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // Extract the 10-digit mobile number from the authorized number
    String authorizedNumber = AppConstants.superAdminPhoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    String authorizedMobileNumber = authorizedNumber.substring(authorizedNumber.length - 10);
    
    // Debug logging
    print('🔍 Phone Number Verification:');
    print('  Input: $phoneNumber');
    print('  Clean Input: $cleanInput');
    print('  Authorized Number: ${AppConstants.superAdminPhoneNumber}');
    print('  Clean Authorized: $authorizedNumber');
    print('  Mobile Number: $authorizedMobileNumber');
    print('  Match: ${cleanInput == authorizedMobileNumber}');
    
    // Compare the 10-digit mobile numbers
    return cleanInput == authorizedMobileNumber;
  }

  // Send OTP to phone number
  Future<void> sendOTP(String phoneNumber) async {
    if (!isAuthorizedPhoneNumber(phoneNumber)) {
      throw Exception('Unauthorized phone number');
    }

    // Format phone number for Firebase (ensure it has +91 prefix)
    String formattedPhoneNumber = phoneNumber.startsWith('+91') 
        ? phoneNumber 
        : '+91$phoneNumber';

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
      
      // Create or update user document
      await _createOrUpdateUserDocument(userCredential.user!);
      
      // Initialize collections if they don't exist (first Super Admin login)
      await _initializeCollectionsIfNeeded();
      
      return userCredential.user;
    } catch (e) {
      throw Exception('Invalid OTP: ${e.toString()}');
    }
  }

  // Create or update user document in Firestore
  Future<void> _createOrUpdateUserDocument(firebase_auth.User firebaseUser) async {
    final userRef = _firestore.collection(AppConstants.usersCollection).doc(firebaseUser.uid);
    
    final docSnapshot = await userRef.get();
    
    if (!docSnapshot.exists) {
      // Create new user document
      final newUser = app_user.User(
        userId: firebaseUser.uid,
        name: 'Super Admin',
        phoneNo: firebaseUser.phoneNumber ?? '',
        email: firebaseUser.email ?? '',
        profilePhotoUrl: null,
        status: AppConstants.userStatusActive,
        createdDate: DateTime.now(),
        updatedDate: DateTime.now(),
        lastLoginDate: DateTime.now(),
        metadata: const app_user.UserMetadata(
          totalOrganizations: 0,
          primaryOrgId: null,
          notificationPreferences: {},
        ),
      );
      
      await userRef.set(newUser.toMap());
    } else {
      // Update last login date
      await userRef.update({
        'lastLoginDate': Timestamp.fromDate(DateTime.now()),
        'updatedDate': Timestamp.fromDate(DateTime.now()),
      });
    }
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

  // Initialize SUPERADMIN_CONFIG and SYSTEM_METADATA collections if they don't exist
  Future<void> _initializeCollectionsIfNeeded() async {
    try {
      await _configRepository.initializeCollectionsIfNeeded();
    } catch (e) {
      // Log error but don't throw - this shouldn't prevent login
      print('Warning: Failed to initialize collections: $e');
    }
  }
}
