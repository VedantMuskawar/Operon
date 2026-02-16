import 'package:operon_driver_android/data/services/app_update_service.dart';

/// Base class for app update states
abstract class AppUpdateState {
  const AppUpdateState();
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
}

/// Update is being downloaded
class AppUpdateDownloadingState extends AppUpdateState {
  final int progress; // 0-100
  final String downloadUrl;

  const AppUpdateDownloadingState({
    required this.progress,
    required this.downloadUrl,
  });
}

/// Error occurred during update check
class AppUpdateErrorState extends AppUpdateState {
  final String message;

  const AppUpdateErrorState(this.message);
}
