import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_models/core_models.dart';
import 'package:core_utils/core_utils.dart';
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

  /// Fetch DM document by dmNumber or dmId
  Future<Map<String, dynamic>?> fetchDmByNumberOrId({
    required String organizationId,
    int? dmNumber,
    String? dmId,
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
        return null;
      }

      final snapshot = await queryRef.limit(1).get();
      if (snapshot.docs.isEmpty) {
        return null;
      }

      final doc = snapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>?;
      
      if (data == null) {
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
      return convertedData;
    } catch (e) {
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
      final pdfBytes = await generateDmPdf(
        dmData: dmData,
        dmSettings: dmSettings,
        paymentAccount: paymentAccount,
        logoBytes: logoBytes,
        qrCodeBytes: qrCodeBytes,
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

  /// Generate and print/save DM PDF
  /// Uses print preferences from DM Settings
  Future<void> printDm({
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

      // Generate PDF using preferences from DM Settings
      final pdfBytes = await generateDmPdf(
        dmData: dmData,
        dmSettings: dmSettings,
        paymentAccount: paymentAccount,
        logoBytes: logoBytes,
        qrCodeBytes: qrCodeBytes,
      );

      // Show print dialog
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
      );
    } catch (e) {
      throw Exception('Failed to print DM: $e');
    }
  }

  /// Generate and save DM PDF
  /// Uses print preferences from DM Settings
  Future<void> saveDmPdf({
    required String organizationId,
    required Map<String, dynamic> dmData,
    required String fileName,
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

      // Fetch payment accounts
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

      // Generate PDF using preferences from DM Settings
      final pdfBytes = await generateDmPdf(
        dmData: dmData,
        dmSettings: dmSettings,
        paymentAccount: paymentAccount,
        logoBytes: logoBytes,
        qrCodeBytes: qrCodeBytes,
      );

      // Share/save PDF
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: fileName,
      );
    } catch (e) {
      throw Exception('Failed to save DM PDF: $e');
    }
  }
}
