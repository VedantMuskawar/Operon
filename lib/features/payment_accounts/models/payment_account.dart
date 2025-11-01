import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentAccount {
  final String? id;
  final String accountId;
  final String accountName;
  final String accountType;
  final String? accountNumber;
  final String? bankName;
  final String? ifscCode;
  final String currency;
  final String status;
  final bool isDefault;
  final String? staticQr;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;

  PaymentAccount({
    this.id,
    required this.accountId,
    required this.accountName,
    required this.accountType,
    this.accountNumber,
    this.bankName,
    this.ifscCode,
    this.currency = 'INR',
    this.status = 'Active',
    this.isDefault = false,
    this.staticQr,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  // Create PaymentAccount from Firestore document
  factory PaymentAccount.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return PaymentAccount(
      id: doc.id,
      accountId: data['accountId'] ?? '',
      accountName: data['accountName'] ?? '',
      accountType: data['accountType'] ?? '',
      accountNumber: data['accountNumber'],
      bankName: data['bankName'],
      ifscCode: data['ifscCode'],
      currency: data['currency'] ?? 'INR',
      status: data['status'] ?? 'Active',
      isDefault: data['isDefault'] ?? false,
      staticQr: data['staticQr'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'],
      updatedBy: data['updatedBy'],
    );
  }

  // Convert PaymentAccount to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'accountId': accountId,
      'accountName': accountName,
      'accountType': accountType,
      if (accountNumber != null) 'accountNumber': accountNumber,
      if (bankName != null) 'bankName': bankName,
      if (ifscCode != null) 'ifscCode': ifscCode,
      'currency': currency,
      'status': status,
      'isDefault': isDefault,
      if (staticQr != null) 'staticQr': staticQr,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (createdBy != null) 'createdBy': createdBy,
      if (updatedBy != null) 'updatedBy': updatedBy,
    };
  }

  // Create copy of PaymentAccount with updated fields
  PaymentAccount copyWith({
    String? accountId,
    String? accountName,
    String? accountType,
    String? accountNumber,
    String? bankName,
    String? ifscCode,
    String? currency,
    String? status,
    bool? isDefault,
    String? staticQr,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return PaymentAccount(
      id: id,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      accountType: accountType ?? this.accountType,
      accountNumber: accountNumber ?? this.accountNumber,
      bankName: bankName ?? this.bankName,
      ifscCode: ifscCode ?? this.ifscCode,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      isDefault: isDefault ?? this.isDefault,
      staticQr: staticQr ?? this.staticQr,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  // Check if account is active
  bool get isActive => status == 'Active';

  @override
  String toString() {
    return 'PaymentAccount(id: $id, accountId: $accountId, accountName: $accountName, type: $accountType, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaymentAccount && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Payment account types
class PaymentAccountType {
  static const String bankAccount = 'Bank Account';
  static const String digitalWallet = 'Digital Wallet';
  static const String paymentGateway = 'Payment Gateway';
  static const String other = 'Other';

  static const List<String> all = [
    bankAccount,
    digitalWallet,
    paymentGateway,
    other,
  ];
}

// Payment account status
class PaymentAccountStatus {
  static const String active = 'Active';
  static const String inactive = 'Inactive';

  static const List<String> all = [
    active,
    inactive,
  ];
}

