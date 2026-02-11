import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:core_models/core_models.dart';
import 'base_operon_document.dart';
import 'pdf_builder.dart';

/// Row data for Fuel Ledger PDF (Voucher, Date, Amount, VehicleNo)
class FuelLedgerRow {
  const FuelLedgerRow({
    required this.voucher,
    required this.date,
    required this.amount,
    required this.vehicleNo,
  });

  final String voucher;
  final DateTime date;
  final double amount;
  final String vehicleNo;
}

/// Generates a PDF for Fuel Ledger: company header, vendor name,
/// table (Voucher, Date, Amount, VehicleNo), footer with Total,
/// Payment Mode and Payment Date.
Future<Uint8List> generateFuelLedgerPdf({
  required DmHeaderSettings companyHeader,
  required String vendorName,
  required List<FuelLedgerRow> rows,
  required double total,
  String? paymentMode,
  DateTime? paymentDate,
  Uint8List? logoBytes,
}) async {
  final pdf = pw.Document();
  const pageFormat = PdfPageFormat.a4;

  pdf.addPage(
    pw.MultiPage(
      pageFormat: pageFormat,
      margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 35),
      build: (pw.Context context) {
        return [
          BaseOperonDocument.buildOperonHeader(
            companyHeader,
            logoBytes,
            documentTitle: 'FUEL LEDGER',
          ),
          pw.SizedBox(height: 16),
          _buildVendorTitle(vendorName),
          pw.SizedBox(height: 14),
          _buildTable(rows),
          pw.SizedBox(height: 16),
          _buildFooter(total, paymentMode, paymentDate),
        ];
      },
    ),
  );

  return pdf.save();
}

pw.Widget _buildVendorTitle(String vendorName) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: const pw.BoxDecoration(
      color: PdfColors.grey50,
      border: pw.Border(
        left: pw.BorderSide(color: PdfColors.grey700, width: 3),
      ),
    ),
    child: pw.Text(
      vendorName,
      style: pw.TextStyle(
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      ),
    ),
  );
}

pw.Widget _buildTable(List<FuelLedgerRow> rows) {
  const headers = ['VOUCHER', 'DATE', 'AMOUNT', 'VEHICLE NO'];

  return pw.Table(
    columnWidths: {
      0: const pw.FlexColumnWidth(1.2),
      1: const pw.FlexColumnWidth(1.2),
      2: const pw.FlexColumnWidth(1),
      3: const pw.FlexColumnWidth(1.2),
    },
    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
        children: headers.map((h) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: pw.Text(
            h,
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
              letterSpacing: 0.3,
            ),
          ),
        )).toList(),
      ),
      ...rows.asMap().entries.map((entry) {
        final index = entry.key;
        final row = entry.value;
        final bg = index % 2 == 0 ? PdfColors.white : PdfColors.grey50;
        return pw.TableRow(
          decoration: pw.BoxDecoration(color: bg),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: pw.Text(
                row.voucher,
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.black),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: pw.Text(
                PdfBuilder.formatDateDDMMYYYY(row.date),
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.black),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: pw.Text(
                PdfBuilder.formatCurrency(row.amount),
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.black),
                textAlign: pw.TextAlign.right,
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: pw.Text(
                row.vehicleNo,
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.black),
              ),
            ),
          ],
        );
      }),
    ],
  );
}

pw.Widget _buildFooter(
  double total,
  String? paymentMode,
  DateTime? paymentDate,
) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Total',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
            pw.Text(
              PdfBuilder.formatCurrency(total),
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ],
        ),
        if (paymentMode != null && paymentMode.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Payment Mode',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                paymentMode,
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey800,
                ),
              ),
            ],
          ),
        ],
        if (paymentDate != null) ...[
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Payment Date',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                PdfBuilder.formatDateDDMMYYYY(paymentDate),
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey800,
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
