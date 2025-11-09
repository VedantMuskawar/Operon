import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/client.dart';
import '../../../core/repositories/client_repository.dart';
import 'clients_event.dart';
import 'clients_state.dart';

class ClientsBloc extends Bloc<ClientsEvent, ClientsState> {
  ClientsBloc({required ClientRepository clientRepository})
    : _clientRepository = clientRepository,
      super(const ClientsState()) {
    on<ClientsRequested>(_onClientsRequested);
    on<ClientsRefreshed>(_onClientsRefreshed);
    on<ClientsLoadMore>(_onClientsLoadMore);
    on<ClientsSearchQueryChanged>(_onSearchQueryChanged);
    on<ClientsClearSearch>(_onClearSearch);
  }

  final ClientRepository _clientRepository;

  final Map<String, Client> _clientCache = {};
  String? _organizationId;
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _hasMore = false;
  bool _isFetchingMore = false;
  bool _hasLoadedAllForSearch = false;

  List<Client> get _allClients {
    final list = _clientCache.values.toList(growable: false);
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<void> _onClientsRequested(
    ClientsRequested event,
    Emitter<ClientsState> emit,
  ) async {
    if (_organizationId == event.organizationId &&
        !event.forceRefresh &&
        state.status == ClientsStatus.success) {
      return;
    }

    _organizationId = event.organizationId;
    _clientCache.clear();
    _lastDocument = null;
    _hasMore = false;
    _hasLoadedAllForSearch = false;

    emit(
      state.copyWith(
        status: ClientsStatus.loading,
        clients: const [],
        visibleClients: const [],
        metrics: const ClientsMetrics(
          total: 0,
          active: 0,
          inactive: 0,
          recent: 0,
        ),
        searchQuery: '',
        hasMore: false,
        clearError: true,
      ),
    );

    try {
      final result = await _clientRepository.fetchClientsPage(
        organizationId: event.organizationId,
        limit: 50,
      );

      _ingestClients(result.clients);
      _lastDocument = result.lastDocument;
      _hasMore = result.hasMore;

      if (_clientCache.isEmpty) {
        emit(
          state.copyWith(
            status: ClientsStatus.empty,
            clients: const [],
            visibleClients: const [],
            hasMore: false,
          ),
        );
        return;
      }

      emit(_buildSuccessState(hasMore: _hasMore));
    } catch (error) {
      emit(
        state.copyWith(
          status: ClientsStatus.failure,
          errorMessage: 'Failed to load clients: $error',
        ),
      );
    }
  }

  Future<void> _onClientsRefreshed(
    ClientsRefreshed event,
    Emitter<ClientsState> emit,
  ) async {
    final organizationId = _organizationId;
    if (organizationId == null) return;

    emit(state.copyWith(isRefreshing: true, clearError: true));

    try {
      final result = await _clientRepository.fetchClientsPage(
        organizationId: organizationId,
        limit: 50,
      );

      _clientCache.clear();
      _ingestClients(result.clients);
      _lastDocument = result.lastDocument;
      _hasMore = result.hasMore;
      _hasLoadedAllForSearch = false;

      if (_clientCache.isEmpty) {
        emit(
          state.copyWith(
            status: ClientsStatus.empty,
            clients: const [],
            visibleClients: const [],
            hasMore: false,
            isRefreshing: false,
          ),
        );
        return;
      }

      emit(_buildSuccessState(hasMore: _hasMore, isRefreshing: false));
    } catch (error) {
      emit(
        state.copyWith(
          status: ClientsStatus.failure,
          errorMessage: 'Failed to refresh clients: $error',
          isRefreshing: false,
        ),
      );
    }
  }

  Future<void> _onClientsLoadMore(
    ClientsLoadMore event,
    Emitter<ClientsState> emit,
  ) async {
    if (!_hasMore || _isFetchingMore) {
      return;
    }

    final organizationId = _organizationId;
    final lastDocument = _lastDocument;
    if (organizationId == null || lastDocument == null) {
      return;
    }

    _isFetchingMore = true;
    emit(state.copyWith(isFetchingMore: true, clearError: true));

    try {
      final result = await _clientRepository.fetchClientsPage(
        organizationId: organizationId,
        limit: 50,
        startAfter: lastDocument,
      );

      _ingestClients(result.clients);
      _lastDocument = result.lastDocument ?? _lastDocument;
      _hasMore = result.hasMore;

      emit(_buildSuccessState(hasMore: _hasMore, isFetchingMore: false));
    } catch (error) {
      emit(
        state.copyWith(
          status: ClientsStatus.failure,
          errorMessage: 'Failed to load more clients: $error',
          isFetchingMore: false,
        ),
      );
    } finally {
      _isFetchingMore = false;
    }
  }

  Future<void> _onSearchQueryChanged(
    ClientsSearchQueryChanged event,
    Emitter<ClientsState> emit,
  ) async {
    final trimmedQuery = event.query.trim();

    if (trimmedQuery.isEmpty) {
      emit(
        _buildSuccessState(
          searchQuery: '',
          hasMore: _hasMore,
          isFetchingMore: false,
        ),
      );
      return;
    }

    if (!_hasLoadedAllForSearch && _hasMore) {
      await _loadRemainingClients();
    }

    emit(_buildSuccessState(searchQuery: trimmedQuery, hasMore: _hasMore));
  }

  void _onClearSearch(ClientsClearSearch event, Emitter<ClientsState> emit) {
    emit(_buildSuccessState(searchQuery: '', hasMore: _hasMore));
  }

  Future<void> _loadRemainingClients() async {
    final organizationId = _organizationId;
    if (organizationId == null) return;

    try {
      final allClients = await _clientRepository.fetchAllClients(
        organizationId: organizationId,
      );
      _clientCache.clear();
      _ingestClients(allClients);
      _hasMore = false;
      _hasLoadedAllForSearch = true;
    } catch (_) {
      // If fetching all fails, keep existing data. Search will operate on current cache.
    }
  }

  void _ingestClients(List<Client> clients) {
    for (final client in clients) {
      final key = client.clientId.isNotEmpty ? client.clientId : client.id;
      _clientCache[key] = client;
    }
  }

  ClientsState _buildSuccessState({
    String? searchQuery,
    bool? hasMore,
    bool? isFetchingMore,
    bool? isRefreshing,
  }) {
    final query = searchQuery ?? state.searchQuery;
    final clients = _allClients;
    final metrics = ClientsMetrics.fromClients(clients);
    final visible = _filterClients(clients, query);

    final status = clients.isEmpty
        ? ClientsStatus.empty
        : ClientsStatus.success;

    return state.copyWith(
      status: status,
      clients: clients,
      visibleClients: visible,
      metrics: metrics,
      searchQuery: query,
      hasMore: hasMore ?? _hasMore,
      isFetchingMore: isFetchingMore ?? false,
      isRefreshing: isRefreshing ?? false,
      clearError: true,
    );
  }

  List<Client> _filterClients(List<Client> clients, String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return clients;
    }

    final digitsQuery = trimmed.replaceAll(RegExp(r'[^0-9]'), '');

    return clients
        .where((client) {
          final name = client.name.toLowerCase();
          final email = client.email?.toLowerCase() ?? '';
          final phonePrimary = client.phoneNumber.toLowerCase();
          final tags = client.tags.map((tag) => tag.toLowerCase());

          final matchesText =
              name.contains(trimmed) ||
              phonePrimary.contains(trimmed) ||
              email.contains(trimmed) ||
              tags.any((tag) => tag.contains(trimmed));

          if (matchesText) return true;

          if (digitsQuery.isEmpty) return false;

          final candidatePhones = <String>{
            client.phoneNumber,
            ...client.phoneList,
          };
          return candidatePhones.any((phone) {
            final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
            return digits.contains(digitsQuery);
          });
        })
        .toList(growable: false);
  }
}
