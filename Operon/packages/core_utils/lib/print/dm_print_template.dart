import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:core_models/core_models.dart';
import 'pdf_builder.dart';
import 'dm_custom_templates.dart';

/// Generates a PDF for a Delivery Memo (DM)
/// 
/// Supports both Portrait and Landscape orientations
/// Uses DM Settings for header/footer customization and print preferences
/// Optionally includes payment account for QR code or bank details
/// Routes to custom templates when templateType is custom
Future<Uint8List> generateDmPdf({
  required Map<String, dynamic> dmData,
  required DmSettings dmSettings,
  Map<String, dynamic>? paymentAccount,
  Uint8List? logoBytes,
  Uint8List? qrCodeBytes,
  Uint8List? watermarkBytes,
}) async {
  // Check if custom template should be used
  if (dmSettings.templateType == DmTemplateType.custom && 
      dmSettings.customTemplateId != null) {
    return generateCustomDmPdf(
      dmData: dmData,
      dmSettings: dmSettings,
      customTemplateId: dmSettings.customTemplateId!,
      paymentAccount: paymentAccount,
      logoBytes: logoBytes,
      qrCodeBytes: qrCodeBytes,
      watermarkBytes: watermarkBytes,
    );
  }
  
  // Otherwise, use universal template
  final pdf = pw.Document();
  
  // Get orientation from DM Settings
  final pageFormat = dmSettings.printOrientation == DmPrintOrientation.portrait
      ? PdfPageFormat.a4
      : PdfPageFormat.a4.landscape;
  final isPortrait = dmSettings.printOrientation == DmPrintOrientation.portrait;
  
  // Get payment display preference from DM Settings
  final showQrCode = dmSettings.paymentDisplay == DmPaymentDisplay.qrCode;

  // Extract DM data - handle different field name variations
  final dmNumber = dmData['dmNumber'] as int? ?? 
                   (dmData['dmNumber'] as num?)?.toInt() ?? 0;
  final scheduledDate = _parseDate(dmData['scheduledDate']);
  
  // Client data - check multiple possible field names
  final clientName = dmData['clientName'] as String? ?? 'N/A';
  final clientPhone = dmData['clientPhone'] as String? ?? 
                     dmData['customerNumber'] as String? ?? '';
  
  // Vehicle data
  final vehicleNumber = dmData['vehicleNumber'] as String? ?? 'N/A';
  
  // Driver data - may be null
  final driverName = (dmData['driverName'] as String?) ?? 'N/A';
  final driverPhone = dmData['driverPhone'] as String?;
  
  // Delivery zone
  final deliveryZone = dmData['deliveryZone'] as Map<String, dynamic>?;
  
  // Items - ensure it's a list
  final itemsData = dmData['items'];
  final items = itemsData is List ? itemsData : 
                (itemsData != null ? [itemsData] : []);
  
  // Trip pricing - ensure it's a map
  final tripPricingData = dmData['tripPricing'];
  final tripPricing = tripPricingData is Map<String, dynamic> 
      ? tripPricingData 
      : <String, dynamic>{};
  
  final subtotal = (tripPricing['subtotal'] as num?)?.toDouble() ?? 0.0;
  final total = (tripPricing['total'] as num?)?.toDouble() ?? 0.0;
  final advanceDeducted = (tripPricing['advanceAmountDeducted'] as num?)?.toDouble();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: pageFormat,
      margin: const pw.EdgeInsets.all(10),
      textDirection: pw.TextDirection.ltr,
      build: (context) => [
        // Outer container with rounded border and padding
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
              color: PdfColors.grey400,
              width: 1.5,
            ),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Section with decorative border
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
                  ),
                ),
                child: _buildHeader(
                  dmSettings.header,
                  logoBytes: logoBytes,
                  isPortrait: isPortrait,
                ),
              ),
              
              pw.SizedBox(height: 10),
              
              // DM Info Section with background
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: PdfColors.grey300, width: 1),
                ),
                child: _buildDmInfo(
                  dmNumber: dmNumber,
                  date: scheduledDate,
                  clientName: clientName,
                  clientPhone: clientPhone,
                  vehicleNumber: vehicleNumber,
                  driverName: driverName,
                  driverPhone: driverPhone,
                  deliveryZone: deliveryZone,
                  isPortrait: isPortrait,
                ),
              ),
              
              pw.SizedBox(height: 12),
              
              // Items Table and Payment Section (layout varies by orientation)
              if (isPortrait) ...[
                // Portrait: Items table, then payment section below
                _buildItemsTable(items),
                pw.SizedBox(height: 12),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Pricing Summary on left
                    pw.Expanded(
                      flex: 2,
                      child: _buildPricingSummary(
                        subtotal: subtotal,
                        advanceDeducted: advanceDeducted,
                        total: total,
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    // Payment Section on right
                    pw.Expanded(
                      flex: 1,
                      child: _buildPaymentSection(
                        paymentAccount: paymentAccount,
                        showQrCode: showQrCode,
                        qrCodeBytes: qrCodeBytes,
                        isPortrait: true,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Landscape: Items table and payment section side by side
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildItemsTable(items),
                          pw.SizedBox(height: 10),
                          _buildPricingSummary(
                            subtotal: subtotal,
                            advanceDeducted: advanceDeducted,
                            total: total,
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      flex: 2,
                      child: _buildPaymentSection(
                        paymentAccount: paymentAccount,
                        showQrCode: showQrCode,
                        qrCodeBytes: qrCodeBytes,
                        isPortrait: false,
                      ),
                    ),
                  ],
                ),
              ],
              
              pw.SizedBox(height: 12),
              
              // Footer Section with decorative border
              if (dmSettings.footer.customText != null &&
                  dmSettings.footer.customText!.isNotEmpty) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      top: pw.BorderSide(color: PdfColors.grey300, width: 1),
                    ),
                  ),
                  child: pw.Text(
                    dmSettings.footer.customText!,
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                      fontStyle: pw.FontStyle.italic,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  return pdf.save();
}

