part of 'auth_bloc.dart';

abstract class AuthEvent {
  const AuthEvent();
}

class PhoneNumberSubmitted extends AuthEvent {
  const PhoneNumberSubmitted(this.phoneNumber);

  final String phoneNumber;
}

class OtpSubmitted extends AuthEvent {
  const OtpSubmitted({
    required this.verificationId,
    required this.code,
  });

  final String verificationId;
  final String code;
}

class AuthReset extends AuthEvent {
  const AuthReset();
}

class AuthStatusRequested extends AuthEvent {
  const AuthStatusRequested();
}

