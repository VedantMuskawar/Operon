import 'package:dash_web/domain/entities/weekly_ledger_entry.dart';

class WeeklyLedgerCell {
  const WeeklyLedgerCell({
    required this.details,
    required this.amount,
  });

  final List<String> details;
  final double amount;

  String get detailsText => details.isEmpty ? '—' : details.join(', ');
}

class WeeklyLedgerRow {
  const WeeklyLedgerRow({
    required this.employeeId,
    required this.employeeName,
    required this.cells,
    required this.totalAmount,
    required this.debitTotal,
    required this.currentBalance,
    required this.openingBalance,
  });

  final String employeeId;
  final String employeeName;
  final Map<DateTime, WeeklyLedgerCell> cells;
  final double totalAmount;
  final double debitTotal;
  final double currentBalance;
  final double openingBalance;
}

class WeeklyLedgerMatrix {
  const WeeklyLedgerMatrix({
    required this.dates,
    required this.rows,
    required this.totalsByDate,
    required this.grandTotal,
    required this.totalDebit,
    required this.totalCurrentBalance,
    required this.totalOpeningBalance,
  });

  final List<DateTime> dates;
  final List<WeeklyLedgerRow> rows;
  final Map<DateTime, double> totalsByDate;
  final double grandTotal;
  final double totalDebit;
  final double totalCurrentBalance;
  final double totalOpeningBalance;
}

DateTime _normalizeDate(DateTime date) => DateTime(date.year, date.month, date.day);

WeeklyLedgerMatrix buildProductionLedgerMatrix(
  List<ProductionLedgerEntry> entries, {
  required Map<String, double> debitByEmployeeId,
  required Map<String, double> currentBalanceByEmployeeId,
}) {
  final dateSet = <DateTime>{};
  final employeeNames = <String, String>{};

  for (final entry in entries) {
    dateSet.add(_normalizeDate(entry.date));
    for (var i = 0; i < entry.employeeIds.length; i++) {
      final id = entry.employeeIds[i];
      final name = i < entry.employeeNames.length ? entry.employeeNames[i] : 'Employee';
      employeeNames[id] = name;
    }
  }

  final dates = dateSet.toList()..sort();
  final rowBuilders = <String, _RowBuilder>{};

  for (final entry in entries) {
    final dateKey = _normalizeDate(entry.date);
    final detail = 'Batch ${entry.batchNo}: ${entry.bricksProduced}+${entry.bricksStacked}';

    for (final employeeId in entry.employeeIds) {
      final builder = rowBuilders.putIfAbsent(
        employeeId,
        () => _RowBuilder(
          employeeId,
          employeeNames[employeeId] ?? 'Employee',
          currentBalanceByEmployeeId[employeeId] ?? 0.0,
          debitByEmployeeId[employeeId] ?? 0.0,
        ),
      );

      final cell = builder.cells.putIfAbsent(dateKey, _CellBuilder.new);
      cell.addDetail(detail);

      final amountForEmployee = entry.salaryTransactions
          .where((tx) => tx.employeeId == employeeId)
          .fold<double>(0.0, (sum, tx) => sum + tx.amount);
      cell.amount += amountForEmployee;
      builder.total += amountForEmployee;
    }
  }

  final rows = rowBuilders.values
      .map((b) => b.build())
      .toList()
    ..sort((a, b) => a.employeeName.compareTo(b.employeeName));

  final totalsByDate = <DateTime, double>{};
  for (final date in dates) {
    totalsByDate[date] = rows.fold<double>(
      0.0,
      (sum, row) => sum + (row.cells[date]?.amount ?? 0.0),
    );
  }

  final grandTotal = totalsByDate.values.fold<double>(0.0, (a, b) => a + b);
  final totalDebit = rows.fold<double>(0.0, (sum, row) => sum + row.debitTotal);
  final totalCurrentBalance = rows.fold<double>(0.0, (sum, row) => sum + row.currentBalance);
  final totalOpeningBalance = rows.fold<double>(0.0, (sum, row) => sum + row.openingBalance);

  return WeeklyLedgerMatrix(
    dates: dates,
    rows: rows,
    totalsByDate: totalsByDate,
    grandTotal: grandTotal,
    totalDebit: totalDebit,
    totalCurrentBalance: totalCurrentBalance,
    totalOpeningBalance: totalOpeningBalance,
  );
}

