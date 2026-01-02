import 'package:cloud_firestore/cloud_firestore.dart';

/// Ledger types for transactions
enum LedgerType {
  clientLedger,
  vendorLedger,
  employeeLedger,
  organizationLedger, // For general business expenses
  // Future: bankLedger, etc.
}

/// Simplified transaction types
/// Credit = Increases receivable (client owes us)
/// Debit = Decreases receivable (client paid us)
enum TransactionType {
  credit,
  debit,
}

/// Transaction categories for context
enum TransactionCategory {
  advance,          // Advance payment on order
  clientCredit,     // Client owes (PayLater order)
  tripPayment,      // Payment collected on delivery
  clientPayment,    // General payment recorded manually
  refund,           // Refund given to client
  adjustment,       // Manual adjustment
  vendorPurchase,   // Purchase from vendor (credit transaction)
  vendorPayment,    // Payment to vendor (debit on vendorLedger)
  salaryCredit,     // Monthly salary credit to employee
  salaryDebit,      // Salary payment to employee (debit on employeeLedger)
  bonus,            // Bonus payment to employee
  employeeAdvance,  // Advance payment to employee (future use)
  employeeAdjustment, // Manual adjustment for employee
  generalExpense,   // General business expense (debit on organizationLedger)
}

class Transaction {
  const Transaction({
    required this.id,
    required this.organizationId,
    this.clientId,
    this.vendorId,
    this.employeeId,
    required this.ledgerType,
    required this.type,
    required this.category,
    required this.amount,
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
    this.balanceBefore,
    this.balanceAfter,
  });

  final String id;
  final String organizationId;
  final String? clientId; // Optional for general expenses
  final String? vendorId; // For vendor ledger transactions
  final String? employeeId; // For employee ledger transactions
  final LedgerType ledgerType;
  final TransactionType type;
  final TransactionCategory category;
  final double amount;
  final String? paymentAccountId;
  final String? paymentAccountType; // "bank" | "cash" | "upi" | "other"
  final String? referenceNumber;
  final String? orderId;
  final String? description;
  final Map<String, dynamic>? metadata;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String financialYear;
  final double? balanceBefore;
  final double? balanceAfter;

  Map<String, dynamic> toJson() {
    return {
      'transactionId': id,
      'organizationId': organizationId,
      if (clientId != null) 'clientId': clientId,
      if (vendorId != null) 'vendorId': vendorId,
      if (employeeId != null) 'employeeId': employeeId,
      'ledgerType': ledgerType.name,
      'type': type.name,
      'category': category.name,
      'amount': amount,
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
      'financialYear': financialYear,
      if (balanceBefore != null) 'balanceBefore': balanceBefore,
      if (balanceAfter != null) 'balanceAfter': balanceAfter,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json, String docId) {
    return Transaction(
      id: json['transactionId'] as String? ?? docId,
      organizationId: json['organizationId'] as String? ?? '',
      clientId: json['clientId'] as String?,
      vendorId: json['vendorId'] as String?,
      employeeId: json['employeeId'] as String?,
      ledgerType: LedgerType.values.firstWhere(
        (l) => l.name == json['ledgerType'],
        orElse: () => LedgerType.clientLedger, // Default to ClientLedger for backward compatibility
      ),
      type: TransactionType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => TransactionType.debit, // Default fallback
      ),
      category: TransactionCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => TransactionCategory.clientPayment, // Default fallback
      ),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentAccountId: json['paymentAccountId'] as String?,
      paymentAccountType: json['paymentAccountType'] as String?,
      referenceNumber: json['referenceNumber'] as String?,
      orderId: json['orderId'] as String?,
      description: json['description'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
      financialYear: json['financialYear'] as String? ?? '',
      balanceBefore: (json['balanceBefore'] as num?)?.toDouble(),
      balanceAfter: (json['balanceAfter'] as num?)?.toDouble(),
    );
  }

  Transaction copyWith({
    String? id,
    String? organizationId,
    String? clientId,
    String? vendorId,
    String? employeeId,
    LedgerType? ledgerType,
    TransactionType? type,
    TransactionCategory? category,
    double? amount,
    String? paymentAccountId,
    String? paymentAccountType,
    String? referenceNumber,
    String? orderId,
    String? description,
    Map<String, dynamic>? metadata,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? financialYear,
    double? balanceBefore,
    double? balanceAfter,
  }) {
    return Transaction(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      clientId: clientId ?? this.clientId,
      vendorId: vendorId ?? this.vendorId,
      employeeId: employeeId ?? this.employeeId,
      ledgerType: ledgerType ?? this.ledgerType,
      type: type ?? this.type,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      paymentAccountId: paymentAccountId ?? this.paymentAccountId,
      paymentAccountType: paymentAccountType ?? this.paymentAccountType,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      orderId: orderId ?? this.orderId,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      financialYear: financialYear ?? this.financialYear,
      balanceBefore: balanceBefore ?? this.balanceBefore,
      balanceAfter: balanceAfter ?? this.balanceAfter,
    );
  }
}



