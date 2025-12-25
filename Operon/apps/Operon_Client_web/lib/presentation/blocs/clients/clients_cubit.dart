import 'dart:async';

import 'package:core_bloc/core_bloc.dart';
import 'package:dash_web/data/repositories/clients_repository.dart';
import 'package:dash_web/domain/entities/client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
part 'clients_state.dart';

class ClientsCubit extends Cubit<ClientsState> {
  ClientsCubit({
    required ClientsRepository repository,
    required String orgId,
  })  : _repository = repository,
        _orgId = orgId,
        super(const ClientsState());

  final ClientsRepository _repository;
  final String _orgId;
  Timer? _searchDebounce;

  Future<void> loadClients() async {
    emit(state.copyWith(status: ViewStatus.loading));
    try {
      debugPrint('[ClientsCubit] Loading clients');
      final clients = await _repository.fetchClients();
      debugPrint('[ClientsCubit] Fetched ${clients.length} clients');
      emit(state.copyWith(
        status: ViewStatus.success,
        clients: clients,
        message: null,
      ));
    } catch (e, stackTrace) {
      debugPrint('[ClientsCubit] Error loading clients: $e');
      debugPrint('[ClientsCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to load clients: ${e.toString()}',
      ));
    }
  }

  Future<void> loadRecentClients({int limit = 10}) async {
    emit(state.copyWith(isRecentLoading: true, message: null));
    try {
      final clients = await _repository.fetchRecentClients(limit: limit);
      emit(state.copyWith(
        recentClients: clients,
        isRecentLoading: false,
        status: ViewStatus.success,
      ));
    } catch (e) {
      emit(state.copyWith(
        isRecentLoading: false,
        message: 'Unable to load recent clients.',
        status: ViewStatus.failure,
      ));
    }
  }

  void search(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      emit(
        state.copyWith(
          searchQuery: '',
          searchResults: const [],
          isSearchLoading: false,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        searchQuery: trimmed,
        isSearchLoading: true,
        message: null,
      ),
    );

    try {
      final results = await _repository.searchClients(trimmed);
      emit(
        state.copyWith(
          searchResults: results,
          isSearchLoading: false,
          status: ViewStatus.success,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isSearchLoading: false,
          message: 'Unable to search clients.',
          status: ViewStatus.failure,
        ),
      );
    }
  }

  Future<void> createClient({
    required String name,
    required String primaryPhone,
    required List<String> phones,
    required List<String> tags,
  }) async {
    try {
      await _repository.createClient(
        name: name,
        primaryPhone: primaryPhone,
        phones: phones,
        tags: tags,
        organizationId: _orgId,
      );
      await loadClients();
      await loadRecentClients();
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to create client: ${e.toString()}',
      ));
    }
  }

  Future<void> updateClient(Client client) async {
    try {
      await _repository.updateClient(client);
      await loadClients();
      await loadRecentClients();
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to update client: ${e.toString()}',
      ));
    }
  }

  Future<void> deleteClient(String clientId) async {
    try {
      await _repository.deleteClient(clientId);
      await loadClients();
      await loadRecentClients();
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to delete client: ${e.toString()}',
      ));
    }
  }

  @override
  Future<void> close() {
    _searchDebounce?.cancel();
    return super.close();
  }
}
