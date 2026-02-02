import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_bloc/core_bloc.dart';
import 'package:dash_web/data/repositories/analytics_repository.dart';
import 'package:dash_web/data/repositories/clients_repository.dart';
import 'package:dash_web/domain/entities/client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
part 'clients_state.dart';

class ClientsCubit extends Cubit<ClientsState> {
  ClientsCubit({
    required ClientsRepository repository,
    required String orgId,
    AnalyticsRepository? analyticsRepository,
  })  : _repository = repository,
        _orgId = orgId,
        _analyticsRepository = analyticsRepository,
        super(const ClientsState());

  final ClientsRepository _repository;
  final String _orgId;
  final AnalyticsRepository? _analyticsRepository;
  Timer? _searchDebounce;
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  static const int _pageSize = 20;

  Future<void> loadClients() async {
    _lastDoc = null;
    emit(state.copyWith(status: ViewStatus.loading));
    try {
      debugPrint('[ClientsCubit] Loading clients');
      final result = await _repository.fetchClients(orgId: _orgId, limit: _pageSize);
      _lastDoc = result.lastDoc;
      final hasMore = result.clients.length == _pageSize;
      debugPrint('[ClientsCubit] Fetched ${result.clients.length} clients');
      emit(state.copyWith(
        status: ViewStatus.success,
        clients: result.clients,
        hasMore: hasMore,
        message: null,
      ));

      // Load analytics in parallel
      loadAnalytics();
    } catch (e, stackTrace) {
      debugPrint('[ClientsCubit] Error loading clients: $e');
      debugPrint('[ClientsCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to load clients: ${e.toString()}',
      ));
    }
  }

  Future<void> loadMoreClients() async {
    if (!state.hasMore || state.isLoadingMore || _lastDoc == null) return;
    emit(state.copyWith(isLoadingMore: true));
    try {
      final result = await _repository.fetchClients(
        orgId: _orgId,
        limit: _pageSize,
        startAfterDocument: _lastDoc,
      );
      _lastDoc = result.lastDoc;
      final hasMore = result.clients.length == _pageSize;
      final newClients = [...state.clients, ...result.clients];
      emit(state.copyWith(
        clients: newClients,
        hasMore: hasMore,
        isLoadingMore: false,
      ));
    } catch (e) {
      debugPrint('[ClientsCubit] Error loading more clients: $e');
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  Future<void> loadAnalytics() async {
    final analyticsRepo = _analyticsRepository;
    if (analyticsRepo == null) return;
    
    emit(state.copyWith(isAnalyticsLoading: true));
    try {
      final analytics = await analyticsRepo.fetchClientsAnalytics(
        organizationId: _orgId,
      );
      emit(state.copyWith(
        analytics: analytics,
        isAnalyticsLoading: false,
      ));
    } catch (e) {
      debugPrint('[ClientsCubit] Error loading analytics: $e');
      emit(state.copyWith(
        isAnalyticsLoading: false,
      ));
    }
  }

  Future<void> loadRecentClients({int limit = 10}) async {
    emit(state.copyWith(isRecentLoading: true, message: null));
    try {
      final clients = await _repository.fetchRecentClients(orgId: _orgId, limit: limit);
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
      final results = await _repository.searchClients(_orgId, trimmed);
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
