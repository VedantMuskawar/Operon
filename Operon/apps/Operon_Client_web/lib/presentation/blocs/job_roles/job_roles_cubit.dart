import 'package:core_bloc/core_bloc.dart';
import 'package:dash_web/data/repositories/job_roles_repository.dart';
import 'package:dash_web/domain/entities/organization_job_role.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
part 'job_roles_state.dart';

class JobRolesCubit extends Cubit<JobRolesState> {
  JobRolesCubit({
    required JobRolesRepository repository,
    required String orgId,
    List<OrganizationJobRole>? initialJobRoles,
    bool skipInitialLoad = false,
  })  : _repository = repository,
        _orgId = orgId,
        super(JobRolesState(
          jobRoles: initialJobRoles ?? const [],
          status: (initialJobRoles != null && initialJobRoles.isNotEmpty)
              ? ViewStatus.success
              : ViewStatus.initial,
        )) {
    if (!skipInitialLoad && (initialJobRoles == null || initialJobRoles.isEmpty)) {
      load();
    }
  }

  final JobRolesRepository _repository;
  final String _orgId;

  Future<void> load() async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      final jobRoles = await _repository.fetchJobRoles(_orgId);
      emit(state.copyWith(status: ViewStatus.success, jobRoles: jobRoles));
    } catch (error) {
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: 'Unable to load job roles. Please try again.',
        ),
      );
    }
  }

  Future<void> createJobRole(OrganizationJobRole jobRole) async {
    try {
      await _repository.createJobRole(_orgId, jobRole);
      await load();
    } catch (error) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to create job role.',
      ));
    }
  }

  Future<void> updateJobRole(OrganizationJobRole jobRole) async {
    try {
      await _repository.updateJobRole(_orgId, jobRole);
      await load();
    } catch (error) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to update job role.',
      ));
    }
  }

  Future<void> deleteJobRole(String jobRoleId) async {
    try {
      await _repository.deleteJobRole(_orgId, jobRoleId);
      await load();
    } catch (error) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to delete job role.',
      ));
    }
  }

  Future<List<OrganizationJobRole>> fetchJobRolesByIds(List<String> jobRoleIds) async {
    try {
      return await _repository.fetchJobRolesByIds(_orgId, jobRoleIds);
    } catch (error) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to fetch job roles.',
      ));
      return [];
    }
  }
}
