import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:core_models/core_models.dart';

// ---------------------------------------------------------------------------
// Data models for Lakshmee DM template
// ---------------------------------------------------------------------------

/// Client info for DM print.
class DmPrintDataClient {
  const DmPrintDataClient({required this.name, required this.phone});
  final String name;
  final String phone;
}

/// Vehicle info for DM print.
class DmPrintDataVehicle {
  const DmPrintDataVehicle({required this.number});
  final String number;
}

/// Driver info for DM print.
class DmPrintDataDriver {
  const DmPrintDataDriver({required this.name});
  final String name;
}

/// Product line item for DM print.
class ProductItem {
  const ProductItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    double? lineTotal,
  }) : lineTotal = lineTotal ?? (quantity * unitPrice);
  final String productName;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
}

/// Structured data for the Lakshmee DM template (replaces Map parsing).
class DmPrintData {
  const DmPrintData({
    required this.dmNumber,
    required this.deliveryDate,
    required this.client,
    required this.vehicle,
    required this.driver,
    required this.productItems,
    required this.total,
    required this.paymentMode,
    required this.accountName,
    required this.formattedAddress,
  });

  final int dmNumber;
  final DateTime deliveryDate;
  final DmPrintDataClient client;
  final DmPrintDataVehicle vehicle;
  final DmPrintDataDriver driver;
  final List<ProductItem> productItems;
  final double total;
  final String paymentMode;
  final String accountName;
  final String formattedAddress;

  /// Parses raw DM map (and optional payment account) with Firestore/null-safety handling.
  factory DmPrintData.fromMap(
    Map<String, dynamic> dmData,
    Map<String, dynamic>? paymentAccount,
  ) {
    final dmNumber = dmData['dmNumber'] as int? ??
        (dmData['dmNumber'] as num?)?.toInt() ??
        0;

    final deliveryDateData = dmData['deliveryDate'] ?? dmData['scheduledDate'];
    final deliveryDate = deliveryDateData != null
        ? _parseDate(deliveryDateData)
        : DateTime.now();

    final clientName = dmData['clientName'] as String? ?? 'N/A';
    final clientPhone = dmData['clientPhone'] as String? ??
        dmData['clientPhoneNumber'] as String? ??
        dmData['customerNumber'] as String? ??
        'N/A';
    final client = DmPrintDataClient(name: clientName, phone: clientPhone);

    final vehicleNumber = dmData['vehicleNumber'] as String? ?? 'N/A';
    final vehicle = DmPrintDataVehicle(number: vehicleNumber);

    final driverName = dmData['driverName'] as String? ?? 'N/A';
    final driver = DmPrintDataDriver(name: driverName);

    final itemsData = dmData['items'];
    final rawItems = itemsData is List
        ? itemsData
        : (itemsData != null ? [itemsData] : []);
    final productItems = <ProductItem>[];
    for (final raw in rawItems) {
      final itemMap =
          raw is Map<String, dynamic> ? raw : <String, dynamic>{};
      final productName = itemMap['productName'] as String? ??
          itemMap['name'] as String? ??
          'N/A';
      final quantity = (itemMap['fixedQuantityPerTrip'] as num?)?.toInt() ??
          (itemMap['totalQuantity'] as num?)?.toInt() ??
          (itemMap['quantity'] as num?)?.toInt() ??
          0;
      final unitPrice = (itemMap['unitPrice'] as num?)?.toDouble() ??
          (itemMap['price'] as num?)?.toDouble() ??
          0.0;
      productItems.add(ProductItem(
        productName: productName,
        quantity: quantity,
        unitPrice: unitPrice,
      ));
    }

    double totalAmount = 0.0;
    final tripPricingData = dmData['tripPricing'];
    if (tripPricingData is Map<String, dynamic>) {
      totalAmount = (tripPricingData['total'] as num?)?.toDouble() ?? 0.0;
    }
    if (totalAmount == 0.0 && productItems.isNotEmpty) {
      totalAmount = productItems.fold<double>(
        0.0,
        (sum, i) => sum + i.lineTotal,
      );
    }

    final paymentStatus = dmData['paymentStatus'] as bool? ?? false;
    final toAccount = dmData['toAccount'] as String?;
    final paySchedule = dmData['paySchedule'] as String?;
    String paymentMode = 'N/A';
    if (paymentStatus && toAccount != null) {
      paymentMode = toAccount;
    } else if (paySchedule == 'POD') {
      paymentMode = 'Cash';
    } else if (paySchedule == 'PL') {
      paymentMode = 'Credit';
    } else if (paySchedule != null) {
      paymentMode = paySchedule;
    }

    final accountName = paymentAccount?['name'] as String? ??
        'Lakshmee Intelligent Technologies';

    final address = dmData['address'] as String?;
    final regionName = dmData['regionName'] as String?;
    // Use hyphen (not em dash U+2014) so standard PDF fonts can draw it
    final rawAddress = '${address ?? "-"}, ${regionName ?? ""}'.trim();
    final formattedAddress =
        (rawAddress.isEmpty || rawAddress == ',') ? 'N/A' : rawAddress;

    return DmPrintData(
      dmNumber: dmNumber,
      deliveryDate: deliveryDate,
      client: client,
      vehicle: vehicle,
      driver: driver,
      productItems: productItems,
      total: totalAmount,
      paymentMode: paymentMode,
      accountName: accountName,
      formattedAddress: formattedAddress.isEmpty ? 'N/A' : formattedAddress,
    );
  }
}

