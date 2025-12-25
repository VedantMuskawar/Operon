part of 'job_roles_cubit.dart';

class JobRolesState extends BaseState {
  const JobRolesState({
    super.status = ViewStatus.initial,
    this.jobRoles = const [],
    this.message,
  }) : super(message: message);

  final List<OrganizationJobRole> jobRoles;
  @override
  final String? message;

  @override
  JobRolesState copyWith({
    ViewStatus? status,
    List<OrganizationJobRole>? jobRoles,
    String? message,
  }) {
    return JobRolesState(
      status: status ?? this.status,
      jobRoles: jobRoles ?? this.jobRoles,
      message: message ?? this.message,
    );
  }
}
