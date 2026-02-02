import 'package:core_ui/core_ui.dart';
import 'package:dash_web/domain/entities/weekly_ledger_entry.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Table widget for Weekly Ledger with merged cells and nested rows.
/// Productions: Date | Batch No. | Employee names (row 1) | Current Balance (row 2) | Salary Transaction rows.
/// Trips: Date | Vehicle No. (trip count) | Employee names (row 1) | Current Balance (row 2) | Salary Transaction rows.
class WeeklyLedgerTable extends StatelessWidget {
  const WeeklyLedgerTable({
    super.key,
    required this.productionEntries,
    required this.tripEntries,
    this.formatCurrency,
  });

  final List<ProductionLedgerEntry> productionEntries;
  final List<TripLedgerEntry> tripEntries;
  final String Function(double)? formatCurrency;

  String _formatCurrency(double amount) =>
      formatCurrency != null ? formatCurrency!(amount) : '₹${amount.toStringAsFixed(2)}';

  String _formatDate(DateTime date) => DateFormat('dd MMM yyyy').format(date);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (productionEntries.isNotEmpty) ...[
            _SectionHeader(title: 'Productions'),
            const SizedBox(height: 8),
            _ProductionsTable(
              entries: productionEntries,
              formatCurrency: _formatCurrency,
              formatDate: _formatDate,
            ),
            const SizedBox(height: 32),
          ],
          if (tripEntries.isNotEmpty) ...[
            _SectionHeader(title: 'Trips'),
            const SizedBox(height: 8),
            _TripsTable(
              entries: tripEntries,
              formatCurrency: _formatCurrency,
              formatDate: _formatDate,
            ),
          ],
          if (productionEntries.isEmpty && tripEntries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No data for this week. Click Generate Weekly Ledger to load data.',
                style: TextStyle(color: AuthColors.textSub, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AuthColors.textMain,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        fontFamily: 'SF Pro Display',
      ),
    );
  }
}

class _ProductionsTable extends StatelessWidget {
  const _ProductionsTable({
    required this.entries,
    required this.formatCurrency,
    required this.formatDate,
  });

  final List<ProductionLedgerEntry> entries;
  final String Function(double) formatCurrency;
  final String Function(DateTime) formatDate;

  int get _maxEmployees =>
      entries.isEmpty ? 0 : entries.map((e) => e.employeeNames.length).reduce((a, b) => a > b ? a : b);

  @override
  Widget build(BuildContext context) {
    final maxCols = _maxEmployees;
    final colCount = 2 + (maxCols > 0 ? maxCols : 1) + 2; // Date | Batch | employees | Desc | Amount

    return Container(
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Table(
        border: TableBorder.symmetric(
          inside: BorderSide(color: AuthColors.textMainWithOpacity(0.1)),
          outside: BorderSide.none,
        ),
        columnWidths: {
          for (int i = 0; i < colCount; i++)
            i: i == 0
                ? const FixedColumnWidth(100)
                : i == 1
                    ? const FixedColumnWidth(120)
                    : i < 2 + maxCols
                        ? const FixedColumnWidth(100)
                        : i == colCount - 2
                            ? const IntrinsicColumnWidth(flex: 1)
                            : const FixedColumnWidth(90),
        },
        children: [
          // Header row
          TableRow(
            decoration: BoxDecoration(color: AuthColors.background),
            children: [
              _cell('Date', isHeader: true),
              _cell('Batch No.', isHeader: true),
              ...List.generate(maxCols > 0 ? maxCols : 1, (_) => _cell('', isHeader: true)),
              _cell('Description', isHeader: true),
              _cell('Amount', isHeader: true),
            ],
          ),
          // Data rows per entry
          for (final entry in entries) ..._buildEntryRows(entry, maxCols, colCount),
        ],
      ),
    );
  }

  List<TableRow> _buildEntryRows(ProductionLedgerEntry entry, int maxCols, int colCount) {
    final rows = <TableRow>[];
    final n = entry.employeeNames.length;

    // Row 1: Date, Batch No., Employee names, empty for tx
    rows.add(
      TableRow(
        children: [
          _cell(formatDate(entry.date)),
          _cell(entry.batchNo),
          ...List.generate(maxCols, (i) => _cell(i < n ? entry.employeeNames[i] : '')),
          _cell(''),
          _cell(''),
        ],
      ),
    );
    // Row 2: empty, empty, Balances, empty
    rows.add(
      TableRow(
        decoration: BoxDecoration(color: AuthColors.background.withOpacity(0.3)),
        children: [
          _cell(''),
          _cell(''),
          ...List.generate(maxCols, (i) => _cell(i < n ? formatCurrency(entry.employeeBalances[i]) : '', muted: true)),
          _cell(''),
          _cell(''),
        ],
      ),
    );
    // Salary transaction rows
    for (final tx in entry.salaryTransactions) {
      rows.add(
        TableRow(
          children: [
            _cell(''),
            _cell(''),
            ...List.generate(maxCols, (_) => _cell('')),
            _cell(tx.description, small: true),
            _cell(formatCurrency(tx.amount), numeric: true, small: true),
          ],
        ),
      );
    }

    return rows;
  }

