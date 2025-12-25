class PhoneAuthSession {
  const PhoneAuthSession({
    required this.phoneNumber,
    this.verificationId,
    this.resendToken,
    this.isVerified = false,
  });

  final String phoneNumber;
  final String? verificationId;
  final int? resendToken;
  final bool isVerified;

  PhoneAuthSession copyWith({
    String? verificationId,
    int? resendToken,
    bool? isVerified,
  }) {
    return PhoneAuthSession(
      phoneNumber: phoneNumber,
      verificationId: verificationId ?? this.verificationId,
      resendToken: resendToken ?? this.resendToken,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  @override
  String toString() =>
      'PhoneAuthSession(phone: $phoneNumber, verified: $isVerified)';
}
