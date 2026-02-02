import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:core_models/core_models.dart';

/// Navy accent used across Operon PDFs (ledger, fuel ledger, etc.)
const PdfColor kOperonNavyBlue = PdfColor.fromInt(0xFF1E3A5F);

/// Base for Operon PDF documents. Provides shared branding (logo, company name, GST),
/// standard page template (A4/landscape), and shared widgets for header, footer, and QR.
/// Logo must be provided as bytes; caller fetches from [DmHeaderSettings.logoImageUrl].
abstract class BaseOperonDocument {
  BaseOperonDocument({
    required this.header,
    this.logoBytes,
    this.footer,
  });

  final DmHeaderSettings header;
  final Uint8List? logoBytes;
  final DmFooterSettings? footer;

  /// Override for landscape (e.g. DM, Lakshmee).
  PdfPageFormat get pageFormat => PdfPageFormat.a4;

  /// Standard margin for ledger/fuel; override in subclasses if needed.
  pw.EdgeInsets get pageMargin =>
      const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 35);

  /// Build full PDF bytes. Subclasses implement by building document and calling helpers.
  Future<Uint8List> generate();

  /// Navy top border, logo + company info, optional right-side document title (e.g. "LEDGER STATEMENT").
  /// Static so ledger/fuel generators can use without extending.
  static pw.Widget buildOperonHeader(
    DmHeaderSettings header,
    Uint8List? logoBytes, {
    String? documentTitle,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: kOperonNavyBlue, width: 2),
        ),
      ),
      child: pw.Padding(
        padding: const pw.EdgeInsets.only(top: 16, bottom: 16),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logoBytes != null) _staticLogoContainer(logoBytes),
                  pw.SizedBox(width: 16),
                  pw.Expanded(child: BaseOperonDocument.buildCompanyInfo(header)),
                ],
              ),
            ),
            if (documentTitle != null)
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  documentTitle,
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

  /// Company name, address, phone, GST — for header or DM portrait/landscape.
  static pw.Widget buildCompanyInfo(DmHeaderSettings header) {
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

  /// Optional footer with custom text from settings or parameter; centered, small italic.
  static pw.Widget buildOperonFooter(DmFooterSettings? footer, {String? customText}) {
    final text = footer?.customText ?? customText;
    if (text == null || text.isEmpty) return pw.SizedBox.shrink();
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          color: PdfColors.grey700,
          fontStyle: pw.FontStyle.italic,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  /// Shared payment QR section for DM/custom templates. [compact] reduces size for side panels.
  static pw.Widget buildQrCodeSection({
    required Uint8List? qrCodeBytes,
    String? accountName,
    String? upiId,
    String? amountText,
    bool compact = false,
  }) {
    final size = compact ? 130.0 : 160.0;
    final qrChildren = <pw.Widget>[
      pw.Text(
        'Payment QR Code',
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue900,
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Container(
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: qrCodeBytes != null && qrCodeBytes.isNotEmpty
            ? pw.Image(
                pw.MemoryImage(qrCodeBytes),
                width: size,
                height: size,
                fit: pw.BoxFit.contain,
              )
            : pw.SizedBox(
                width: size,
                height: size,
                child: pw.Center(
                  child: pw.Text(
                    'QR Code',
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
              ),
      ),
    ];
    if (accountName != null && accountName.isNotEmpty) {
      qrChildren.addAll([
        pw.SizedBox(height: 6),
        pw.Text(
          accountName,
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey700,
            fontWeight: pw.FontWeight.bold,
          ),
          textAlign: pw.TextAlign.center,
        ),
      ]);
    }
    if (upiId != null && upiId.isNotEmpty) {
      qrChildren.addAll([
        pw.SizedBox(height: 3),
        pw.Text(
          upiId,
          style: const pw.TextStyle(
            fontSize: 8,
            color: PdfColors.grey600,
          ),
          textAlign: pw.TextAlign.center,
        ),
      ]);
    }
    if (amountText != null && amountText.isNotEmpty) {
      qrChildren.addAll([
        pw.SizedBox(height: 3),
        pw.Text(
          amountText,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
          textAlign: pw.TextAlign.center,
        ),
      ]);
    }
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blue700, width: 1.5),
        borderRadius: pw.BorderRadius.circular(6),
        color: PdfColors.grey50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisSize: pw.MainAxisSize.min,
        children: qrChildren,
      ),
    );
  }

  static pw.Widget _staticLogoContainer(Uint8List bytes) {
    try {
      final logoImage = pw.MemoryImage(bytes);
      return pw.Container(
        width: 60,
        height: 60,
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        ),
        child: pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
        ),
      );
    } catch (_) {
      return pw.SizedBox.shrink();
    }
  }
}
