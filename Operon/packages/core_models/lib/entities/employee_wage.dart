/// Wage Type - Defines how an employee is compensated
enum WageType {
  perMonth,    // Fixed monthly salary
  perTrip,     // Payment per delivery trip
  perBatch,    // Payment per batch/order batch
  perHour,     // Hourly wage
  perKm,       // Payment per kilometer
  commission,  // Commission-based compensation
  hybrid,      // Combination (e.g., base + commission)
}

/// Employee Wage Structure
class EmployeeWage {
  const EmployeeWage({
    required this.type,
    this.baseAmount,
    this.rate,
    this.unit,
    this.commissionPercent,
    this.hybridStructure,
    this.effectiveFrom,
  });

  final WageType type;
  final double? baseAmount;        // For perMonth: fixed monthly salary
  final double? rate;              // For perTrip, perBatch, perHour, perKm
  final String? unit;              // Unit of measurement (optional)
  final double? commissionPercent; // For commission-based
  final HybridWageStructure? hybridStructure;
  final DateTime? effectiveFrom;

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      if (baseAmount != null) 'baseAmount': baseAmount,
      if (rate != null) 'rate': rate,
      if (unit != null) 'unit': unit,
      if (commissionPercent != null) 'commissionPercent': commissionPercent,
      if (hybridStructure != null) 'hybridStructure': hybridStructure!.toJson(),
      // Note: effectiveFrom not included in JSON as it's optional and can be added later
    };
  }

  factory EmployeeWage.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'perMonth';
    final wageType = WageType.values.firstWhere(
      (type) => type.name == typeStr,
      orElse: () => WageType.perMonth,
    );

    HybridWageStructure? hybridStructure;
    if (json['hybridStructure'] != null) {
      hybridStructure = HybridWageStructure.fromJson(
        json['hybridStructure'] as Map<String, dynamic>,
      );
    }

    return EmployeeWage(
      type: wageType,
      baseAmount: (json['baseAmount'] as num?)?.toDouble(),
      rate: (json['rate'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      commissionPercent: (json['commissionPercent'] as num?)?.toDouble(),
      hybridStructure: hybridStructure,
    );
  }

  EmployeeWage copyWith({
    WageType? type,
    double? baseAmount,
    double? rate,
    String? unit,
    double? commissionPercent,
    HybridWageStructure? hybridStructure,
    DateTime? effectiveFrom,
  }) {
    return EmployeeWage(
      type: type ?? this.type,
      baseAmount: baseAmount ?? this.baseAmount,
      rate: rate ?? this.rate,
      unit: unit ?? this.unit,
      commissionPercent: commissionPercent ?? this.commissionPercent,
      hybridStructure: hybridStructure ?? this.hybridStructure,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
    );
  }
}

/// Hybrid Wage Structure - Base salary + commission
class HybridWageStructure {
  const HybridWageStructure({
    required this.baseAmount,
    required this.commissionPercent,
  });

  final double baseAmount;
  final double commissionPercent;

  Map<String, dynamic> toJson() {
    return {
      'baseAmount': baseAmount,
      'commissionPercent': commissionPercent,
    };
  }

  factory HybridWageStructure.fromJson(Map<String, dynamic> json) {
    return HybridWageStructure(
      baseAmount: (json['baseAmount'] as num?)?.toDouble() ?? 0,
      commissionPercent: (json['commissionPercent'] as num?)?.toDouble() ?? 0,
    );
  }

  HybridWageStructure copyWith({
    double? baseAmount,
    double? commissionPercent,
  }) {
    return HybridWageStructure(
      baseAmount: baseAmount ?? this.baseAmount,
      commissionPercent: commissionPercent ?? this.commissionPercent,
    );
  }
}
