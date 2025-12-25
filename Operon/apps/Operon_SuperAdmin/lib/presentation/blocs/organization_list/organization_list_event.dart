part of 'organization_list_bloc.dart';

abstract class OrganizationListEvent {
  const OrganizationListEvent();
}

class OrganizationListWatchRequested extends OrganizationListEvent {
  const OrganizationListWatchRequested();
}

class _OrganizationListUpdated extends OrganizationListEvent {
  const _OrganizationListUpdated({required this.organizations});

  final List<OrganizationSummary> organizations;
}

class _OrganizationListError extends OrganizationListEvent {
  const _OrganizationListError({required this.message});

  final String message;
}

class OrganizationListDeleteRequested extends OrganizationListEvent {
  const OrganizationListDeleteRequested({required this.organizationId});

  final String organizationId;
}

class OrganizationListUpdateRequested extends OrganizationListEvent {
  const OrganizationListUpdateRequested({
    required this.organizationId,
    required this.name,
    required this.industry,
  });

  final String organizationId;
  final String name;
  final String industry;
}

