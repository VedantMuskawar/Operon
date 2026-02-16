import 'package:equatable/equatable.dart';

/// Base class for app update events
abstract class AppUpdateEvent extends Equatable {
  const AppUpdateEvent();

  @override
  List<Object?> get props => [];
}

/// Event to trigger checking for updates
class CheckUpdateEvent extends AppUpdateEvent {
  const CheckUpdateEvent();
}

/// Event when download starts
class UpdateDownloadStartedEvent extends AppUpdateEvent {
  const UpdateDownloadStartedEvent();
}

/// Event when user dismisses update dialog (for non-mandatory updates)
class UpdateDismissedEvent extends AppUpdateEvent {
  const UpdateDismissedEvent();
}
