import 'dart:html' as html;
import 'dart:typed_data';

import 'package:dash_web/domain/entities/weekly_ledger_entry.dart';
import 'package:dash_web/domain/entities/weekly_ledger_matrix.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

/// Exports weekly ledger table data to Excel and triggers download.
class WeeklyLedgerExcelGenerator {
  static String _formatDate(DateTime date) =>
      DateFormat('dd MMM yyyy').format(date);
  static String _formatCurrency(double amount) =>
      '₹${amount.toStringAsFixed(2)}';

  static Future<void> export({
    required DateTime weekStart,
    required DateTime weekEnd,
    required List<ProductionLedgerEntry> productionEntries,
    required List<TripLedgerEntry> tripEntries,
        required Map<String, double> debitByEmployeeId,
        required Map<String, double> currentBalanceByEmployeeId,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel.tables.isEmpty ? null : excel[excel.tables.keys.first];
    if (sheet == null) throw Exception('Failed to create Excel sheet');

    int row = 0;
        if (productionEntries.isNotEmpty) {
            row = _writeMatrixSheet(
                sheet,
                buildProductionLedgerMatrix(
                    productionEntries,
                    debitByEmployeeId: debitByEmployeeId,
                    currentBalanceByEmployeeId: currentBalanceByEmployeeId,
                ),
                startRow: row,
                sectionTitle: 'Productions',
                detailHeader: 'Production',
            );
      row += 2; // gap before Trips
    }
    if (tripEntries.isNotEmpty) {
            _writeMatrixSheet(
                sheet,
                buildTripLedgerMatrix(
                    tripEntries,
                    debitByEmployeeId: debitByEmployeeId,
                    currentBalanceByEmployeeId: currentBalanceByEmployeeId,
                ),
                startRow: row,
                sectionTitle: 'Trips',
                detailHeader: 'No. of Trips',
            );
    }

    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Failed to generate Excel file');
    }

    final filename =
        'weekly-ledger-${weekStart.year}${weekStart.month.toString().padLeft(2, '0')}${weekStart.day.toString().padLeft(2, '0')}.xlsx';
    final blob = html.Blob([Uint8List.fromList(bytes)]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    (html.AnchorElement(href: url)..setAttribute('download', filename)).click();
    html.Url.revokeObjectUrl(url);
  }

  static int _writeMatrixSheet(
    Sheet sheet,
    WeeklyLedgerMatrix matrix, {
    required int startRow,
    required String sectionTitle,
    required String detailHeader,
  }) {
    final dateCount = matrix.dates.length;
    final totalColumn = 2 + (dateCount * 2);
    final debitColumn = totalColumn + 1;
    final currentBalanceColumn = totalColumn + 2;
    int row = startRow;

    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = TextCellValue(sectionTitle);
    row++;

    // Header Row 1
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = TextCellValue('EMPLOYEES NAMES');
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        .value = TextCellValue('Opening Balance');
    for (var i = 0; i < dateCount; i++) {
      final dateLabel = _formatDate(matrix.dates[i]);
      final startCol = 2 + (i * 2);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row))
          .value = TextCellValue(dateLabel);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: startCol + 1, rowIndex: row))
          .value = TextCellValue('');
    }
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: debitColumn, rowIndex: row))
        .value = TextCellValue('Debit');
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: totalColumn, rowIndex: row))
        .value = TextCellValue('Total');
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: currentBalanceColumn, rowIndex: row))
        .value = TextCellValue('Current Balance');
    row++;

    // Header Row 2
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = TextCellValue('');
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        .value = TextCellValue('');
    for (var i = 0; i < dateCount; i++) {
      final startCol = 2 + (i * 2);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row))
          .value = TextCellValue(detailHeader);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: startCol + 1, rowIndex: row))
          .value = TextCellValue('Amount');
    }
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: debitColumn, rowIndex: row))
        .value = TextCellValue('');
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: totalColumn, rowIndex: row))
        .value = TextCellValue('');
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: currentBalanceColumn, rowIndex: row))
        .value = TextCellValue('');
    row++;

    for (final ledgerRow in matrix.rows) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue(ledgerRow.employeeName);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = TextCellValue(_formatCurrency(ledgerRow.openingBalance));
      for (var i = 0; i < dateCount; i++) {
        final date = matrix.dates[i];
        final cell = ledgerRow.cells[date];
        final startCol = 2 + (i * 2);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row))
            .value = TextCellValue(cell?.detailsText ?? '—');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: startCol + 1, rowIndex: row))
            .value = TextCellValue(_formatCurrency(cell?.amount ?? 0.0));
      }
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: debitColumn, rowIndex: row))
          .value = TextCellValue(_formatCurrency(ledgerRow.debitTotal));
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: totalColumn, rowIndex: row))
          .value = TextCellValue(_formatCurrency(ledgerRow.totalAmount));
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: currentBalanceColumn, rowIndex: row))
          .value = TextCellValue(_formatCurrency(ledgerRow.currentBalance));
      row++;
    }

    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = TextCellValue('TOTAL');
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        .value = TextCellValue(_formatCurrency(matrix.totalOpeningBalance));
    for (var i = 0; i < dateCount; i++) {
      final date = matrix.dates[i];
      final startCol = 2 + (i * 2);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row))
          .value = TextCellValue('');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: startCol + 1, rowIndex: row))
          .value = TextCellValue(_formatCurrency(matrix.totalsByDate[date] ?? 0.0));
    }
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: debitColumn, rowIndex: row))
        .value = TextCellValue(_formatCurrency(matrix.totalDebit));
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: totalColumn, rowIndex: row))
        .value = TextCellValue(_formatCurrency(matrix.grandTotal));
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: currentBalanceColumn, rowIndex: row))
        .value = TextCellValue(_formatCurrency(matrix.totalCurrentBalance));
    row++;

    return row;
  }
}
