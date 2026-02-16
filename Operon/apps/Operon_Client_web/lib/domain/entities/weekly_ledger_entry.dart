/// Represents a salary/wage transaction row in the weekly ledger table.
class WeeklyLedgerTransactionRow {
  const WeeklyLedgerTransactionRow({
    required this.description,
    required this.amount,
    this.transactionId,
    this.employeeId,
  });

  final String? transactionId;
  final String description;
  final double amount;
  final String? employeeId;
}

/// Base data for a weekly ledger entry (production or trip).
abstract class WeeklyLedgerEntry {
  const WeeklyLedgerEntry({
    required this.date,
    required this.employeeIds,
    required this.employeeNames,
    required this.employeeBalances,
    this.salaryTransactions = const [],
  });

  final DateTime date;
  final List<String> employeeIds;
  final List<String> employeeNames;
  final List<double> employeeBalances;
  final List<WeeklyLedgerTransactionRow> salaryTransactions;
}

/// Production batch row for the Weekly Ledger Productions section.
class ProductionLedgerEntry extends WeeklyLedgerEntry {
  const ProductionLedgerEntry({
    required super.date,
    required this.batchNo,
    required this.bricksProduced,
    required this.bricksStacked,
    required super.employeeIds,
    required super.employeeNames,
    required super.employeeBalances,
    super.salaryTransactions,
    this.batchId,
  });

  final String batchNo;
  final String? batchId;
  final int bricksProduced;
  final int bricksStacked;
}

/// Trip row for the Weekly Ledger Trips section (grouped by date + vehicle).
class TripLedgerEntry extends WeeklyLedgerEntry {
  const TripLedgerEntry({
    required super.date,
    required this.vehicleNo,
    required this.tripCount,
    required super.employeeIds,
    required super.employeeNames,
    required super.employeeBalances,
    super.salaryTransactions,
  });

  final String vehicleNo;
  final int tripCount;
}
