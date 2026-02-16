abstract class AppUpdateEvent {
  const AppUpdateEvent();
}

/// Check for app update event
class CheckUpdateEvent extends AppUpdateEvent {
  const CheckUpdateEvent();
}

/// Update download started event
class UpdateDownloadStartedEvent extends AppUpdateEvent {
  const UpdateDownloadStartedEvent();
}

/// Update dismissed event
class UpdateDismissedEvent extends AppUpdateEvent {
  const UpdateDismissedEvent();
}
