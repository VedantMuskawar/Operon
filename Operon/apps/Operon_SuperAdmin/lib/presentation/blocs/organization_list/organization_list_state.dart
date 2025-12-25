part of 'organization_list_bloc.dart';

class OrganizationListState extends BaseState {
  const OrganizationListState({
    super.status = ViewStatus.initial,
    super.message,
    this.organizations = const [],
    this.commandStatus = ViewStatus.initial,
  });

  final List<OrganizationSummary> organizations;
  final ViewStatus commandStatus;

  @override
  OrganizationListState copyWith({
    ViewStatus? status,
    String? message,
    List<OrganizationSummary>? organizations,
    ViewStatus? commandStatus,
  }) {
    return OrganizationListState(
      status: status ?? this.status,
      message: message ?? this.message,
      organizations: organizations ?? this.organizations,
      commandStatus: commandStatus ?? this.commandStatus,
    );
  }
}

