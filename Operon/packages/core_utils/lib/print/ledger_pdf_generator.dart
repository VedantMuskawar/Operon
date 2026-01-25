import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:core_models/core_models.dart';
import 'pdf_builder.dart';

/// Professional Navy Blue color for FinTech theme
const PdfColor _navyBlue = PdfColor.fromInt(0xFF1E3A5F);

/// Calculate opening balance for a date range
/// 
/// Takes all transactions for an entity and calculates the running balance
/// up to (but not including) the start date. If there are no transactions
/// before the start date, returns the stored opening balance.
/// Returns the final balance which becomes the opening balance for the date range.
double calculateOpeningBalance({
  required List<Transaction> allTransactions,
  required DateTime startDate,
  required double storedOpeningBalance,
}) {
  // Filter transactions before start date
  final transactionsBeforeStart = allTransactions.where((tx) {
    final txDate = tx.createdAt ?? tx.updatedAt;
    if (txDate == null) return false;
    // Include transactions up to but not including start date
    return txDate.isBefore(startDate);
  }).toList();

  // If no transactions before start date, use stored opening balance
  if (transactionsBeforeStart.isEmpty) {
    return storedOpeningBalance;
  }

  // Sort chronologically (oldest first)
  transactionsBeforeStart.sort((a, b) {
    final aDate = a.createdAt ?? a.updatedAt ?? DateTime(1970);
    final bDate = b.createdAt ?? b.updatedAt ?? DateTime(1970);
    return aDate.compareTo(bDate);
  });

  // Calculate running balance starting from stored opening balance
  double balance = storedOpeningBalance;
  for (final tx in transactionsBeforeStart) {
    if (tx.type == TransactionType.credit) {
      balance += tx.amount;
    } else if (tx.type == TransactionType.debit) {
      balance -= tx.amount;
    }
  }

  return balance;
}

/// Ledger row data for PDF generation
class LedgerRowData {
  const LedgerRowData({
    required this.date,
    required this.reference,
    required this.debit,
    required this.credit,
    required this.balance,
    required this.type,
    required this.remarks,
  });

  final DateTime date;
  final String reference; // DM No. / Batch/Trip / Invoice No.
  final double debit;
  final double credit;
  final double balance;
  final String type;
  final String remarks;
}

/// Generate a ledger PDF for Client, Employee, or Vendor
/// Modern FinTech/SaaS design with clean hierarchy and high contrast
Future<Uint8List> generateLedgerPdf({
  required LedgerType ledgerType,
  required String entityName,
  required List<LedgerRowData> transactions,
  required double openingBalance,
  required DmHeaderSettings companyHeader,
  required DateTime startDate,
  required DateTime endDate,
  Uint8List? logoBytes,
}) async {
  final pdf = pw.Document();
  final pageFormat = PdfPageFormat.a4; // A4 Portrait

  // Determine column headers based on ledger type
  final List<String> headers = _getHeadersForLedgerType(ledgerType);

  // Calculate totals
  final totalDebit = transactions.fold<double>(0, (sum, row) => sum + row.debit);
  final totalCredit = transactions.fold<double>(0, (sum, row) => sum + row.credit);
  final closingBalance = openingBalance + totalCredit - totalDebit;
  final netBalance = totalCredit - totalDebit;

  pdf.addPage(
    pw.MultiPage(
      pageFormat: pageFormat,
      margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 35),
      build: (pw.Context context) {
        return [
          // Modern Header with Navy Blue top border
          _buildModernHeader(companyHeader, logoBytes),
          pw.SizedBox(height: 20),

          // Title Section
          _buildLedgerTitle(entityName, startDate, endDate),
          pw.SizedBox(height: 18),

          // Modern Table (no vertical lines, horizontal dividers only)
          _buildModernTable(
            headers: headers,
            openingBalance: openingBalance,
            transactions: transactions,
            startDate: startDate,
          ),
          
          pw.SizedBox(height: 16),
          
          // Summary Dashboard (3-column grid)
          _buildSummaryDashboard(
            openingBalance: openingBalance,
            totalDebit: totalDebit,
            totalCredit: totalCredit,
            closingBalance: closingBalance,
            netBalance: netBalance,
          ),
        ];
      },
    ),
  );

  return pdf.save();
}

/// Get column headers based on ledger type
List<String> _getHeadersForLedgerType(LedgerType ledgerType) {
  switch (ledgerType) {
    case LedgerType.clientLedger:
      return ['Date', 'DM No.', 'Debit', 'Credit', 'Balance', 'Type', 'Remarks'];
    case LedgerType.employeeLedger:
      return ['Date', 'Batch/Trip', 'Debit', 'Credit', 'Balance', 'Type', 'Remarks'];
    case LedgerType.vendorLedger:
      return ['Date', 'Invoice No.', 'Debit', 'Credit', 'Balance', 'Type', 'Remarks'];
    default:
      return ['Date', 'Reference', 'Debit', 'Credit', 'Balance', 'Type', 'Remarks'];
  }
}

