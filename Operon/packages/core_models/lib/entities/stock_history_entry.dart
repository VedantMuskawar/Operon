import 'package:cloud_firestore/cloud_firestore.dart';

enum StockHistoryType { in_, out, adjustment }

class StockHistoryEntry {
  const StockHistoryEntry({
    required this.id,
    required this.materialId,
    required this.type,
    required this.quantity,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.reason,
    this.transactionId,
    this.vendorId,
    this.invoiceNumber,
    this.notes,
    required this.createdBy,
    this.createdAt,
  });

  final String id;
  final String materialId; // Reference to parent material
  final StockHistoryType type; // "in" | "out" | "adjustment"
  final double quantity; // Quantity change (positive for in, negative for out)
  final double balanceBefore; // Stock before this change
  final double balanceAfter; // Stock after this change
  final String reason; // Reason for change (e.g., "purchase", "manual_adjustment")
  final String? transactionId; // Reference to TRANSACTIONS if from purchase
  final String? vendorId; // Reference to vendor if from purchase
  final String? invoiceNumber; // Invoice number if from purchase
  final String? notes; // Optional notes
  final String createdBy; // User ID who made the change
  final DateTime? createdAt;

  Map<String, dynamic> toJson() {
    return {
      'entryId': id,
      'materialId': materialId,
      'type': type == StockHistoryType.in_ ? 'in' : type.name,
      'quantity': quantity,
      'balanceBefore': balanceBefore,
      'balanceAfter': balanceAfter,
      'reason': reason,
      if (transactionId != null) 'transactionId': transactionId,
      if (vendorId != null) 'vendorId': vendorId,
      if (invoiceNumber != null) 'invoiceNumber': invoiceNumber,
      if (notes != null) 'notes': notes,
      'createdBy': createdBy,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    };
  }

  factory StockHistoryEntry.fromJson(Map<String, dynamic> json, String docId) {
    final typeString = json['type'] as String? ?? 'in';
    StockHistoryType type;
    if (typeString == 'in') {
      type = StockHistoryType.in_;
    } else if (typeString == 'out') {
      type = StockHistoryType.out;
    } else {
      type = StockHistoryType.values.firstWhere(
        (t) => t.name == typeString,
        orElse: () => StockHistoryType.adjustment,
      );
    }

    return StockHistoryEntry(
      id: json['entryId'] as String? ?? docId,
      materialId: json['materialId'] as String? ?? '',
      type: type,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      balanceBefore: (json['balanceBefore'] as num?)?.toDouble() ?? 0,
      balanceAfter: (json['balanceAfter'] as num?)?.toDouble() ?? 0,
      reason: json['reason'] as String? ?? '',
      transactionId: json['transactionId'] as String?,
      vendorId: json['vendorId'] as String?,
      invoiceNumber: json['invoiceNumber'] as String?,
      notes: json['notes'] as String?,
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  StockHistoryEntry copyWith({
    String? id,
    String? materialId,
    StockHistoryType? type,
    double? quantity,
    double? balanceBefore,
    double? balanceAfter,
    String? reason,
    String? transactionId,
    String? vendorId,
    String? invoiceNumber,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return StockHistoryEntry(
      id: id ?? this.id,
      materialId: materialId ?? this.materialId,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      balanceBefore: balanceBefore ?? this.balanceBefore,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      reason: reason ?? this.reason,
      transactionId: transactionId ?? this.transactionId,
      vendorId: vendorId ?? this.vendorId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

