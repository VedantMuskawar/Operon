import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_constants.dart';
import '../user.dart' as app_user;

class AndroidAuthRepository {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _verificationId;
  int? _resendToken;

  // Send OTP to phone number (no Super Admin restriction)
  Future<void> sendOTP(String phoneNumber) async {
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
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      throw Exception('Failed to send OTP: ${e.toString()}');
    }
  }

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
    final userRef = _firestore.collection(AppConstants.usersCollection).doc(firebaseUser.uid);
    final docSnapshot = await userRef.get();
    
    if (!docSnapshot.exists) {
      throw Exception('User not found. Please contact your administrator.');
    }
    
    final userData = docSnapshot.data()!;
    final organizations = userData['organizations'] as List<dynamic>? ?? [];
    
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

  // Get user's organizations
  Future<List<Map<String, dynamic>>> getUserOrganizations(String userId) async {
    final userDoc = await getUserDocument(userId);
    if (userDoc == null) return [];
    
    final organizations = userDoc['organizations'] as List<dynamic>? ?? [];
    return organizations.cast<Map<String, dynamic>>();
  }
}