/// Build header section with logo, company name, address, phone
pw.Widget _buildHeader(
  DmHeaderSettings header, {
  Uint8List? logoBytes,
  required bool isPortrait,
}) {
  final headerChildren = <pw.Widget>[];

  // Logo and Company Info
  if (logoBytes != null) {
    try {
      final logoImage = pw.MemoryImage(logoBytes);
      if (isPortrait) {
        // Portrait: Logo on left, info on right
        headerChildren.add(
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Image(
                logoImage,
                width: 50,
                height: 50,
                fit: pw.BoxFit.contain,
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _buildCompanyInfo(header),
              ),
            ],
          ),
        );
      } else {
        // Landscape: Logo on left, info flows right
        headerChildren.add(
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Image(
                logoImage,
                width: 50,
                height: 50,
                fit: pw.BoxFit.contain,
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _buildCompanyInfo(header),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // If logo fails to load, just show company info
      headerChildren.add(_buildCompanyInfo(header));
    }
  } else {
    headerChildren.add(_buildCompanyInfo(header));
  }

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: headerChildren,
  );
}

pw.Widget _buildCompanyInfo(DmHeaderSettings header) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        header.name,
        style: pw.TextStyle(
          fontSize: 16,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.black,
        ),
      ),
      if (header.address.isNotEmpty) ...[
        pw.SizedBox(height: 3),
        pw.Text(
          header.address,
          style: const pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey700,
          ),
        ),
      ],
      pw.SizedBox(height: 3),
      pw.Row(
        children: [
          pw.Text(
            'Phone: ${header.phone}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
          if (header.gstNo != null && header.gstNo!.isNotEmpty) ...[
            pw.SizedBox(width: 12),
            pw.Text(
              'GST: ${header.gstNo}',
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ],
      ),
    ],
  );
}

