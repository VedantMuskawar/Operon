import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';
import 'package:core_utils/core_utils.dart' as pdf_template;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';

/// Helper for generating and printing/sharing DM PDF in the Driver app.
/// Uses DmSettings from Firestore; no payment accounts or QR (optional).
class DmPrintHelper {
  DmPrintHelper({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  static const String _deliveryMemosCollection = 'DELIVERY_MEMOS';

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

  Future<Map<String, dynamic>?> fetchDmByNumberOrId({
    required String organizationId,
    int? dmNumber,
    String? dmId,
    Map<String, dynamic>? tripData,
  }) async {
    try {
      Query<Map<String, dynamic>> queryRef = _firestore
          .collection(_deliveryMemosCollection)
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
          throw Exception('Failed to fetch DM: $e2');
        }
      }
      throw Exception('Failed to fetch DM: $e');
    }
  }

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

  Future<Uint8List> generatePdfBytes({
    required String organizationId,
    required Map<String, dynamic> dmData,
  }) async {
    final dataSource = DmSettingsDataSource(firestore: _firestore);
    final dmSettings = await dataSource.fetchDmSettings(organizationId);
    if (dmSettings == null) {
      throw Exception('DM Settings not found.');
    }

    final logoBytes = await loadImageBytes(dmSettings.header.logoImageUrl);

    final pdfBytes = await pdf_template.generateDmPdf(
      dmData: dmData,
      dmSettings: dmSettings,
      paymentAccount: null,
      logoBytes: logoBytes,
      qrCodeBytes: null,
      watermarkBytes: null,
    );

    return pdfBytes;
  }

  Future<void> printPdfBytes(Uint8List pdfBytes) async {
    await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
  }

  Future<void> sharePdfBytes({
    required Uint8List pdfBytes,
    required String fileName,
  }) async {
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: fileName,
    );
  }
}
