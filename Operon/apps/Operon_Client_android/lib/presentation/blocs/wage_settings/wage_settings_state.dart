import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';

class WageSettingsState extends BaseState {
  const WageSettingsState({
    super.status = ViewStatus.initial,
    this.settings,
    super.message,
  });

  final WageSettings? settings;

  @override
  WageSettingsState copyWith({
    ViewStatus? status,
    WageSettings? settings,
    String? message,
  }) {
    return WageSettingsState(
      status: status ?? this.status,
      settings: settings ?? this.settings,
      message: message,
    );
  }
}

