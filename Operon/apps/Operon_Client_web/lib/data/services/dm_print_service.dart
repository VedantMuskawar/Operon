import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_models/core_models.dart';
import 'package:core_utils/core_utils.dart' as pdf_template;
import 'package:dash_web/data/repositories/dm_settings_repository.dart';
import 'package:dash_web/data/repositories/payment_accounts_repository.dart';
import 'package:dash_web/data/services/qr_code_service.dart';
import 'package:dash_web/domain/entities/payment_account.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';

// Export QrCodeService for use in print service
export 'package:dash_web/data/services/qr_code_service.dart' show QrCodeService;

/// Service for printing Delivery Memos (DM)
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
  Future<Map<String, dynamic>?> fetchDmByNumberOrId({
    required String organizationId,
    int? dmNumber,
    String? dmId,
    Map<String, dynamic>? tripData,
  }) async {
    try {
      Query queryRef = FirebaseFirestore.instance
          .collection('DELIVERY_MEMOS')
          .where('organizationId', isEqualTo: organizationId);

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

  /// Load image bytes from URL (Firebase Storage or HTTP)
  Future<Uint8List?> loadImageBytes(String? url) async {
    if (url == null || url.isEmpty) return null;

    try {
      if (url.startsWith('gs://') || url.contains('firebase')) {
        // Firebase Storage URL
        final ref = _storage.refFromURL(url);
        return await ref.getData();
      } else {
        // HTTP/HTTPS URL
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          return response.bodyBytes;
        }
      }
    } catch (e) {
      // Silently fail - images are optional
      return null;
    }

    return null;
  }

  /// Generate PDF bytes (used for auto-generation in dialog)
  Future<Uint8List> generatePdfBytes({
    required String organizationId,
    required Map<String, dynamic> dmData,
  }) async {
    try {
      // Load DM Settings (includes print preferences)
      final dmSettings = await _dmSettingsRepository.fetchDmSettings(organizationId);
      if (dmSettings == null) {
        throw Exception('DM Settings not found. Please configure DM Settings first.');
      }

      // Load Payment Account based on DM Settings preference
      Map<String, dynamic>? paymentAccount;
      Uint8List? qrCodeBytes;

      final showQrCode = dmSettings.paymentDisplay == DmPaymentDisplay.qrCode;

      // Fetch payment accounts to find one with QR or bank details
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
          
          // Load QR code image - try multiple sources
          if (selectedAccount.qrCodeImageUrl != null && selectedAccount.qrCodeImageUrl!.isNotEmpty) {
            try {
              qrCodeBytes = await loadImageBytes(selectedAccount.qrCodeImageUrl);
              // If loading failed, try generating from UPI data
              if (qrCodeBytes == null || qrCodeBytes.isEmpty) {
                throw Exception('QR image loading failed');
              }
            } catch (e) {
              // Fall through to generate from UPI data
              qrCodeBytes = null;
            }
          }
          
          // Try to generate QR code from UPI data if image not loaded
          if ((qrCodeBytes == null || qrCodeBytes.isEmpty)) {
            if (selectedAccount.upiQrData != null && selectedAccount.upiQrData!.isNotEmpty) {
              // Generate QR code from UPI QR data
              try {
                qrCodeBytes = await _qrCodeService.generateQrCodeImage(selectedAccount.upiQrData!);
              } catch (e) {
                // If generation fails, continue without QR code
              }
            } else if (selectedAccount.upiId != null && selectedAccount.upiId!.isNotEmpty) {
              // Generate QR code from UPI ID if UPI QR data not available
              try {
                // Format UPI ID as UPI payment string
                final upiPaymentString = 'upi://pay?pa=${selectedAccount.upiId}&pn=${Uri.encodeComponent(selectedAccount.name)}&cu=INR';
                qrCodeBytes = await _qrCodeService.generateQrCodeImage(upiPaymentString);
              } catch (e) {
                // If generation fails, continue without QR code
              }
            }
          }
        } else {
          try {
            selectedAccount = accounts.firstWhere(
              (acc) => (acc.accountNumber != null && acc.accountNumber!.isNotEmpty) ||
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

        // selectedAccount is guaranteed to be non-null since accounts.isNotEmpty
        paymentAccount = {
          'name': selectedAccount.name,
          'accountNumber': selectedAccount.accountNumber,
          'ifscCode': selectedAccount.ifscCode,
          'upiId': selectedAccount.upiId,
          'qrCodeImageUrl': selectedAccount.qrCodeImageUrl,
        };
      }

      // Load logo image
      final logoBytes = await loadImageBytes(dmSettings.header.logoImageUrl);

      // Generate PDF using preferences from DM Settings
      // Load watermark image (optional - for custom templates)
      // Watermark path can be stored in org settings or default location
      Uint8List? watermarkBytes;
      try {
        // Try to load watermark from Firebase Storage if available
        // For now, watermark is optional - custom templates will work without it
        // Feature planned: Add watermark URL configuration to DM settings or organization settings
      } catch (e) {
        // Watermark is optional, continue without it
      }

      // Use PDF template generator from core_utils. For custom templates
      // (e.g. Lakshmee), dmData is converted to structured DmPrintData inside.
      final pdfBytes = await pdf_template.generateDmPdf(
        dmData: dmData,
        dmSettings: dmSettings,
        paymentAccount: paymentAccount,
        logoBytes: logoBytes,
        qrCodeBytes: qrCodeBytes,
        watermarkBytes: watermarkBytes,
      );

      return pdfBytes;
    } catch (e) {
      throw Exception('Failed to generate PDF: $e');
    }
  }

  /// Print PDF from bytes
  Future<void> printPdfBytes({
    required Uint8List pdfBytes,
  }) async {
    try {
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
      );
    } catch (e) {
      throw Exception('Failed to print PDF: $e');
    }
  }

  /// Save PDF from bytes
  Future<void> savePdfBytes({
    required Uint8List pdfBytes,
    required String fileName,
  }) async {
    try {
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: fileName,
      );
    } catch (e) {
      throw Exception('Failed to save PDF: $e');
    }
  }

  /// Generate preview content for DM (HTML for universal, PDF bytes for custom)
  /// Returns a map with 'type' ('html' or 'pdf') and the content
  Future<Map<String, dynamic>> generateDmPreviewContent({
    required String organizationId,
    required Map<String, dynamic> dmData,
  }) async {
    try {
      // Load DM Settings (includes print preferences)
      final dmSettings = await _dmSettingsRepository.fetchDmSettings(organizationId);
      if (dmSettings == null) {
        throw Exception('DM Settings not found. Please configure DM Settings first.');
      }

      // Check if custom template is used
      if (dmSettings.templateType == DmTemplateType.custom && 
          dmSettings.customTemplateId != null) {
        // Generate PDF for custom templates
        final pdfBytes = await generatePdfBytes(
          organizationId: organizationId,
          dmData: dmData,
        );
        
        return {
          'type': 'pdf',
          'content': pdfBytes,
        };
      }

      // Generate HTML for universal template
      // Load Payment Account based on DM Settings preference
      Map<String, dynamic>? paymentAccount;
      Uint8List? qrCodeBytes;

      final showQrCode = dmSettings.paymentDisplay == DmPaymentDisplay.qrCode;

      // Fetch payment accounts to find one with QR or bank details
      final accounts = await _paymentAccountsRepository.fetchAccounts(organizationId);
      
      if (accounts.isNotEmpty) {
        // Find primary account or first account with required details
        PaymentAccount? selectedAccount;
        
        if (showQrCode) {
          // Find account with QR code
          try {
            selectedAccount = accounts.firstWhere(
              (acc) => acc.qrCodeImageUrl != null && acc.qrCodeImageUrl!.isNotEmpty,
            );
          } catch (e) {
            // Fallback to primary or first account
            try {
              selectedAccount = accounts.firstWhere((acc) => acc.isPrimary);
            } catch (e) {
              selectedAccount = accounts.first;
            }
          }
          
          // Load QR code image - try multiple sources
          if (selectedAccount.qrCodeImageUrl != null && selectedAccount.qrCodeImageUrl!.isNotEmpty) {
            try {
              qrCodeBytes = await loadImageBytes(selectedAccount.qrCodeImageUrl);
              // If loading failed, try generating from UPI data
              if (qrCodeBytes == null || qrCodeBytes.isEmpty) {
                throw Exception('QR image loading failed');
              }
            } catch (e) {
              // Fall through to generate from UPI data
              qrCodeBytes = null;
            }
          }
          
          // Try to generate QR code from UPI data if image not loaded
          if ((qrCodeBytes == null || qrCodeBytes.isEmpty)) {
            if (selectedAccount.upiQrData != null && selectedAccount.upiQrData!.isNotEmpty) {
              // Generate QR code from UPI QR data
              try {
                qrCodeBytes = await _qrCodeService.generateQrCodeImage(selectedAccount.upiQrData!);
              } catch (e) {
                // If generation fails, continue without QR code
              }
            } else if (selectedAccount.upiId != null && selectedAccount.upiId!.isNotEmpty) {
              // Generate QR code from UPI ID if UPI QR data not available
              try {
                // Format UPI ID as UPI payment string
                final upiPaymentString = 'upi://pay?pa=${selectedAccount.upiId}&pn=${Uri.encodeComponent(selectedAccount.name)}&cu=INR';
                qrCodeBytes = await _qrCodeService.generateQrCodeImage(upiPaymentString);
              } catch (e) {
                // If generation fails, continue without QR code
              }
            }
          }
        } else {
          // Find account with bank details
          try {
            selectedAccount = accounts.firstWhere(
              (acc) => (acc.accountNumber != null && acc.accountNumber!.isNotEmpty) ||
                       (acc.ifscCode != null && acc.ifscCode!.isNotEmpty),
            );
          } catch (e) {
            // Fallback to primary or first account
            try {
              selectedAccount = accounts.firstWhere((acc) => acc.isPrimary);
            } catch (e) {
              selectedAccount = accounts.first;
            }
          }
        }

        // selectedAccount will always be non-null here since accounts.isNotEmpty
        paymentAccount = {
          'name': selectedAccount.name,
          'accountNumber': selectedAccount.accountNumber,
          'ifscCode': selectedAccount.ifscCode,
          'upiId': selectedAccount.upiId,
          'qrCodeImageUrl': selectedAccount.qrCodeImageUrl,
        };
      }

      // Load logo image
      final logoBytes = await loadImageBytes(dmSettings.header.logoImageUrl);

      // Generate HTML string
      final htmlString = _generateDmHtml(
        dmData: dmData,
        dmSettings: dmSettings,
        paymentAccount: paymentAccount,
        logoBytes: logoBytes,
        qrCodeBytes: qrCodeBytes,
      );
      
      return {
        'type': 'html',
        'content': htmlString,
      };
    } catch (e) {
      throw Exception('Failed to generate DM preview: $e');
    }
  }

  /// Generate and print/save DM PDF
  /// Uses print preferences and template type (custom vs universal) from DM Settings
  Future<void> printDm({
    required String organizationId,
    required Map<String, dynamic> dmData,
  }) async {
    try {
      // Load DM Settings (includes print preferences and template type)
      final dmSettings = await _dmSettingsRepository.fetchDmSettings(organizationId);
      if (dmSettings == null) {
        throw Exception('DM Settings not found. Please configure DM Settings first.');
      }

      // Follow DM Settings template type: custom → PDF, universal → HTML
      if (dmSettings.templateType == DmTemplateType.custom &&
          dmSettings.customTemplateId != null) {
        final pdfBytes = await generatePdfBytes(
          organizationId: organizationId,
          dmData: dmData,
        );
        await printPdfBytes(pdfBytes: pdfBytes);
        return;
      }

      // Universal template: HTML path
      Map<String, dynamic>? paymentAccount;
      Uint8List? qrCodeBytes;

      final showQrCode = dmSettings.paymentDisplay == DmPaymentDisplay.qrCode;

      // Fetch payment accounts to find one with QR or bank details
      final accounts = await _paymentAccountsRepository.fetchAccounts(organizationId);
      
      if (accounts.isNotEmpty) {
        // Find primary account or first account with required details
        PaymentAccount? selectedAccount;
        
        if (showQrCode) {
          // Find account with QR code
          try {
            selectedAccount = accounts.firstWhere(
              (acc) => acc.qrCodeImageUrl != null && acc.qrCodeImageUrl!.isNotEmpty,
            );
          } catch (e) {
            // Fallback to primary or first account
            try {
              selectedAccount = accounts.firstWhere((acc) => acc.isPrimary);
            } catch (e) {
              selectedAccount = accounts.first;
            }
          }
          
          // Load QR code image - try multiple sources
          if (selectedAccount.qrCodeImageUrl != null && selectedAccount.qrCodeImageUrl!.isNotEmpty) {
            try {
              qrCodeBytes = await loadImageBytes(selectedAccount.qrCodeImageUrl);
              // If loading failed, try generating from UPI data
              if (qrCodeBytes == null || qrCodeBytes.isEmpty) {
                throw Exception('QR image loading failed');
              }
            } catch (e) {
              // Fall through to generate from UPI data
              qrCodeBytes = null;
            }
          }
          
          // Try to generate QR code from UPI data if image not loaded
          if ((qrCodeBytes == null || qrCodeBytes.isEmpty)) {
            if (selectedAccount.upiQrData != null && selectedAccount.upiQrData!.isNotEmpty) {
              // Generate QR code from UPI QR data
              try {
                qrCodeBytes = await _qrCodeService.generateQrCodeImage(selectedAccount.upiQrData!);
              } catch (e) {
                // If generation fails, continue without QR code
              }
            } else if (selectedAccount.upiId != null && selectedAccount.upiId!.isNotEmpty) {
              // Generate QR code from UPI ID if UPI QR data not available
              try {
                // Format UPI ID as UPI payment string
                final upiPaymentString = 'upi://pay?pa=${selectedAccount.upiId}&pn=${Uri.encodeComponent(selectedAccount.name)}&cu=INR';
                qrCodeBytes = await _qrCodeService.generateQrCodeImage(upiPaymentString);
              } catch (e) {
                // If generation fails, continue without QR code
              }
            }
          }
        } else {
          // Find account with bank details
          try {
            selectedAccount = accounts.firstWhere(
              (acc) => (acc.accountNumber != null && acc.accountNumber!.isNotEmpty) ||
                       (acc.ifscCode != null && acc.ifscCode!.isNotEmpty),
            );
          } catch (e) {
            // Fallback to primary or first account
            try {
              selectedAccount = accounts.firstWhere((acc) => acc.isPrimary);
            } catch (e) {
              selectedAccount = accounts.first;
            }
          }
        }

        // selectedAccount will always be non-null here since accounts.isNotEmpty
        paymentAccount = {
          'name': selectedAccount.name,
          'accountNumber': selectedAccount.accountNumber,
          'ifscCode': selectedAccount.ifscCode,
          'upiId': selectedAccount.upiId,
          'qrCodeImageUrl': selectedAccount.qrCodeImageUrl,
        };
      }

      // Load logo image
      final logoBytes = await loadImageBytes(dmSettings.header.logoImageUrl);

      // Generate HTML and print using browser's native print
      final htmlString = _generateDmHtml(
        dmData: dmData,
        dmSettings: dmSettings,
        paymentAccount: paymentAccount,
        logoBytes: logoBytes,
        qrCodeBytes: qrCodeBytes,
      );
      
      // Print HTML using browser's native print functionality
      _printHtml(htmlString);
    } catch (e) {
      throw Exception('Failed to print DM: $e');
    }
  }

  /// Generate and save DM PDF
  /// Uses print preferences and template type (custom vs universal) from DM Settings
  Future<void> saveDmPdf({
    required String organizationId,
    required Map<String, dynamic> dmData,
    required String fileName,
  }) async {
    try {
      // Load DM Settings (includes print preferences and template type)
      final dmSettings = await _dmSettingsRepository.fetchDmSettings(organizationId);
      if (dmSettings == null) {
        throw Exception('DM Settings not found. Please configure DM Settings first.');
      }

      // Follow DM Settings template type: custom → PDF, universal → HTML-to-PDF
      if (dmSettings.templateType == DmTemplateType.custom &&
          dmSettings.customTemplateId != null) {
        final pdfBytes = await generatePdfBytes(
          organizationId: organizationId,
          dmData: dmData,
        );
        await savePdfBytes(pdfBytes: pdfBytes, fileName: fileName);
        return;
      }

      // Universal template: HTML path
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
          
          if (selectedAccount.qrCodeImageUrl != null) {
            qrCodeBytes = await loadImageBytes(selectedAccount.qrCodeImageUrl);
          }
        } else {
          try {
            selectedAccount = accounts.firstWhere(
              (acc) => (acc.accountNumber != null && acc.accountNumber!.isNotEmpty) ||
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

      final htmlString = _generateDmHtml(
        dmData: dmData,
        dmSettings: dmSettings,
        paymentAccount: paymentAccount,
        logoBytes: logoBytes,
        qrCodeBytes: qrCodeBytes,
      );

      final pdfBytes = await _htmlToPdf(htmlString);

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: fileName,
      );
    } catch (e) {
      throw Exception('Failed to save DM PDF: $e');
    }
  }

  /// Generate DM PDF document from HTML
  /// Handles portrait orientation only
  Future<Uint8List> generateDmPdf({
    required Map<String, dynamic> dmData,
    required DmSettings dmSettings,
    Map<String, dynamic>? paymentAccount,
    Uint8List? logoBytes,
    Uint8List? qrCodeBytes,
  }) async {
    try {
      // Generate HTML
      final htmlString = _generateDmHtml(
        dmData: dmData,
        dmSettings: dmSettings,
        paymentAccount: paymentAccount,
        logoBytes: logoBytes,
        qrCodeBytes: qrCodeBytes,
      );

      // Convert HTML to PDF bytes
      return await _htmlToPdf(htmlString);
    } catch (e) {
      throw Exception('Failed to generate DM PDF: $e');
    }
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
    final clientPhoneRaw = dmData['clientPhone'] as String?;
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
  </style>
  <script>
    // Print function is triggered from Flutter modal, not auto on load
  </script>
</head>
<body>
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

  /// Print HTML using browser's native print functionality
  void _printHtml(String htmlString) {
    // Use Blob URL instead of data URI to avoid browser security restrictions
    // Create a Blob from HTML string
    final blob = html.Blob([htmlString], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    // Open in new window with Blob URL (allowed by browsers)
    // The HTML contains a script that auto-triggers print when page loads
    html.window.open(url, '_blank');
    
    // Clean up the blob URL after a delay
    Future.delayed(const Duration(seconds: 5), () {
      html.Url.revokeObjectUrl(url);
    });
  }

  /// Convert HTML to PDF bytes using html2pdf.js
  Future<Uint8List> _htmlToPdf(String htmlString) async {
    try {
      // Call the JavaScript helper function convertHtmlToPdfBlob
      // This function is defined in index.html and uses html2pdf.js
      // The function is attached to window, so we access it via window property
      final windowObj = js.context['window'];
      if (windowObj == null) {
        throw Exception('window object is not available');
      }
      final jsPromise = (windowObj as js.JsObject).callMethod('convertHtmlToPdfBlob', [htmlString]);
      
      // Convert JavaScript Promise to Dart Future using Completer
      final completer = Completer<html.Blob>();
      
      // Set up promise callbacks using JsFunction
      js.JsObject promise = jsPromise as js.JsObject;
      promise.callMethod('then', [
        js.JsFunction.withThis((_, blob) {
          completer.complete(blob as html.Blob);
        })
      ]);
      promise.callMethod('catch', [
        js.JsFunction.withThis((_, error) {
          completer.completeError(Exception('html2pdf.js error: $error'));
        })
      ]);
      
      // Wait for the blob
      final pdfBlob = await completer.future;
      
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
}
