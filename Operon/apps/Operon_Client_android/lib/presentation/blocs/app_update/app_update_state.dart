import 'package:dash_mobile/data/services/app_update_service.dart';
import 'package:equatable/equatable.dart';

/// Base class for app update states
abstract class AppUpdateState extends Equatable {
  const AppUpdateState();

  @override
  List<Object?> get props => [];
}

/// Initial state - no update check performed yet
class AppUpdateInitialState extends AppUpdateState {
  const AppUpdateInitialState();
}

/// Update is being checked from server
class AppUpdateCheckingState extends AppUpdateState {
  const AppUpdateCheckingState();
}

/// No update available - app is up to date
class AppUpdateUnavailableState extends AppUpdateState {
  const AppUpdateUnavailableState();
}

/// Update is available and should be shown to user
class AppUpdateAvailableState extends AppUpdateState {
  final UpdateInfo updateInfo;

  const AppUpdateAvailableState(this.updateInfo);

  @override
  List<Object?> get props => [updateInfo];
}

/// Update is being downloaded
class AppUpdateDownloadingState extends AppUpdateState {
  final int progress; // 0-100
  final String downloadUrl;

  const AppUpdateDownloadingState({
    required this.progress,
    required this.downloadUrl,
  });

  @override
  List<Object?> get props => [progress, downloadUrl];
}

/// Error occurred during update check
class AppUpdateErrorState extends AppUpdateState {
  final String message;

  const AppUpdateErrorState(this.message);

  @override
  List<Object?> get props => [message];
}
