part of 'create_org_bloc.dart';

class CreateOrgState extends BaseState {
  const CreateOrgState({
    super.status = ViewStatus.initial,
    super.message,
    this.fieldErrors = const {},
    this.organizationId,
    this.adminUserId,
    this.isSuccess = false,
  });

  final Map<String, String> fieldErrors;
  final String? organizationId;
  final String? adminUserId;
  final bool isSuccess;

  @override
  CreateOrgState copyWith({
    ViewStatus? status,
    String? message,
    Map<String, String>? fieldErrors,
    String? organizationId,
    String? adminUserId,
    bool? isSuccess,
    bool resetIdentifiers = false,
    bool resetErrors = false,
  }) {
    return CreateOrgState(
      status: status ?? this.status,
      message: message ?? this.message,
      fieldErrors:
          resetErrors ? const {} : (fieldErrors ?? this.fieldErrors),
      organizationId: resetIdentifiers
          ? null
          : (organizationId ?? this.organizationId),
      adminUserId: resetIdentifiers
          ? null
          : (adminUserId ?? this.adminUserId),
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

