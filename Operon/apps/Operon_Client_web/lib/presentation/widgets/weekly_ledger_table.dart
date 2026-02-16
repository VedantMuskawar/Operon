import 'package:core_ui/core_ui.dart';
import 'package:dash_web/domain/entities/weekly_ledger_entry.dart';
import 'package:dash_web/domain/entities/weekly_ledger_matrix.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Weekly Ledger table in date-column matrix format.
/// Header Row 1: Employees | Date (2 cols) ... | Total
/// Header Row 2: (blank) | No. of Trips/Production | Amount ... | (blank)
class WeeklyLedgerTable extends StatelessWidget {
  const WeeklyLedgerTable({
    super.key,
    required this.productionEntries,
    required this.tripEntries,
    required this.debitByEmployeeId,
    required this.currentBalanceByEmployeeId,
    this.formatCurrency,
  });

  final List<ProductionLedgerEntry> productionEntries;
  final List<TripLedgerEntry> tripEntries;
  final Map<String, double> debitByEmployeeId;
  final Map<String, double> currentBalanceByEmployeeId;
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
            const _SectionHeader(title: 'Productions'),
            const SizedBox(height: 8),
            _LedgerMatrixTable(
              matrix: buildProductionLedgerMatrix(
                productionEntries,
                debitByEmployeeId: debitByEmployeeId,
                currentBalanceByEmployeeId: currentBalanceByEmployeeId,
              ),
              formatCurrency: _formatCurrency,
              formatDate: _formatDate,
              detailHeader: 'Production',
            ),
            const SizedBox(height: 32),
          ],
          if (tripEntries.isNotEmpty) ...[
            const _SectionHeader(title: 'Trips'),
            const SizedBox(height: 8),
            _LedgerMatrixTable(
              matrix: buildTripLedgerMatrix(
                tripEntries,
                debitByEmployeeId: debitByEmployeeId,
                currentBalanceByEmployeeId: currentBalanceByEmployeeId,
              ),
              formatCurrency: _formatCurrency,
              formatDate: _formatDate,
              detailHeader: 'No. of Trips',
            ),
          ],
          if (productionEntries.isEmpty && tripEntries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
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

class _LedgerMatrixTable extends StatelessWidget {
  const _LedgerMatrixTable({
    required this.matrix,
    required this.formatCurrency,
    required this.formatDate,
    required this.detailHeader,
  });

  final WeeklyLedgerMatrix matrix;
  final String Function(double) formatCurrency;
  final String Function(DateTime) formatDate;
  final String detailHeader;

  static const double _employeeColWidth = 180;
  static const double _openingColWidth = 110;
  static const double _detailColWidth = 160;
  static const double _amountColWidth = 90;
  static const double _debitColWidth = 90;
  static const double _totalColWidth = 100;
  static const double _currentColWidth = 120;

  @override
  Widget build(BuildContext context) {
    final dateCount = matrix.dates.length;
    final colCount = 2 + (dateCount * 2) + 3; // Employee + Opening + date pairs + Debit + Total + Current

    final columnWidths = <int, TableColumnWidth>{
      0: const FixedColumnWidth(_employeeColWidth),
      1: const FixedColumnWidth(_openingColWidth),
      for (int i = 0; i < dateCount * 2; i++)
        2 + i: i.isEven
            ? const FixedColumnWidth(_detailColWidth)
            : const FixedColumnWidth(_amountColWidth),
      colCount - 3: const FixedColumnWidth(_debitColWidth),
      colCount - 2: const FixedColumnWidth(_totalColWidth),
      colCount - 1: const FixedColumnWidth(_currentColWidth),
    };

    return Container(
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderRow1Merged(matrix),
          _buildHeaderRow2Merged(matrix),
          Divider(height: 1, thickness: 1, color: AuthColors.textMainWithOpacity(0.1)),
          Table(
            border: TableBorder.symmetric(
              inside: BorderSide(color: AuthColors.textMainWithOpacity(0.1)),
              outside: BorderSide.none,
            ),
            columnWidths: columnWidths,
            children: [
              for (final row in matrix.rows) _buildDataRow(row),
              _buildFooterRow(matrix),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow1Merged(WeeklyLedgerMatrix matrix) {
    return Container(
      color: AuthColors.background,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: _employeeColWidth,
            child: _cell('EMPLOYEES NAMES', isHeader: true),
          ),
          SizedBox(
            width: _openingColWidth,
            child: _cell('Opening Balance', isHeader: true),
          ),
          for (final date in matrix.dates)
            SizedBox(
              width: _detailColWidth + _amountColWidth,
              child: _cell(formatDate(date), isHeader: true),
            ),
          SizedBox(
            width: _debitColWidth,
            child: _cell('Debit', isHeader: true),
          ),
          SizedBox(
            width: _totalColWidth,
            child: _cell('Total', isHeader: true),
          ),
          SizedBox(
            width: _currentColWidth,
            child: _cell('Current Balance', isHeader: true),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow2Merged(WeeklyLedgerMatrix matrix) {
    return Container(
      color: AuthColors.background.withOpacity(0.85),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: _employeeColWidth, child: _cell('', isHeader: true)),
          SizedBox(width: _openingColWidth, child: _cell('', isHeader: true)),
          for (int i = 0; i < matrix.dates.length; i++) ...[
            SizedBox(
              width: _detailColWidth,
              child: _cell(detailHeader, isHeader: true),
            ),
            SizedBox(
              width: _amountColWidth,
              child: _cell('Amount', isHeader: true, numeric: true),
            ),
          ],
          SizedBox(width: _debitColWidth, child: _cell('', isHeader: true)),
          SizedBox(width: _totalColWidth, child: _cell('', isHeader: true)),
          SizedBox(width: _currentColWidth, child: _cell('', isHeader: true)),
        ],
      ),
    );
  }

  TableRow _buildDataRow(WeeklyLedgerRow row) {
    return TableRow(
      children: [
        _cell(row.employeeName),
        _cell(formatCurrency(row.openingBalance), numeric: true),
        for (final date in matrix.dates) ...[
          _cell(row.cells[date]?.detailsText ?? '—', small: true),
          _cell(formatCurrency(row.cells[date]?.amount ?? 0.0), numeric: true),
        ],
        _cell(formatCurrency(row.debitTotal), numeric: true),
        _cell(formatCurrency(row.totalAmount), numeric: true),
        _cell(formatCurrency(row.currentBalance), numeric: true),
      ],
    );
  }

  TableRow _buildFooterRow(WeeklyLedgerMatrix matrix) {
    return TableRow(
      decoration: const BoxDecoration(color: AuthColors.background),
      children: [
        _cell('TOTAL', isHeader: true),
        _cell(formatCurrency(matrix.totalOpeningBalance), isHeader: true, numeric: true),
        for (final date in matrix.dates) ...[
          _cell('', isHeader: true),
          _cell(formatCurrency(matrix.totalsByDate[date] ?? 0.0), isHeader: true, numeric: true),
        ],
        _cell(formatCurrency(matrix.totalDebit), isHeader: true, numeric: true),
        _cell(formatCurrency(matrix.grandTotal), isHeader: true, numeric: true),
        _cell(formatCurrency(matrix.totalCurrentBalance), isHeader: true, numeric: true),
      ],
    );
  }

  Widget _cell(String text, {bool isHeader = false, bool numeric = false, bool small = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Text(
        text,
        style: TextStyle(
          color: isHeader ? AuthColors.textSub : AuthColors.textMain,
          fontSize: small ? 12 : (isHeader ? 12 : 13),
          fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 3,
        textAlign: TextAlign.center,
      ),
    );
  }
}
