import 'package:equatable/equatable.dart';

abstract class ClientsEvent extends Equatable {
  const ClientsEvent();

  @override
  List<Object?> get props => [];
}

class ClientsRequested extends ClientsEvent {
  const ClientsRequested({
    required this.organizationId,
    this.forceRefresh = false,
  });

  final String organizationId;
  final bool forceRefresh;

  @override
  List<Object?> get props => [organizationId, forceRefresh];
}

class ClientsRefreshed extends ClientsEvent {
  const ClientsRefreshed();
}

class ClientsLoadMore extends ClientsEvent {
  const ClientsLoadMore();
}

class ClientsSearchQueryChanged extends ClientsEvent {
  const ClientsSearchQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

class ClientsClearSearch extends ClientsEvent {
  const ClientsClearSearch();
}
