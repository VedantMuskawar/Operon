part of 'clients_cubit.dart';

class ClientsState extends BaseState {
  const ClientsState({
    super.status = ViewStatus.initial,
    this.clients = const [],
    this.recentClients = const [],
    this.searchResults = const [],
    this.searchQuery = '',
    this.isRecentLoading = false,
    this.isSearchLoading = false,
    this.analytics,
    this.isAnalyticsLoading = false,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.message,
  }) : super(message: message);

  final List<Client> clients;
  final List<Client> recentClients;
  final List<Client> searchResults;
  final String searchQuery;
  final bool isRecentLoading;
  final bool isSearchLoading;
  final ClientsAnalytics? analytics;
  final bool isAnalyticsLoading;
  final bool hasMore;
  final bool isLoadingMore;
  @override
  final String? message;

  @override
  ClientsState copyWith({
    ViewStatus? status,
    List<Client>? clients,
    List<Client>? recentClients,
    List<Client>? searchResults,
    String? searchQuery,
    bool? isRecentLoading,
    bool? isSearchLoading,
    ClientsAnalytics? analytics,
    bool? isAnalyticsLoading,
    bool? hasMore,
    bool? isLoadingMore,
    String? message,
  }) {
    return ClientsState(
      status: status ?? this.status,
      clients: clients ?? this.clients,
      recentClients: recentClients ?? this.recentClients,
      searchResults: searchResults ?? this.searchResults,
      searchQuery: searchQuery ?? this.searchQuery,
      isRecentLoading: isRecentLoading ?? this.isRecentLoading,
      isSearchLoading: isSearchLoading ?? this.isSearchLoading,
      analytics: analytics ?? this.analytics,
      isAnalyticsLoading: isAnalyticsLoading ?? this.isAnalyticsLoading,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      message: message ?? this.message,
    );
  }
}
