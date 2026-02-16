import 'package:dash_web/domain/entities/weekly_ledger_entry.dart';
import 'package:dash_web/domain/entities/weekly_ledger_matrix.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show PdfGoogleFonts;

/// Generates PDF from weekly ledger table data.
class WeeklyLedgerPdfGenerator {
  static String _formatDate(DateTime date) => DateFormat('dd MMM yyyy').format(date);
  static String _formatCurrency(double amount) => '₹${amount.toStringAsFixed(2)}';

  static Future<pw.Document> generate({
    required DateTime weekStart,
    required DateTime weekEnd,
    required List<ProductionLedgerEntry> productionEntries,
    required List<TripLedgerEntry> tripEntries,
    required Map<String, double> debitByEmployeeId,
    required Map<String, double> currentBalanceByEmployeeId,
  }) async {
    final fonts = _PdfFonts(
      regular: await PdfGoogleFonts.notoSansRegular(),
      bold: await PdfGoogleFonts.notoSansBold(),
    );
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
            _buildMatrixTable(
              fonts,
              buildProductionLedgerMatrix(
                productionEntries,
                debitByEmployeeId: debitByEmployeeId,
                currentBalanceByEmployeeId: currentBalanceByEmployeeId,
              ),
              detailHeader: 'Production',
            ),
            pw.SizedBox(height: 24),
          ],
          if (tripEntries.isNotEmpty) ...[
            pw.Text('Trips', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _buildMatrixTable(
              fonts,
              buildTripLedgerMatrix(
                tripEntries,
                debitByEmployeeId: debitByEmployeeId,
                currentBalanceByEmployeeId: currentBalanceByEmployeeId,
              ),
              detailHeader: 'No. of Trips',
            ),
          ],
        ],
      ),
    );

    return pdf;
  }

  static pw.Widget _buildMatrixTable(
    _PdfFonts fonts,
    WeeklyLedgerMatrix matrix, {
    required String detailHeader,
  }) {
    final dateCount = matrix.dates.length;
    final colCount = 2 + (dateCount * 2) + 3;

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.2),
        1: const pw.FlexColumnWidth(1.4),
        for (int i = 0; i < dateCount * 2; i++)
          2 + i: i.isEven ? const pw.FlexColumnWidth(2) : const pw.FlexColumnWidth(1),
        colCount - 3: const pw.FlexColumnWidth(1),
        colCount - 2: const pw.FlexColumnWidth(1.2),
        colCount - 1: const pw.FlexColumnWidth(1.4),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _cell(fonts, 'EMPLOYEES NAMES', header: true),
            _cell(fonts, 'Opening Balance', header: true),
            for (final date in matrix.dates) ...[
              _cell(fonts, _formatDate(date), header: true),
              _cell(fonts, '', header: true),
            ],
            _cell(fonts, 'Debit', header: true),
            _cell(fonts, 'Total', header: true),
            _cell(fonts, 'Current Balance', header: true),
          ],
        ),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _cell(fonts, '', header: true),
            _cell(fonts, '', header: true),
            for (int i = 0; i < dateCount; i++) ...[
              _cell(fonts, detailHeader, header: true),
              _cell(fonts, 'Amount', header: true),
            ],
            _cell(fonts, '', header: true),
            _cell(fonts, '', header: true),
            _cell(fonts, '', header: true),
          ],
        ),
        for (final row in matrix.rows)
          pw.TableRow(
            children: [
              _cell(fonts, row.employeeName),
              _cell(fonts, _formatCurrency(row.openingBalance)),
              for (final date in matrix.dates) ...[
                _cell(fonts, row.cells[date]?.detailsText ?? '—', small: true),
                _cell(fonts, _formatCurrency(row.cells[date]?.amount ?? 0.0)),
              ],
              _cell(fonts, _formatCurrency(row.debitTotal)),
              _cell(fonts, _formatCurrency(row.totalAmount)),
              _cell(fonts, _formatCurrency(row.currentBalance)),
            ],
          ),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _cell(fonts, 'TOTAL', header: true),
            _cell(fonts, _formatCurrency(matrix.totalOpeningBalance), header: true),
            for (final date in matrix.dates) ...[
              _cell(fonts, '', header: true),
              _cell(fonts, _formatCurrency(matrix.totalsByDate[date] ?? 0.0), header: true),
            ],
            _cell(fonts, _formatCurrency(matrix.totalDebit), header: true),
            _cell(fonts, _formatCurrency(matrix.grandTotal), header: true),
            _cell(fonts, _formatCurrency(matrix.totalCurrentBalance), header: true),
          ],
        ),
      ],
    );
  }

  static pw.Widget _cell(_PdfFonts fonts, String text, {bool header = false, bool small = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: header ? fonts.bold : fonts.regular,
          fontSize: small ? 8 : (header ? 9 : 10),
        ),
        textAlign: pw.TextAlign.center,
        maxLines: 2,
      ),
    );
  }
}

class _PdfFonts {
  const _PdfFonts({required this.regular, required this.bold});

  final pw.Font regular;
  final pw.Font bold;
}