/// Build modern header with Navy Blue top border
pw.Widget _buildModernHeader(DmHeaderSettings header, Uint8List? logoBytes) {
  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border(
        top: pw.BorderSide(color: _navyBlue, width: 2),
      ),
    ),
    child: pw.Padding(
      padding: const pw.EdgeInsets.only(top: 16, bottom: 16),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // Left: Logo and Company Info
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logoBytes != null) ...[
                  pw.Container(
                    width: 60,
                    height: 60,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                    ),
                    child: (() {
                      try {
                        final logoImage = pw.MemoryImage(logoBytes);
                        return pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                        );
                      } catch (e) {
                        return pw.SizedBox.shrink();
                      }
                    })(),
                  ),
                  pw.SizedBox(width: 16),
                ],
                pw.Expanded(
                  child: _buildCompanyInfo(header),
                ),
              ],
            ),
          ),
          // Right: LEDGER STATEMENT anchor
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'LEDGER STATEMENT',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey500,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Build company info section
pw.Widget _buildCompanyInfo(DmHeaderSettings header) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        header.name,
        style: pw.TextStyle(
          fontSize: 18,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.black,
          letterSpacing: 0.3,
        ),
      ),
      pw.SizedBox(height: 6),
      if (header.address.isNotEmpty) ...[
        pw.Text(
          header.address,
          style: const pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey700,
            height: 1.3,
          ),
        ),
        pw.SizedBox(height: 4),
      ],
      pw.Wrap(
        spacing: 14,
        runSpacing: 3,
        children: [
          pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                'Phone: ',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                  fontWeight: pw.FontWeight.normal,
                ),
              ),
              pw.Text(
                header.phone,
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey800,
                ),
              ),
            ],
          ),
          if (header.gstNo != null && header.gstNo!.isNotEmpty)
            pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  'GST: ',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                    fontWeight: pw.FontWeight.normal,
                  ),
                ),
                pw.Text(
                  header.gstNo!,
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey800,
                  ),
                ),
              ],
            ),
        ],
      ),
    ],
  );
}

/// Build ledger title section
pw.Widget _buildLedgerTitle(String entityName, DateTime startDate, DateTime endDate) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey50,
      border: pw.Border(
        left: pw.BorderSide(color: PdfColors.grey700, width: 3),
      ),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          entityName,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          '${PdfBuilder.formatDateDDMMYYYY(startDate)} to ${PdfBuilder.formatDateDDMMYYYY(endDate)}',
          style: pw.TextStyle(
            fontSize: 9,
            color: PdfColors.grey700,
          ),
        ),
      ],
    ),
  );
}

/// Build modern table with no vertical lines, only horizontal dividers
pw.Widget _buildModernTable({
  required List<String> headers,
  required double openingBalance,
  required List<LedgerRowData> transactions,
  required DateTime startDate,
}) {
  // Create opening balance row
  final openingBalanceRow = LedgerRowData(
    date: startDate,
    reference: 'Opening Balance',
    debit: openingBalance < 0 ? -openingBalance : 0.0,
    credit: openingBalance >= 0 ? openingBalance : 0.0,
    balance: openingBalance,
    type: 'Opening Balance',
    remarks: '-',
  );

  // Combine opening balance with transactions
  final allRows = [openingBalanceRow, ...transactions];

  // Build table rows
  final tableRows = allRows.asMap().entries.map((entry) {
    final index = entry.key;
    final row = entry.value;
    final isOpeningBalance = index == 0;
    final isEven = index % 2 == 0;
    return _buildTableRow(
      row,
      headers.length,
      isOpeningBalance: isOpeningBalance,
      isEven: isEven,
      isLast: index == allRows.length - 1,
    );
  }).toList();

  return pw.Column(
    children: [
      // Header row
      _buildTableHeaderRow(headers),
      // Data rows with horizontal dividers
      ...tableRows,
    ],
  );
}

/// Build table header row
pw.Widget _buildTableHeaderRow(List<String> headers) {
  return pw.Container(
    decoration: const pw.BoxDecoration(
      color: PdfColors.grey100,
    ),
    child: pw.Table(
      columnWidths: {
        for (int i = 0; i < headers.length; i++)
          i: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          children: headers.asMap().entries.map((entry) {
            final index = entry.key;
            final header = entry.value;
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: pw.Text(
                header.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                  letterSpacing: 0.3,
                ),
                textAlign: _getHeaderAlignment(index),
              ),
            );
          }).toList(),
        ),
      ],
    ),
  );
}

/// Get header alignment based on column index
pw.TextAlign _getHeaderAlignment(int index) {
  if (index == 2 || index == 3 || index == 4) return pw.TextAlign.right; // Debit, Credit, Balance
  if (index == 0 || index == 1 || index == 5) return pw.TextAlign.center; // Date, Reference, Type
  return pw.TextAlign.left; // Remarks
}

