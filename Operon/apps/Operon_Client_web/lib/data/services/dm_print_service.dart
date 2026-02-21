
export 'package:dash_web/data/services/qr_code_service.dart' show QrCodeService;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:core_models/core_models.dart';
import 'package:core_utils/core_utils.dart' as pdf_template;
import 'package:dash_web/data/repositories/dm_settings_repository.dart';
import 'package:dash_web/data/repositories/payment_accounts_repository.dart';
import 'package:dash_web/data/services/qr_code_service.dart';
import 'package:dash_web/data/services/print_view_data_mixin.dart';
import 'package:dash_web/data/services/js_util_bridge.dart' as js_util;

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

/// Payload for print data stored in sessionStorage (Web optimization)
class PrintDataPayload {
  PrintDataPayload({
    required this.dmData,
    required this.viewPayload,
    required this.htmlString,
  });

  final Map<String, dynamic> dmData;
  final DmViewPayload viewPayload;
  final String htmlString;

  Map<String, dynamic> toJson() => {
    'dmData': dmData,
    'viewPayload': {
      'dmSettings': viewPayload.dmSettings.toJson(),
      'paymentAccount': viewPayload.paymentAccount,
      // Note: logoBytes and qrCodeBytes are in HTML as base64, don't store separately
    },
    'htmlString': htmlString,
  };

  static PrintDataPayload? fromJson(Map<String, dynamic> json) {
    try {
      final dmSettingsJson = json['viewPayload']?['dmSettings'] as Map<String, dynamic>?;
      if (dmSettingsJson == null) return null;
      
      final dmSettings = DmSettings.fromJson(dmSettingsJson);
      final viewPayload = DmViewPayload(
        dmSettings: dmSettings,
        paymentAccount: json['viewPayload']?['paymentAccount'] as Map<String, dynamic>?,
        // logoBytes and qrCodeBytes are embedded in HTML, not stored separately
        logoBytes: null,
        qrCodeBytes: null,
      );
      
      return PrintDataPayload(
        dmData: json['dmData'] as Map<String, dynamic>,
        viewPayload: viewPayload,
        htmlString: json['htmlString'] as String,
      );
    } catch (e) {
      debugPrint('[PrintDataPayload] Error parsing from JSON: $e');
      return null;
    }
  }
}

/// Service for printing Delivery Memos (DM)
class DmPrintService with PrintViewDataMixin {
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

  // Mixin requirements
  @override
  DmSettingsRepository get dmSettingsRepository => _dmSettingsRepository;

  @override
  PaymentAccountsRepository get paymentAccountsRepository => _paymentAccountsRepository;

  @override
  QrCodeService get qrCodeService => _qrCodeService;

  @override
  FirebaseStorage get storage => _storage;