WeeklyLedgerMatrix buildTripLedgerMatrix(
  List<TripLedgerEntry> entries, {
  required Map<String, double> debitByEmployeeId,
  required Map<String, double> currentBalanceByEmployeeId,
}) {
  final dateSet = <DateTime>{};
  final employeeNames = <String, String>{};

  for (final entry in entries) {
    dateSet.add(_normalizeDate(entry.date));
    for (var i = 0; i < entry.employeeIds.length; i++) {
      final id = entry.employeeIds[i];
      final name = i < entry.employeeNames.length ? entry.employeeNames[i] : 'Employee';
      employeeNames[id] = name;
    }
  }

  final dates = dateSet.toList()..sort();
  final rowBuilders = <String, _RowBuilder>{};

  for (final entry in entries) {
    final dateKey = _normalizeDate(entry.date);
    final detail = '${entry.vehicleNo} (${entry.tripCount})';

    for (final employeeId in entry.employeeIds) {
      final builder = rowBuilders.putIfAbsent(
        employeeId,
        () => _RowBuilder(
          employeeId,
          employeeNames[employeeId] ?? 'Employee',
          currentBalanceByEmployeeId[employeeId] ?? 0.0,
          debitByEmployeeId[employeeId] ?? 0.0,
        ),
      );

      final cell = builder.cells.putIfAbsent(dateKey, _CellBuilder.new);
      cell.addDetail(detail);

      final amountForEmployee = entry.salaryTransactions
          .where((tx) => tx.employeeId == employeeId)
          .fold<double>(0.0, (sum, tx) => sum + tx.amount);
      cell.amount += amountForEmployee;
      builder.total += amountForEmployee;
    }
  }

  final rows = rowBuilders.values
      .map((b) => b.build())
      .toList()
    ..sort((a, b) => a.employeeName.compareTo(b.employeeName));

  final totalsByDate = <DateTime, double>{};
  for (final date in dates) {
    totalsByDate[date] = rows.fold<double>(
      0.0,
      (sum, row) => sum + (row.cells[date]?.amount ?? 0.0),
    );
  }

  final grandTotal = totalsByDate.values.fold<double>(0.0, (a, b) => a + b);
  final totalDebit = rows.fold<double>(0.0, (sum, row) => sum + row.debitTotal);
  final totalCurrentBalance = rows.fold<double>(0.0, (sum, row) => sum + row.currentBalance);
  final totalOpeningBalance = rows.fold<double>(0.0, (sum, row) => sum + row.openingBalance);

  return WeeklyLedgerMatrix(
    dates: dates,
    rows: rows,
    totalsByDate: totalsByDate,
    grandTotal: grandTotal,
    totalDebit: totalDebit,
    totalCurrentBalance: totalCurrentBalance,
    totalOpeningBalance: totalOpeningBalance,
  );
}

class _CellBuilder {
  final List<String> _details = [];
  double amount = 0.0;

  void addDetail(String detail) {
    if (detail.isEmpty) return;
    if (_details.contains(detail)) return;
    _details.add(detail);
  }

  WeeklyLedgerCell build() {
    return WeeklyLedgerCell(details: List.unmodifiable(_details), amount: amount);
  }
}

class _RowBuilder {
  _RowBuilder(this.employeeId, this.employeeName, this.currentBalance, this.debitTotal);

  final String employeeId;
  final String employeeName;
  final double currentBalance;
  final double debitTotal;
  final Map<DateTime, _CellBuilder> cells = {};
  double total = 0.0;

  WeeklyLedgerRow build() {
    final openingBalance = currentBalance - total + debitTotal;
    return WeeklyLedgerRow(
      employeeId: employeeId,
      employeeName: employeeName,
      cells: cells.map((key, value) => MapEntry(key, value.build())),
      totalAmount: total,
      debitTotal: debitTotal,
      currentBalance: currentBalance,
      openingBalance: openingBalance,
    );
  }
}