  Widget _cell(String text, {bool isHeader = false, bool muted = false, bool numeric = false, bool small = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Text(
        text,
        style: TextStyle(
          color: isHeader ? AuthColors.textSub : (muted ? AuthColors.textSub : AuthColors.textMain),
          fontSize: small ? 12 : (isHeader ? 12 : 13),
          fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
        textAlign: numeric ? TextAlign.right : TextAlign.start,
      ),
    );
  }
}

class _TripsTable extends StatelessWidget {
  const _TripsTable({
    required this.entries,
    required this.formatCurrency,
    required this.formatDate,
  });

  final List<TripLedgerEntry> entries;
  final String Function(double) formatCurrency;
  final String Function(DateTime) formatDate;

  int get _maxEmployees =>
      entries.isEmpty ? 0 : entries.map((e) => e.employeeNames.length).reduce((a, b) => a > b ? a : b);

  @override
  Widget build(BuildContext context) {
    final maxCols = _maxEmployees;
    final colCount = 2 + (maxCols > 0 ? maxCols : 1) + 2;

    return Container(
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Table(
        border: TableBorder.symmetric(
          inside: BorderSide(color: AuthColors.textMainWithOpacity(0.1)),
          outside: BorderSide.none,
        ),
        columnWidths: {
          for (int i = 0; i < colCount; i++)
            i: i == 0
                ? const FixedColumnWidth(100)
                : i == 1
                    ? const FixedColumnWidth(140)
                    : i < 2 + maxCols
                        ? const FixedColumnWidth(100)
                        : i == colCount - 2
                            ? const IntrinsicColumnWidth(flex: 1)
                            : const FixedColumnWidth(90),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: AuthColors.background),
            children: [
              _cell('Date', isHeader: true),
              _cell('Vehicle No. (Trips)', isHeader: true),
              ...List.generate(maxCols > 0 ? maxCols : 1, (_) => _cell('', isHeader: true)),
              _cell('Description', isHeader: true),
              _cell('Amount', isHeader: true),
            ],
          ),
          for (final entry in entries) ..._buildEntryRows(entry, maxCols, colCount),
        ],
      ),
    );
  }

  List<TableRow> _buildEntryRows(TripLedgerEntry entry, int maxCols, int colCount) {
    final rows = <TableRow>[];
    final n = entry.employeeNames.length;
    final vehicleLabel = '${entry.vehicleNo} (${entry.tripCount})';

    rows.add(
      TableRow(
        children: [
          _cell(formatDate(entry.date)),
          _cell(vehicleLabel),
          ...List.generate(maxCols, (i) => _cell(i < n ? entry.employeeNames[i] : '')),
          _cell(''),
          _cell(''),
        ],
      ),
    );
    rows.add(
      TableRow(
        decoration: BoxDecoration(color: AuthColors.background.withOpacity(0.3)),
        children: [
          _cell(''),
          _cell(''),
          ...List.generate(maxCols, (i) => _cell(i < n ? formatCurrency(entry.employeeBalances[i]) : '', muted: true)),
          _cell(''),
          _cell(''),
        ],
      ),
    );
    for (final tx in entry.salaryTransactions) {
      rows.add(
        TableRow(
          children: [
            _cell(''),
            _cell(''),
            ...List.generate(maxCols, (_) => _cell('')),
            _cell(tx.description, small: true),
            _cell(formatCurrency(tx.amount), numeric: true, small: true),
          ],
        ),
      );
    }

    return rows;
  }

  Widget _cell(String text, {bool isHeader = false, bool muted = false, bool numeric = false, bool small = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Text(
        text,
        style: TextStyle(
          color: isHeader ? AuthColors.textSub : (muted ? AuthColors.textSub : AuthColors.textMain),
          fontSize: small ? 12 : (isHeader ? 12 : 13),
          fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
        textAlign: numeric ? TextAlign.right : TextAlign.start,
      ),
    );
  }
}