/// Build DM info section
pw.Widget _buildDmInfo({
  required int dmNumber,
  required DateTime date,
  required String clientName,
  required String clientPhone,
  required String vehicleNumber,
  required String driverName,
  String? driverPhone,
  Map<String, dynamic>? deliveryZone,
  required bool isPortrait,
}) {
  final zoneText = deliveryZone != null
      ? '${deliveryZone['region'] ?? ''}, ${deliveryZone['city_name'] ?? deliveryZone['city'] ?? ''}'
      : '';

  if (isPortrait) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'DM No: DM-$dmNumber',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.Text(
              'Date: ${PdfBuilder.formatDate(date)}',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                'Client: $clientName${clientPhone.isNotEmpty ? ' ($clientPhone)' : ''}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
            if (zoneText.isNotEmpty)
              pw.Text(
                'Zone: $zoneText',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                'Vehicle: $vehicleNumber',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
            if (driverName != 'N/A' && driverName.isNotEmpty) ...[
              pw.Expanded(
                child: pw.Text(
                  'Driver: $driverName${driverPhone != null && driverPhone.isNotEmpty ? ' ($driverPhone)' : ''}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  } else {
    // Landscape: More compact layout
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        PdfBuilder.divider(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'DM No: DM-$dmNumber',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'Date: ${PdfBuilder.formatDate(date)}',
              style: const pw.TextStyle(fontSize: 11),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Text(
                'Client: $clientName${clientPhone.isNotEmpty ? ' ($clientPhone)' : ''}',
                style: const pw.TextStyle(fontSize: 11),
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Text(
                'Vehicle: $vehicleNumber',
                style: const pw.TextStyle(fontSize: 11),
              ),
            ),
            if (driverName != 'N/A' && driverName.isNotEmpty) ...[
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Text(
                  'Driver: $driverName${driverPhone != null && driverPhone.isNotEmpty ? ' ($driverPhone)' : ''}',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ),
            ],
          ],
        ),
        if (zoneText.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            'Zone: $zoneText',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ],
        // No divider needed - spacing is handled by container padding
      ],
    );
  }
}

/// Build items table
pw.Widget _buildItemsTable(List<dynamic> items) {
  if (items.isEmpty) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        'No items',
        style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  final tableRows = <pw.TableRow>[
    // Header row with better styling
    pw.TableRow(
      decoration: const pw.BoxDecoration(
        color: PdfColors.blue900,
      ),
      children: [
            pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: pw.Text(
            'Product',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: pw.Text(
            'Quantity',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: pw.Text(
            'Unit Price',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: pw.Text(
            'Total',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
      ],
    ),
  ];

  // Data rows
  for (final item in items) {
    final itemMap = item is Map<String, dynamic> ? item : <String, dynamic>{};
    
    // Product name - check multiple possible fields
    final productName = itemMap['productName'] as String? ?? 
                       itemMap['name'] as String? ?? 
                       'N/A';
    
    // Quantity - check multiple possible fields
    final quantity = (itemMap['fixedQuantityPerTrip'] as num?)?.toInt() ?? 
                    (itemMap['totalQuantity'] as num?)?.toInt() ?? 
                    (itemMap['quantity'] as num?)?.toInt() ?? 
                    0;
    
    // Unit price - check multiple possible fields
    final unitPrice = (itemMap['unitPrice'] as num?)?.toDouble() ?? 
                     (itemMap['price'] as num?)?.toDouble() ?? 
                     0.0;
    
    // Line total - check multiple possible fields or calculate
    final lineTotal = (itemMap['total'] as num?)?.toDouble() ?? 
                     (itemMap['lineTotal'] as num?)?.toDouble() ??
                     (itemMap['amount'] as num?)?.toDouble() ??
                     (quantity * unitPrice); // Calculate if not present

    // Alternate row colors for better readability
    final rowIndex = tableRows.length - 1; // Subtract header row
    final isEven = rowIndex % 2 == 0;
    tableRows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(
          color: isEven ? PdfColors.white : PdfColors.grey50,
        ),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: pw.Text(
              productName,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: pw.Text(
              quantity.toString(),
              style: const pw.TextStyle(fontSize: 10),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: pw.Text(
              PdfBuilder.formatCurrency(unitPrice),
              style: const pw.TextStyle(fontSize: 10),
              textAlign: pw.TextAlign.right,
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: pw.Text(
              PdfBuilder.formatCurrency(lineTotal),
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey400, width: 1.5),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Table(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        verticalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      ),
      children: tableRows,
    ),
  );
}

/// Build pricing summary
pw.Widget _buildPricingSummary({
  required double subtotal,
  double? advanceDeducted,
  required double total,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey400, width: 1.5),
      borderRadius: pw.BorderRadius.circular(6),
      color: PdfColors.grey50,
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        if (subtotal != total) ...[
          PdfBuilder.labelValue(
            label: 'Subtotal:',
            value: PdfBuilder.formatCurrency(subtotal),
            labelFontSize: 10,
            valueFontSize: 10,
          ),
          pw.SizedBox(height: 5),
        ],
        if (advanceDeducted != null && advanceDeducted > 0) ...[
          PdfBuilder.labelValue(
            label: 'Advance Deducted:',
            value: PdfBuilder.formatCurrency(advanceDeducted),
            labelFontSize: 10,
            valueFontSize: 10,
            valueColor: PdfColors.red700,
          ),
          pw.SizedBox(height: 6),
        ],
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue100,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: PdfBuilder.labelValue(
            label: 'Total:',
            value: PdfBuilder.formatCurrency(total),
            labelFontSize: 12,
            valueFontSize: 12,
            valueWeight: pw.FontWeight.bold,
            valueColor: PdfColors.blue900,
          ),
        ),
      ],
    ),
  );
}

/// Build payment section with QR code or bank details
pw.Widget _buildPaymentSection({
  Map<String, dynamic>? paymentAccount,
  required bool showQrCode,
  Uint8List? qrCodeBytes,
  required bool isPortrait,
}) {
  if (paymentAccount == null) {
    return pw.SizedBox.shrink();
  }

  final accountName = paymentAccount['name'] as String? ?? '';
  final upiId = paymentAccount['upiId'] as String?;

  // Try to show QR Code if preference is QR code
  if (showQrCode) {
    // Check if we have QR code bytes
    if (qrCodeBytes != null && qrCodeBytes.isNotEmpty) {
      // Show QR Code from bytes
      try {
        final qrImage = pw.MemoryImage(qrCodeBytes);
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
            child: pw.Image(
              qrImage,
              width: isPortrait ? 160 : 130,
              height: isPortrait ? 160 : 130,
              fit: pw.BoxFit.contain,
            ),
          ),
        ];
        
        if (accountName.isNotEmpty) {
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
        
        // Also show UPI ID if available
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
        
        return pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blue700, width: 1.5),
            borderRadius: pw.BorderRadius.circular(6),
            color: PdfColors.grey50,
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: qrChildren,
          ),
        );
      } catch (e) {
        // Fall through to show bank details if QR code fails
      }
    }
    
    // If QR code bytes not available but UPI ID exists, show UPI ID prominently
    if (upiId != null && upiId.isNotEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.orange700, width: 1.5),
          borderRadius: pw.BorderRadius.circular(6),
          color: PdfColors.grey50,
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              'UPI Payment',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Text(
                upiId,
                style: pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey900,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            if (accountName.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              pw.Text(
                accountName,
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }
  }
  
  // Fallback to Bank Details if QR code not available or preference is bank details
  {
    // Show Bank Details
    final accountNumber = paymentAccount['accountNumber'] as String?;
    final ifscCode = paymentAccount['ifscCode'] as String?;
    final upiId = paymentAccount['upiId'] as String?;

    if (accountNumber == null && ifscCode == null && upiId == null) {
      return pw.SizedBox.shrink();
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 1.5),
        borderRadius: pw.BorderRadius.circular(6),
        color: PdfColors.grey50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Payment Details',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 8),
          if (accountName.isNotEmpty) ...[
            PdfBuilder.labelValue(
              label: 'Account Name:',
              value: accountName,
              labelFontSize: 11,
              valueFontSize: 11,
            ),
            pw.SizedBox(height: 6),
          ],
          if (accountNumber != null && accountNumber.isNotEmpty) ...[
            PdfBuilder.labelValue(
              label: 'Account Number:',
              value: accountNumber,
              labelFontSize: 11,
              valueFontSize: 11,
            ),
            pw.SizedBox(height: 6),
          ],
          if (ifscCode != null && ifscCode.isNotEmpty) ...[
            PdfBuilder.labelValue(
              label: 'IFSC Code:',
              value: ifscCode,
              labelFontSize: 11,
              valueFontSize: 11,
            ),
            pw.SizedBox(height: 6),
          ],
          if (upiId != null && upiId.isNotEmpty) ...[
            PdfBuilder.labelValue(
              label: 'UPI ID:',
              value: upiId,
              labelFontSize: 11,
              valueFontSize: 11,
            ),
          ],
        ],
      ),
    );
  }
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
