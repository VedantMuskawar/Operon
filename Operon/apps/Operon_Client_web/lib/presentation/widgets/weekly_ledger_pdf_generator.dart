import 'package:dash_web/domain/entities/weekly_ledger_entry.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Generates PDF from weekly ledger table data.
class WeeklyLedgerPdfGenerator {
  static String _formatDate(DateTime date) => DateFormat('dd MMM yyyy').format(date);
  static String _formatCurrency(double amount) => '₹${amount.toStringAsFixed(2)}';

  static pw.Document generate({
    required DateTime weekStart,
    required DateTime weekEnd,
    required List<ProductionLedgerEntry> productionEntries,
    required List<TripLedgerEntry> tripEntries,
  }) {
    final pdf = pw.Document();
    final weekRange = '${_formatDate(weekStart)} - ${_formatDate(weekEnd)}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Weekly Ledger',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                weekRange,
                style: const pw.TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        build: (context) => [
          if (productionEntries.isNotEmpty) ...[
            pw.Text('Productions', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _buildProductionsTable(productionEntries),
            pw.SizedBox(height: 24),
          ],
          if (tripEntries.isNotEmpty) ...[
            pw.Text('Trips', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _buildTripsTable(tripEntries),
          ],
        ],
      ),
    );

    return pdf;
  }

  static pw.Widget _buildProductionsTable(List<ProductionLedgerEntry> entries) {
    final maxCols = entries.isEmpty ? 0 : entries.map((e) => e.employeeNames.length).reduce((a, b) => a > b ? a : b);
    final colCount = 2 + (maxCols > 0 ? maxCols : 1) + 2;

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
      columnWidths: {
        for (int i = 0; i < colCount; i++)
          i: i == 0
              ? const pw.FlexColumnWidth(1.2)
              : i == 1
                  ? const pw.FlexColumnWidth(1.5)
                  : i < 2 + maxCols
                      ? const pw.FlexColumnWidth(1)
                      : i == colCount - 2
                          ? const pw.FlexColumnWidth(2)
                          : const pw.FlexColumnWidth(0.8),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _cell('Date', header: true),
            _cell('Batch No.', header: true),
            ...List.generate(maxCols > 0 ? maxCols : 1, (_) => _cell('', header: true)),
            _cell('Description', header: true),
            _cell('Amount', header: true),
          ],
        ),
        for (final entry in entries) ..._productionEntryRows(entry, maxCols),
      ],
    );
  }

  static List<pw.TableRow> _productionEntryRows(ProductionLedgerEntry entry, int maxCols) {
    final rows = <pw.TableRow>[];
    final n = entry.employeeNames.length;

    rows.add(
      pw.TableRow(
        children: [
          _cell(_formatDate(entry.date)),
          _cell(entry.batchNo),
          ...List.generate(maxCols, (i) => _cell(i < n ? entry.employeeNames[i] : '')),
          _cell(''),
          _cell(''),
        ],
      ),
    );
    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
        children: [
          _cell(''),
          _cell(''),
          ...List.generate(maxCols, (i) => _cell(i < n ? _formatCurrency(entry.employeeBalances[i]) : '')),
          _cell(''),
          _cell(''),
        ],
      ),
    );
    for (final tx in entry.salaryTransactions) {
      rows.add(
        pw.TableRow(
          children: [
            _cell(''),
            _cell(''),
            ...List.generate(maxCols, (_) => _cell('')),
            _cell(tx.description, small: true),
            _cell(_formatCurrency(tx.amount), small: true),
          ],
        ),
      );
    }
    return rows;
  }

  static pw.Widget _buildTripsTable(List<TripLedgerEntry> entries) {
    final maxCols = entries.isEmpty ? 0 : entries.map((e) => e.employeeNames.length).reduce((a, b) => a > b ? a : b);
    final colCount = 2 + (maxCols > 0 ? maxCols : 1) + 2;

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
      columnWidths: {
        for (int i = 0; i < colCount; i++)
          i: i == 0
              ? const pw.FlexColumnWidth(1.2)
              : i == 1
                  ? const pw.FlexColumnWidth(1.8)
                  : i < 2 + maxCols
                      ? const pw.FlexColumnWidth(1)
                      : i == colCount - 2
                          ? const pw.FlexColumnWidth(2)
                          : const pw.FlexColumnWidth(0.8),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _cell('Date', header: true),
            _cell('Vehicle No. (Trips)', header: true),
            ...List.generate(maxCols > 0 ? maxCols : 1, (_) => _cell('', header: true)),
            _cell('Description', header: true),
            _cell('Amount', header: true),
          ],
        ),
        for (final entry in entries) ..._tripEntryRows(entry, maxCols),
      ],
    );
  }

  static List<pw.TableRow> _tripEntryRows(TripLedgerEntry entry, int maxCols) {
    final rows = <pw.TableRow>[];
    final n = entry.employeeNames.length;
    final vehicleLabel = '${entry.vehicleNo} (${entry.tripCount})';

    rows.add(
      pw.TableRow(
        children: [
          _cell(_formatDate(entry.date)),
          _cell(vehicleLabel),
          ...List.generate(maxCols, (i) => _cell(i < n ? entry.employeeNames[i] : '')),
          _cell(''),
          _cell(''),
        ],
      ),
    );
    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
        children: [
          _cell(''),
          _cell(''),
          ...List.generate(maxCols, (i) => _cell(i < n ? _formatCurrency(entry.employeeBalances[i]) : '')),
          _cell(''),
          _cell(''),
        ],
      ),
    );
    for (final tx in entry.salaryTransactions) {
      rows.add(
        pw.TableRow(
          children: [
            _cell(''),
            _cell(''),
            ...List.generate(maxCols, (_) => _cell('')),
            _cell(tx.description, small: true),
            _cell(_formatCurrency(tx.amount), small: true),
          ],
        ),
      );
    }
    return rows;
  }

  static pw.Widget _cell(String text, {bool header = false, bool small = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: small ? 8 : (header ? 9 : 10),
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        maxLines: 2,
      ),
    );
  }
}
