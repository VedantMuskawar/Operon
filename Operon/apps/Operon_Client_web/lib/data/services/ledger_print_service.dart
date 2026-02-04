import 'dart:typed_data';
import 'package:core_models/core_models.dart';
import 'package:dash_web/data/repositories/dm_settings_repository.dart';
import 'package:dash_web/data/repositories/payment_accounts_repository.dart';
import 'package:dash_web/data/services/qr_code_service.dart';
import 'package:dash_web/data/services/print_view_data_mixin.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Payload for Ledger view (no PDF). Same data source as PDF generation.
class LedgerViewPayload {
  const LedgerViewPayload({
    required this.dmSettings,
    this.logoBytes,
  });

  final DmSettings dmSettings;
  final Uint8List? logoBytes;
}

/// Service for loading ledger view data (shared with DM flow via mixin)
class LedgerPrintService with PrintViewDataMixin {
  LedgerPrintService({
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

  /// Load view data only (no PDF). Use for "view first" UI; same data as PDF.
  Future<LedgerViewPayload> loadLedgerViewData({
    required String organizationId,
  }) async {
    final dmSettings = await loadDmSettings(organizationId);
    final logoBytes = await loadImageBytes(dmSettings.header.logoImageUrl);

    return LedgerViewPayload(
      dmSettings: dmSettings,
      logoBytes: logoBytes,
    );
  }
}
