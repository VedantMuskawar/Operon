import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_bloc/core_bloc.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DeliveryMemosState extends BaseState {
  static const Object _unset = Object();

  const DeliveryMemosState({
    super.status = ViewStatus.initial,
    this.deliveryMemos = const [],
    this.searchQuery = '',
    this.statusFilter, // 'active' or 'cancelled'
    this.startDate,
    this.endDate,
    this.currentPage = 1,
    this.pageSize = 20,
    this.hasPreviousPage = false,
    this.hasNextPage = false,
    this.message,
  }) : super(message: message);

  final List<Map<String, dynamic>> deliveryMemos;
  final String searchQuery;
  final String? statusFilter;
  final DateTime? startDate;
  final DateTime? endDate;
  final int currentPage;
  final int pageSize;
  final bool hasPreviousPage;
  final bool hasNextPage;
  @override
  final String? message;
  static final Map<String, String> _searchIndexCache = {};
  static String? _lastSearchIndexHash;

  static Map<String, String> _buildSearchIndex(
    List<Map<String, dynamic>> memos,
    String memosHash,
  ) {
    if (_lastSearchIndexHash == memosHash && _searchIndexCache.isNotEmpty) {
      return _searchIndexCache;
    }

    _searchIndexCache.clear();
    for (final dm in memos) {
      final buffer = StringBuffer();
      void add(String? value) {
        if (value == null) return;
        final trimmed = value.trim();
        if (trimmed.isEmpty) return;
        buffer.write(trimmed.toLowerCase());
        buffer.write(' ');
      }

      final dmId = dm['dmId'] as String?;
      final dmNumberStr = (dm['dmNumber'] as int? ?? 0).toString();
      add(dmId);
      add(dmNumberStr);
      add(dm['clientName'] as String?);
      add(dm['vehicleNumber'] as String?);

      final key = dmId ?? dmNumberStr;
      _searchIndexCache[key] = buffer.toString();
    }

    _lastSearchIndexHash = memosHash;
    return _searchIndexCache;
  }

  List<Map<String, dynamic>> get filteredDeliveryMemos {
    var filtered = deliveryMemos;

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      final memosHash = '${deliveryMemos.length}_${deliveryMemos.hashCode}';
      final searchIndex = _buildSearchIndex(deliveryMemos, memosHash);
      filtered = filtered.where((dm) {
        final dmId = dm['dmId'] as String?;
        final dmNumberStr = (dm['dmNumber'] as int? ?? 0).toString();
        final key = dmId ?? dmNumberStr;
        final indexText = searchIndex[key] ?? '';
        return indexText.contains(query);
      }).toList();
    }

    return filtered;
  }

  @override
  DeliveryMemosState copyWith({
    ViewStatus? status,
    List<Map<String, dynamic>>? deliveryMemos,
    String? searchQuery,
    Object? statusFilter = _unset,
    Object? startDate = _unset,
    Object? endDate = _unset,
    int? currentPage,
    int? pageSize,
    bool? hasPreviousPage,
    bool? hasNextPage,
    Object? message = _unset,
  }) {
    return DeliveryMemosState(
      status: status ?? this.status,
      deliveryMemos: deliveryMemos ?? this.deliveryMemos,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: identical(statusFilter, _unset)
          ? this.statusFilter
          : statusFilter as String?,
      startDate: identical(startDate, _unset)
          ? this.startDate
          : startDate as DateTime?,
      endDate: identical(endDate, _unset)
          ? this.endDate
          : endDate as DateTime?,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      hasPreviousPage: hasPreviousPage ?? this.hasPreviousPage,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      message: identical(message, _unset) ? this.message : message as String?,
    );
  }
}

class DeliveryMemosCubit extends Cubit<DeliveryMemosState> {
  DeliveryMemosCubit({
    required DeliveryMemoRepository repository,
    required String organizationId,
  })  : _repository = repository,
        _organizationId = organizationId,
        super(const DeliveryMemosState());

  final DeliveryMemoRepository _repository;
  final String _organizationId;
  StreamSubscription<List<Map<String, dynamic>>>? _deliveryMemosSubscription;
  final List<DocumentSnapshot<Map<String, dynamic>>?> _pageCursors = [null];
  int _currentPageIndex = 0;

  static const int _defaultLimit = 20;
  static const int _searchLimit = 200;

  String get organizationId => _organizationId;

  void search(String query) {
    emit(state.copyWith(searchQuery: query));
    if (query.trim().isEmpty) {
      _resetPagination();
    }
    _subscribeToDeliveryMemos();
  }

  void setStatusFilter(String? status) {
    emit(state.copyWith(statusFilter: status));
    _resetPagination();
    _subscribeToDeliveryMemos();
  }

  void setDateRange(DateTime? start, DateTime? end) {
    emit(state.copyWith(startDate: start, endDate: end));
    _resetPagination();
    _subscribeToDeliveryMemos();
  }

  void clearFilters() {
    emit(state.copyWith(
      statusFilter: null,
      startDate: null,
      endDate: null,
      searchQuery: '',
    ));
    _resetPagination();
    _subscribeToDeliveryMemos();
  }

  void _resetPagination() {
    _pageCursors
      ..clear()
      ..add(null);
    _currentPageIndex = 0;
  }

