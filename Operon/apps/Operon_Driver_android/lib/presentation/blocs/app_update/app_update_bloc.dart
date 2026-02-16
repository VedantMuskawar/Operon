import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:operon_driver_android/data/services/app_update_service.dart';
import 'package:operon_driver_android/presentation/blocs/app_update/app_update_event.dart';
import 'package:operon_driver_android/presentation/blocs/app_update/app_update_state.dart';

/// Bloc for managing app updates
/// Handles checking for updates and maintaining update state
class AppUpdateBloc extends Bloc<AppUpdateEvent, AppUpdateState> {
  final AppUpdateService updateService;

  AppUpdateBloc({
    required this.updateService,
  }) : super(const AppUpdateInitialState()) {
    on<CheckUpdateEvent>(_onCheckUpdate);
    on<UpdateDownloadStartedEvent>(_onDownloadStarted);
    on<UpdateDismissedEvent>(_onUpdateDismissed);
  }

  /// Handle update check event
  Future<void> _onCheckUpdate(
    CheckUpdateEvent event,
    Emitter<AppUpdateState> emit,
  ) async {
    try {
      emit(const AppUpdateCheckingState());

      final updateInfo = await updateService.checkForUpdate();

      if (updateInfo != null) {
        emit(AppUpdateAvailableState(updateInfo));
      } else {
        emit(const AppUpdateUnavailableState());
      }
    } catch (e) {
      emit(AppUpdateErrorState('Failed to check for updates: $e'));
    }
  }

  /// Handle download started event
  Future<void> _onDownloadStarted(
    UpdateDownloadStartedEvent event,
    Emitter<AppUpdateState> emit,
  ) async {
    if (state is AppUpdateAvailableState) {
      final updateInfo = (state as AppUpdateAvailableState).updateInfo;
      emit(AppUpdateDownloadingState(
        progress: 0,
        downloadUrl: updateInfo.downloadUrl,
      ));
    }
  }

  /// Handle update dismissed event
  Future<void> _onUpdateDismissed(
    UpdateDismissedEvent event,
    Emitter<AppUpdateState> emit,
  ) async {
    emit(const AppUpdateUnavailableState());
  }
}
