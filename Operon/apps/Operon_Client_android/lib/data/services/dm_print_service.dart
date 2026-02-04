import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_models/core_models.dart';
import 'package:core_utils/core_utils.dart' as pdf_template;
import 'package:dash_mobile/data/repositories/dm_settings_repository.dart';
import 'package:dash_mobile/data/repositories/payment_accounts_repository.dart';
import 'package:dash_mobile/data/services/qr_code_service.dart';
import 'package:dash_mobile/domain/entities/payment_account.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
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
    final items = itemsData is List
        ? itemsData
        : (itemsData != null ? [itemsData] : []);

    var tripPricingData = tripData['tripPricing'] as Map<String, dynamic>?;
    if (tripPricingData == null) {
      tripPricingData = <String, dynamic>{};
      if (tripData['total'] != null) tripPricingData['total'] = tripData['total'];
      if (tripData['subtotal'] != null) tripPricingData['subtotal'] = tripData['subtotal'];
      if (tripPricingData['total'] == null && items.isNotEmpty) {
        double calculatedTotal = 0.0;
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            final quantity = (item['fixedQuantityPerTrip'] as num?)?.toDouble() ??
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
      if (tripData['region'] != null) deliveryZone['region'] = tripData['region'];
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
    final dmSettings = await _dmSettingsRepository.fetchDmSettings(organizationId);
    if (dmSettings == null) {
      throw Exception('DM Settings not found. Please configure DM Settings first.');
    }

    Map<String, dynamic>? paymentAccount;
    Uint8List? qrCodeBytes;
    final showQrCode = dmSettings.paymentDisplay == DmPaymentDisplay.qrCode;

    final accounts = await _paymentAccountsRepository.fetchAccounts(organizationId);

    if (accounts.isNotEmpty) {
      PaymentAccount? selectedAccount;
      if (showQrCode) {
        try {
          selectedAccount = accounts.firstWhere(
            (acc) => acc.qrCodeImageUrl != null && acc.qrCodeImageUrl!.isNotEmpty,
          );
        } catch (e) {
          try {
            selectedAccount = accounts.firstWhere((acc) => acc.isPrimary);
          } catch (e) {
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
            qrCodeBytes =
                await _qrCodeService.generateQrCodeImage(selectedAccount.upiQrData!);
          } catch (e) {}
        } else if ((qrCodeBytes == null || qrCodeBytes.isEmpty) &&
            selectedAccount.upiId != null &&
            selectedAccount.upiId!.isNotEmpty) {
          try {
            final upiPaymentString =
                'upi://pay?pa=${selectedAccount.upiId}&pn=${Uri.encodeComponent(selectedAccount.name)}&cu=INR';
            qrCodeBytes =
                await _qrCodeService.generateQrCodeImage(upiPaymentString);
          } catch (e) {}
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
