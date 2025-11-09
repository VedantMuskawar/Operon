import 'package:equatable/equatable.dart';

import '../../../core/models/client.dart';

enum ClientsStatus { initial, loading, success, empty, failure }

class ClientsMetrics extends Equatable {
  const ClientsMetrics({
    required this.total,
    required this.active,
    required this.inactive,
    required this.recent,
  });

  final int total;
  final int active;
  final int inactive;
  final int recent;

  static ClientsMetrics fromClients(List<Client> clients) {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    int active = 0;
    int inactive = 0;
    int recent = 0;

    for (final client in clients) {
      if (client.status == ClientStatus.active) {
        active++;
      } else {
        inactive++;
      }

      if (client.createdAt.isAfter(thirtyDaysAgo)) {
        recent++;
      }
    }

    return ClientsMetrics(
      total: clients.length,
      active: active,
      inactive: inactive,
      recent: recent,
    );
  }

  @override
  List<Object?> get props => [total, active, inactive, recent];
}

class ClientsState extends Equatable {
  const ClientsState({
    this.status = ClientsStatus.initial,
    this.clients = const [],
    this.visibleClients = const [],
    this.metrics = const ClientsMetrics(
      total: 0,
      active: 0,
      inactive: 0,
      recent: 0,
    ),
    this.errorMessage,
    this.searchQuery = '',
    this.isFetchingMore = false,
    this.hasMore = false,
    this.isRefreshing = false,
  });

  final ClientsStatus status;
  final List<Client> clients;
  final List<Client> visibleClients;
  final ClientsMetrics metrics;
  final String? errorMessage;
  final String searchQuery;
  final bool isFetchingMore;
  final bool hasMore;
  final bool isRefreshing;

  ClientsState copyWith({
    ClientsStatus? status,
    List<Client>? clients,
    List<Client>? visibleClients,
    ClientsMetrics? metrics,
    String? errorMessage,
    bool clearError = false,
    String? searchQuery,
    bool? isFetchingMore,
    bool? hasMore,
    bool? isRefreshing,
  }) {
    return ClientsState(
      status: status ?? this.status,
      clients: clients ?? this.clients,
      visibleClients: visibleClients ?? this.visibleClients,
      metrics: metrics ?? this.metrics,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      searchQuery: searchQuery ?? this.searchQuery,
      isFetchingMore: isFetchingMore ?? this.isFetchingMore,
      hasMore: hasMore ?? this.hasMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  ClientsState clearError() {
    return copyWith(clearError: true);
  }

  @override
  List<Object?> get props => [
    status,
    clients,
    visibleClients,
    metrics,
    errorMessage,
    searchQuery,
    isFetchingMore,
    hasMore,
    isRefreshing,
  ];
}