  /// Convert schedule trip data to DM data format
  Map<String, dynamic> convertTripToDmData(Map<String, dynamic> tripData) {
    // Extract items - handle both list and single item
    final itemsData = tripData['items'];
    final items = itemsData is List ? itemsData : 
                  (itemsData != null ? [itemsData] : []);
    
    // Extract trip pricing - ensure it's a map
    var tripPricingData = tripData['tripPricing'] as Map<String, dynamic>?;
    if (tripPricingData == null) {
      // Try to construct from individual pricing fields
      tripPricingData = <String, dynamic>{};
      if (tripData['total'] != null) {
        tripPricingData['total'] = tripData['total'];
      }
      if (tripData['subtotal'] != null) {
        tripPricingData['subtotal'] = tripData['subtotal'];
      }
      // Calculate total from items if not present
      if (tripPricingData['total'] == null && items.isNotEmpty) {
        double calculatedTotal = 0.0;
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            final quantity = (item['fixedQuantityPerTrip'] as num?)?.toDouble() ?? 
                           (item['totalQuantity'] as num?)?.toDouble() ?? 
                           (item['quantity'] as num?)?.toDouble() ?? 0.0;
            final unitPrice = (item['unitPrice'] as num?)?.toDouble() ?? 
                            (item['price'] as num?)?.toDouble() ?? 0.0;
            calculatedTotal += quantity * unitPrice;
          }
        }
        tripPricingData['total'] = calculatedTotal;
      }
    }
    
    // Extract delivery zone
    var deliveryZone = tripData['deliveryZone'] as Map<String, dynamic>?;
    if (deliveryZone == null) {
      deliveryZone = <String, dynamic>{};
      // Try to extract zone info from other fields
      if (tripData['region'] != null) {
        deliveryZone['region'] = tripData['region'];
      }
      if (tripData['city'] != null || tripData['cityName'] != null) {
        deliveryZone['city_name'] = tripData['cityName'] ?? tripData['city'];
      }
      if (tripData['area'] != null) {
        deliveryZone['area'] = tripData['area'];
      }
    }
    
    // Extract scheduled date - handle multiple formats
    var scheduledDate = tripData['scheduledDate'] ?? tripData['deliveryDate'];
    
    // Build DM data structure from trip data
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
      'driverPhone': tripData['driverPhone'] ?? 
                     tripData['driverPhoneNumber'] ?? 
                     'N/A',
      'items': items,
      'tripPricing': tripPricingData,
      'paymentStatus': tripData['paymentStatus'] ?? false,
      'toAccount': tripData['toAccount'],
      'paySchedule': tripData['paySchedule'],
      'address': tripData['address'],
      'regionName': tripData['regionName'] ?? 
                   ((deliveryZone['region'] as String?) ?? ''),
    };
    
    // Convert Timestamp fields if present
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
    
    // Ensure items is a list
    if (normalized['items'] == null) {
      normalized['items'] = [];
    } else if (normalized['items'] is! List) {
      normalized['items'] = [normalized['items']];
    }
    
    // Ensure tripPricing is a map
    if (normalized['tripPricing'] == null) {
      normalized['tripPricing'] = <String, dynamic>{};
    } else if (normalized['tripPricing'] is! Map) {
      normalized['tripPricing'] = <String, dynamic>{};
    }
    
    // Ensure deliveryZone is a map
    if (normalized['deliveryZone'] == null) {
      normalized['deliveryZone'] = <String, dynamic>{};
    } else if (normalized['deliveryZone'] is! Map) {
      normalized['deliveryZone'] = <String, dynamic>{};
    }
    
    return normalized;
  }

  /// Fetch DM document by dmNumber or dmId, or convert from trip data
  /// If organizationId is null, queries without organization filter (for print route)
  Future<Map<String, dynamic>?> fetchDmByNumberOrId({
    String? organizationId,
    int? dmNumber,
    String? dmId,
    Map<String, dynamic>? tripData,
  }) async {
    try {
      Query queryRef = FirebaseFirestore.instance
          .collection('DELIVERY_MEMOS');

      // Add organization filter only if provided
      if (organizationId != null && organizationId.isNotEmpty) {
        queryRef = queryRef.where('organizationId', isEqualTo: organizationId);
      }

      if (dmNumber != null) {
        queryRef = queryRef.where('dmNumber', isEqualTo: dmNumber);
      } else if (dmId != null) {
        queryRef = queryRef.where('dmId', isEqualTo: dmId);
      } else {
        // If no DM number/ID and trip data provided, convert trip to DM format
        if (tripData != null) {
          final converted = convertTripToDmData(tripData);
          return normalizeDmData(converted);
        }
        return null;
      }

      final snapshot = await queryRef.limit(1).get();
      if (snapshot.docs.isEmpty) {
        // DM not found in Firestore, but if trip data provided, convert it
        if (tripData != null) {
          final converted = convertTripToDmData(tripData);
          return normalizeDmData(converted);
        }
        return null;
      }

      final doc = snapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>?;
      
      if (data == null) {
        // If trip data provided as fallback, use it
        if (tripData != null) {
          final converted = convertTripToDmData(tripData);
          return normalizeDmData(converted);
        }
        return null;
      }
      
      // Convert Firestore data types to JSON-serializable types
      final convertedData = <String, dynamic>{};
      data.forEach((key, value) {
        if (value is Timestamp) {
          convertedData[key] = {
            '_seconds': value.seconds,
            '_nanoseconds': value.nanoseconds,
          };
        } else if (value is DateTime) {
          convertedData[key] = {
            '_seconds': (value.millisecondsSinceEpoch / 1000).floor(),
            '_nanoseconds': (value.millisecond * 1000000).round(),
          };
        } else {
          convertedData[key] = value;
        }
      });
      
      convertedData['id'] = doc.id; // Add document ID
      return normalizeDmData(convertedData);
    } catch (e) {
        // If error and trip data provided, try converting trip data
      if (tripData != null) {
        try {
          final converted = convertTripToDmData(tripData);
          return normalizeDmData(converted);
        } catch (e2) {
          throw Exception('Failed to fetch DM and convert trip data: $e2');
        }
      }
      throw Exception('Failed to fetch DM: $e');
    }
  }


  /// Load view data only (no PDF). Use for "view first" UI; same data as PDF.
  /// DM settings loaded first; then payment account+QR and logo load in parallel.
  Future<DmViewPayload> loadDmViewData({
    required String organizationId,
    required Map<String, dynamic> dmData,
  }) async {
    final dmSettings = await loadDmSettings(organizationId);
    final paymentFuture = loadPaymentAccountWithQr(
      organizationId: organizationId,
      dmSettings: dmSettings,
    );
    final logoFuture = loadImageBytes(dmSettings.header.logoImageUrl);
    final paymentAccountResult = await paymentFuture;
    final logoBytes = await logoFuture;

    return DmViewPayload(
      dmSettings: dmSettings,
      paymentAccount: paymentAccountResult.paymentAccount,
      logoBytes: logoBytes,
      qrCodeBytes: paymentAccountResult.qrCodeBytes,
    );
  }

  /// Generate PDF bytes (used for print). Pass [viewPayload] to avoid duplicate fetches when user taps Print after viewing.
  Future<Uint8List> generatePdfBytes({
    required String organizationId,
    required Map<String, dynamic> dmData,
    DmViewPayload? viewPayload,
  }) async {
    try {
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

      // Use PDF template generator from core_utils for custom templates
      final pdfBytes = await pdf_template.generateDmPdf(
        dmData: dmData,
        dmSettings: dmSettings,
        paymentAccount: paymentAccount,
        logoBytes: logoBytes,
        qrCodeBytes: qrCodeBytes,
        watermarkBytes: null,
      );

      return pdfBytes;
    } catch (e) {
      throw Exception('Failed to generate PDF: $e');
    }
  }

  /// Returns PDF bytes for the current template (custom → core_utils PDF; universal → HTML to PDF). Use for Print from view-first dialog.
  Future<Uint8List> getPdfBytesForPrint({
    required String organizationId,
    required Map<String, dynamic> dmData,
    DmViewPayload? viewPayload,
  }) async {
    final payload = viewPayload ??
        await loadDmViewData(
          organizationId: organizationId,
          dmData: dmData,
        );

    if (payload.dmSettings.templateType == DmTemplateType.custom &&
        payload.dmSettings.customTemplateId != null) {
      return generatePdfBytes(
        organizationId: organizationId,
        dmData: dmData,
        viewPayload: payload,
      );
    }

    // Universal template: HTML then convert to PDF
    final htmlString = _generateDmHtml(
      dmData: dmData,
      dmSettings: payload.dmSettings,
      paymentAccount: payload.paymentAccount,
      logoBytes: payload.logoBytes,
      qrCodeBytes: payload.qrCodeBytes,
    );
    return _htmlToPdf(htmlString);
  }

  /// Generate HTML string for DM (public method for browser print)
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

  /// Generate HTML string for DM
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
    final clientPhoneRaw = dmData['clientPhone'] as String? ??
        dmData['clientPhoneNumber'] as String? ??
        dmData['customerNumber'] as String?;
    final clientPhone = (clientPhoneRaw != null && clientPhoneRaw.trim().isNotEmpty)
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
    final dateText = date != null
        ? '${date.day}/${date.month}/${date.year}'
        : 'N/A';
    
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
    if (qrCodeBytes != null && qrCodeBytes.isNotEmpty &&
        dmSettings.paymentDisplay == DmPaymentDisplay.qrCode) {
      qrDataUri = 'data:image/png;base64,${base64Encode(qrCodeBytes)}';
    }
    
    // Build HTML
    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    /* Base styles */
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
    .qr-text {
      font-size: 13px;
      font-weight: 500;
      margin-top: 8px;
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
    /* Print-specific styles - follow DM Settings print orientation */
    @media print {
      @page {
        size: A4 ${dmSettings.printOrientation == DmPrintOrientation.landscape ? 'landscape' : 'portrait'};
        margin: 15mm;
      }
      * {
        -webkit-print-color-adjust: exact;
        print-color-adjust: exact;
        color-adjust: exact;
      }
      body {
        background: white;
        color: black;
      }
      .no-print {
        display: none !important;
      }
      .dm-container {
        border: 2px solid #000;
        background: white;
        box-shadow: none;
      }
      .header {
        border-bottom: 2px solid #000;
      }
      .title {
        border-top: 2px solid #000;
        border-bottom: 2px solid #000;
      }
      .recipient-section,
      .address-section,
      .driver-section,
      .items-qr-container {
        border: none;
      }
      .items-container,
      .payment-section,
      .footer {
        border: 1px solid #000;
        background: white !important;
        box-shadow: none;
      }
      .items-qr-container {
        display: flex;
        gap: 20px;
      }
      table th {
        background: white !important;
        -webkit-print-color-adjust: exact;
        print-color-adjust: exact;
      }
      table td {
        background: white !important;
        -webkit-print-color-adjust: exact;
        print-color-adjust: exact;
      }
      .logo,
      .qr-code {
        -webkit-print-color-adjust: exact;
        print-color-adjust: exact;
        filter: grayscale(100%) contrast(120%);
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
  
  <div class="dm-container">
  <!-- Header -->
  <div class="header">
    ${logoDataUri != null ? '<img src="$logoDataUri" alt="Logo" class="logo">' : ''}
    <div class="company-info">
      <div class="company-name">${_escapeHtml(dmSettings.header.name)}</div>
      ${dmSettings.header.address.isNotEmpty ? '<div>${_escapeHtml(dmSettings.header.address)}</div>' : ''}
      ${dmSettings.header.phone.isNotEmpty ? '<div>Phone: ${_escapeHtml(dmSettings.header.phone)}</div>' : ''}
      ${dmSettings.header.gstNo != null && dmSettings.header.gstNo!.isNotEmpty ? '<div>GST No: ${_escapeHtml(dmSettings.header.gstNo!)}</div>' : ''}
    </div>
  </div>
  
  <!-- Title -->
  <div class="title">DELIVERY MEMO</div>
  
  <!-- Recipient Section -->
  <div class="recipient-section">
    <div class="recipient-info">
      <div><strong>DM No.:</strong> $dmNumber</div>
      <div><strong>M/s</strong> ${_escapeHtml(clientName)}</div>
      <div><strong>Mobile:</strong> ${_escapeHtml(clientPhone)}</div>
    </div>
    <div><strong>Date:</strong> $dateText</div>
  </div>
  
  <!-- Address Section -->
  <div class="address-section">
    <strong>Address:</strong> ${_escapeHtml(clientAddress)}
  </div>
  
  <!-- Driver Section -->
  <div class="driver-section">
    <div class="driver-info-left"><strong>Driver Name:</strong> ${_escapeHtml(driverName)}</div>
    <div class="driver-info-right"><strong>Driver Phone:</strong> ${_escapeHtml(driverPhone)}</div>
  </div>
  
  <!-- Items and QR Code Section (Side by Side) -->
  <div class="items-qr-container">
    <!-- Items Table -->
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
    
    <!-- Payment Section (QR Code) -->
    ${_buildPaymentSection(dmSettings, paymentAccount, qrDataUri)}
  </div>
  
  <!-- Footer -->
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

  /// Build table rows HTML
  String _buildTableRows(List<dynamic> items) {
    final buffer = StringBuffer();
    double totalAmount = 0.0;
    
    for (int i = 0; i < items.length; i++) {
      final item = items[i] as Map<String, dynamic>;
      final productName = item['productName'] as String? ?? 'N/A';
      final quantity = (item['fixedQuantityPerTrip'] as num?)?.toDouble() ??
          (item['quantity'] as num?)?.toDouble() ?? 0.0;
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
    buffer.writeln('        <td style="text-align: right; font-weight: bold;">Total</td>');
    buffer.writeln('        <td style="text-align: right; font-weight: bold;">${_formatCurrency(totalAmount)}</td>');
    buffer.writeln('      </tr>');
    
    return buffer.toString();
  }

  /// Build payment section HTML
  String _buildPaymentSection(
    DmSettings dmSettings,
    Map<String, dynamic>? paymentAccount,
    String? qrDataUri,
  ) {
    if (dmSettings.paymentDisplay == DmPaymentDisplay.qrCode && qrDataUri != null) {
      return '''
  <div class="payment-section">
    <img src="$qrDataUri" alt="QR Code" class="qr-code">
    <div>Scan QR Code to Pay</div>
  </div>
''';
    } else if (dmSettings.paymentDisplay == DmPaymentDisplay.bankDetails && paymentAccount != null) {
      final buffer = StringBuffer();
      buffer.writeln('  <div class="payment-section">');
      buffer.writeln('    <div style="text-align: left;">');
      buffer.writeln('      <div style="font-weight: bold; font-size: 14px; margin-bottom: 5px;">Bank Details:</div>');
      if (paymentAccount['name'] != null && paymentAccount['name'].toString().isNotEmpty) {
        buffer.writeln('      <div>Bank Name: ${_escapeHtml(paymentAccount['name'].toString())}</div>');
      }
      if (paymentAccount['accountNumber'] != null && paymentAccount['accountNumber'].toString().isNotEmpty) {
        buffer.writeln('      <div>Account Number: ${_escapeHtml(paymentAccount['accountNumber'].toString())}</div>');
      }
      if (paymentAccount['ifscCode'] != null && paymentAccount['ifscCode'].toString().isNotEmpty) {
        buffer.writeln('      <div>IFSC Code: ${_escapeHtml(paymentAccount['ifscCode'].toString())}</div>');
      }
      if (paymentAccount['upiId'] != null && paymentAccount['upiId'].toString().isNotEmpty) {
        buffer.writeln('      <div>UPI ID: ${_escapeHtml(paymentAccount['upiId'].toString())}</div>');
      }
      buffer.writeln('    </div>');
      buffer.writeln('  </div>');
      return buffer.toString();
    }
    return '';
  }

  /// Convert HTML to PDF bytes using html2pdf.js
  Future<Uint8List> _htmlToPdf(String htmlString) async {
    try {
      // Use js_util to access window and call JS function
      // Use window directly for Flutter web
      final windowObj = html.window;
      final convertFunc = js_util.getProperty(windowObj, 'convertHtmlToPdfBlob');
      if (convertFunc == null) {
        throw Exception('convertHtmlToPdfBlob function is not available on window');
      }
      // Call the JS function and get a JS Promise
      final jsPromise = js_util.callMethod(convertFunc, 'call', [windowObj, htmlString]);
      if (jsPromise == null) {
        throw Exception('convertHtmlToPdfBlob returned null');
      }
      // Convert JS Promise to Dart Future
      final pdfBlob = await js_util.promiseToFuture(jsPromise) as html.Blob;
      
      // Convert blob to Uint8List using FileReader
      final fileReader = html.FileReader();
      final bytesCompleter = Completer<Uint8List>();
      
      fileReader.onLoadEnd.listen((_) {
        try {
          final result = fileReader.result;
          if (result is! ByteBuffer) {
            bytesCompleter.completeError(Exception('FileReader result is not ByteBuffer'));
            return;
          }
          bytesCompleter.complete(Uint8List.view(result));
        } catch (e) {
          bytesCompleter.completeError(Exception('Failed to convert blob to bytes: $e'));
        }
      });
      
      fileReader.onError.listen((e) {
        bytesCompleter.completeError(Exception('FileReader error: $e'));
      });
      
      fileReader.readAsArrayBuffer(pdfBlob);
      return await bytesCompleter.future;
    } catch (e) {
      throw Exception('Failed to convert HTML to PDF: $e');
    }
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

  /// Format currency with 2 decimals (for Unit Price display)
  String _formatCurrencyWithDecimals(double amount) {
    final formatted = amount.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+\.)'),
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
    final clientPhone = (clientPhoneRaw != null && clientPhoneRaw.trim().isNotEmpty)
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
      productName = item['productName'] as String? ??
          item['name'] as String? ??
          'N/A';
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

    // Extract payment info - map paymentType to display value
    final paymentType = dmData['paymentType'] as String?;
    String paymentMode = 'N/A';
    if (paymentType == 'pay_later') {
      paymentMode = 'Credit';
    } else if (paymentType == 'pay_on_delivery') {
      paymentMode = 'Cash';
    }

    // Convert images to base64
    String? logoDataUri;
    if (logoBytes != null && logoBytes.isNotEmpty) {
      logoDataUri = 'data:image/png;base64,${base64Encode(logoBytes)}';
    }
    
    String? qrDataUri;
    String? qrLabel;
    if (qrCodeBytes != null && qrCodeBytes.isNotEmpty &&
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
    final addressDisplay = (address.isEmpty || address == 'N/A') ? '—' : address;
    
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
                <div class="table-row"><span>💰 Unit Price</span><span>${hidePriceFields ? '' : _formatCurrencyWithDecimals(productUnitPrice)}</span></div>
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
                <div class="table-row"><span>💰 Unit Price</span><span>${hidePriceFields ? '' : _formatCurrencyWithDecimals(productUnitPrice)}</span></div>
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

  /// Convert number to words (basic implementation)
  String _convertNumberToWords(int number) {
    if (number == 0) return 'Zero';
    
    final ones = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
      'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
      'Seventeen', 'Eighteen', 'Nineteen'
    ];
    
    final tens = [
      '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
    ];
    
    if (number < 20) {
      return ones[number];
    }
    
    if (number < 100) {
      final ten = number ~/ 10;
      final one = number % 10;
      return one > 0 ? '${tens[ten]} ${ones[one]}' : tens[ten];
    }
    
    if (number < 1000) {
      final hundred = number ~/ 100;
      final remainder = number % 100;
      return remainder > 0
          ? '${ones[hundred]} Hundred ${_convertNumberToWords(remainder)}'
          : '${ones[hundred]} Hundred';
    }
    
    if (number < 100000) {
      final thousand = number ~/ 1000;
      final remainder = number % 1000;
      return remainder > 0
          ? '${_convertNumberToWords(thousand)} Thousand ${_convertNumberToWords(remainder)}'
          : '${_convertNumberToWords(thousand)} Thousand';
    }
    
    if (number < 10000000) {
      final lakh = number ~/ 100000;
      final remainder = number % 100000;
      return remainder > 0
          ? '${_convertNumberToWords(lakh)} Lakh ${_convertNumberToWords(remainder)}'
          : '${_convertNumberToWords(lakh)} Lakh';
    }
    
    final crore = number ~/ 10000000;
    final remainder = number % 10000000;
    return remainder > 0
        ? '${_convertNumberToWords(crore)} Crore ${_convertNumberToWords(remainder)}'
        : '${_convertNumberToWords(crore)} Crore';
  }

  /// Prepare all print data: fetch DM, load view payload, generate HTML
  /// Returns payload with all data needed for printing
  Future<PrintDataPayload> preparePrintData({
    required int dmNumber,
    Map<String, dynamic>? dmData, // Optional: if already fetched
  }) async {
    debugPrint('[DmPrintService] Preparing print data for DM $dmNumber');
    
    // Fetch DM data if not provided
    Map<String, dynamic>? finalDmData = dmData;
    if (finalDmData == null) {
      debugPrint('[DmPrintService] Fetching DM data by number: $dmNumber');
      finalDmData = await fetchDmByNumberOrId(
        organizationId: null, // Query without orgId filter
        dmNumber: dmNumber,
        dmId: null,
        tripData: null,
      );
      
      if (finalDmData == null) {
        throw Exception('DM not found for number: $dmNumber');
      }
    }
    
    // Extract organizationId from DM data
    final orgId = finalDmData['organizationId'] as String? ?? 
                  finalDmData['orgID'] as String?;
    
    if (orgId == null || orgId.isEmpty) {
      throw Exception('Organization ID not found in DM data');
    }
    
    debugPrint('[DmPrintService] Organization ID: $orgId');
    
    final needsOrderEnrichment = _needsOrderEnrichment(finalDmData);
    // Fetch related order and view payload in parallel (neither depends on the other)
    final orderId = finalDmData['orderID'] as String?;
    final orderFuture = (needsOrderEnrichment && orderId != null && orderId.isNotEmpty)
      ? _fetchRelatedOrder(orderId, orgId)
      : Future<Map<String, dynamic>?>.value(null);
    final viewPayloadFuture = loadDmViewData(
      organizationId: orgId,
      dmData: finalDmData,
    );

    final results = await Future.wait([orderFuture, viewPayloadFuture]);
    final orderData = results[0] as Map<String, dynamic>?;
    final viewPayload = results[1] as DmViewPayload;

    if (orderData != null) {
      debugPrint('[DmPrintService] Order data fetched, merging phone/driver info');
      finalDmData['clientPhone'] = orderData['clientPhoneNumber'] as String? ??
          finalDmData['clientPhone'] as String?;
      finalDmData['driverName'] = orderData['driverName'] as String? ??
          finalDmData['driverName'] as String?;
      finalDmData['driverPhone'] = orderData['driverPhone'] as String? ??
          finalDmData['driverPhone'] as String?;
    }
    
    // Generate HTML string
    debugPrint('[DmPrintService] Generating HTML for print...');
    final htmlString = generateDmHtmlForPrint(
      dmData: finalDmData,
      dmSettings: viewPayload.dmSettings,
      paymentAccount: viewPayload.paymentAccount,
      logoBytes: viewPayload.logoBytes,
      qrCodeBytes: viewPayload.qrCodeBytes,
    );
    
    debugPrint('[DmPrintService] Print data prepared successfully (HTML length: ${htmlString.length} chars)');
    
    return PrintDataPayload(
      dmData: finalDmData,
      viewPayload: viewPayload,
      htmlString: htmlString,
    );
  }

  bool _needsOrderEnrichment(Map<String, dynamic> dmData) {
    final hasClientPhone = _hasNonEmptyString(
      dmData,
      ['clientPhone', 'clientPhoneNumber', 'customerNumber'],
    );
    final hasDriverName = _hasNonEmptyString(dmData, ['driverName']);
    final hasDriverPhone = _hasNonEmptyString(dmData, ['driverPhone', 'driverPhoneNumber']);

    return !hasClientPhone || !hasDriverName || !hasDriverPhone;
  }

  bool _hasNonEmptyString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  /// Fetch related order data from SCH_ORDERS collection
  Future<Map<String, dynamic>?> _fetchRelatedOrder(String orderId, String orgId) async {
    try {
      final orderQuery = FirebaseFirestore.instance
          .collection('SCH_ORDERS')
          .where('orderID', isEqualTo: orderId)
          .where('orgID', isEqualTo: orgId)
          .limit(1);
      
      final orderSnap = await orderQuery.get();
      
      if (orderSnap.docs.isNotEmpty) {
        final orderData = orderSnap.docs.first.data();
        // Convert Firestore Timestamp to Map format
        final convertedData = <String, dynamic>{};
        orderData.forEach((key, value) {
          if (value is Timestamp) {
            convertedData[key] = {
              '_seconds': value.seconds,
              '_nanoseconds': value.nanoseconds,
            };
          } else {
            convertedData[key] = value;
          }
        });
        return convertedData;
      }
      return null;
    } catch (e) {
      debugPrint('[DmPrintService] Error fetching related order: $e');
      // Silently fail - order data is optional
      return null;
    }
  }

  /// Store print data in sessionStorage for instant print flow
  /// Recursively convert all Timestamp objects to ISO8601 strings
  dynamic _sanitizeTimestamps(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k, _sanitizeTimestamps(v)));
    } else if (value is List) {
      return value.map(_sanitizeTimestamps).toList();
    } else if (value is Timestamp) {
      return value.toDate().toIso8601String();
    } else {
      return value;
    }
  }

  void storePrintDataInSession({
    required int dmNumber,
    required Map<String, dynamic> dmData,
    required DmViewPayload viewPayload,
    required String htmlString,
  }) {
    try {
      final payload = PrintDataPayload(
        dmData: dmData,
        viewPayload: viewPayload,
        htmlString: htmlString,
      );
      // Sanitize all Timestamps before encoding
      final jsonData = _sanitizeTimestamps(payload.toJson());
      final jsonString = jsonEncode(jsonData);
      final storageKey = 'temp_print_data_$dmNumber';
      html.window.sessionStorage[storageKey] = jsonString;
      debugPrint('[DmPrintService] Stored print data in sessionStorage with key: $storageKey (size: ${jsonString.length} bytes)');
    } catch (e) {
      debugPrint('[DmPrintService] ERROR storing print data in sessionStorage: $e');
      // Don't throw - sessionStorage failure should fall back to Firestore fetch
    }
  }

  /// Retrieve print data from sessionStorage
  PrintDataPayload? getPrintDataFromSession(int dmNumber) {
    try {
      final storageKey = 'temp_print_data_$dmNumber';
      final jsonString = html.window.sessionStorage[storageKey];
      
      if (jsonString == null || jsonString.isEmpty) {
        debugPrint('[DmPrintService] No cached print data found in sessionStorage for DM $dmNumber');
        return null;
      }
      
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      final payload = PrintDataPayload.fromJson(jsonData);
      
      if (payload != null) {
        debugPrint('[DmPrintService] Retrieved print data from sessionStorage for DM $dmNumber');
        // Clean up after retrieval (one-time use)
        html.window.sessionStorage.remove(storageKey);
      } else {
        debugPrint('[DmPrintService] Failed to parse cached print data from sessionStorage');
      }
      
      return payload;
    } catch (e) {
      debugPrint('[DmPrintService] ERROR retrieving print data from sessionStorage: $e');
      return null;
    }
  }

  /// Unified print flow: fetch data, generate HTML, store in sessionStorage, then open window
  /// This enables instant print dialog when PrintDMPage loads (no double Firestore fetch)
  Future<void> printDeliveryMemo(int dmNumber) async {
    try {
      debugPrint('[DmPrintService] Starting unified print flow for DM $dmNumber');
      
      // Prepare all print data (fetch DM, load view payload, generate HTML)
      final printData = await preparePrintData(dmNumber: dmNumber);
      
      // Store in sessionStorage for instant access in PrintDMPage
      storePrintDataInSession(
        dmNumber: dmNumber,
        dmData: printData.dmData,
        viewPayload: printData.viewPayload,
        htmlString: printData.htmlString,
      );
      
      // Open print window - PrintDMPage will use cached data from sessionStorage
      // Use explicit size + position + window-only features so browser opens a popup
      // instead of a new tab (especially in fullscreen).
      final url = '/print-dm/$dmNumber';
      debugPrint('[DmPrintService] Opening print window for DM $dmNumber at URL: $url');
      
      const width = 900;
      const height = 700;
      // Center on screen when possible; fallback left/top for popup
      final left = (html.window.outerWidth - width) ~/ 2;
      final top = (html.window.outerHeight - height) ~/ 2;
      final features = 'width=$width,height=$height,'
          'left=${left > 0 ? left : 100},top=${top > 0 ? top : 100},'
          'scrollbars=yes,resizable=yes,'
          'location=no,menubar=no,toolbar=no,status=no';
      
      final printWindow = html.window.open(
        url,
        'operon_print_dm',
        features,
      );
      // ignore: unnecessary_null_comparison -- browsers can return null when popup is blocked
      if (printWindow == null) {
        print('[DmPrintService] ERROR: Popup blocked');
        throw Exception('Popup blocked. Please allow popups for this site to print delivery memos.');
      }
      
      print('[DmPrintService] Print window opened successfully');
    } catch (e, stackTrace) {
      print('[DmPrintService] ERROR in print flow: $e');
      print('[DmPrintService] Stack trace: $stackTrace');
      throw Exception('Failed to prepare print: $e');
    }
  }

}
