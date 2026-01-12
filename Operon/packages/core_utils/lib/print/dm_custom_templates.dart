import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:core_models/core_models.dart';

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
/// Replicates the design from PrintDM.jsx (single copy, portrait)
Future<Uint8List> generateLakshmeeTemplate({
  required Map<String, dynamic> dmData,
  required DmSettings dmSettings,
  Map<String, dynamic>? paymentAccount,
  Uint8List? qrCodeBytes,
  Uint8List? watermarkBytes,
}) async {
  final pdf = pw.Document();

  // Parse DM data
  final dmNumber = dmData['dmNumber'] as int? ?? 
                   (dmData['dmNumber'] as num?)?.toInt() ?? 0;
  
  // Date parsing - handle multiple formats
  DateTime deliveryDate;
  final deliveryDateData = dmData['deliveryDate'] ?? dmData['scheduledDate'];
  if (deliveryDateData != null) {
    deliveryDate = _parseDate(deliveryDateData);
  } else {
    deliveryDate = DateTime.now();
  }

  // Client data
  final clientName = dmData['clientName'] as String? ?? 'N/A';
  final clientPhone = dmData['clientPhoneNumber'] as String? ?? 
                     dmData['clientPhone'] as String? ?? 
                     'N/A';
  final address = dmData['address'] as String? ?? '—';
  final regionName = dmData['regionName'] as String? ?? '';
  final fullAddress = '$address${regionName.isNotEmpty ? ', $regionName' : ''}';

  // Vehicle and driver
  final vehicleNumber = dmData['vehicleNumber'] as String? ?? 'N/A';
  final driverName = dmData['driverName'] as String? ?? 'N/A';

  // Product data - get first item
  final itemsData = dmData['items'];
  final items = itemsData is List ? itemsData : 
                (itemsData != null ? [itemsData] : []);
  
  String productName = 'N/A';
  int quantity = 0;
  double unitPrice = 0.0;
  double total = 0.0;

  if (items.isNotEmpty) {
    final itemMap = items[0] is Map<String, dynamic> 
        ? items[0] as Map<String, dynamic>
        : <String, dynamic>{};
    
    productName = itemMap['productName'] as String? ?? 
                 itemMap['name'] as String? ?? 
                 'N/A';
    
    quantity = (itemMap['fixedQuantityPerTrip'] as num?)?.toInt() ?? 
              (itemMap['totalQuantity'] as num?)?.toInt() ?? 
              (itemMap['quantity'] as num?)?.toInt() ?? 
              0;
    
    unitPrice = (itemMap['unitPrice'] as num?)?.toDouble() ?? 
               (itemMap['price'] as num?)?.toDouble() ?? 
               0.0;
  }

  // Get total from trip pricing
  final tripPricingData = dmData['tripPricing'];
  if (tripPricingData is Map<String, dynamic>) {
    total = (tripPricingData['total'] as num?)?.toDouble() ?? 
           (quantity * unitPrice);
  } else {
    total = quantity * unitPrice;
  }

  // Payment mode
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

  // Account name for QR code label
  final accountName = paymentAccount?['name'] as String? ?? 
                     'Lakshmee Intelligent Technologies';

  // Ticket dimensions for landscape: adjusted for A4 landscape
  // A4 landscape is 297mm x 210mm, so ticket can be larger
  final ticketWidth = PdfPageFormat.a4.landscape.width - 20; // With 5mm margins each side
  final ticketHeight = PdfPageFormat.a4.landscape.height - 20; // With 5mm margins each side

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(0),
      build: (context) {
        return pw.Container(
          width: PdfPageFormat.a4.landscape.width,
          height: PdfPageFormat.a4.landscape.height,
          padding: const pw.EdgeInsets.all(5 * PdfPageFormat.mm),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
          ),
          child: pw.Container(
            width: ticketWidth,
            height: ticketHeight,
            padding: const pw.EdgeInsets.all(4 * PdfPageFormat.mm),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1),
              color: PdfColors.white,
            ),
            child: pw.Stack(
              children: [
                // Watermark background
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
                
                // Main content
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                      // Header with "जय श्री राम" and branding
                      pw.Text(
                        '🚩 जय श्री राम 🚩',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#b22222'),
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 4),
                      
                      // Company branding box
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey100,
                          border: pw.Border.all(color: PdfColors.grey400, width: 1),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Column(
                          children: [
                            pw.Text(
                              'LAKSHMEE INTELLIGENT TECHNOLOGIES',
                              style: pw.TextStyle(
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                            pw.SizedBox(height: 2),
                              pw.Text(
                                'B-24/2, M.I.D.C., CHANDRAPUR - 442406',
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.normal,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                'Ph: +91 8149448822 | +91 9420448822',
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.normal,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                          ],
                        ),
                      ),
                      
                      pw.SizedBox(height: 4),
                      pw.Divider(
                        color: PdfColors.black,
                        thickness: 2,
                        height: 6,
                      ),
                      pw.SizedBox(height: 4),
                      
                      // Title row with DM number
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '🚚 Delivery Memo',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            'DM No. #$dmNumber',
                            style: pw.TextStyle(
                              fontSize: 15,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      
                      // Main content: QR code left, info right
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Left column: QR code
                          pw.Container(
                            width: 180,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                // QR code container
                                pw.Container(
                                  width: 180,
                                  height: 180,
                                  decoration: pw.BoxDecoration(
                                    border: pw.Border.all(color: PdfColors.black, width: 3),
                                    color: PdfColors.grey100,
                                  ),
                                  padding: const pw.EdgeInsets.all(10),
                                  child: qrCodeBytes != null && qrCodeBytes.isNotEmpty
                                      ? pw.Image(
                                          pw.MemoryImage(qrCodeBytes),
                                          fit: pw.BoxFit.contain,
                                        )
                                      : pw.Center(
                                          child: pw.Text(
                                            'QR Code',
                                            style: pw.TextStyle(
                                              fontSize: 22,
                                              color: PdfColors.grey600,
                                            ),
                                          ),
                                        ),
                                ),
                                pw.SizedBox(height: 4),
                                // QR label
                                pw.Text(
                                  accountName,
                                  style: pw.TextStyle(
                                    fontSize: 14,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                  textAlign: pw.TextAlign.center,
                                ),
                                pw.SizedBox(height: 2),
                                // Amount
                                pw.Text(
                                  'Scan to pay ₹${_formatCurrency(total)}',
                                  style: pw.TextStyle(
                                    fontSize: 14,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          
                          pw.SizedBox(width: 10),
                          
                          // Right column: Client info and product table
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                // Client info box
                                pw.Container(
                                  padding: const pw.EdgeInsets.all(4),
                                  decoration: pw.BoxDecoration(
                                    border: pw.Border.all(color: PdfColors.grey400),
                                    borderRadius: pw.BorderRadius.circular(4),
                                    color: PdfColors.grey50,
                                  ),
                                  child: pw.Row(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      // Left info column
                                      pw.Expanded(
                                        child: pw.Column(
                                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                                          children: [
                                            pw.RichText(
                                              text: pw.TextSpan(
                                                children: [
                                                  pw.TextSpan(
                                                    text: 'Client: ',
                                                    style: pw.TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: pw.FontWeight.bold,
                                                    ),
                                                  ),
                                                  pw.TextSpan(
                                                    text: clientName,
                                                    style: pw.TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: pw.FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            pw.SizedBox(height: 1),
                                            pw.RichText(
                                              text: pw.TextSpan(
                                                children: [
                                                  pw.TextSpan(
                                                    text: 'Address: ',
                                                    style: pw.TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: pw.FontWeight.bold,
                                                    ),
                                                  ),
                                                  pw.TextSpan(
                                                    text: fullAddress,
                                                    style: pw.TextStyle(fontSize: 14),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            pw.SizedBox(height: 1),
                                            pw.RichText(
                                              text: pw.TextSpan(
                                                children: [
                                                  pw.TextSpan(
                                                    text: 'Phone: ',
                                                    style: pw.TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: pw.FontWeight.bold,
                                                    ),
                                                  ),
                                                  pw.TextSpan(
                                                    text: clientPhone,
                                                    style: pw.TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: pw.FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Right info column
                                      pw.Expanded(
                                        child: pw.Column(
                                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                                          children: [
                                            pw.RichText(
                                              text: pw.TextSpan(
                                                children: [
                                                  pw.TextSpan(
                                                    text: 'Date: ',
                                                    style: pw.TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: pw.FontWeight.bold,
                                                    ),
                                                  ),
                                                  pw.TextSpan(
                                                    text: _formatDate(deliveryDate),
                                                    style: pw.TextStyle(fontSize: 14),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            pw.SizedBox(height: 1),
                                            pw.RichText(
                                              text: pw.TextSpan(
                                                children: [
                                                  pw.TextSpan(
                                                    text: 'Vehicle: ',
                                                    style: pw.TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: pw.FontWeight.bold,
                                                    ),
                                                  ),
                                                  pw.TextSpan(
                                                    text: vehicleNumber,
                                                    style: pw.TextStyle(fontSize: 14),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            pw.SizedBox(height: 1),
                                            pw.RichText(
                                              text: pw.TextSpan(
                                                children: [
                                                  pw.TextSpan(
                                                    text: 'Driver: ',
                                                    style: pw.TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: pw.FontWeight.bold,
                                                    ),
                                                  ),
                                                  pw.TextSpan(
                                                    text: driverName,
                                                    style: pw.TextStyle(fontSize: 14),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                pw.SizedBox(height: 4),
                                
                                // Product table
                                pw.Container(
                                  padding: const pw.EdgeInsets.all(3),
                                  decoration: pw.BoxDecoration(
                                    border: pw.Border.all(color: PdfColors.black),
                                    borderRadius: pw.BorderRadius.circular(4),
                                    color: PdfColors.white,
                                  ),
                                  child: pw.Column(
                                    children: [
                                      // Table rows
                                      _buildTableRow(
                                        '📦 Product',
                                        productName,
                                        isTotal: false,
                                      ),
                                      _buildTableRow(
                                        '🔢 Quantity',
                                        quantity.toString(),
                                        isTotal: false,
                                      ),
                                      _buildTableRow(
                                        '💰 Unit Price',
                                        '₹${_formatCurrency(unitPrice)}',
                                        isTotal: false,
                                      ),
                                      _buildTableRow(
                                        '🧾 Total',
                                        '₹${_formatCurrency(total)}',
                                        isTotal: true,
                                      ),
                                      _buildTableRow(
                                        '💳 Payment Mode',
                                        paymentMode,
                                        isTotal: false,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      pw.SizedBox(height: 6),
                      
                      // Jurisdiction note
                      pw.Text(
                        'Note: Subject to Chandrapur Jurisdiction',
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.grey700,
                          fontStyle: pw.FontStyle.italic,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      
                      pw.Spacer(),
                      
                      // Footer with signatures
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                pw.Text(
                                  'Received By',
                                  style: pw.TextStyle(
                                    fontSize: 13,
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Divider(
                                  color: PdfColors.black,
                                  thickness: 1,
                                ),
                              ],
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                pw.Text(
                                  'Authorized Signature',
                                  style: pw.TextStyle(
                                    fontSize: 13,
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Divider(
                                  color: PdfColors.black,
                                  thickness: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
      },
    ),
  );

  return pdf.save();
}

/// Build a table row for product info (matching PrintDM.jsx style)
pw.Widget _buildTableRow(String label, String value, {required bool isTotal}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
    decoration: isTotal
        ? null
        : pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(
                color: PdfColors.grey400,
                width: 0.5,
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
            fontSize: 14,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
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
