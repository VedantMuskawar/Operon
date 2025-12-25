enum PaymentAccountType { bank, cash, upi, other }

class PaymentAccount {
  const PaymentAccount({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.type,
    this.accountNumber,
    this.ifscCode,
    this.upiId,
    this.qrCodeImageUrl,
    this.isActive = true,
    this.isPrimary = false,
  });

  final String id;
  final String organizationId;
  final String name;
  final PaymentAccountType type;
  final String? accountNumber;
  final String? ifscCode;
  final String? upiId;
  final String? qrCodeImageUrl; // Firebase Storage URL
  final bool isActive;
  final bool isPrimary;

  /// Generate UPI QR code data string
  /// Format: upi://pay?pa=<UPI_ID>&pn=<PAYEE_NAME>&cu=INR
  String? get upiQrData {
    if (type != PaymentAccountType.upi && type != PaymentAccountType.bank) {
      return null;
    }
    if (upiId == null || upiId!.isEmpty) {
      return null;
    }
    // Encode the payee name (account name)
    final encodedName = Uri.encodeComponent(name);
    return 'upi://pay?pa=$upiId&pn=$encodedName&cu=INR';
  }

  Map<String, dynamic> toJson() {
    return {
      'accountId': id,
      'organizationId': organizationId,
      'name': name,
      'type': type.name,
      if (accountNumber != null) 'accountNumber': accountNumber,
      if (ifscCode != null) 'ifscCode': ifscCode,
      if (upiId != null) 'upiId': upiId,
      if (qrCodeImageUrl != null) 'qrCodeImageUrl': qrCodeImageUrl,
      'isActive': isActive,
      'isPrimary': isPrimary,
    };
  }

  factory PaymentAccount.fromJson(Map<String, dynamic> json, String docId) {
    return PaymentAccount(
      id: json['accountId'] as String? ?? docId,
      organizationId: json['organizationId'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed Account',
      type: PaymentAccountType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => PaymentAccountType.other,
      ),
      accountNumber: json['accountNumber'] as String?,
      ifscCode: json['ifscCode'] as String?,
      upiId: json['upiId'] as String?,
      qrCodeImageUrl: json['qrCodeImageUrl'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      isPrimary: json['isPrimary'] as bool? ?? false,
    );
  }

  PaymentAccount copyWith({
    String? id,
    String? organizationId,
    String? name,
    PaymentAccountType? type,
    String? accountNumber,
    String? ifscCode,
    String? upiId,
    String? qrCodeImageUrl,
    bool? isActive,
    bool? isPrimary,
  }) {
    return PaymentAccount(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      name: name ?? this.name,
      type: type ?? this.type,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      upiId: upiId ?? this.upiId,
      qrCodeImageUrl: qrCodeImageUrl ?? this.qrCodeImageUrl,
      isActive: isActive ?? this.isActive,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}

