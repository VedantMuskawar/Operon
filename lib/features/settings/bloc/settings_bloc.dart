import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/repositories/config_repository.dart';
import '../../../../core/models/superadmin_config.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final ConfigRepository _configRepository;

  SettingsBloc({required ConfigRepository configRepository})
      : _configRepository = configRepository,
        super(const SettingsLoading()) {
    on<LoadSettings>(_onLoadSettings);
    on<UpdateAppPreferences>(_onUpdateAppPreferences);
    on<UpdateSystemConfig>(_onUpdateSystemConfig);
    on<UpdateNotificationSettings>(_onUpdateNotificationSettings);
    on<UpdateSecuritySettings>(_onUpdateSecuritySettings);
    on<ToggleMaintenanceMode>(_onToggleMaintenanceMode);
    on<UpdateAllowedDomains>(_onUpdateAllowedDomains);
  }

  Future<void> _onLoadSettings(LoadSettings event, Emitter<SettingsState> emit) async {
    try {
      emit(const SettingsLoading());
      
      final config = await _configRepository.getSuperAdminConfig();
      
      // Default app preferences (could be stored in local storage or user preferences)
      final appPreferences = {
        'displayDensity': 'comfortable', // compact, comfortable, spacious
        'language': 'en',
        'timezone': 'UTC',
        'theme': 'dark',
      };

      emit(SettingsLoaded(config: config, appPreferences: appPreferences));
    } catch (e) {
      emit(SettingsError('Failed to load settings: $e'));
    }
  }

  Future<void> _onUpdateAppPreferences(
    UpdateAppPreferences event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoaded) return;

    try {
      emit(const SettingsUpdating());
      
      final currentState = state as SettingsLoaded;
      final updatedPreferences = {...currentState.appPreferences, ...event.preferences};

      // Here you would typically save app preferences to local storage
      // For now, we'll just emit the updated state
      emit(SettingsUpdated(
        config: currentState.config,
        appPreferences: updatedPreferences,
      ));
    } catch (e) {
      emit(SettingsError('Failed to update app preferences: $e'));
    }
  }

  Future<void> _onUpdateSystemConfig(
    UpdateSystemConfig event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoaded) return;

    try {
      emit(const SettingsUpdating());
      
      await _configRepository.updateSuperAdminConfig(event.config);
      final currentState = state as SettingsLoaded;

      emit(SettingsUpdated(
        config: event.config,
        appPreferences: currentState.appPreferences,
      ));
    } catch (e) {
      emit(SettingsError('Failed to update system config: $e'));
    }
  }

  Future<void> _onUpdateNotificationSettings(
    UpdateNotificationSettings event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoaded) return;

    try {
      emit(const SettingsUpdating());
      
      final currentState = state as SettingsLoaded;
      final updatedConfig = currentState.config.copyWith(
        notificationSettings: event.notificationSettings,
      );

      await _configRepository.updateSuperAdminConfig(updatedConfig);

      emit(SettingsUpdated(
        config: updatedConfig,
        appPreferences: currentState.appPreferences,
      ));
    } catch (e) {
      emit(SettingsError('Failed to update notification settings: $e'));
    }
  }

  Future<void> _onUpdateSecuritySettings(
    UpdateSecuritySettings event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoaded) return;

    try {
      emit(const SettingsUpdating());
      
      final currentState = state as SettingsLoaded;
      final updatedConfig = currentState.config.copyWith(
        securitySettings: event.securitySettings,
      );

      await _configRepository.updateSuperAdminConfig(updatedConfig);

      emit(SettingsUpdated(
        config: updatedConfig,
        appPreferences: currentState.appPreferences,
      ));
    } catch (e) {
      emit(SettingsError('Failed to update security settings: $e'));
    }
  }

  Future<void> _onToggleMaintenanceMode(
    ToggleMaintenanceMode event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoaded) return;

    try {
      emit(const SettingsUpdating());
      
      final currentState = state as SettingsLoaded;
      final updatedConfig = currentState.config.copyWith(
        maintenanceMode: event.enabled,
      );

      await _configRepository.updateSuperAdminConfig(updatedConfig);

      emit(SettingsUpdated(
        config: updatedConfig,
        appPreferences: currentState.appPreferences,
      ));
    } catch (e) {
      emit(SettingsError('Failed to toggle maintenance mode: $e'));
    }
  }

  Future<void> _onUpdateAllowedDomains(
    UpdateAllowedDomains event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoaded) return;

    try {
      emit(const SettingsUpdating());
      
      final currentState = state as SettingsLoaded;
      final updatedConfig = currentState.config.copyWith(
        allowedDomains: event.domains,
      );

      await _configRepository.updateSuperAdminConfig(updatedConfig);

      emit(SettingsUpdated(
        config: updatedConfig,
        appPreferences: currentState.appPreferences,
      ));
    } catch (e) {
      emit(SettingsError('Failed to update allowed domains: $e'));
    }
  }
}
