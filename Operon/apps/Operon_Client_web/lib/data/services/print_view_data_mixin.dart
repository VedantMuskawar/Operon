import 'dart:typed_data';
import 'package:core_models/core_models.dart';
import 'package:dash_web/data/repositories/dm_settings_repository.dart';
import 'package:dash_web/data/repositories/payment_accounts_repository.dart';
import 'package:dash_web/data/services/qr_code_service.dart';
import 'package:dash_web/domain/entities/payment_account.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

/// Shared mixin for loading view data (Logo, DmHeaderSettings, Payment Account)
/// Used by both DM and Ledger print flows to prevent code duplication
mixin PrintViewDataMixin {
  DmSettingsRepository get dmSettingsRepository;
  PaymentAccountsRepository get paymentAccountsRepository;
  QrCodeService get qrCodeService;
  FirebaseStorage get storage;

  /// Session cache for logo bytes (key: logo URL)
  static final Map<String, Uint8List?> _logoCache = {};

  /// Session cache for QR code bytes (key: QR data/URL)
  static final Map<String, Uint8List?> _qrCodeCache = {};

  /// Load image bytes from URL (Firebase Storage or HTTP) with memoization
  Future<Uint8List?> loadImageBytes(String? url) async {
    if (url == null || url.isEmpty) return null;

    // Check cache first
    if (_logoCache.containsKey(url)) {
      return _logoCache[url];
    }

    try {
      Uint8List? bytes;
      if (url.startsWith('gs://') || url.contains('firebase')) {
        // Firebase Storage URL
        final ref = storage.refFromURL(url);
        bytes = await ref.getData();
      } else {
        // HTTP/HTTPS URL
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          bytes = response.bodyBytes;
        }
      }
      // Cache the result (even if null)
      _logoCache[url] = bytes;
      return bytes;
    } catch (e) {
      // Silently fail - images are optional
      _logoCache[url] = null;
      return null;
    }
  }

  /// Load DM settings for organization
  Future<DmSettings> loadDmSettings(String organizationId) async {
    final dmSettings = await dmSettingsRepository.fetchDmSettings(organizationId);
    if (dmSettings == null) {
      throw Exception('DM Settings not found. Please configure DM Settings first.');
    }
    return dmSettings;
  }

  /// Load payment account with QR code generation (with memoization)
  /// Returns a record: (paymentAccount, qrCodeBytes)
  Future<({Map<String, dynamic>? paymentAccount, Uint8List? qrCodeBytes})> loadPaymentAccountWithQr({
    required String organizationId,
    required DmSettings dmSettings,
  }) async {
    Map<String, dynamic>? paymentAccount;
    Uint8List? qrCodeBytes;
    final showQrCode = dmSettings.paymentDisplay == DmPaymentDisplay.qrCode;

    final accounts = await paymentAccountsRepository.fetchAccounts(organizationId);

    if (accounts.isEmpty) {
      return (paymentAccount: null, qrCodeBytes: null);
    }

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

      // Try to load QR code from URL first (with cache check)
      if (selectedAccount.qrCodeImageUrl != null &&
          selectedAccount.qrCodeImageUrl!.isNotEmpty) {
        final cacheKey = selectedAccount.qrCodeImageUrl!;
        if (_qrCodeCache.containsKey(cacheKey)) {
          qrCodeBytes = _qrCodeCache[cacheKey];
        } else {
          qrCodeBytes = await loadImageBytes(selectedAccount.qrCodeImageUrl);
          _qrCodeCache[cacheKey] = qrCodeBytes;
        }
      }

      // Generate QR code if not available from URL
      if ((qrCodeBytes == null || qrCodeBytes.isEmpty) &&
          selectedAccount.upiQrData != null &&
          selectedAccount.upiQrData!.isNotEmpty) {
        final cacheKey = 'upi_qr_${selectedAccount.upiQrData}';
        if (_qrCodeCache.containsKey(cacheKey)) {
          qrCodeBytes = _qrCodeCache[cacheKey];
        } else {
          try {
            qrCodeBytes = await qrCodeService.generateQrCodeImage(selectedAccount.upiQrData!);
            _qrCodeCache[cacheKey] = qrCodeBytes;
          } catch (e) {
            // continue without QR
            _qrCodeCache[cacheKey] = null;
          }
        }
      } else if ((qrCodeBytes == null || qrCodeBytes.isEmpty) &&
          selectedAccount.upiId != null &&
          selectedAccount.upiId!.isNotEmpty) {
        final upiPaymentString =
            'upi://pay?pa=${selectedAccount.upiId}&pn=${Uri.encodeComponent(selectedAccount.name)}&cu=INR';
        final cacheKey = 'upi_$upiPaymentString';
        if (_qrCodeCache.containsKey(cacheKey)) {
          qrCodeBytes = _qrCodeCache[cacheKey];
        } else {
          try {
            qrCodeBytes = await qrCodeService.generateQrCodeImage(upiPaymentString);
            _qrCodeCache[cacheKey] = qrCodeBytes;
          } catch (e) {
            // continue without QR
            _qrCodeCache[cacheKey] = null;
          }
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

    return (paymentAccount: paymentAccount, qrCodeBytes: qrCodeBytes);
  }

  /// Load payment account only (without QR code)
  Future<Map<String, dynamic>?> loadPaymentAccount({
    required String organizationId,
    required DmSettings dmSettings,
  }) async {
    final result = await loadPaymentAccountWithQr(
      organizationId: organizationId,
      dmSettings: dmSettings,
    );
    return result.paymentAccount;
  }

  /// Clear all caches (call on logout or when needed)
  static void clearCaches() {
    _logoCache.clear();
    _qrCodeCache.clear();
  }
}
