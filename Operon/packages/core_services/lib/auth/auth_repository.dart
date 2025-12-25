import 'package:core_models/core_models.dart';

abstract class AuthRepository {
  Future<PhoneAuthSession> sendOtp({required String phoneNumber});

  Future<UserProfile> verifyOtp({
    required String verificationId,
    required String smsCode,
  });

  Future<UserProfile?> currentUser();

  Future<void> signOut();

  Future<bool> isAuthorizedSuperAdmin(String phoneNumber);
}