/// Build a single table row with horizontal divider
pw.Widget _buildTableRow(
  LedgerRowData row,
  int columnCount, {
  required bool isOpeningBalance,
  required bool isEven,
  required bool isLast,
}) {
  // Determine background color
  PdfColor backgroundColor;
  if (isOpeningBalance) {
    backgroundColor = PdfColors.grey100;
  } else if (isEven) {
    backgroundColor = PdfColors.white;
  } else {
    backgroundColor = PdfColors.grey50;
  }

  return pw.Column(
    children: [
      pw.Container(
        color: backgroundColor,
        child: pw.Table(
          columnWidths: {
            for (int i = 0; i < 7; i++)
              i: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              children: [
                // Date
                _buildTableCell(
                  PdfBuilder.formatDateDDMMYYYY(row.date),
                  pw.TextAlign.center,
                  backgroundColor: backgroundColor,
                  isOpeningBalance: isOpeningBalance,
                ),
                // Reference
                _buildTableCell(
                  row.reference,
                  pw.TextAlign.center,
                  backgroundColor: backgroundColor,
                  isOpeningBalance: isOpeningBalance,
                ),
                // Debit
                _buildTableCell(
                  row.debit > 0 ? PdfBuilder.formatCurrency(row.debit) : '-',
                  pw.TextAlign.right,
                  backgroundColor: backgroundColor,
                  isOpeningBalance: isOpeningBalance,
                  isNumeric: true,
                ),
                // Credit
                _buildTableCell(
                  row.credit > 0 ? PdfBuilder.formatCurrency(row.credit) : '-',
                  pw.TextAlign.right,
                  backgroundColor: backgroundColor,
                  isOpeningBalance: isOpeningBalance,
                  isNumeric: true,
                ),
                // Balance
                _buildTableCell(
                  PdfBuilder.formatCurrency(row.balance),
                  pw.TextAlign.right,
                  fontWeight: pw.FontWeight.bold,
                  color: row.balance >= 0 ? PdfColors.green700 : PdfColors.red700,
                  backgroundColor: backgroundColor,
                  isOpeningBalance: isOpeningBalance,
                  isNumeric: true,
                ),
                // Type
                _buildTableCell(
                  row.type,
                  pw.TextAlign.center,
                  backgroundColor: backgroundColor,
                  isOpeningBalance: isOpeningBalance,
                ),
                // Remarks
                _buildTableCell(
                  row.remarks,
                  pw.TextAlign.left,
                  backgroundColor: backgroundColor,
                  isOpeningBalance: isOpeningBalance,
                ),
              ],
            ),
          ],
        ),
      ),
      // Horizontal divider (subtle grey200)
      if (!isLast)
        pw.Container(
          height: 0.5,
          color: PdfColors.grey200,
        ),
    ],
  );
}

/// Build a table cell
pw.Widget _buildTableCell(
  String text,
  pw.TextAlign align, {
  pw.FontWeight? fontWeight,
  PdfColor? color,
  PdfColor? backgroundColor,
  bool isOpeningBalance = false,
  bool isNumeric = false,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    decoration: backgroundColor != null
        ? pw.BoxDecoration(color: backgroundColor)
        : null,
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: isOpeningBalance ? 9 : 8.5,
        fontWeight: fontWeight ?? pw.FontWeight.normal,
        color: color ?? PdfColors.black,
        // For numeric columns, use tighter letter spacing for better alignment
        letterSpacing: isNumeric ? 0.1 : 0,
      ),
      textAlign: align,
      maxLines: 2,
      overflow: pw.TextOverflow.clip,
    ),
  );
}

/// Build summary dashboard with 3-column grid layout
pw.Widget _buildSummaryDashboard({
  required double openingBalance,
  required double totalDebit,
  required double totalCredit,
  required double closingBalance,
  required double netBalance,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Opening Balance (subtle line above grid)
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Opening Balance',
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey600,
                fontWeight: pw.FontWeight.normal,
              ),
            ),
            pw.Text(
              PdfBuilder.formatCurrency(openingBalance),
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        // 3-column grid
        pw.Row(
          children: [
            // Column 1: Total Debit
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Total Debit',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                      fontWeight: pw.FontWeight.normal,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    PdfBuilder.formatCurrency(totalDebit),
                    style: pw.TextStyle(
                      fontSize: 10.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
            // Column 2: Total Credit
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Total Credit',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                      fontWeight: pw.FontWeight.normal,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    PdfBuilder.formatCurrency(totalCredit),
                    style: pw.TextStyle(
                      fontSize: 10.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
            // Column 3: Net Balance (highlighted)
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey400, width: 1),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Net Balance',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                        fontWeight: pw.FontWeight.normal,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      PdfBuilder.formatCurrency(closingBalance),
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: closingBalance >= 0 ? PdfColors.green700 : PdfColors.red700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
