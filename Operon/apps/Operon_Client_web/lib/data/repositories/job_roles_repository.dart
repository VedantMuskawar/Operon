import 'package:dash_web/data/datasources/job_roles_data_source.dart';
import 'package:dash_web/domain/entities/organization_job_role.dart';

class JobRolesRepository {
  JobRolesRepository({required JobRolesDataSource dataSource})
      : _dataSource = dataSource;

  final JobRolesDataSource _dataSource;

  final Map<String, ({DateTime timestamp, List<OrganizationJobRole> data})> _cache = {};
  final Map<String, Future<List<OrganizationJobRole>>> _inFlight = {};
  static const Duration _cacheTtl = Duration(minutes: 2);

  Future<List<OrganizationJobRole>> fetchJobRoles(
    String orgId, {
    bool forceRefresh = false,
  }) {
    if (!forceRefresh) {
      final cached = _cache[orgId];
      if (cached != null && DateTime.now().difference(cached.timestamp) < _cacheTtl) {
        return Future.value(cached.data);
      }

      final inFlight = _inFlight[orgId];
      if (inFlight != null) return inFlight;
    }

    final future = _dataSource.fetchJobRoles(orgId);
    _inFlight[orgId] = future;
    return future.then((roles) {
      _cache[orgId] = (timestamp: DateTime.now(), data: roles);
      _inFlight.remove(orgId);
      return roles;
    }).catchError((e) {
      _inFlight.remove(orgId);
      throw e;
    });
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
    _cache.remove(orgId);
    return _dataSource.createJobRole(orgId, jobRole);
  }

  Future<void> updateJobRole(String orgId, OrganizationJobRole jobRole) {
    _cache.remove(orgId);
    return _dataSource.updateJobRole(orgId, jobRole);
  }

  Future<void> deleteJobRole(String orgId, String jobRoleId) {
    _cache.remove(orgId);
    return _dataSource.deleteJobRole(orgId, jobRoleId);
  }
}
