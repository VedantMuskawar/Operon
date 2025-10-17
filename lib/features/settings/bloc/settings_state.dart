import 'package:equatable/equatable.dart';
import '../../../../core/models/superadmin_config.dart';

abstract class SettingsState extends Equatable {
  const SettingsState();

  @override
  List<Object?> get props => [];
}

class SettingsLoading extends SettingsState {
  const SettingsLoading();
}

class SettingsLoaded extends SettingsState {
  final SuperAdminConfig config;
  final Map<String, dynamic> appPreferences;

  const SettingsLoaded({
    required this.config,
    required this.appPreferences,
  });

  @override
  List<Object?> get props => [config, appPreferences];
}

class SettingsUpdating extends SettingsState {
  const SettingsUpdating();
}

class SettingsError extends SettingsState {
  final String message;

  const SettingsError(this.message);

  @override
  List<Object?> get props => [message];
}

class SettingsUpdated extends SettingsState {
  final SuperAdminConfig config;
  final Map<String, dynamic> appPreferences;

  const SettingsUpdated({
    required this.config,
    required this.appPreferences,
  });

  @override
  List<Object?> get props => [config, appPreferences];
}
