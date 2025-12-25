import 'package:dash_web/data/datasources/job_roles_data_source.dart';
import 'package:dash_web/domain/entities/organization_job_role.dart';

class JobRolesRepository {
  JobRolesRepository({required JobRolesDataSource dataSource})
      : _dataSource = dataSource;

  final JobRolesDataSource _dataSource;

  Future<List<OrganizationJobRole>> fetchJobRoles(String orgId) {
    return _dataSource.fetchJobRoles(orgId);
  }

  Future<OrganizationJobRole?> fetchJobRole(String orgId, String jobRoleId) {
    return _dataSource.fetchJobRole(orgId, jobRoleId);
  }

  Future<List<OrganizationJobRole>> fetchJobRolesByIds(
    String orgId,
    List<String> jobRoleIds,
  ) {
    return _dataSource.fetchJobRolesByIds(orgId, jobRoleIds);
  }

  Future<void> createJobRole(String orgId, OrganizationJobRole jobRole) {
    return _dataSource.createJobRole(orgId, jobRole);
  }

  Future<void> updateJobRole(String orgId, OrganizationJobRole jobRole) {
    return _dataSource.updateJobRole(orgId, jobRole);
  }

  Future<void> deleteJobRole(String orgId, String jobRoleId) {
    return _dataSource.deleteJobRole(orgId, jobRoleId);
  }
}