  void _subscribeToDeliveryMemos() {
    _deliveryMemosSubscription?.cancel();

    developer.log('Subscribing to delivery memos', name: 'DeliveryMemosCubit');
    developer.log('Organization ID: $_organizationId', name: 'DeliveryMemosCubit');
    developer.log('Status filter: ${state.statusFilter}', name: 'DeliveryMemosCubit');
    developer.log('Start date: ${state.startDate}', name: 'DeliveryMemosCubit');
    developer.log('End date: ${state.endDate}', name: 'DeliveryMemosCubit');

    final normalizedQuery = state.searchQuery.trim();
    final dmNumber = _parseDmNumber(normalizedQuery);
    if (dmNumber != null) {
      developer.log('DM number search: $dmNumber', name: 'DeliveryMemosCubit');
      emit(state.copyWith(status: ViewStatus.loading));
      _loadByDmNumber(dmNumber);
      return;
    }

    // Keep broad search on stream with capped results.
    if (normalizedQuery.isNotEmpty) {
      final limit = _searchLimit;
      developer.log('Search mode limit: $limit', name: 'DeliveryMemosCubit');

      _deliveryMemosSubscription = _repository
          .watchDeliveryMemos(
            organizationId: _organizationId,
            status: state.statusFilter,
            startDate: state.startDate,
            endDate: state.endDate,
            limit: limit,
          )
          .listen(
        (deliveryMemos) {
          emit(state.copyWith(
            status: ViewStatus.success,
            deliveryMemos: deliveryMemos,
            currentPage: 1,
            hasPreviousPage: false,
            hasNextPage: false,
            pageSize: _defaultLimit,
            message: null,
          ));
        },
        onError: (error, stackTrace) {
          developer.log('Error loading delivery memos: $error', name: 'DeliveryMemosCubit', error: error, stackTrace: stackTrace);
          emit(state.copyWith(
            status: ViewStatus.failure,
            message: 'Unable to load delivery memos: ${error.toString()}',
          ));
        },
      );

      emit(state.copyWith(status: ViewStatus.loading));
      return;
    }

    // Non-search mode: true cursor-based pagination to navigate old DMs.
    _loadPage(_currentPageIndex);
  }

  Future<void> nextPage() async {
    if (!state.hasNextPage) return;
    await _loadPage(_currentPageIndex + 1);
  }

  Future<void> previousPage() async {
    if (_currentPageIndex <= 0) return;
    await _loadPage(_currentPageIndex - 1);
  }

  Future<void> _loadPage(int targetPageIndex) async {
    try {
      emit(state.copyWith(status: ViewStatus.loading));

      final cursor = targetPageIndex < _pageCursors.length
          ? _pageCursors[targetPageIndex]
          : null;

      final page = await _repository.fetchDeliveryMemosPage(
        organizationId: _organizationId,
        status: state.statusFilter,
        startDate: state.startDate,
        endDate: state.endDate,
        limit: _defaultLimit,
        startAfterDocument: cursor,
      );

      if (_pageCursors.length <= targetPageIndex + 1) {
        _pageCursors.add(page.lastDocument);
      } else {
        _pageCursors[targetPageIndex + 1] = page.lastDocument;
      }

      _currentPageIndex = targetPageIndex;

      emit(state.copyWith(
        status: ViewStatus.success,
        deliveryMemos: page.memos,
        currentPage: _currentPageIndex + 1,
        pageSize: _defaultLimit,
        hasPreviousPage: _currentPageIndex > 0,
        hasNextPage: page.hasMore,
        message: null,
      ));
    } catch (error, stackTrace) {
      developer.log('Error loading delivery memo page: $error', name: 'DeliveryMemosCubit', error: error, stackTrace: stackTrace);
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to load delivery memos: ${error.toString()}',
      ));
    }
  }

  int? _parseDmNumber(String query) {
    if (query.isEmpty) return null;
    final normalized = query.toLowerCase();
    final match = RegExp(r'^(dm[\-/ ]?)?(\d+)$').firstMatch(normalized);
    if (match == null) return null;
    return int.tryParse(match.group(2) ?? '');
  }

  Future<void> _loadByDmNumber(int dmNumber) async {
    try {
      final memo = await _repository.getDeliveryMemoByDmNumber(
        organizationId: _organizationId,
        dmNumber: dmNumber,
      );
      emit(state.copyWith(
        status: ViewStatus.success,
        deliveryMemos: memo != null ? [memo] : const [],
        currentPage: 1,
        pageSize: _defaultLimit,
        hasPreviousPage: false,
        hasNextPage: false,
        message: null,
      ));
    } catch (error) {
      developer.log(
        'Error loading delivery memo by dmNumber: $error',
        name: 'DeliveryMemosCubit',
        error: error,
      );
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to load delivery memo: ${error.toString()}',
      ));
    }
  }

  void load() {
    _subscribeToDeliveryMemos();
  }

  Future<void> cancelDM({
    required String tripId,
    String? dmId,
    required String cancelledBy,
    String? cancellationReason,
  }) async {
    try {
      await _repository.cancelDM(
        tripId: tripId,
        dmId: dmId,
        cancelledBy: cancelledBy,
        cancellationReason: cancellationReason,
      );
      // The subscription will automatically update the list
    } catch (error) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to cancel DM: ${error.toString()}',
      ));
      rethrow;
    }
  }

  @override
  Future<void> close() {
    _deliveryMemosSubscription?.cancel();
    return super.close();
  }
}

