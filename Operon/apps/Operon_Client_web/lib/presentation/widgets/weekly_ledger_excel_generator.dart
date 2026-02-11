import 'dart:html' as html;
import 'dart:typed_data';

import 'package:dash_web/domain/entities/weekly_ledger_entry.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

/// Exports weekly ledger table data to Excel and triggers download.
class WeeklyLedgerExcelGenerator {
  static String _formatDate(DateTime date) => DateFormat('dd MMM yyyy').format(date);
  static String _formatCurrency(double amount) => '₹${amount.toStringAsFixed(2)}';

  static Future<void> export({
    required DateTime weekStart,
    required DateTime weekEnd,
    required List<ProductionLedgerEntry> productionEntries,
    required List<TripLedgerEntry> tripEntries,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel.tables.isEmpty ? null : excel[excel.tables.keys.first];
    if (sheet == null) throw Exception('Failed to create Excel sheet');

    int row = 0;
    if (productionEntries.isNotEmpty) {
      row = _writeProductionsSheet(sheet, productionEntries, row);
      row += 2; // gap before Trips
    }
    if (tripEntries.isNotEmpty) {
      _writeTripsSheet(sheet, tripEntries, row);
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

  static int _writeProductionsSheet(Sheet sheet, List<ProductionLedgerEntry> entries, int startRow) {
    final maxCols = entries.isEmpty ? 0 : entries.map((e) => e.employeeNames.length).reduce((a, b) => a > b ? a : b);
    int row = startRow;

    // Section title
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('Productions');
    row++;

    // Header row
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('Date');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue('Batch No.');
    for (var c = 0; c < maxCols; c++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2 + c, rowIndex: row)).value =
          TextCellValue('Employee ${c + 1}');
    }
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2 + maxCols, rowIndex: row)).value = TextCellValue('Description');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3 + maxCols, rowIndex: row)).value = TextCellValue('Amount');
    row++;

    for (final entry in entries) {
      final n = entry.employeeNames.length;
      // Names row
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(_formatDate(entry.date));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(entry.batchNo);
      for (var c = 0; c < maxCols; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2 + c, rowIndex: row)).value =
            TextCellValue(c < n ? entry.employeeNames[c] : '');
      }
      row++;
      // Balances row
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue('');
      for (var c = 0; c < maxCols; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2 + c, rowIndex: row)).value =
            TextCellValue(c < n ? _formatCurrency(entry.employeeBalances[c]) : '');
      }
      row++;
      // Transaction rows
      for (final tx in entry.salaryTransactions) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue('');
        for (var c = 0; c < maxCols; c++) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2 + c, rowIndex: row)).value = TextCellValue('');
        }
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2 + maxCols, rowIndex: row)).value =
            TextCellValue(tx.description);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3 + maxCols, rowIndex: row)).value =
            TextCellValue(_formatCurrency(tx.amount));
        row++;
      }
    }
    return row;
  }

  static void _writeTripsSheet(Sheet sheet, List<TripLedgerEntry> entries, int startRow) {
    final maxCols = entries.isEmpty ? 0 : entries.map((e) => e.employeeNames.length).reduce((a, b) => a > b ? a : b);
    int row = startRow;

    // Section title
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('Trips');
    row++;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('Date');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue('Vehicle No. (Trips)');
    for (var c = 0; c < maxCols; c++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2 + c, rowIndex: row)).value =
          TextCellValue('Employee ${c + 1}');
    }
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2 + maxCols, rowIndex: row)).value = TextCellValue('Description');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3 + maxCols, rowIndex: row)).value = TextCellValue('Amount');
    row++;

    for (final entry in entries) {
      final n = entry.employeeNames.length;
      final vehicleLabel = '${entry.vehicleNo} (${entry.tripCount})';

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(_formatDate(entry.date));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(vehicleLabel);
      for (var c = 0; c < maxCols; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2 + c, rowIndex: row)).value =
            TextCellValue(c < n ? entry.employeeNames[c] : '');
      }
      row++;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue('');
      for (var c = 0; c < maxCols; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2 + c, rowIndex: row)).value =
            TextCellValue(c < n ? _formatCurrency(entry.employeeBalances[c]) : '');
      }
      row++;

      for (final tx in entry.salaryTransactions) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue('');
        for (var c = 0; c < maxCols; c++) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2 + c, rowIndex: row)).value = TextCellValue('');
        }
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2 + maxCols, rowIndex: row)).value =
            TextCellValue(tx.description);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3 + maxCols, rowIndex: row)).value =
            TextCellValue(_formatCurrency(tx.amount));
        row++;
      }
    }
  }
}
