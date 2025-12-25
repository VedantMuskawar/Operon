import 'dart:async';

import 'package:core_bloc/core_bloc.dart';
import 'package:dash_superadmin/data/repositories/organization_repository.dart';
import 'package:dash_superadmin/domain/entities/organization_summary.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'organization_list_event.dart';
part 'organization_list_state.dart';

class OrganizationListBloc
    extends BaseBloc<OrganizationListEvent, OrganizationListState> {
  OrganizationListBloc({
    required OrganizationRepository repository,
  })  : _repository = repository,
        super(const OrganizationListState()) {
    on<OrganizationListWatchRequested>(_onWatchRequested);
    on<_OrganizationListUpdated>(_onOrganizationsUpdated);
    on<_OrganizationListError>(_onError);
    on<OrganizationListDeleteRequested>(_onDeleteRequested);
    on<OrganizationListUpdateRequested>(_onUpdateRequested);
  }

  final OrganizationRepository _repository;
  StreamSubscription<List<OrganizationSummary>>? _subscription;

  Future<void> _onWatchRequested(
    OrganizationListWatchRequested event,
    Emitter<OrganizationListState> emit,
  ) async {
    emit(state.copyWith(status: ViewStatus.loading));
    await _subscription?.cancel();
    _subscription = _repository.watchOrganizations().listen(
          (organizations) =>
              add(_OrganizationListUpdated(organizations: organizations)),
          onError: (error, _) => add(
            _OrganizationListError(
              message: error is Exception ? error.toString() : 'Failed to load organizations',
            ),
          ),
        );
  }

  Future<void> _onDeleteRequested(
    OrganizationListDeleteRequested event,
    Emitter<OrganizationListState> emit,
  ) async {
    emit(state.copyWith(commandStatus: ViewStatus.loading));
    try {
      await _repository.deleteOrganization(event.organizationId);
      emit(state.copyWith(commandStatus: ViewStatus.success, message: 'Organization deleted'));
    } catch (error) {
      emit(state.copyWith(
        commandStatus: ViewStatus.failure,
        message: 'Failed to delete organization',
      ));
    } finally {
      emit(state.copyWith(commandStatus: ViewStatus.initial));
    }
  }

  void _onError(
    _OrganizationListError event,
    Emitter<OrganizationListState> emit,
  ) {
    emit(
      state.copyWith(
        status: ViewStatus.failure,
        message: event.message,
      ),
    );
  }

  void _onOrganizationsUpdated(
    _OrganizationListUpdated event,
    Emitter<OrganizationListState> emit,
  ) {
    emit(
      state.copyWith(
        status: ViewStatus.success,
        organizations: event.organizations,
      ),
    );
  }

  Future<void> _onUpdateRequested(
    OrganizationListUpdateRequested event,
    Emitter<OrganizationListState> emit,
  ) async {
    emit(state.copyWith(commandStatus: ViewStatus.loading));
    try {
      await _repository.updateOrganization(
        organizationId: event.organizationId,
        name: event.name,
        industry: event.industry,
      );
      emit(state.copyWith(commandStatus: ViewStatus.success, message: 'Organization updated'));
    } catch (_) {
      emit(state.copyWith(
        commandStatus: ViewStatus.failure,
        message: 'Failed to update organization',
      ));
    } finally {
      emit(state.copyWith(commandStatus: ViewStatus.initial));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}

