import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_web/data/repositories/dm_settings_repository.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DmSettingsState extends BaseState {
  const DmSettingsState({
    super.status = ViewStatus.initial,
    this.settings,
    this.message,
  }) : super(message: message);

  final DmSettings? settings;
  @override
  final String? message;

  @override
  DmSettingsState copyWith({
    ViewStatus? status,
    DmSettings? settings,
    String? message,
    bool clearMessage = false,
  }) {
    return DmSettingsState(
      status: status ?? this.status,
      settings: settings ?? this.settings,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

class DmSettingsCubit extends Cubit<DmSettingsState> {
  DmSettingsCubit({
    required DmSettingsRepository repository,
    required String orgId,
    required String userId,
    FirebaseStorage? storage,
  })  : _repository = repository,
        _orgId = orgId,
        _userId = userId,
        _storage = storage ?? FirebaseStorage.instance,
        super(const DmSettingsState()) {
    loadSettings();
  }

  final DmSettingsRepository _repository;
  final String _orgId;
  final String _userId;
  final FirebaseStorage _storage;

  Future<void> loadSettings() async {
    debugPrint('[DmSettingsCubit] loadSettings called for orgId: $_orgId');
    emit(state.copyWith(status: ViewStatus.loading, clearMessage: true));
    try {
      debugPrint('[DmSettingsCubit] Fetching settings from repository...');
      final settings = await _repository.fetchDmSettings(_orgId);
      debugPrint('[DmSettingsCubit] Settings fetched - hasSettings: ${settings != null}');
      emit(state.copyWith(
        status: ViewStatus.success,
        settings: settings,
      ));
      debugPrint('[DmSettingsCubit] State emitted with success status');
    } catch (error) {
      debugPrint('[DmSettingsCubit] Error loading settings: $error');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to load DM settings. Please try again.',
      ));
    }
  }

  Future<String?> uploadLogo(Uint8List imageBytes, String fileExtension) async {
    try {
      final extension = fileExtension.toLowerCase();
      if (!['png', 'jpg', 'jpeg'].contains(extension)) {
        throw Exception('Invalid file format. Only PNG, JPG, and JPEG are supported.');
      }

      final ref = _storage
          .ref()
          .child('organizations')
          .child(_orgId)
          .child('dm_settings')
          .child('logo.$extension');

      final uploadTask = ref.putData(
        imageBytes,
        SettableMetadata(
          contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
          cacheControl: 'public, max-age=31536000',
        ),
      );

      await uploadTask;
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload logo: $e');
    }
  }

  Future<void> deleteLogo() async {
    try {
      final currentSettings = state.settings;
      if (currentSettings?.header.logoImageUrl == null) {
        return;
      }

      // Extract filename from URL
      final url = currentSettings!.header.logoImageUrl!;
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      // Continue even if deletion fails - the URL in Firestore will be cleared
    }
  }

  Future<void> saveSettings({
    required String name,
    required String address,
    required String phone,
    String? gstNo,
    String? customText,
    String? logoImageUrl,
    DmPrintOrientation? printOrientation,
    DmPaymentDisplay? paymentDisplay,
    DmTemplateType? templateType,
    String? customTemplateId,
  }) async {
    emit(state.copyWith(status: ViewStatus.loading, clearMessage: true));
    try {
      final currentSettings = state.settings;

      final header = DmHeaderSettings(
        name: name,
        address: address,
        phone: phone,
        gstNo: gstNo?.trim().isEmpty == true ? null : gstNo?.trim(),
        logoImageUrl: logoImageUrl ?? currentSettings?.header.logoImageUrl,
      );

      final footer = DmFooterSettings(
        customText: customText?.trim().isEmpty == true ? null : customText?.trim(),
      );

      final template = templateType ?? currentSettings?.templateType ?? DmTemplateType.universal;
      final templateId = template == DmTemplateType.custom
          ? (customTemplateId?.trim().isEmpty == true ? null : customTemplateId?.trim())
          : null;

      final settings = DmSettings(
        organizationId: _orgId,
        header: header,
        footer: footer,
        updatedAt: DateTime.now(),
        updatedBy: _userId,
        printOrientation: printOrientation ?? currentSettings?.printOrientation ?? DmPrintOrientation.portrait,
        paymentDisplay: paymentDisplay ?? currentSettings?.paymentDisplay ?? DmPaymentDisplay.qrCode,
        templateType: template,
        customTemplateId: templateId,
      );

      await _repository.updateDmSettings(_orgId, settings);
      emit(state.copyWith(
        status: ViewStatus.success,
        settings: settings,
        message: 'DM settings saved successfully',
      ));
    } catch (error) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to save DM settings. Please try again.',
      ));
    }
  }

  Future<void> updatePrintPreferences({
    required DmPrintOrientation printOrientation,
    required DmPaymentDisplay paymentDisplay,
  }) async {
    emit(state.copyWith(status: ViewStatus.loading, clearMessage: true));
    try {
      final currentSettings = state.settings;
      if (currentSettings == null) {
        throw Exception('DM Settings not loaded');
      }

      final updatedSettings = currentSettings.copyWith(
        printOrientation: printOrientation,
        paymentDisplay: paymentDisplay,
        updatedAt: DateTime.now(),
        updatedBy: _userId,
      );

      await _repository.updateDmSettings(_orgId, updatedSettings);
      emit(state.copyWith(
        status: ViewStatus.success,
        settings: updatedSettings,
        message: 'Print preferences saved successfully',
      ));
    } catch (error) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to save print preferences. Please try again.',
      ));
    }
  }
}
