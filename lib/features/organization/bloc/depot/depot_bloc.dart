import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/depot_location.dart';
import '../../../../core/repositories/depot_repository.dart';
import 'depot_event.dart';
import 'depot_state.dart';

class DepotBloc extends Bloc<DepotEvent, DepotState> {
  DepotBloc({
    required DepotRepository depotRepository,
  })  : _depotRepository = depotRepository,
        super(DepotState.initial()) {
    on<LoadDepotLocation>(_onLoadDepotLocation);
    on<SaveDepotLocation>(_onSaveDepotLocation);
    on<ClearDepotStatus>(_onClearDepotStatus);
  }

  final DepotRepository _depotRepository;

  Future<void> _onLoadDepotLocation(
    LoadDepotLocation event,
    Emitter<DepotState> emit,
  ) async {
    emit(state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    ));

    try {
      final location = await _depotRepository.fetchPrimaryDepot(event.orgId);
      emit(state.copyWith(
        isLoading: false,
        overrideLocation: true,
        location: location,
      ));
    } catch (error) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: _stringifyError(error),
      ));
    }
  }

  Future<void> _onSaveDepotLocation(
    SaveDepotLocation event,
    Emitter<DepotState> emit,
  ) async {
    emit(state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    ));

    try {
      final now = DateTime.now();
      final existing = state.location;
      final depot = DepotLocation(
        depotId: existing?.depotId ?? 'primary',
        latitude: event.latitude,
        longitude: event.longitude,
        label: event.label,
        address: event.address,
        isPrimary: true,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );

      final saved = await _depotRepository.saveDepot(event.orgId, depot);

      emit(state.copyWith(
        isSaving: false,
        saveSuccess: true,
        overrideLocation: true,
        location: saved,
      ));
    } catch (error) {
      emit(state.copyWith(
        isSaving: false,
        errorMessage: _stringifyError(error),
      ));
    }
  }

  void _onClearDepotStatus(
    ClearDepotStatus event,
    Emitter<DepotState> emit,
  ) {
    emit(state.copyWith(
      clearError: true,
      clearSuccess: true,
    ));
  }

  String _stringifyError(Object error) {
    final message = error.toString();
    if (message.startsWith('Exception: ')) {
      return message.replaceFirst('Exception: ', '');
    }
    return message;
  }
}


