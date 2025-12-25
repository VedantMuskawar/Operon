part of 'clients_cubit.dart';

class ClientsState extends BaseState {
  const ClientsState({
    super.status = ViewStatus.initial,
    super.message,
    this.recentClients = const [],
    this.searchResults = const [],
    this.searchQuery = '',
    this.isRecentLoading = false,
    this.isSearchLoading = false,
  });

  final List<ClientRecord> recentClients;
  final List<ClientRecord> searchResults;
  final String searchQuery;
  final bool isRecentLoading;
  final bool isSearchLoading;

  @override
  ClientsState copyWith({
    ViewStatus? status,
    String? message,
    List<ClientRecord>? recentClients,
    List<ClientRecord>? searchResults,
    String? searchQuery,
    bool? isRecentLoading,
    bool? isSearchLoading,
  }) {
    return ClientsState(
      status: status ?? this.status,
      message: message ?? this.message,
      recentClients: recentClients ?? this.recentClients,
      searchResults: searchResults ?? this.searchResults,
      searchQuery: searchQuery ?? this.searchQuery,
      isRecentLoading: isRecentLoading ?? this.isRecentLoading,
      isSearchLoading: isSearchLoading ?? this.isSearchLoading,
    );
  }
}
