import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_models/core_models.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  FirebaseAuth get auth => _auth;
  FirebaseFirestore get firestore => _firestore;

  Future<PhoneAuthSession> sendOtp({required String phoneNumber}) async {
    final completer = Completer<PhoneAuthSession>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        final userCredential = await _auth.signInWithCredential(credential);
        completer.complete(
          PhoneAuthSession(
            phoneNumber: phoneNumber,
            verificationId: credential.verificationId,
            isVerified: userCredential.user != null,
          ),
        );
      },
      verificationFailed: (exception) {
        completer.completeError(exception);
      },
      codeSent: (verificationId, resendToken) {
        completer.complete(
          PhoneAuthSession(
            phoneNumber: phoneNumber,
            verificationId: verificationId,
            resendToken: resendToken,
          ),
        );
      },
      codeAutoRetrievalTimeout: (_) {},
    );

    return completer.future;
  }

  Future<UserProfile> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user!;
    return UserProfile(
      id: user.uid,
      phoneNumber: user.phoneNumber ?? '',
      role: UserRole.superAdmin,
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }

  Future<UserProfile?> currentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return UserProfile(
      id: user.uid,
      phoneNumber: user.phoneNumber ?? '',
      role: UserRole.superAdmin,
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }

  Future<void> signOut() => _auth.signOut();
}
