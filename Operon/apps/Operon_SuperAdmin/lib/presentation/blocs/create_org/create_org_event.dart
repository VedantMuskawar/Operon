part of 'create_org_bloc.dart';

abstract class CreateOrgEvent {
  const CreateOrgEvent();
}

class CreateOrgSubmitted extends CreateOrgEvent {
  const CreateOrgSubmitted({
    required this.organizationName,
    required this.industry,
    this.businessId,
    required this.adminName,
    required this.adminPhone,
    required this.creatorUserId,
  });

  final String organizationName;
  final String industry;
  final String? businessId;
  final String adminName;
  final String adminPhone;
  final String creatorUserId;
}

class CreateOrgReset extends CreateOrgEvent {
  const CreateOrgReset();
}


