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

  factory PaymentAccount.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Debug: Print all available fields
    print('PaymentAccount document ${doc.id} fields: ${data.keys.toList()}');

    try {
      return PaymentAccount(
        id: doc.id,
        accountId: data['accountId'] ?? data['account_id'] ?? '',
        accountName: data['accountName'] ?? data['account_name'] ?? '',
        accountType: data['accountType'] ?? data['account_type'] ?? '',
        accountNumber: data['accountNumber'] ?? data['account_number'],
        bankName: data['bankName'] ?? data['bank_name'],
        ifscCode: data['ifscCode'] ?? data['ifsc_code'] ?? data['ifsc'],
        currency: data['currency'] ?? 'INR',
        status: data['status'] ?? 'Active',
        isDefault: data['isDefault'] ?? data['is_default'] ?? false,
        staticQr: data['staticQr'] ?? data['static_qr'] ?? data['qrCode'],
        createdAt: (data['createdAt'] ?? data['created_at']) != null
            ? ((data['createdAt'] ?? data['created_at']) as Timestamp).toDate()
            : DateTime.now(),
        updatedAt: (data['updatedAt'] ?? data['updated_at']) != null
            ? ((data['updatedAt'] ?? data['updated_at']) as Timestamp).toDate()
            : DateTime.now(),
        createdBy: data['createdBy'] ?? data['created_by'],
        updatedBy: data['updatedBy'] ?? data['updated_by'],
      );
    } catch (e, stackTrace) {
      print('Error creating PaymentAccount from document ${doc.id}: $e');
      print('Stack trace: $stackTrace');
      print('Document data: $data');
      rethrow;
    }
  }

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

  bool get isActive => status == 'Active';
}

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

class PaymentAccountStatus {
  static const String active = 'Active';
  static const String inactive = 'Inactive';

  static const List<String> all = [
    active,
    inactive,
  ];
}