// ---------------------------------------------------------------------------
// Lakshmee design system (reusable for Invoice/Report later)
// ---------------------------------------------------------------------------

class LakshmeeTheme {
  const LakshmeeTheme({
    this.headerBackground = '#f1f1f1',
    this.headerBorder = '#bbbbbb',
    this.bodyText = '#333333',
    this.mutedText = '#444444',
    this.infoBoxBorder = '#cccccc',
    this.infoBoxBackground = '#fafafa',
    this.qrBoxBackground = '#f8f8f8',
    this.amountText = '#1f2937',
    this.fontSizeTitle = 16,
    this.fontSizeSubtitle = 11,
    this.fontSizeBody = 11,
    this.fontSizeTableLabel = 12,
    this.fontSizeDeliveryMemo = 13,
    this.fontSizeDmNumber = 12,
    this.borderRadius = 4,
    this.dividerThickness = 2,
    this.borderWidth = 1,
    this.qrBoxBorderWidth = 3,
    this.companyTitle = 'LAKSHMEE INTELLIGENT TECHNOLOGIES',
    this.companyAddress = 'B-24/2, M.I.D.C., CHANDRAPUR - 442406',
    this.companyPhone = 'Ph: +91 8149448822 | +91 9420448822',
    this.jurisdictionNote = 'Note: Subject to Chandrapur Jurisdiction',
  });

  final String headerBackground;
  final String headerBorder;
  final String bodyText;
  final String mutedText;
  final String infoBoxBorder;
  final String infoBoxBackground;
  final String qrBoxBackground;
  final String amountText;
  final int fontSizeTitle;
  final int fontSizeSubtitle;
  final int fontSizeBody;
  final int fontSizeTableLabel;
  final int fontSizeDeliveryMemo;
  final int fontSizeDmNumber;
  final double borderRadius;
  final double dividerThickness;
  final double borderWidth;
  final double qrBoxBorderWidth;
  final String companyTitle;
  final String companyAddress;
  final String companyPhone;
  final String jurisdictionNote;

  static const LakshmeeTheme defaultTheme = LakshmeeTheme();
}

// ---------------------------------------------------------------------------
// Custom DM template routing
// ---------------------------------------------------------------------------

/// Generates a PDF for a custom DM template based on template ID
/// 
/// Routes to specific template implementations based on customTemplateId
Future<Uint8List> generateCustomDmPdf({
  required Map<String, dynamic> dmData,
  required DmSettings dmSettings,
  required String customTemplateId,
  Map<String, dynamic>? paymentAccount,
  Uint8List? logoBytes,
  Uint8List? qrCodeBytes,
  Uint8List? watermarkBytes,
}) async {
  // Route to specific template based on ID
  switch (customTemplateId) {
    case 'lakshmee_v1':
      return generateLakshmeeTemplate(
        dmData: dmData,
        dmSettings: dmSettings,
        paymentAccount: paymentAccount,
        qrCodeBytes: qrCodeBytes,
        watermarkBytes: watermarkBytes,
      );
    default:
      // Fallback to universal template if template ID not found
      throw Exception('Unknown custom template ID: $customTemplateId');
  }
}

