import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType {
  advance,
  payment,
  refund,
  adjustment,
  credit,
  debit,
}

enum TransactionCategory {
  income,
  expense,
}

enum TransactionStatus {
  pending,
  completed,
  cancelled,
}

class Transaction {
  const Transaction({
    required this.id,
    required this.organizationId,
    required this.clientId,
    required this.type,
    required this.category,
    required this.amount,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.financialYear,
    this.paymentAccountId,
    this.paymentAccountType,
    this.referenceNumber,
    this.orderId,
    this.description,
    this.metadata,
    this.cancelledAt,
    this.cancelledBy,
    this.cancellationReason,
    this.balanceBefore,
    this.balanceAfter,
  });

  final String id;
  final String organizationId;
  final String clientId;
  final TransactionType type;
  final TransactionCategory category;
  final double amount;
  final TransactionStatus status;
  final String? paymentAccountId;
  final String? paymentAccountType; // "bank" | "cash" | "upi" | "other"
  final String? referenceNumber;
  final String? orderId;
  final String? description;
  final Map<String, dynamic>? metadata;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final String? cancellationReason;
  final String financialYear;
  final double? balanceBefore;
  final double? balanceAfter;

  Map<String, dynamic> toJson() {
    return {
      'transactionId': id,
      'organizationId': organizationId,
      'clientId': clientId,
      'type': type.name,
      'category': category.name,
      'amount': amount,
      'status': status.name,
      'currency': 'INR',
      if (paymentAccountId != null) 'paymentAccountId': paymentAccountId,
      if (paymentAccountType != null) 'paymentAccountType': paymentAccountType,
      if (referenceNumber != null) 'referenceNumber': referenceNumber,
      if (orderId != null) 'orderId': orderId,
      if (description != null) 'description': description,
      if (metadata != null) 'metadata': metadata,
      'createdBy': createdBy,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      if (cancelledAt != null) 'cancelledAt': Timestamp.fromDate(cancelledAt!),
      if (cancelledBy != null) 'cancelledBy': cancelledBy,
      if (cancellationReason != null) 'cancellationReason': cancellationReason,
      'financialYear': financialYear,
      if (balanceBefore != null) 'balanceBefore': balanceBefore,
      if (balanceAfter != null) 'balanceAfter': balanceAfter,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json, String docId) {
    return Transaction(
      id: json['transactionId'] as String? ?? docId,
      organizationId: json['organizationId'] as String? ?? '',
      clientId: json['clientId'] as String? ?? '',
      type: TransactionType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => TransactionType.advance,
      ),
      category: TransactionCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => TransactionCategory.income,
      ),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: TransactionStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => TransactionStatus.pending,
      ),
      paymentAccountId: json['paymentAccountId'] as String?,
      paymentAccountType: json['paymentAccountType'] as String?,
      referenceNumber: json['referenceNumber'] as String?,
      orderId: json['orderId'] as String?,
      description: json['description'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
      cancelledAt: (json['cancelledAt'] as Timestamp?)?.toDate(),
      cancelledBy: json['cancelledBy'] as String?,
      cancellationReason: json['cancellationReason'] as String?,
      financialYear: json['financialYear'] as String? ?? '',
      balanceBefore: (json['balanceBefore'] as num?)?.toDouble(),
      balanceAfter: (json['balanceAfter'] as num?)?.toDouble(),
    );
  }

  Transaction copyWith({
    String? id,
    String? organizationId,
    String? clientId,
    TransactionType? type,
    TransactionCategory? category,
    double? amount,
    TransactionStatus? status,
    String? paymentAccountId,
    String? paymentAccountType,
    String? referenceNumber,
    String? orderId,
    String? description,
    Map<String, dynamic>? metadata,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? cancelledAt,
    String? cancelledBy,
    String? cancellationReason,
    String? financialYear,
    double? balanceBefore,
    double? balanceAfter,
  }) {
    return Transaction(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      clientId: clientId ?? this.clientId,
      type: type ?? this.type,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      paymentAccountId: paymentAccountId ?? this.paymentAccountId,
      paymentAccountType: paymentAccountType ?? this.paymentAccountType,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      orderId: orderId ?? this.orderId,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      financialYear: financialYear ?? this.financialYear,
      balanceBefore: balanceBefore ?? this.balanceBefore,
      balanceAfter: balanceAfter ?? this.balanceAfter,
    );
  }
}

