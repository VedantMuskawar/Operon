import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_models/core_models.dart';
import 'package:core_utils/core_utils.dart' as pdf_template;
import 'package:operon_driver_android/data/repositories/dm_settings_repository.dart';
import 'package:operon_driver_android/data/repositories/payment_accounts_repository.dart';
import 'package:operon_driver_android/data/services/qr_code_service.dart';
import 'package:operon_driver_android/domain/entities/payment_account.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_html_to_pdf_plus/flutter_html_to_pdf_plus.dart'
    show
        FlutterHtmlToPdf,
        PrintPdfConfiguration,
        PrintOrientation,
        PrintSize,
        PdfPageMargin;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

/// Payload for DM view (no PDF). Same data source as PDF generation.
class DmViewPayload {
  const DmViewPayload({
    required this.dmSettings,
    this.paymentAccount,
    this.logoBytes,
    this.qrCodeBytes,
  });

  final DmSettings dmSettings;
  final Map<String, dynamic>? paymentAccount;
  final Uint8List? logoBytes;
  final Uint8List? qrCodeBytes;
}

/// Service for printing Delivery Memos (DM) on Android.
/// Uses core_utils PDF generation and the printing package for preview/print/share.
class DmPrintService {
  DmPrintService({
    required DmSettingsRepository dmSettingsRepository,
    required PaymentAccountsRepository paymentAccountsRepository,
    QrCodeService? qrCodeService,
    FirebaseStorage? storage,
  })  : _dmSettingsRepository = dmSettingsRepository,
        _paymentAccountsRepository = paymentAccountsRepository,
        _qrCodeService = qrCodeService ?? QrCodeService(),
        _storage = storage ?? FirebaseStorage.instance;

  final DmSettingsRepository _dmSettingsRepository;
  final PaymentAccountsRepository _paymentAccountsRepository;
  final QrCodeService _qrCodeService;
  final FirebaseStorage _storage;

