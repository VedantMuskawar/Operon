import 'dart:async';

import 'package:core_bloc/core_bloc.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'wage_settings_state.dart';

class WageSettingsCubit extends Cubit<WageSettingsState> {
  WageSettingsCubit({
    required WageSettingsRepository repository,
    required String organizationId,
  })  : _repository = repository,
        _organizationId = organizationId,
        super(const WageSettingsState());

  final WageSettingsRepository _repository;
  final String _organizationId;
  StreamSubscription<WageSettings?>? _settingsSubscription;

  @override
  Future<void> close() {
    _settingsSubscription?.cancel();
    return super.close();
  }

  /// Load wage settings
  Future<void> loadSettings() async {
    emit(state.copyWith(status: ViewStatus.loading));
    try {
      final settings = await _repository.fetchWageSettings(_organizationId);
      emit(state.copyWith(
        status: ViewStatus.success,
        settings: settings,
        message: null,
      ));
    } catch (e, stackTrace) {
      debugPrint('[WageSettingsCubit] Error loading settings: $e');
      debugPrint('[WageSettingsCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to load wage settings: ${e.toString()}',
      ));
    }
  }

  /// Watch settings stream for real-time updates
  void watchSettings() {
    _settingsSubscription?.cancel();
    _settingsSubscription = _repository.watchWageSettings(_organizationId).listen(
      (settings) {
        emit(state.copyWith(
          status: ViewStatus.success,
          settings: settings,
          message: null,
        ));
      },
      onError: (error) {
        debugPrint('[WageSettingsCubit] Error in settings stream: $error');
        emit(state.copyWith(
          status: ViewStatus.failure,
          message: 'Failed to load wage settings: ${error.toString()}',
        ));
      },
    );
  }

  /// Update wage settings
  Future<void> updateSettings(WageSettings settings) async {
    emit(state.copyWith(status: ViewStatus.loading));
    try {
      await _repository.updateWageSettings(_organizationId, settings);
      emit(state.copyWith(
        status: ViewStatus.success,
        settings: settings,
        message: null,
      ));
    } catch (e, stackTrace) {
      debugPrint('[WageSettingsCubit] Error updating settings: $e');
      debugPrint('[WageSettingsCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to update wage settings: ${e.toString()}',
      ));
      rethrow;
    }
  }

  /// Toggle wage settings enabled state
  Future<void> toggleEnabled(bool enabled) async {
    final currentSettings = state.settings;
    if (currentSettings == null) {
      // Create new settings if none exist
      final newSettings = WageSettings(
        organizationId: _organizationId,
        enabled: enabled,
        calculationMethods: const {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await updateSettings(newSettings);
      return;
    }

    final updatedSettings = currentSettings.copyWith(
      enabled: enabled,
      updatedAt: DateTime.now(),
    );
    await updateSettings(updatedSettings);
  }

  /// Add a new wage calculation method
  Future<void> addWageMethod(WageCalculationMethod method) async {
    final currentSettings = state.settings;
    if (currentSettings == null) {
      final newSettings = WageSettings(
        organizationId: _organizationId,
        enabled: true,
        calculationMethods: {method.methodId: method},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await updateSettings(newSettings);
      return;
    }

    final updatedMethods = Map<String, WageCalculationMethod>.from(
      currentSettings.calculationMethods,
    );
    updatedMethods[method.methodId] = method;

    final updatedSettings = currentSettings.copyWith(
      calculationMethods: updatedMethods,
      updatedAt: DateTime.now(),
    );
    await updateSettings(updatedSettings);
  }

  /// Update an existing wage calculation method
  Future<void> updateWageMethod(WageCalculationMethod method) async {
    final currentSettings = state.settings;
    if (currentSettings == null) {
      throw Exception('Cannot update method: settings not loaded');
    }

    final updatedMethods = Map<String, WageCalculationMethod>.from(
      currentSettings.calculationMethods,
    );
    updatedMethods[method.methodId] = method;

    final updatedSettings = currentSettings.copyWith(
      calculationMethods: updatedMethods,
      updatedAt: DateTime.now(),
    );
    await updateSettings(updatedSettings);
  }

  /// Delete a wage calculation method
  Future<void> deleteWageMethod(String methodId) async {
    final currentSettings = state.settings;
    if (currentSettings == null) {
      throw Exception('Cannot delete method: settings not loaded');
    }

    final updatedMethods = Map<String, WageCalculationMethod>.from(
      currentSettings.calculationMethods,
    );
    updatedMethods.remove(methodId);

    final updatedSettings = currentSettings.copyWith(
      calculationMethods: updatedMethods,
      updatedAt: DateTime.now(),
    );
    await updateSettings(updatedSettings);
  }

  /// Toggle enabled state of a specific wage method
  Future<void> toggleWageMethodStatus(String methodId, bool enabled) async {
    final currentSettings = state.settings;
    if (currentSettings == null) {
      throw Exception('Cannot toggle method: settings not loaded');
    }

    final method = currentSettings.calculationMethods[methodId];
    if (method == null) {
      throw Exception('Method not found: $methodId');
    }

    final updatedMethod = method.copyWith(
      enabled: enabled,
      updatedAt: DateTime.now(),
    );

    await updateWageMethod(updatedMethod);
  }
}

