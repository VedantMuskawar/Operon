import 'package:equatable/equatable.dart';
import '../../../../core/models/superadmin_config.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

class LoadSettings extends SettingsEvent {
  const LoadSettings();
}

class UpdateAppPreferences extends SettingsEvent {
  final Map<String, dynamic> preferences;

  const UpdateAppPreferences(this.preferences);

  @override
  List<Object?> get props => [preferences];
}

class UpdateSystemConfig extends SettingsEvent {
  final SuperAdminConfig config;

  const UpdateSystemConfig(this.config);

  @override
  List<Object?> get props => [config];
}

class UpdateNotificationSettings extends SettingsEvent {
  final Map<String, dynamic> notificationSettings;

  const UpdateNotificationSettings(this.notificationSettings);

  @override
  List<Object?> get props => [notificationSettings];
}

class UpdateSecuritySettings extends SettingsEvent {
  final Map<String, dynamic> securitySettings;

  const UpdateSecuritySettings(this.securitySettings);

  @override
  List<Object?> get props => [securitySettings];
}

class ToggleMaintenanceMode extends SettingsEvent {
  final bool enabled;

  const ToggleMaintenanceMode(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

class UpdateAllowedDomains extends SettingsEvent {
  final List<String> domains;

  const UpdateAllowedDomains(this.domains);

  @override
  List<Object?> get props => [domains];
}
