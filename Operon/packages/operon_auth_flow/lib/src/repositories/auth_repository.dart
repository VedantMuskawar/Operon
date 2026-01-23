import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_models/core_models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

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

  Future<PhoneAuthSession> sendOtp({
    required String phoneNumber,
    int? forceResendingToken,
  }) async {
    // #region agent log
    try { File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').writeAsStringSync('${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').readAsStringSync()}${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').existsSync() ? '\n' : ''}{"sessionId":"debug-session","runId":"run1","hypothesisId":"A","location":"auth_repository.dart:21","message":"sendOtp entry","data":{"phoneNumber":"$phoneNumber","hasResendToken":${forceResendingToken != null}},"timestamp":${DateTime.now().millisecondsSinceEpoch}}\n', mode: FileMode.append); } catch (_) {}
    // #endregion
    final completer = Completer<PhoneAuthSession>();

    // Add timeout to prevent infinite waiting
    // Note: Firebase's verifyPhoneNumber timeout is 60s, so we set ours to 70s to catch it
    Timer? timeoutTimer;
    timeoutTimer = Timer(const Duration(seconds: 70), () {
      // #region agent log
      try { File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').writeAsStringSync('${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').readAsStringSync()}${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').existsSync() ? '\n' : ''}{"sessionId":"debug-session","runId":"run1","hypothesisId":"F","location":"auth_repository.dart:30","message":"Timer timeout fired","data":{"completerCompleted":${completer.isCompleted}},"timestamp":${DateTime.now().millisecondsSinceEpoch}}\n', mode: FileMode.append); } catch (_) {}
      // #endregion
      if (!completer.isCompleted) {
        // Get actual package name dynamically from Firebase app options
        String packageName = 'unknown';
        try {
          // Try to extract package name from Firebase Android options
          final androidOptions = Firebase.app().options;
          // #region agent log
          try { File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').writeAsStringSync('${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').readAsStringSync()}${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').existsSync() ? '\n' : ''}{"sessionId":"debug-session","runId":"run1","hypothesisId":"E","location":"auth_repository.dart:41","message":"Extracting package name","data":{"androidClientId":"${androidOptions.androidClientId}","appName":"${Firebase.app().name}"},"timestamp":${DateTime.now().millisecondsSinceEpoch}}\n', mode: FileMode.append); } catch (_) {}
          // #endregion
          if (androidOptions.androidClientId != null && androidOptions.androidClientId!.isNotEmpty) {
            // Extract package from client ID (format: package_name:sha1)
            final parts = androidOptions.androidClientId!.split(':');
            if (parts.isNotEmpty) {
              packageName = parts[0];
            }
          }
          // If still unknown, try to infer from app name
          if (packageName == 'unknown') {
            final appName = Firebase.app().name;
            if (appName.contains('driver') || appName.contains('Driver')) {
              packageName = 'com.operondriverandroid.app';
            } else {
              packageName = 'com.operonclientandroid.app';
            }
          }
        } catch (e) {
          // #region agent log
          try { File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').writeAsStringSync('${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').readAsStringSync()}${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').existsSync() ? '\n' : ''}{"sessionId":"debug-session","runId":"run1","hypothesisId":"E","location":"auth_repository.dart:55","message":"Package name extraction failed","data":{"error":"$e"},"timestamp":${DateTime.now().millisecondsSinceEpoch}}\n', mode: FileMode.append); } catch (_) {}
          // #endregion
          packageName = 'com.operonclientandroid.app'; // Default fallback
        }
        
        completer.completeError(
          TimeoutException(
            'Phone verification request timed out. This usually means:\n'
            '1. SHA-1 fingerprint is not added to Firebase Console\n'
            '2. Network connectivity issues\n'
            '3. Firebase Authentication is not properly configured\n\n'
            'Please check Firebase Console and ensure SHA-1 fingerprint is added for package: $packageName',
            const Duration(seconds: 70),
          ),
        );
      }
    });

    try {
      debugPrint('[AuthRepository] Starting verifyPhoneNumber for $phoneNumber');
      // #region agent log
      try { File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').writeAsStringSync('${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').readAsStringSync()}${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').existsSync() ? '\n' : ''}{"sessionId":"debug-session","runId":"run1","hypothesisId":"B","location":"auth_repository.dart:47","message":"Before verifyPhoneNumber call","data":{"phoneNumber":"$phoneNumber","authInstance":"${_auth.app.name}"},"timestamp":${DateTime.now().millisecondsSinceEpoch}}\n', mode: FileMode.append); } catch (_) {}
      // #endregion
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        forceResendingToken: forceResendingToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          // #region agent log
          try { File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').writeAsStringSync('${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').readAsStringSync()}${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').existsSync() ? '\n' : ''}{"sessionId":"debug-session","runId":"run1","hypothesisId":"C","location":"auth_repository.dart:51","message":"verificationCompleted callback fired","data":{"hasVerificationId":${credential.verificationId != null}},"timestamp":${DateTime.now().millisecondsSinceEpoch}}\n', mode: FileMode.append); } catch (_) {}
          // #endregion
          debugPrint('[AuthRepository] verificationCompleted callback fired');
          timeoutTimer?.cancel();
          try {
            await _auth.signInWithCredential(credential);
            if (!completer.isCompleted) {
              debugPrint('[AuthRepository] Auto-verification successful');
              completer.complete(
                PhoneAuthSession(
                  phoneNumber: phoneNumber,
                  verificationId: credential.verificationId,
                  isVerified: true,
                ),
              );
            }
          } catch (e) {
            debugPrint('[AuthRepository] Error in verificationCompleted: $e');
            if (!completer.isCompleted) completer.completeError(e);
          }
        },
        verificationFailed: (exception) {
          // #region agent log
          try { File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').writeAsStringSync('${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').readAsStringSync()}${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').existsSync() ? '\n' : ''}{"sessionId":"debug-session","runId":"run1","hypothesisId":"A","location":"auth_repository.dart:71","message":"verificationFailed callback fired","data":{"code":"${exception.code}","message":"${exception.message}"},"timestamp":${DateTime.now().millisecondsSinceEpoch}}\n', mode: FileMode.append); } catch (_) {}
          // #endregion
          debugPrint('[AuthRepository] verificationFailed callback fired: ${exception.code} - ${exception.message}');
          timeoutTimer?.cancel();
          if (!completer.isCompleted) completer.completeError(exception);
        },
        codeSent: (verificationId, forceResendingToken) {
          // #region agent log
          try { File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').writeAsStringSync('${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').readAsStringSync()}${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').existsSync() ? '\n' : ''}{"sessionId":"debug-session","runId":"run1","hypothesisId":"C","location":"auth_repository.dart:76","message":"codeSent callback fired","data":{"verificationId":"$verificationId","hasResendToken":${forceResendingToken != null}},"timestamp":${DateTime.now().millisecondsSinceEpoch}}\n', mode: FileMode.append); } catch (_) {}
          // #endregion
          debugPrint('[AuthRepository] codeSent callback fired - verificationId: $verificationId');
          timeoutTimer?.cancel();
          if (!completer.isCompleted) {
            completer.complete(
              PhoneAuthSession(
                phoneNumber: phoneNumber,
                verificationId: verificationId,
                resendToken: forceResendingToken,
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          // #region agent log
          try { File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').writeAsStringSync('${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').readAsStringSync()}${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').existsSync() ? '\n' : ''}{"sessionId":"debug-session","runId":"run1","hypothesisId":"C","location":"auth_repository.dart:89","message":"codeAutoRetrievalTimeout callback fired","data":{"verificationId":"$verificationId"},"timestamp":${DateTime.now().millisecondsSinceEpoch}}\n', mode: FileMode.append); } catch (_) {}
          // #endregion
          debugPrint('[AuthRepository] codeAutoRetrievalTimeout callback fired - verificationId: $verificationId');
          timeoutTimer?.cancel();
          if (!completer.isCompleted) {
            completer.complete(
              PhoneAuthSession(
                phoneNumber: phoneNumber,
                verificationId: verificationId,
                isVerified: false,
              ),
            );
          }
        },
      );
      // #region agent log
      try { File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').writeAsStringSync('${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').readAsStringSync()}${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').existsSync() ? '\n' : ''}{"sessionId":"debug-session","runId":"run1","hypothesisId":"B","location":"auth_repository.dart:103","message":"After verifyPhoneNumber call","data":{},"timestamp":${DateTime.now().millisecondsSinceEpoch}}\n', mode: FileMode.append); } catch (_) {}
      // #endregion
      debugPrint('[AuthRepository] verifyPhoneNumber call completed, waiting for callbacks...');
    } catch (e) {
      // #region agent log
      try { File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').writeAsStringSync('${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').readAsStringSync()}${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').existsSync() ? '\n' : ''}{"sessionId":"debug-session","runId":"run1","hypothesisId":"B","location":"auth_repository.dart:104","message":"Exception in verifyPhoneNumber","data":{"error":"$e"},"timestamp":${DateTime.now().millisecondsSinceEpoch}}\n', mode: FileMode.append); } catch (_) {}
      // #endregion
      debugPrint('[AuthRepository] Exception in verifyPhoneNumber: $e');
      timeoutTimer?.cancel();
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }

    // #region agent log
    try { File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').writeAsStringSync('${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').readAsStringSync()}${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').existsSync() ? '\n' : ''}{"sessionId":"debug-session","runId":"run1","hypothesisId":"A","location":"auth_repository.dart:112","message":"Returning completer future","data":{},"timestamp":${DateTime.now().millisecondsSinceEpoch}}\n', mode: FileMode.append); } catch (_) {}
    // #endregion
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
      role: UserRole.user,
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
      role: UserRole.user,
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }

  Future<void> signOut() => _auth.signOut();
}