  /// Convert schedule trip data to DM data format
  Map<String, dynamic> convertTripToDmData(Map<String, dynamic> tripData) {
    final itemsData = tripData['items'];
    final items =
        itemsData is List ? itemsData : (itemsData != null ? [itemsData] : []);

    var tripPricingData = tripData['tripPricing'] as Map<String, dynamic>?;
    if (tripPricingData == null) {
      tripPricingData = <String, dynamic>{};
      if (tripData['total'] != null) {
        tripPricingData['total'] = tripData['total'];
      }
      if (tripData['subtotal'] != null) {
        tripPricingData['subtotal'] = tripData['subtotal'];
      }
      if (tripPricingData['total'] == null && items.isNotEmpty) {
        double calculatedTotal = 0.0;
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            final quantity =
                (item['fixedQuantityPerTrip'] as num?)?.toDouble() ??
                    (item['totalQuantity'] as num?)?.toDouble() ??
                    (item['quantity'] as num?)?.toDouble() ??
                    0.0;
            final unitPrice = (item['unitPrice'] as num?)?.toDouble() ??
                (item['price'] as num?)?.toDouble() ??
                0.0;
            calculatedTotal += quantity * unitPrice;
          }
        }
        tripPricingData['total'] = calculatedTotal;
      }
    }

    var deliveryZone = tripData['deliveryZone'] as Map<String, dynamic>?;
    if (deliveryZone == null) {
      deliveryZone = <String, dynamic>{};
      if (tripData['region'] != null) {
        deliveryZone['region'] = tripData['region'];
      }
      if (tripData['city'] != null || tripData['cityName'] != null) {
        deliveryZone['city_name'] = tripData['cityName'] ?? tripData['city'];
      }
      if (tripData['area'] != null) deliveryZone['area'] = tripData['area'];
    }

    final scheduledDate = tripData['scheduledDate'] ?? tripData['deliveryDate'];

    final dmData = <String, dynamic>{
      'dmNumber': tripData['dmNumber'] ?? 0,
      'dmId': tripData['dmId'],
      'clientName': tripData['clientName'] ?? 'N/A',
      'clientPhone': tripData['clientPhone'] ??
          tripData['clientPhoneNumber'] ??
          tripData['customerNumber'] ??
          'N/A',
      'deliveryZone': deliveryZone,
      'scheduledDate': scheduledDate,
      'vehicleNumber': tripData['vehicleNumber'] ?? 'N/A',
      'driverName': tripData['driverName'] ?? 'N/A',
      'driverPhone':
          tripData['driverPhone'] ?? tripData['driverPhoneNumber'] ?? 'N/A',
      'items': items,
      'tripPricing': tripPricingData,
      'paymentStatus': tripData['paymentStatus'] ?? false,
      'toAccount': tripData['toAccount'],
      'paySchedule': tripData['paySchedule'],
      'address': tripData['address'],
      'regionName':
          tripData['regionName'] ?? ((deliveryZone['region'] as String?) ?? ''),
    };

    if (dmData['scheduledDate'] is Timestamp) {
      final ts = dmData['scheduledDate'] as Timestamp;
      dmData['scheduledDate'] = {
        '_seconds': ts.seconds,
        '_nanoseconds': ts.nanoseconds,
      };
    }

    return dmData;
  }

  /// Normalize DM data to ensure all required fields are present
  Map<String, dynamic> normalizeDmData(Map<String, dynamic> dmData) {
    final normalized = Map<String, dynamic>.from(dmData);
    if (normalized['items'] == null) {
      normalized['items'] = [];
    } else if (normalized['items'] is! List) {
      normalized['items'] = [normalized['items']];
    }
    if (normalized['tripPricing'] == null) {
      normalized['tripPricing'] = <String, dynamic>{};
    } else if (normalized['tripPricing'] is! Map) {
      normalized['tripPricing'] = <String, dynamic>{};
    }
    if (normalized['deliveryZone'] == null) {
      normalized['deliveryZone'] = <String, dynamic>{};
    } else if (normalized['deliveryZone'] is! Map) {
      normalized['deliveryZone'] = <String, dynamic>{};
    }
    return normalized;
  }

  /// Fetch DM document by dmNumber or dmId, or convert from trip data
  Future<Map<String, dynamic>?> fetchDmByNumberOrId({
    required String organizationId,
    int? dmNumber,
    String? dmId,
    Map<String, dynamic>? tripData,
  }) async {
    try {
      Query<Map<String, dynamic>> queryRef = FirebaseFirestore.instance
          .collection('DELIVERY_MEMOS')
          .where('organizationId', isEqualTo: organizationId);

      if (dmNumber != null) {
        queryRef = queryRef.where('dmNumber', isEqualTo: dmNumber);
      } else if (dmId != null) {
        queryRef = queryRef.where('dmId', isEqualTo: dmId);
      } else {
        if (tripData != null) {
          return normalizeDmData(convertTripToDmData(tripData));
        }
        return null;
      }

      final snapshot = await queryRef.limit(1).get();
      if (snapshot.docs.isEmpty) {
        if (tripData != null) {
          return normalizeDmData(convertTripToDmData(tripData));
        }
        return null;
      }

      final doc = snapshot.docs.first;
      final data = doc.data();

      final convertedData = <String, dynamic>{};
      for (final entry in data.entries) {
        final value = entry.value;
        if (value is Timestamp) {
          convertedData[entry.key] = {
            '_seconds': value.seconds,
            '_nanoseconds': value.nanoseconds,
          };
        } else if (value is DateTime) {
          convertedData[entry.key] = {
            '_seconds': (value.millisecondsSinceEpoch / 1000).floor(),
            '_nanoseconds': (value.millisecond * 1000000).round(),
          };
        } else {
          convertedData[entry.key] = value;
        }
      }
      convertedData['id'] = doc.id;
      return normalizeDmData(convertedData);
    } catch (e) {
      if (tripData != null) {
        try {
          return normalizeDmData(convertTripToDmData(tripData));
        } catch (e2) {
          throw Exception('Failed to fetch DM and convert trip data: $e2');
        }
      }
      throw Exception('Failed to fetch DM: $e');
    }
  }

  /// Load image bytes from URL (Firebase Storage or HTTP)
  Future<Uint8List?> loadImageBytes(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      if (url.startsWith('gs://') || url.contains('firebase')) {
        final ref = _storage.refFromURL(url);
        return await ref.getData();
      }
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (e) {
      return null;
    }
    return null;
  }

  /// Load view data only (no PDF). Use for "view first" UI; same data as PDF.
  Future<DmViewPayload> loadDmViewData({
    required String organizationId,
    required Map<String, dynamic> dmData,
  }) async {
    final dmSettings =
        await _dmSettingsRepository.fetchDmSettings(organizationId);
    if (dmSettings == null) {
      throw Exception(
          'DM Settings not found. Please configure DM Settings first.');
    }

    Map<String, dynamic>? paymentAccount;
    Uint8List? qrCodeBytes;
    final showQrCode = dmSettings.paymentDisplay == DmPaymentDisplay.qrCode;

    final accounts =
        await _paymentAccountsRepository.fetchAccounts(organizationId);

    if (accounts.isNotEmpty) {
      PaymentAccount? selectedAccount;
      if (showQrCode) {
        try {
          selectedAccount = accounts.firstWhere(
            (acc) =>
                acc.qrCodeImageUrl != null && acc.qrCodeImageUrl!.isNotEmpty,
          );
        } catch (e) {
          debugPrint('[DmPrintService] QR account lookup failed: $e');
          try {
            selectedAccount = accounts.firstWhere((acc) => acc.isPrimary);
          } catch (e) {
            debugPrint('[DmPrintService] Primary account lookup failed: $e');
            selectedAccount = accounts.first;
          }
        }

        if (selectedAccount.qrCodeImageUrl != null &&
            selectedAccount.qrCodeImageUrl!.isNotEmpty) {
          qrCodeBytes = await loadImageBytes(selectedAccount.qrCodeImageUrl);
        }
        if ((qrCodeBytes == null || qrCodeBytes.isEmpty) &&
            selectedAccount.upiQrData != null &&
            selectedAccount.upiQrData!.isNotEmpty) {
          try {
            qrCodeBytes = await _qrCodeService
                .generateQrCodeImage(selectedAccount.upiQrData!);
          } catch (e) {
            debugPrint(
                '[DmPrintService] Failed generating QR from UPI data: $e');
          }
        } else if ((qrCodeBytes == null || qrCodeBytes.isEmpty) &&
            selectedAccount.upiId != null &&
            selectedAccount.upiId!.isNotEmpty) {
          try {
            final upiPaymentString =
                'upi://pay?pa=${selectedAccount.upiId}&pn=${Uri.encodeComponent(selectedAccount.name)}&cu=INR';
            qrCodeBytes =
                await _qrCodeService.generateQrCodeImage(upiPaymentString);
          } catch (e) {
            debugPrint('[DmPrintService] Failed generating QR from UPI ID: $e');
          }
        }
      } else {
        try {
          selectedAccount = accounts.firstWhere(
            (acc) =>
                (acc.accountNumber != null && acc.accountNumber!.isNotEmpty) ||
                (acc.ifscCode != null && acc.ifscCode!.isNotEmpty),
          );
        } catch (e) {
          try {
            selectedAccount = accounts.firstWhere((acc) => acc.isPrimary);
          } catch (e) {
            selectedAccount = accounts.first;
          }
        }
      }

      paymentAccount = {
        'name': selectedAccount.name,
        'accountNumber': selectedAccount.accountNumber,
        'ifscCode': selectedAccount.ifscCode,
        'upiId': selectedAccount.upiId,
        'qrCodeImageUrl': selectedAccount.qrCodeImageUrl,
      };
    }

    final logoBytes = await loadImageBytes(dmSettings.header.logoImageUrl);

    return DmViewPayload(
      dmSettings: dmSettings,
      paymentAccount: paymentAccount,
      logoBytes: logoBytes,
      qrCodeBytes: qrCodeBytes,
    );
  }

  /// Generate PDF bytes for the given DM data. Pass [viewPayload] to avoid duplicate fetches when user taps Print after viewing.
  Future<Uint8List> generatePdfBytes({
    required String organizationId,
    required Map<String, dynamic> dmData,
    DmViewPayload? viewPayload,
  }) async {
    final DmSettings dmSettings;
    final Map<String, dynamic>? paymentAccount;
    final Uint8List? logoBytes;
    final Uint8List? qrCodeBytes;

    if (viewPayload != null) {
      dmSettings = viewPayload.dmSettings;
      paymentAccount = viewPayload.paymentAccount;
      logoBytes = viewPayload.logoBytes;
      qrCodeBytes = viewPayload.qrCodeBytes;
    } else {
      final payload = await loadDmViewData(
        organizationId: organizationId,
        dmData: dmData,
      );
      dmSettings = payload.dmSettings;
      paymentAccount = payload.paymentAccount;
      logoBytes = payload.logoBytes;
      qrCodeBytes = payload.qrCodeBytes;
    }

    final pdfBytes = await pdf_template.generateDmPdf(
      dmData: dmData,
      dmSettings: dmSettings,
      paymentAccount: paymentAccount,
      logoBytes: logoBytes,
      qrCodeBytes: qrCodeBytes,
      watermarkBytes: null,
    );

    return pdfBytes;
  }

  /// Escape HTML entities
  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  /// Format currency (INR format with commas)
  String _formatCurrency(double amount) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return '₹$formatted';
  }

  /// Format number (with commas)
  String _formatNumber(double number) {
    return number.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  /// Convert number to words (for amount in words)
  String _numberToWords(double amount) {
    if (amount < 1) {
      return 'Zero Rupees';
    }

    final rupees = amount.floor();
    final paise = ((amount - rupees) * 100).round();

    final rupeesText = _convertNumberToWords(rupees.toInt());
    final paiseText = paise > 0 ? _convertNumberToWords(paise) : '';

    if (paise > 0) {
      return '$rupeesText Rupees and $paiseText Paise Only';
    } else {
      return '$rupeesText Rupees Only';
    }
  }

  /// Convert number to words (helper)
  String _convertNumberToWords(int number) {
    if (number == 0) return 'Zero';
    if (number < 0) return 'Negative ${_convertNumberToWords(-number)}';

    final ones = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine'
    ];
    final teens = [
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen'
    ];
    final tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety'
    ];

    if (number < 10) return ones[number];
    if (number < 20) return teens[number - 10];
    if (number < 100) {
      return tens[number ~/ 10] +
          (number % 10 != 0 ? ' ${ones[number % 10]}' : '');
    }
    if (number < 1000) {
      return '${ones[number ~/ 100]} Hundred${number % 100 != 0 ? ' ${_convertNumberToWords(number % 100)}' : ''}';
    }
    if (number < 100000) {
      return '${_convertNumberToWords(number ~/ 1000)} Thousand${number % 1000 != 0 ? ' ${_convertNumberToWords(number % 1000)}' : ''}';
    }
    if (number < 10000000) {
      return '${_convertNumberToWords(number ~/ 100000)} Lakh${number % 100000 != 0 ? ' ${_convertNumberToWords(number % 100000)}' : ''}';
    }

    final crore = number ~/ 10000000;
    final remainder = number % 10000000;
    return remainder > 0
        ? '${_convertNumberToWords(crore)} Crore ${_convertNumberToWords(remainder)}'
        : '${_convertNumberToWords(crore)} Crore';
  }

  /// Build table rows HTML
  String _buildTableRows(List<dynamic> items) {
    final buffer = StringBuffer();
    double totalAmount = 0.0;

    for (int i = 0; i < items.length; i++) {
      final item = items[i] as Map<String, dynamic>;
      final productName = item['productName'] as String? ?? 'N/A';
      final quantity = (item['fixedQuantityPerTrip'] as num?)?.toDouble() ??
          (item['quantity'] as num?)?.toDouble() ??
          0.0;
      final unitPrice = (item['unitPrice'] as num?)?.toDouble() ?? 0.0;
      final amount = (item['subtotal'] as num?)?.toDouble() ??
          (item['amount'] as num?)?.toDouble() ??
          (quantity * unitPrice);

      totalAmount += amount;

      buffer.writeln('      <tr>');
      buffer.writeln('        <td>${i + 1}</td>');
      buffer.writeln('        <td>${_escapeHtml(productName)}</td>');
      buffer.writeln('        <td>${_formatNumber(quantity)}</td>');
      buffer.writeln('        <td>${_formatCurrency(unitPrice)}</td>');
      buffer.writeln('        <td>${_formatCurrency(amount)}</td>');
      buffer.writeln('      </tr>');
    }

    // Total row
    buffer.writeln('      <tr>');
    buffer.writeln('        <td></td>');
    buffer.writeln('        <td></td>');
    buffer.writeln('        <td></td>');
    buffer.writeln(
        '        <td style="text-align: right; font-weight: bold;">Total</td>');
    buffer.writeln(
        '        <td style="text-align: right; font-weight: bold;">${_formatCurrency(totalAmount)}</td>');
    buffer.writeln('      </tr>');

    return buffer.toString();
  }

  /// Build payment section HTML
  String _buildPaymentSection(
    DmSettings dmSettings,
    Map<String, dynamic>? paymentAccount,
    String? qrDataUri,
  ) {
    if (dmSettings.paymentDisplay == DmPaymentDisplay.qrCode &&
        qrDataUri != null) {
      return '''
  <div class="payment-section">
    <img src="$qrDataUri" alt="QR Code" class="qr-code">
    <div>Scan QR Code to Pay</div>
  </div>
''';
    } else if (dmSettings.paymentDisplay == DmPaymentDisplay.bankDetails &&
        paymentAccount != null) {
      final buffer = StringBuffer();
      buffer.writeln('  <div class="payment-section">');
      buffer.writeln('    <div style="text-align: left;">');
      buffer.writeln(
          '      <div style="font-weight: bold; font-size: 14px; margin-bottom: 5px;">Bank Details:</div>');
      if (paymentAccount['name'] != null &&
          paymentAccount['name'].toString().isNotEmpty) {
        buffer.writeln(
            '      <div>Bank Name: ${_escapeHtml(paymentAccount['name'].toString())}</div>');
      }
      if (paymentAccount['accountNumber'] != null &&
          paymentAccount['accountNumber'].toString().isNotEmpty) {
        buffer.writeln(
            '      <div>Account Number: ${_escapeHtml(paymentAccount['accountNumber'].toString())}</div>');
      }
      if (paymentAccount['ifscCode'] != null &&
          paymentAccount['ifscCode'].toString().isNotEmpty) {
        buffer.writeln(
            '      <div>IFSC Code: ${_escapeHtml(paymentAccount['ifscCode'].toString())}</div>');
      }
      if (paymentAccount['upiId'] != null &&
          paymentAccount['upiId'].toString().isNotEmpty) {
        buffer.writeln(
            '      <div>UPI ID: ${_escapeHtml(paymentAccount['upiId'].toString())}</div>');
      }
      buffer.writeln('    </div>');
      buffer.writeln('  </div>');
      return buffer.toString();
    }
    return '';
  }

  /// Generate HTML string for DM (same as Web - unified PrintDMPage system)
  /// Respects custom template preference (LIT1/LIT2) if set
  String generateDmHtmlForPrint({
    required Map<String, dynamic> dmData,
    required DmSettings dmSettings,
    Map<String, dynamic>? paymentAccount,
    Uint8List? logoBytes,
    Uint8List? qrCodeBytes,
  }) {
    // Check if custom template (lakshmee) is preferred
    final customTemplateId = dmSettings.customTemplateId?.trim();
    final isLakshmeeTemplate = dmSettings.templateType == DmTemplateType.custom &&
      (customTemplateId == 'LIT1' ||
        customTemplateId == 'LIT2' ||
        customTemplateId == 'lakshmee_v1' ||
        customTemplateId == 'lakshmee_v2');
    if (isLakshmeeTemplate) {
      return _generateLakshmeeHtml(
        dmData: dmData,
        dmSettings: dmSettings,
        paymentAccount: paymentAccount,
        logoBytes: logoBytes,
        qrCodeBytes: qrCodeBytes,
        hidePriceFields: customTemplateId == 'LIT2' || customTemplateId == 'lakshmee_v2',
      );
    }

    // Use universal template for all other cases
    return _generateDmHtml(
      dmData: dmData,
      dmSettings: dmSettings,
      paymentAccount: paymentAccount,
      logoBytes: logoBytes,
      qrCodeBytes: qrCodeBytes,
    );
  }

  /// Generate HTML string for DM (universal template)
  String _generateDmHtml({
    required Map<String, dynamic> dmData,
    required DmSettings dmSettings,
    Map<String, dynamic>? paymentAccount,
    Uint8List? logoBytes,
    Uint8List? qrCodeBytes,
  }) {
    // Extract data from dmData
    final dmNumber = dmData['dmNumber'] as int? ?? 0;
    final clientName = dmData['clientName'] as String? ?? 'N/A';
    final clientPhoneRaw = dmData['clientPhone'] as String?;
    final clientPhone =
        (clientPhoneRaw != null && clientPhoneRaw.trim().isNotEmpty)
            ? clientPhoneRaw.trim()
            : 'N/A';
    final deliveryZone = dmData['deliveryZone'] as Map<String, dynamic>?;
    String clientAddress = 'N/A';
    if (deliveryZone != null) {
      final city = deliveryZone['city_name'] ?? deliveryZone['city'] ?? '';
      final region = deliveryZone['region'] ?? '';
      final area = deliveryZone['area'] ?? '';

      final addressParts = <String>[];
      if (area.isNotEmpty) addressParts.add(area);
      if (city.isNotEmpty) addressParts.add(city);
      if (region.isNotEmpty) addressParts.add(region);

      clientAddress = addressParts.isNotEmpty ? addressParts.join(', ') : 'N/A';
    } else {
      clientAddress = dmData['clientAddress'] as String? ?? 'N/A';
    }

    // Extract date
    final scheduledDate = dmData['scheduledDate'];
    DateTime? date;
    if (scheduledDate != null) {
      if (scheduledDate is Map && scheduledDate.containsKey('_seconds')) {
        date = DateTime.fromMillisecondsSinceEpoch(
          (scheduledDate['_seconds'] as int) * 1000,
        );
      } else if (scheduledDate is DateTime) {
        date = scheduledDate;
      }
    }
    final dateText =
        date != null ? '${date.day}/${date.month}/${date.year}' : 'N/A';

    // Extract driver info
    final driverName = dmData['driverName'] as String? ?? 'N/A';
    final driverPhone = dmData['driverPhone'] as String? ?? 'N/A';

    // Extract items
    final items = (dmData['items'] as List<dynamic>?) ?? [];

    // Extract pricing
    final tripPricing = dmData['tripPricing'] as Map<String, dynamic>? ?? {};
    final total = (tripPricing['total'] as num?)?.toDouble() ?? 0.0;

    // Convert images to base64
    String? logoDataUri;
    if (logoBytes != null && logoBytes.isNotEmpty) {
      logoDataUri = 'data:image/png;base64,${base64Encode(logoBytes)}';
    }

    String? qrDataUri;
    if (qrCodeBytes != null &&
        qrCodeBytes.isNotEmpty &&
        dmSettings.paymentDisplay == DmPaymentDisplay.qrCode) {
      qrDataUri = 'data:image/png;base64,${base64Encode(qrCodeBytes)}';
    }

    // Build HTML (simplified version without print header for Android PDF)
    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    * {
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }
    body {
      font-family: 'Arial', 'Helvetica', sans-serif;
      font-size: 13px;
      line-height: 1.5;
      margin: 0;
      padding: 0;
      background: white;
      color: black;
    }
    .dm-container {
      border: 2px solid #000;
      padding: 20px;
      margin: 0;
      min-height: calc(100vh - 0.8in);
      box-sizing: border-box;
      background: white;
    }
    .header {
      display: flex;
      align-items: flex-start;
      margin-bottom: 20px;
      border-bottom: 2px solid #000;
      padding-bottom: 15px;
    }
    .logo {
      width: 80px;
      height: 80px;
      margin-right: 20px;
      object-fit: contain;
      filter: grayscale(100%);
    }
    .company-info {
      flex: 1;
    }
    .company-info > div {
      margin-bottom: 4px;
      font-size: 13px;
      line-height: 1.6;
    }
    .company-name {
      font-size: 20px;
      font-weight: bold;
      margin-bottom: 8px;
      color: #000;
      letter-spacing: 0.5px;
    }
    .title {
      text-align: center;
      font-size: 26px;
      font-weight: bold;
      margin: 25px 0;
      border-top: 2px solid #000;
      border-bottom: 2px solid #000;
      padding: 12px 0;
      color: #000;
      letter-spacing: 1px;
    }
    .recipient-section {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      margin-bottom: 12px;
      padding: 16px;
      border: 1px solid #000;
      background: white;
    }
    .recipient-info {
      flex: 1;
    }
    .recipient-info > div {
      margin-bottom: 8px;
      line-height: 1.6;
    }
    .recipient-info > div:last-child {
      margin-bottom: 0;
    }
    .address-section {
      margin-bottom: 12px;
      padding: 16px;
      border: 1px solid #000;
      background: white;
      line-height: 1.6;
    }
    .items-qr-container {
      display: flex;
      gap: 20px;
      margin: 20px 0;
      align-items: flex-start;
    }
    .items-container {
      flex: 1;
      border: 1px solid #000;
      overflow: hidden;
    }
    .driver-section {
      margin-bottom: 20px;
      padding: 14px 16px;
      border: 1px solid #000;
      background: white;
      display: flex;
      justify-content: space-between;
      align-items: center;
      line-height: 1.6;
    }
    .driver-info-left,
    .driver-info-right {
      flex: 1;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      margin: 0;
      background: white;
    }
    table th, table td {
      border: 1px solid #000;
      padding: 10px 8px;
      text-align: left;
      background: white;
      line-height: 1.5;
    }
    table th {
      background: white !important;
      font-weight: bold;
      border-bottom: 2px solid #000;
      font-size: 13px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    table td {
      font-size: 13px;
    }
    table td:last-child,
    table th:last-child {
      text-align: right;
    }
    table td:nth-last-child(2),
    table th:nth-last-child(2) {
      text-align: right;
    }
    table tbody tr {
      background: white;
    }
    table tbody tr:nth-child(even) {
      background: white;
    }
    .payment-section {
      text-align: center;
      padding: 20px 15px;
      border: 1px solid #000;
      background: white;
      flex-shrink: 0;
      min-width: 220px;
      display: flex;
      flex-direction: column;
      justify-content: center;
      align-items: center;
    }
    .qr-code {
      width: 160px;
      height: 160px;
      margin: 0 auto 12px;
      display: block;
      filter: grayscale(100%) contrast(120%);
    }
    .footer {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      margin-top: 30px;
      padding: 20px;
      border: 1px solid #000;
      background: white;
      min-height: 100px;
    }
    .footer-left {
      flex: 1;
      line-height: 1.6;
    }
    .footer-left > div {
      margin-bottom: 8px;
    }
    .footer-signature {
      text-align: right;
      padding-top: 60px;
      min-width: 120px;
    }
  </style>
</head>
<body>
  <div class="dm-container">
    <div class="header">
      ${logoDataUri != null ? '<img src="$logoDataUri" alt="Logo" class="logo">' : ''}
      <div class="company-info">
        <div class="company-name">${_escapeHtml(dmSettings.header.name)}</div>
        ${dmSettings.header.address.isNotEmpty ? '<div>${_escapeHtml(dmSettings.header.address)}</div>' : ''}
        ${dmSettings.header.phone.isNotEmpty ? '<div>Phone: ${_escapeHtml(dmSettings.header.phone)}</div>' : ''}
        ${dmSettings.header.gstNo != null && dmSettings.header.gstNo!.isNotEmpty ? '<div>GST No: ${_escapeHtml(dmSettings.header.gstNo!)}</div>' : ''}
      </div>
    </div>

    <div class="title">DELIVERY MEMO</div>

    <div class="recipient-section">
      <div class="recipient-info">
        <div><strong>DM No.:</strong> $dmNumber</div>
        <div><strong>M/s</strong> ${_escapeHtml(clientName)}</div>
        <div><strong>Mobile:</strong> ${_escapeHtml(clientPhone)}</div>
      </div>
      <div><strong>Date:</strong> $dateText</div>
    </div>

    <div class="address-section">
      <strong>Address:</strong> ${_escapeHtml(clientAddress)}
    </div>

    <div class="driver-section">
      <div class="driver-info-left"><strong>Driver Name:</strong> ${_escapeHtml(driverName)}</div>
      <div class="driver-info-right"><strong>Driver Phone:</strong> ${_escapeHtml(driverPhone)}</div>
    </div>

    <div class="items-qr-container">
      <div class="items-container">
        <table>
          <thead>
            <tr>
              <th>S.N.</th>
              <th>Description of Goods</th>
              <th>Quantity</th>
              <th>Rate</th>
              <th>Amount</th>
            </tr>
          </thead>
          <tbody>
            ${_buildTableRows(items)}
          </tbody>
        </table>
      </div>

      ${_buildPaymentSection(dmSettings, paymentAccount, qrDataUri)}
    </div>

    <div class="footer">
      <div class="footer-left">
        <div><strong>Amount in words:</strong> ${_numberToWords(total)}</div>
        ${dmSettings.footer.customText != null && dmSettings.footer.customText!.isNotEmpty ? '''
        <div style="margin-top: 12px;">
          <div style="font-weight: bold; margin-bottom: 4px;">Terms & Conditions:</div>
          <div style="font-size: 12px;">${_escapeHtml(dmSettings.footer.customText!)}</div>
        </div>
        ''' : ''}
      </div>
      <div class="footer-signature">
        <div style="border-top: 1px solid #000; padding-top: 4px; margin-top: -4px;">Signature</div>
      </div>
    </div>
  </div>
</body>
</html>
''';

    return html;
  }

  /// Generate Lakshmee template HTML (matches PaveBoard's PrintDM.jsx design)
  String _generateLakshmeeHtml({
    required Map<String, dynamic> dmData,
    required DmSettings dmSettings,
    Map<String, dynamic>? paymentAccount,
    Uint8List? logoBytes,
    Uint8List? qrCodeBytes,
    bool hidePriceFields = false,
  }) {
    // Extract data from dmData
    final dmNumber = dmData['dmNumber'] as int? ?? 0;
    final clientName = dmData['clientName'] as String? ?? 'N/A';
    final clientPhoneRaw = dmData['clientPhone'] as String? ??
        dmData['clientPhoneNumber'] as String? ??
        dmData['customerNumber'] as String?;
    final clientPhone =
        (clientPhoneRaw != null && clientPhoneRaw.trim().isNotEmpty)
            ? clientPhoneRaw.trim()
            : 'N/A';

    // Extract address
    final deliveryZone = dmData['deliveryZone'] as Map<String, dynamic>?;
    String address = 'N/A';
    String regionName = 'N/A';
    if (deliveryZone != null) {
      final city = deliveryZone['city_name'] ?? deliveryZone['city'] ?? '';
      final region = deliveryZone['region'] ?? '';
      final area = deliveryZone['area'] ?? '';

      final addressParts = <String>[];
      if (area.isNotEmpty) addressParts.add(area);
      if (city.isNotEmpty) addressParts.add(city);
      if (region.isNotEmpty) {
        addressParts.add(region);
        regionName = region;
      }

      address = addressParts.isNotEmpty ? addressParts.join(', ') : 'N/A';
    } else {
      address = dmData['clientAddress'] as String? ?? 'N/A';
      regionName = dmData['regionName'] as String? ?? 'N/A';
    }

    // Extract date
    final scheduledDate = dmData['scheduledDate'];
    DateTime? date;
    if (scheduledDate != null) {
      if (scheduledDate is Map && scheduledDate.containsKey('_seconds')) {
        date = DateTime.fromMillisecondsSinceEpoch(
          (scheduledDate['_seconds'] as int) * 1000,
        );
      } else if (scheduledDate is DateTime) {
        date = scheduledDate;
      }
    }
    final dateText = date != null
        ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
        : 'N/A';

    // Extract driver and vehicle info
    final driverName = dmData['driverName'] as String? ?? 'N/A';
    final vehicleNumber = dmData['vehicleNumber'] as String? ?? 'N/A';

    // Extract product info: use top-level fields if present, else derive from items + tripPricing
    final items = (dmData['items'] as List<dynamic>?) ?? [];
    final tripPricing = dmData['tripPricing'] as Map<String, dynamic>? ?? {};
    String productName = dmData['productName'] as String? ?? 'N/A';
    double productQuant = (dmData['productQuant'] as num?)?.toDouble() ?? 0.0;
    double productUnitPrice =
        (dmData['productUnitPrice'] as num?)?.toDouble() ?? 0.0;
    double total;
    if (productName != 'N/A' && productQuant > 0) {
      total = productQuant * productUnitPrice;
    } else if (items.isNotEmpty) {
      final item = items.first as Map<String, dynamic>;
      productName =
          item['productName'] as String? ?? item['name'] as String? ?? 'N/A';
      productQuant = (item['fixedQuantityPerTrip'] as num?)?.toDouble() ??
          (item['totalQuantity'] as num?)?.toDouble() ??
          (item['quantity'] as num?)?.toDouble() ??
          0.0;
      productUnitPrice = (item['unitPrice'] as num?)?.toDouble() ??
          (item['price'] as num?)?.toDouble() ??
          0.0;
      total = (tripPricing['total'] as num?)?.toDouble() ??
          (productQuant * productUnitPrice);
    } else {
      total = (tripPricing['total'] as num?)?.toDouble() ??
          (productQuant * productUnitPrice);
    }

    // Extract payment info - handle both bool and string values from Firestore
    final paymentStatusValue = dmData['paymentStatus'];
    final paymentStatus = paymentStatusValue is bool
        ? paymentStatusValue
        : (paymentStatusValue is String
            ? paymentStatusValue.toLowerCase() == 'true' ||
                paymentStatusValue.toLowerCase() == 'paid'
            : false);
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
    } else {
      final paymentModeRaw = dmData['paymentMode'] as String?;
      if (paymentModeRaw != null && paymentModeRaw.trim().isNotEmpty) {
        paymentMode = paymentModeRaw.trim();
      }
    }

    // Convert images to base64
    String? logoDataUri;
    if (logoBytes != null && logoBytes.isNotEmpty) {
      logoDataUri = 'data:image/png;base64,${base64Encode(logoBytes)}';
    }

    String? qrDataUri;
    String? qrLabel;
    if (qrCodeBytes != null &&
        qrCodeBytes.isNotEmpty &&
        dmSettings.paymentDisplay == DmPaymentDisplay.qrCode) {
      qrDataUri = 'data:image/png;base64,${base64Encode(qrCodeBytes)}';
      final paymentLabel = paymentAccount?['label'] as String?;
      if (paymentLabel != null && paymentLabel.isNotEmpty) {
        qrLabel = paymentLabel;
      } else if (dmSettings.header.name.isNotEmpty) {
        qrLabel = dmSettings.header.name;
      } else {
        qrLabel = 'Lakshmee Intelligent Technologies';
      }
    }

    // Company info from DM settings
    final companyName = dmSettings.header.name.isNotEmpty
        ? dmSettings.header.name.toUpperCase()
        : 'LAKSHMEE INTELLIGENT TECHNOLOGIES';
    final companyAddress = dmSettings.header.address.isNotEmpty
        ? dmSettings.header.address
        : 'B-24/2, M.I.D.C., CHANDRAPUR - 442406';
    final companyPhone = dmSettings.header.phone.isNotEmpty
        ? dmSettings.header.phone
        : 'Ph: +91 8149448822 | +91 9420448822';
    final jurisdictionNote = dmSettings.footer.customText?.isNotEmpty == true
        ? dmSettings.footer.customText!
        : 'Note: Subject to Chandrapur Jurisdiction';

    // Address display: match PrintDM.jsx (address || "—")
    final addressDisplay =
        (address.isEmpty || address == 'N/A') ? '—' : address;

    // Build Lakshmee HTML (matches PaveBoard's PrintDM.jsx)
    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;800&display=swap" rel="stylesheet">
  <style>
    * {
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }
    body {
      font-family: 'Inter', 'Arial', sans-serif;
      margin: 0;
      padding: 0;
      background: #f5f5f5;
      color: black;
    }
    .no-print {
      display: none !important;
    }
    @media print {
      @page {
        size: A4 portrait;
        margin: 0;
      }
      html, body {
        width: 210mm;
        height: 297mm;
        margin: 0;
        padding: 0;
        background: white !important;
        overflow: visible !important;
      }
      .print-preview-container {
        background: white !important;
        padding: 0 !important;
        margin: 0 !important;
        width: 210mm !important;
        height: 297mm !important;
        display: flex !important;
        justify-content: center !important;
        align-items: center !important;
        overflow: visible !important;
      }
      .page-shadow.page {
        box-shadow: none !important;
        border-radius: 0 !important;
        margin: 0 auto !important;
        padding: 10mm 0 !important;
        width: 200mm !important;
        height: auto !important;
        min-height: 277mm !important;
        display: flex !important;
        flex-direction: column !important;
        justify-content: center !important;
        align-items: center !important;
        overflow: visible !important;
      }
      .wrapper {
        width: 190mm !important;
        height: 277mm !important;
        margin: 0 auto !important;
        padding: 0 !important;
        display: flex !important;
        flex-direction: column !important;
        justify-content: center !important;
        align-items: center !important;
        overflow: visible !important;
      }
      .print-page {
        page-break-after: avoid !important;
        break-after: avoid !important;
      }
      .ticket {
        width: 190mm !important;
        height: 138mm !important;
        page-break-inside: avoid !important;
        break-inside: avoid !important;
        margin: 0 auto !important;
        overflow: visible !important;
      }
      img {
        max-width: 100% !important;
        height: auto !important;
        -webkit-print-color-adjust: exact !important;
        print-color-adjust: exact !important;
      }
    }
    /* Header styles (no-print) – Operon app UI */
    .print-header {
      background: #1E1E1E;
      border-bottom: 1px solid rgba(255,255,255,0.08);
      padding: 1rem 1.5rem;
      position: sticky;
      top: 0;
      z-index: 100;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .print-header-left {
      display: flex;
      align-items: center;
      gap: 1rem;
    }
    .print-header-icon {
      width: 40px;
      height: 40px;
      background: #5D1C19;
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 1.2rem;
      color: #E0E0E0;
    }
    .print-header-title {
      margin: 0;
      font-size: 1.25rem;
      font-weight: 700;
      color: #E0E0E0;
      letter-spacing: -0.02em;
    }
    .print-header-subtitle {
      margin: 0;
      font-size: 0.85rem;
      color: #A1A1A1;
      font-weight: 400;
    }
    .print-header-buttons {
      display: flex;
      gap: 0.75rem;
      align-items: center;
    }
    .print-header-btn {
      border-radius: 10px;
      padding: 0.6rem 1.25rem;
      font-size: 0.9rem;
      font-weight: 600;
      cursor: pointer;
      transition: all 180ms ease;
      display: inline-flex;
      align-items: center;
      gap: 0.4rem;
    }
    .print-header-btn-share {
      background: transparent;
      border: 1px solid rgba(255,255,255,0.25);
      color: #E0E0E0;
    }
    .print-header-btn-share:hover {
      background: rgba(255,255,255,0.08);
      border-color: rgba(255,255,255,0.35);
    }
    .print-header-btn-print {
      background: #5D1C19;
      border: 1px solid #871C1C;
      color: #E0E0E0;
    }
    .print-header-btn-print:hover {
      background: #871C1C;
      filter: brightness(1.1);
    }
    .print-header-btn-cancel {
      background: transparent;
      border: 1px solid rgba(255,255,255,0.25);
      color: #A1A1A1;
    }
    .print-header-btn-cancel:hover {
      background: rgba(255,255,255,0.06);
      color: #E0E0E0;
    }
    .print-toast {
      position: fixed;
      bottom: 24px;
      left: 50%;
      transform: translateX(-50%) translateY(80px);
      background: #1E1E1E;
      color: #E0E0E0;
      padding: 0.6rem 1.2rem;
      border-radius: 10px;
      font-size: 0.9rem;
      box-shadow: 0 4px 20px rgba(0,0,0,0.4);
      z-index: 1000;
      opacity: 0;
      transition: transform 0.25s ease, opacity 0.25s ease;
      pointer-events: none;
    }
    .print-toast.show {
      transform: translateX(-50%) translateY(0);
      opacity: 1;
    }
    .print-preview-container {
      width: 210mm;
      height: 297mm;
      background-color: white;
      color: black;
      font-family: 'Inter', sans-serif;
      print-color-adjust: exact;
      overflow: hidden;
      margin: auto;
      display: flex;
      justify-content: center;
      align-items: center;
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3), 0 4px 16px rgba(0, 0, 0, 0.2), 0 0 0 1px rgba(0, 0, 0, 0.1);
      border-radius: 2px;
      position: relative;
      padding: 5mm;
    }
    .page-shadow.page {
      width: 210mm;
      height: 297mm;
      background-color: white;
      color: black;
      font-family: 'Inter', sans-serif;
      print-color-adjust: exact;
      overflow: hidden;
      margin: auto;
      display: flex;
      justify-content: center;
      align-items: center;
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3), 0 4px 16px rgba(0, 0, 0, 0.2), 0 0 0 1px rgba(0, 0, 0, 0.1);
      border-radius: 2px;
      position: relative;
      padding: 5mm;
    }
    .wrapper {
      display: flex;
      flex-direction: column;
      justify-content: center;
      align-items: center;
      width: 190mm;
      margin: auto;
      gap: 1mm;
      height: 277mm;
      padding: 0;
    }
    .print-page {
      page-break-after: avoid;
    }
    .ticket {
      width: 200mm;
      max-width: 200mm;
      height: 138mm;
      padding: 4mm 5mm;
      border: 1px solid black;
      box-sizing: border-box;
      font-size: 11px;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      gap: 1px;
      font-family: 'Inter', sans-serif;
      position: relative;
      z-index: 1;
      background-color: #fff;
    }
    .ticket.duplicate {
      background-color: #e0e0e0;
    }
    .watermark {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      width: 500px;
      opacity: 0.1;
      z-index: 0;
      pointer-events: none;
      user-select: none;
    }
    .flag-text {
      text-align: center;
      font-size: 11px;
      font-weight: bold;
      color: #b22222;
      margin-bottom: 2px;
    }
    .branding {
      text-align: center;
      line-height: 1.4;
      background-color: #f1f1f1;
      padding: 6px 0;
      border: 1px solid #bbb;
      border-radius: 4px;
      margin-bottom: 2px;
    }
    .company-name {
      font-size: 20px;
      font-weight: 800;
      letter-spacing: 0.8px;
      color: #000;
    }
    .contact-details {
      font-size: 14px;
      font-weight: 500;
      color: #333;
    }
    .title-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 16px;
      font-weight: bold;
      margin-top: 2px;
    }
    .memo-title {
      font-size: 16px;
      font-weight: bold;
      color: #000;
    }
    .meta-right {
      font-size: 15px;
      font-weight: 600;
    }
    .main-content {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      gap: 10px;
      margin-top: 2px;
    }
    .left-column {
      flex: 0 0 190px;
      display: flex;
      flex-direction: column;
      align-items: center;
    }
    .right-column {
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 2px;
    }
    .qr-section-large {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 3px;
    }
    .qr-code-large {
      width: 180px;
      height: 180px;
      border: 3px solid #000;
      background-color: #f8f8f8;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 22px;
      color: #666;
      padding: 10px;
      box-sizing: border-box;
    }
    .qr-image-large {
      width: 100%;
      height: 100%;
      object-fit: contain;
      border: none;
      box-sizing: border-box;
    }
    .qr-label-large {
      font-size: 14px;
      font-weight: bold;
      color: #000;
      text-align: center;
    }
    .qr-amount-large {
      font-size: 14px;
      font-weight: bold;
      color: #1f2937;
      text-align: center;
      line-height: 1.2;
    }
    .info-box {
      display: flex;
      justify-content: space-between;
      border: 1px solid #ccc;
      border-radius: 4px;
      padding: 4px 6px;
      gap: 6px;
      background-color: #fafafa;
    }
    .info-col {
      display: flex;
      flex-direction: column;
      gap: 1px;
      font-size: 14px;
    }
    .table,
    .product-table {
      border: 1px solid black;
      padding: 3px 4px;
      display: flex;
      flex-direction: column;
      gap: 1px;
      background-color: #fff;
      border-radius: 4px;
    }
    .table-row {
      display: flex;
      justify-content: space-between;
      border-bottom: 1px dashed #ccc;
      padding-bottom: 1px;
      padding-top: 2px;
      font-size: 14px;
    }
    .table-row-total {
      display: flex;
      justify-content: space-between;
      font-weight: bold;
      border-top: 1px solid #000;
      padding-top: 3px;
      margin-top: 2px;
      font-size: 15px;
    }
    .jurisdiction-note {
      font-size: 14px;
      text-align: center;
      margin-top: 3px;
      color: #444;
      font-style: italic;
    }
    .footer {
      display: flex;
      justify-content: space-between;
      margin-top: 2px;
      gap: 4px;
    }
    .signature {
      flex: 1;
      font-size: 13px;
      text-align: center;
      line-height: 1.2;
    }
    .signature-line {
      margin-top: 2px;
      border-top: 1px solid black;
      width: 100%;
    }
    .cut-line {
      width: 100%;
      text-align: center;
      margin: 0.5mm 0;
    }
    .cut-line hr {
      border-top: 1px dashed #555;
      margin: 0px 0;
    }
    .cut-line-text {
      font-size: 5px;
      color: #888;
    }
  </style>
  <script>
    function handleClose() {
      if (window.opener) window.close();
      else window.history.back();
    }
    function handleShare() {
      var title = 'Delivery Memo #$dmNumber';
      var url = location.href;
      if (navigator.share) {
        navigator.share({ title: title, url: url }).catch(function() {});
      } else {
        navigator.clipboard.writeText(url).then(function() {
          var t = document.getElementById('share-toast');
          if (t) { t.classList.add('show'); setTimeout(function() { t.classList.remove('show'); }, 2000); }
        });
      }
    }
  </script>
</head>
<body>
  <div id="share-toast" class="print-toast">Link copied to clipboard</div>
  <div class="no-print print-header">
    <div class="print-header-left">
      <div class="print-header-icon">🚚</div>
      <div>
        <h1 class="print-header-title">Delivery Memo #$dmNumber</h1>
        <p class="print-header-subtitle">Operon</p>
      </div>
    </div>
    <div class="print-header-buttons">
      <button type="button" class="print-header-btn print-header-btn-share" onclick="handleShare()">Share</button>
      <button type="button" class="print-header-btn print-header-btn-print" onclick="window.print()">Print</button>
      <button type="button" class="print-header-btn print-header-btn-cancel" onclick="handleClose()">Cancel</button>
    </div>
  </div>

  <div class="print-preview-container">
    <div class="page-shadow page">
      <div class="wrapper">
        <div class="print-page">
          <div class="ticket">
          ${logoDataUri != null ? '<img src="$logoDataUri" alt="Watermark" class="watermark" />' : ''}
          <div class="flag-text">🚩 जय श्री राम 🚩</div>
          <div class="branding">
            <div class="company-name">${_escapeHtml(companyName)}</div>
            <div class="contact-details">${_escapeHtml(companyAddress)}</div>
            <div class="contact-details">${_escapeHtml(companyPhone)}</div>
          </div>
          <hr style="border-top: 2px solid #000; margin: 6px 0;" />
          <div class="title-row">
            <div class="memo-title">🚚 Delivery Memo</div>
            <div class="meta-right">DM No. #$dmNumber</div>
          </div>
          <div class="main-content">
            <div class="left-column">
              <div class="qr-section-large">
                <div class="qr-code-large">
                  ${qrDataUri != null ? '<img src="$qrDataUri" alt="Payment QR Code" class="qr-image-large" />' : '<div style="font-size: 22px; color: #666;">QR Code</div>'}
                </div>
                <div class="qr-label-large">${_escapeHtml(qrLabel ?? companyName)}</div>
                <div class="qr-amount-large">Scan to pay ${_formatCurrency(total)}</div>
              </div>
            </div>
            <div class="right-column">
              <div class="info-box">
                <div class="info-col">
                  <div><strong>Client:</strong> <strong>${_escapeHtml(clientName)}</strong></div>
                  <div><strong>Address:</strong> ${_escapeHtml(addressDisplay)}, ${_escapeHtml(regionName)}</div>
                  <div><strong>Phone:</strong> <strong>${_escapeHtml(clientPhone)}</strong></div>
                </div>
                <div class="info-col">
                  <div><strong>Date:</strong> $dateText</div>
                  <div><strong>Vehicle:</strong> ${_escapeHtml(vehicleNumber)}</div>
                  <div><strong>Driver:</strong> ${_escapeHtml(driverName)}</div>
                </div>
              </div>
              <div class="table">
                <div class="table-row"><span>📦 Product</span><span>${_escapeHtml(productName)}</span></div>
                <div class="table-row"><span>🔢 Quantity</span><span>${_formatNumber(productQuant)}</span></div>
                <div class="table-row"><span>💰 Unit Price</span><span>${hidePriceFields ? '' : _formatCurrency(productUnitPrice)}</span></div>
                <div class="table-row-total"><span>🧾 Total</span><span>${hidePriceFields ? '' : _formatCurrency(total)}</span></div>
                <div class="table-row"><span>💳 Payment Mode</span><span>${_escapeHtml(paymentMode)}</span></div>
              </div>
            </div>
          </div>
          <div class="jurisdiction-note">
            ${_escapeHtml(jurisdictionNote)}
          </div>
          <div class="footer">
            <div class="signature">
              <div>Received By</div>
              <div class="signature-line"></div>
            </div>
            <div class="signature">
              <div>Authorized Signature</div>
              <div class="signature-line"></div>
            </div>
          </div>
        </div>
        </div>
        <div style="width: 100%; text-align: center; margin: 0.5mm 0;">
          <hr style="border-top: 1px dashed #555; margin: 0;" />
          <div style="font-size: 5px; color: #888;">✂️ Cut Here</div>
        </div>
        <div class="print-page">
          <div class="ticket duplicate">
          ${logoDataUri != null ? '<img src="$logoDataUri" alt="Watermark" class="watermark" />' : ''}
          <div class="flag-text">🚩 जय श्री राम 🚩</div>
          <div class="branding">
            <div class="company-name">${_escapeHtml(companyName)}</div>
            <div class="contact-details">${_escapeHtml(companyAddress)}</div>
            <div class="contact-details">${_escapeHtml(companyPhone)}</div>
          </div>
          <hr style="border-top: 2px solid #000; margin: 6px 0;" />
          <div class="title-row">
            <div class="memo-title">🚚 Delivery Memo (Duplicate)</div>
            <div class="meta-right">DM No. #$dmNumber</div>
          </div>
          <div class="main-content">
            <div class="left-column">
              <div class="qr-section-large">
                <div class="qr-code-large">
                  ${qrDataUri != null ? '<img src="$qrDataUri" alt="Payment QR Code" class="qr-image-large" />' : '<div style="font-size: 22px; color: #666;">QR Code</div>'}
                </div>
                <div class="qr-label-large">${_escapeHtml(qrLabel ?? companyName)}</div>
                <div class="qr-amount-large">Scan to pay ${_formatCurrency(total)}</div>
              </div>
            </div>
            <div class="right-column">
              <div class="info-box">
                <div class="info-col">
                  <div><strong>Client:</strong> <strong>${_escapeHtml(clientName)}</strong></div>
                  <div><strong>Address:</strong> ${_escapeHtml(addressDisplay)}, ${_escapeHtml(regionName)}</div>
                  <div><strong>Phone:</strong> <strong>${_escapeHtml(clientPhone)}</strong></div>
                </div>
                <div class="info-col">
                  <div><strong>Date:</strong> $dateText</div>
                  <div><strong>Vehicle:</strong> ${_escapeHtml(vehicleNumber)}</div>
                  <div><strong>Driver:</strong> ${_escapeHtml(driverName)}</div>
                </div>
              </div>
              <div class="table">
                <div class="table-row"><span>📦 Product</span><span>${_escapeHtml(productName)}</span></div>
                <div class="table-row"><span>🔢 Quantity</span><span>${_formatNumber(productQuant)}</span></div>
                <div class="table-row"><span>💰 Unit Price</span><span>${hidePriceFields ? '' : _formatCurrency(productUnitPrice)}</span></div>
                <div class="table-row-total"><span>🧾 Total</span><span>${hidePriceFields ? '' : _formatCurrency(total)}</span></div>
                <div class="table-row"><span>💳 Payment Mode</span><span>${_escapeHtml(paymentMode)}</span></div>
              </div>
            </div>
          </div>
          <div class="jurisdiction-note">
            ${_escapeHtml(jurisdictionNote)}
          </div>
          <div class="footer">
            <div class="signature">
              <div>Received By</div>
              <div class="signature-line"></div>
            </div>
            <div class="signature">
              <div>Authorized Signature</div>
              <div class="signature-line"></div>
            </div>
          </div>
        </div>
        </div>
      </div>
    </div>
  </div>
</body>
</html>
''';

    return html;
  }

  /// Unified print flow using HTML-based generation (PrintDMPage system)
  /// Generates HTML using same template as Web, converts to PDF, opens print preview
  Future<void> printDeliveryMemo({
    required int dmNumber,
    required String organizationId,
    Map<String, dynamic>? dmData,
  }) async {
    try {
      debugPrint(
          '[DmPrintService] Starting unified HTML-based print flow for DM $dmNumber');

      // Fetch DM data if not provided
      Map<String, dynamic>? finalDmData = dmData;
      if (finalDmData == null) {
        debugPrint('[DmPrintService] Fetching DM data by number: $dmNumber');
        finalDmData = await fetchDmByNumberOrId(
          organizationId: organizationId,
          dmNumber: dmNumber,
          dmId: null,
          tripData: null,
        );

        if (finalDmData == null) {
          throw Exception('DM not found for number: $dmNumber');
        }
      }

      // Load view payload (settings, payment account, QR code, logo)
      debugPrint('[DmPrintService] Loading DM view data...');
      final viewPayload = await loadDmViewData(
        organizationId: organizationId,
        dmData: finalDmData,
      );

      // Generate HTML string using same method as Web
      debugPrint('[DmPrintService] Generating HTML for print...');
      final htmlString = generateDmHtmlForPrint(
        dmData: finalDmData,
        dmSettings: viewPayload.dmSettings,
        paymentAccount: viewPayload.paymentAccount,
        logoBytes: viewPayload.logoBytes,
        qrCodeBytes: viewPayload.qrCodeBytes,
      );

      // Convert HTML to PDF bytes using flutter_html_to_pdf_plus
      debugPrint('[DmPrintService] Converting HTML to PDF...');
      Uint8List pdfBytes;
      try {
        pdfBytes = await _convertHtmlToPdf(
          htmlString,
          dmSettings: viewPayload.dmSettings,
        );
      } on MissingPluginException catch (e) {
        debugPrint(
            '[DmPrintService] HTML converter plugin unavailable: $e. Falling back to PDF template generation...');
        pdfBytes = await generatePdfBytes(
          organizationId: organizationId,
          dmData: finalDmData,
        );
      } catch (e) {
        debugPrint(
            '[DmPrintService] HTML conversion failed: $e. Falling back to PDF template generation...');
        pdfBytes = await generatePdfBytes(
          organizationId: organizationId,
          dmData: finalDmData,
        );
      }

      // Open print preview with PDF bytes
      debugPrint('[DmPrintService] Opening print preview...');
      await Printing.layoutPdf(onLayout: (_) async => pdfBytes);

      debugPrint('[DmPrintService] Print preview opened successfully');
    } catch (e, stackTrace) {
      debugPrint('[DmPrintService] ERROR in print flow: $e');
      debugPrint('[DmPrintService] Stack trace: $stackTrace');
      throw Exception('Failed to print: $e');
    }
  }

  /// Convert HTML string to PDF bytes using flutter_html_to_pdf_plus
  Future<Uint8List> _convertHtmlToPdf(
    String htmlString, {
    required DmSettings dmSettings,
  }) async {
    try {
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
        final customTemplateId = dmSettings.customTemplateId?.trim();
          final isLakshmee = dmSettings.templateType == DmTemplateType.custom &&
            (customTemplateId == 'LIT1' ||
              customTemplateId == 'LIT2' ||
              customTemplateId == 'lakshmee_v1' ||
              customTemplateId == 'lakshmee_v2');
      final orientation = isLakshmee
          ? PrintOrientation.Portrait
          : (dmSettings.printOrientation == DmPrintOrientation.landscape
              ? PrintOrientation.Landscape
              : PrintOrientation.Portrait);
      final margins = isLakshmee
          ? const PdfPageMargin(top: 0, bottom: 0, left: 0, right: 0)
          : const PdfPageMargin(top: 15, bottom: 15, left: 15, right: 15);

      // Convert HTML content directly to PDF bytes
      final pdfBytes = await FlutterHtmlToPdf.convertFromHtmlContentBytes(
        content: htmlString,
        configuration: PrintPdfConfiguration(
          targetDirectory: tempDir.path,
          targetName: 'temp_dm_print',
          printSize: PrintSize.A4,
          printOrientation: orientation,
          margins: margins,
        ),
      );

      return pdfBytes;
    } catch (e) {
      debugPrint('[DmPrintService] ERROR converting HTML to PDF: $e');
      rethrow;
    }
  }

  /// Open system print dialog with the PDF
  Future<void> printPdfBytes({required Uint8List pdfBytes}) async {
    await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
  }

  /// Share/save PDF (opens share sheet)
  Future<void> savePdfBytes({
    required Uint8List pdfBytes,
    required String fileName,
  }) async {
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: fileName,
    );
  }
}
