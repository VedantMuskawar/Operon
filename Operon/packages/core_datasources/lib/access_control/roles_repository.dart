import 'package:core_datasources/access_control/roles_data_source.dart';
import 'package:core_models/access_control/organization_role.dart';

class RolesRepository {
  RolesRepository({required RolesDataSource dataSource})
      : _dataSource = dataSource;

  final RolesDataSource _dataSource;

  Future<List<OrganizationRole>> fetchRoles(String orgId) {
    return _dataSource.fetchRoles(orgId);
  }

  Future<void> createRole(String orgId, OrganizationRole role) {
    return _dataSource.createRole(orgId, role);
  }

  Future<void> updateRole(String orgId, OrganizationRole role) {
    return _dataSource.updateRole(orgId, role);
  }

  Future<void> deleteRole(String orgId, String roleId) {
    return _dataSource.deleteRole(orgId, roleId);
  }
}

