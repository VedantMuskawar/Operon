import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_bloc/core_bloc.dart';
import 'package:dash_mobile/data/repositories/clients_repository.dart';
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/presentation/utils/network_error_helper.dart';

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
  StreamSubscription<List<ClientRecord>>? _recentSubscription;
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  bool get hasMore => _hasMore;

  Future<void> loadClients({int limit = 20}) async {
    if (isClosed) return;
    _lastDoc = null;
    _hasMore = true;
    emit(state.copyWith(isRecentLoading: true, message: null));
    try {
      final result = await _repository.fetchRecentClientsPage(
        orgId: _orgId,
        limit: limit,
      );
      _lastDoc = result.lastDoc;
      _hasMore = result.clients.length == limit;
      if (!isClosed) {
        emit(
          state.copyWith(
            recentClients: result.clients,
            isRecentLoading: false,
            status: ViewStatus.success,
          ),
        );
      }
    } catch (error) {
      if (!isClosed) {
        final errorMessage = NetworkErrorHelper.isNetworkError(error)
            ? NetworkErrorHelper.getNetworkErrorMessage(error)
            : 'Unable to load clients.';
        emit(
          state.copyWith(
            isRecentLoading: false,
            message: errorMessage,
            status: ViewStatus.failure,
          ),
        );
      }
    }
  }

  Future<void> loadMoreClients({int limit = 20}) async {
    if (isClosed || _isLoadingMore || !_hasMore || _lastDoc == null) return;
    _isLoadingMore = true;
    try {
      final result = await _repository.fetchRecentClientsPage(
        orgId: _orgId,
        limit: limit,
        startAfterDocument: _lastDoc,
      );
      _lastDoc = result.lastDoc;
      _hasMore = result.clients.length == limit;
      final newClients = [...state.recentClients, ...result.clients];
      if (!isClosed) {
        emit(
          state.copyWith(
            recentClients: newClients,
            status: ViewStatus.success,
          ),
        );
      }
    } catch (_) {
      // Keep existing list if pagination fails.
    } finally {
      _isLoadingMore = false;
    }
  }

  void subscribeToRecent({int limit = 10}) {
    if (isClosed) return;
    emit(state.copyWith(isRecentLoading: true, message: null));
    _recentSubscription?.cancel();
    _recentSubscription = _repository
        .recentClientsStream(orgId: _orgId, limit: limit)
        .listen((clients) {
      if (!isClosed) {
        emit(
          state.copyWith(
            recentClients: clients,
            isRecentLoading: false,
            status: ViewStatus.success,
          ),
        );
      }
    }, onError: (error) {
      if (!isClosed) {
        final errorMessage = NetworkErrorHelper.isNetworkError(error)
            ? NetworkErrorHelper.getNetworkErrorMessage(error)
            : 'Unable to load recent clients.';
        emit(
          state.copyWith(
            isRecentLoading: false,
            message: errorMessage,
            status: ViewStatus.failure,
          ),
        );
      }
    });
  }

  void search(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (isClosed) return;
    
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      if (!isClosed) {
        emit(
          state.copyWith(
            searchQuery: '',
            searchResults: const [],
            isSearchLoading: false,
          ),
        );
      }
      return;
    }

    if (!isClosed) {
      emit(
        state.copyWith(
          searchQuery: trimmed,
          isSearchLoading: true,
          message: null,
        ),
      );
    }

    try {
      final results = await _repository.searchClients(_orgId, trimmed);
      if (!isClosed) {
        emit(
          state.copyWith(
            searchResults: results,
            isSearchLoading: false,
            status: ViewStatus.success,
          ),
        );
      }
    } catch (error) {
      if (!isClosed) {
        final errorMessage = NetworkErrorHelper.isNetworkError(error)
            ? NetworkErrorHelper.getNetworkErrorMessage(error)
            : 'Unable to search clients.';
        emit(
          state.copyWith(
            isSearchLoading: false,
            message: errorMessage,
            status: ViewStatus.failure,
          ),
        );
      }
    }
  }

  @override
  Future<void> close() {
    _searchDebounce?.cancel();
    _recentSubscription?.cancel();
    return super.close();
  }
}