/// Generate Lakshmee Intelligent Technologies custom DM template
/// Replicates the design from PrintDM.jsx (single copy, A4 landscape)
Future<Uint8List> generateLakshmeeTemplate({
  required Map<String, dynamic> dmData,
  required DmSettings dmSettings,
  Map<String, dynamic>? paymentAccount,
  Uint8List? qrCodeBytes,
  Uint8List? watermarkBytes,
}) async {
  final data = DmPrintData.fromMap(dmData, paymentAccount);
  const theme = LakshmeeTheme.defaultTheme;
  final pdf = pw.Document();

  final hasQr = qrCodeBytes != null && qrCodeBytes.isNotEmpty;
  final showPaymentSection = hasQr || paymentAccount != null;

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(0),
      build: (context) {
        return pw.Container(
          width: PdfPageFormat.a4.landscape.width,
          height: PdfPageFormat.a4.landscape.height,
          padding: const pw.EdgeInsets.all(5 * PdfPageFormat.mm),
          decoration: const pw.BoxDecoration(color: PdfColors.white),
          child: pw.Container(
            width: PdfPageFormat.a4.landscape.width - 10 * PdfPageFormat.mm,
            height: PdfPageFormat.a4.landscape.height - 10 * PdfPageFormat.mm,
            margin: const pw.EdgeInsets.symmetric(horizontal: 0),
            child: pw.Container(
              width: double.infinity,
              height: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                vertical: 4 * PdfPageFormat.mm,
                horizontal: 5 * PdfPageFormat.mm,
              ),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: PdfColors.black,
                  width: theme.borderWidth,
                ),
                color: PdfColors.white,
              ),
              child: pw.Stack(
                children: [
                  if (watermarkBytes != null)
                    pw.Positioned.fill(
                      child: pw.Opacity(
                        opacity: 0.1,
                        child: pw.Center(
                          child: pw.Image(
                            pw.MemoryImage(watermarkBytes),
                            width: 500,
                            fit: pw.BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.start,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          _buildLakshmeeHeader(theme),
                          pw.SizedBox(height: 3),
                          pw.Divider(
                            color: PdfColors.black,
                            thickness: theme.dividerThickness,
                            height: 0,
                          ),
                          pw.SizedBox(height: 4),
                          _buildLakshmeeTitleRow(data.dmNumber, theme),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              if (showPaymentSection) ...[
                                _buildLakshmeePaymentSection(
                                  accountName: data.accountName,
                                  total: data.total,
                                  qrCodeBytes: qrCodeBytes,
                                  theme: theme,
                                ),
                                pw.SizedBox(width: 8),
                              ],
                              pw.Expanded(
                                flex: 2,
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  mainAxisSize: pw.MainAxisSize.min,
                                  children: [
                                    _buildLakshmeeInfoGrid(data, theme),
                                    pw.SizedBox(height: 3),
                                    _buildLakshmeeProductTable(
                                      data.productItems,
                                      data.total,
                                      data.paymentMode,
                                      theme,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      _buildLakshmeeFooter(theme),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  return pdf.save();
}

pw.Widget _buildLakshmeeHeader(LakshmeeTheme theme) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 0),
    decoration: pw.BoxDecoration(
      color: PdfColor.fromHex(theme.headerBackground),
      border: pw.Border.all(
        color: PdfColor.fromHex(theme.headerBorder),
        width: theme.borderWidth,
      ),
      borderRadius: pw.BorderRadius.circular(theme.borderRadius),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          theme.companyTitle,
          style: pw.TextStyle(
            fontSize: theme.fontSizeTitle.toDouble(),
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.6,
            color: PdfColors.black,
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 1),
        pw.Text(
          theme.companyAddress,
          style: pw.TextStyle(
            fontSize: theme.fontSizeSubtitle.toDouble(),
            fontWeight: pw.FontWeight.normal,
            color: PdfColor.fromHex(theme.bodyText),
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 1),
        pw.Text(
          theme.companyPhone,
          style: pw.TextStyle(
            fontSize: theme.fontSizeSubtitle.toDouble(),
            fontWeight: pw.FontWeight.normal,
            color: PdfColor.fromHex(theme.bodyText),
          ),
          textAlign: pw.TextAlign.center,
        ),
      ],
    ),
  );
}

pw.Widget _buildLakshmeeTitleRow(int dmNumber, LakshmeeTheme theme) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Text(
        'Delivery Memo',
        style: pw.TextStyle(
          fontSize: theme.fontSizeDeliveryMemo.toDouble(),
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.black,
        ),
      ),
      pw.Text(
        'DM No. #$dmNumber',
        style: pw.TextStyle(
          fontSize: theme.fontSizeDmNumber.toDouble(),
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    ],
  );
}

pw.Widget _buildLakshmeePaymentSection({
  required String accountName,
  required double total,
  Uint8List? qrCodeBytes,
  required LakshmeeTheme theme,
}) {
  final hasQr = qrCodeBytes != null && qrCodeBytes.isNotEmpty;
  final hasAccountName =
      accountName.isNotEmpty && accountName != 'N/A';

  if (!hasQr && !hasAccountName) {
    return pw.SizedBox.shrink();
  }

  if (hasQr) {
    final labelText = hasAccountName
        ? (accountName.length > 20
            ? '${accountName.substring(0, 20)}...'
            : accountName)
        : 'Scan to pay';
    return pw.Container(
      width: 80,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(
            width: 75,
            height: 75,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                color: PdfColors.black,
                width: theme.qrBoxBorderWidth,
              ),
              color: PdfColor.fromHex(theme.qrBoxBackground),
            ),
            padding: const pw.EdgeInsets.all(6),
            child: pw.Image(
              pw.MemoryImage(qrCodeBytes),
              fit: pw.BoxFit.contain,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            labelText,
            style: pw.TextStyle(
              fontSize: theme.fontSizeSubtitle.toDouble(),
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
            textAlign: pw.TextAlign.center,
            maxLines: 1,
          ),
          pw.SizedBox(height: 1.5),
          pw.Text(
            'Scan to pay $_pdfCurrencyPrefix${_formatCurrency(total)}',
            style: pw.TextStyle(
              fontSize: theme.fontSizeSubtitle.toDouble(),
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex(theme.amountText),
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  if (hasAccountName) {
    return pw.Container(
      width: 80,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            accountName.length > 20
                ? '${accountName.substring(0, 20)}...'
                : accountName,
            style: pw.TextStyle(
              fontSize: theme.fontSizeSubtitle.toDouble(),
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
            textAlign: pw.TextAlign.center,
            maxLines: 2,
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Pay $_pdfCurrencyPrefix${_formatCurrency(total)}',
            style: pw.TextStyle(
              fontSize: theme.fontSizeSubtitle.toDouble(),
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex(theme.amountText),
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  return pw.SizedBox.shrink();
}

pw.Widget _buildLakshmeeInfoGrid(DmPrintData data, LakshmeeTheme theme) {
  final labelStyle = pw.TextStyle(
    fontSize: theme.fontSizeBody.toDouble(),
    fontWeight: pw.FontWeight.bold,
  );
  final valueStyle = pw.TextStyle(
    fontSize: theme.fontSizeBody.toDouble(),
  );
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(
        color: PdfColor.fromHex(theme.infoBoxBorder),
        width: theme.borderWidth,
      ),
      borderRadius: pw.BorderRadius.circular(theme.borderRadius),
      color: PdfColor.fromHex(theme.infoBoxBackground),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(text: 'Client: ', style: labelStyle),
                    pw.TextSpan(text: data.client.name, style: labelStyle),
                  ],
                ),
              ),
              pw.SizedBox(height: 0.5),
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(text: 'Address: ', style: labelStyle),
                    pw.TextSpan(
                      text: data.formattedAddress,
                      style: valueStyle,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 0.5),
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(text: 'Phone: ', style: labelStyle),
                    pw.TextSpan(text: data.client.phone, style: labelStyle),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 6),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(text: 'Date: ', style: labelStyle),
                    pw.TextSpan(
                      text: _formatDate(data.deliveryDate),
                      style: valueStyle,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 0.5),
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(text: 'Vehicle: ', style: labelStyle),
                    pw.TextSpan(
                      text: data.vehicle.number,
                      style: valueStyle,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 0.5),
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(text: 'Driver: ', style: labelStyle),
                    pw.TextSpan(
                      text: data.driver.name,
                      style: valueStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildLakshmeeProductTable(
  List<ProductItem> productItems,
  double total,
  String paymentMode,
  LakshmeeTheme theme,
) {
  final first = productItems.isNotEmpty
      ? productItems.first
      : const ProductItem(
          productName: 'N/A',
          quantity: 0,
          unitPrice: 0.0,
        );
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1.5),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(
        color: PdfColors.black,
        width: theme.borderWidth,
      ),
      borderRadius: pw.BorderRadius.circular(theme.borderRadius),
      color: PdfColors.white,
    ),
    child: pw.Column(
      children: [
        _buildLakshmeeTableRow(
          'Product',
          first.productName,
          isTotal: false,
          theme: theme,
        ),
        _buildLakshmeeTableRow(
          'Quantity',
          first.quantity.toString(),
          isTotal: false,
          theme: theme,
        ),
        _buildLakshmeeTableRow(
          'Unit Price',
          '$_pdfCurrencyPrefix${_formatCurrency(first.unitPrice)}',
          isTotal: false,
          theme: theme,
        ),
        _buildLakshmeeTableRow(
          'Total',
          '$_pdfCurrencyPrefix${_formatCurrency(total)}',
          isTotal: true,
          theme: theme,
        ),
        _buildLakshmeeTableRow(
          'Payment Mode',
          paymentMode,
          isTotal: false,
          theme: theme,
        ),
      ],
    ),
  );
}

pw.Widget _buildLakshmeeFooter(LakshmeeTheme theme) {
  return pw.Column(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Center(
        child: pw.Text(
          theme.jurisdictionNote,
          style: pw.TextStyle(
            fontSize: theme.fontSizeSubtitle.toDouble(),
            color: PdfColor.fromHex(theme.mutedText),
            // Avoid Helvetica-Oblique; standard PDF italic has no Unicode support
          ),
          textAlign: pw.TextAlign.center,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  'Received By',
                  style: pw.TextStyle(
                    fontSize: theme.fontSizeSubtitle.toDouble(),
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Container(
                  width: double.infinity,
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      top: pw.BorderSide(
                        color: PdfColors.black,
                        width: theme.borderWidth,
                      ),
                    ),
                  ),
                  height: 1,
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 2.8),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  'Authorized Signature',
                  style: pw.TextStyle(
                    fontSize: theme.fontSizeSubtitle.toDouble(),
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Container(
                  width: double.infinity,
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      top: pw.BorderSide(
                        color: PdfColors.black,
                        width: theme.borderWidth,
                      ),
                    ),
                  ),
                  height: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}

pw.Widget _buildLakshmeeTableRow(
  String label,
  String value, {
  required bool isTotal,
  required LakshmeeTheme theme,
}) {
  if (isTotal) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
            color: PdfColors.black,
            width: theme.borderWidth,
          ),
        ),
      ),
      margin: const pw.EdgeInsets.only(top: 1),
      padding: const pw.EdgeInsets.only(
        top: 1.5,
        bottom: 0.5,
        left: 0,
        right: 0,
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: theme.fontSizeTableLabel.toDouble(),
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: theme.fontSizeTableLabel.toDouble(),
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  return pw.Container(
    padding: const pw.EdgeInsets.only(
      top: 1,
      bottom: 0.5,
      left: 0,
      right: 0,
    ),
    decoration: pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(
          color: PdfColor.fromHex(theme.infoBoxBorder),
          width: theme.borderWidth,
          style: pw.BorderStyle.dashed,
        ),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: theme.fontSizeBody.toDouble(),
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: theme.fontSizeBody.toDouble(),
          ),
        ),
      ],
    ),
  );
}

/// Format currency without decimals (matching PrintDM.jsx)
String _formatCurrency(double amount) {
  return amount.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );
}

/// Currency prefix for PDF text. Use "Rs " because standard PDF fonts do not
/// support the Rupee symbol (U+20B9). Pass a Unicode font with fontFallback
/// if you need "₹" in the output.
const String _pdfCurrencyPrefix = 'Rs ';

/// Format date in DD/MM/YYYY format (matching PrintDM.jsx)
String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

/// Parse date from various formats (Firestore Timestamp, DateTime, etc.)
DateTime _parseDate(dynamic date) {
  if (date == null) return DateTime.now();
  
  if (date is DateTime) {
    return date;
  }
  
  if (date is Map && date.containsKey('_seconds')) {
    return DateTime.fromMillisecondsSinceEpoch(
      (date['_seconds'] as int) * 1000,
    );
  }
  
  if (date.toString().contains('-')) {
    try {
      return DateTime.parse(date.toString());
    } catch (e) {
      return DateTime.now();
    }
  }
  
  return DateTime.now();
}
