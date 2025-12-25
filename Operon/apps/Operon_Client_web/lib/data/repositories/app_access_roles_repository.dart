import 'package:dash_web/data/datasources/app_access_roles_data_source.dart';
import 'package:dash_web/domain/entities/app_access_role.dart';

class AppAccessRolesRepository {
  AppAccessRolesRepository({required AppAccessRolesDataSource dataSource})
      : _dataSource = dataSource;

  final AppAccessRolesDataSource _dataSource;

  Future<List<AppAccessRole>> fetchAppAccessRoles(String orgId) {
    return _dataSource.fetchAppAccessRoles(orgId);
  }

  Future<AppAccessRole?> fetchAppAccessRole(String orgId, String roleId) {
    return _dataSource.fetchAppAccessRole(orgId, roleId);
  }

  Future<void> createAppAccessRole(String orgId, AppAccessRole role) {
    return _dataSource.createAppAccessRole(orgId, role);
  }

  Future<void> updateAppAccessRole(String orgId, AppAccessRole role) {
    return _dataSource.updateAppAccessRole(orgId, role);
  }

  Future<void> deleteAppAccessRole(String orgId, String roleId) {
    return _dataSource.deleteAppAccessRole(orgId, roleId);
  }
}
