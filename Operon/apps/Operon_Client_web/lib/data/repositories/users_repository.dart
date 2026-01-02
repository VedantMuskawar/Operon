import 'package:dash_web/data/datasources/users_data_source.dart';
import 'package:dash_web/domain/entities/organization_user.dart';

class UsersRepository {
  UsersRepository({required UsersDataSource dataSource})
      : _dataSource = dataSource;

  final UsersDataSource _dataSource;

  Future<List<OrganizationUser>> fetchOrgUsers(String orgId) {
    return _dataSource.fetchOrgUsers(orgId);
  }

  Future<void> upsertOrgUser({
    required String orgId,
    required String orgName,
    required OrganizationUser user,
  }) {
    return _dataSource.upsertOrgUser(
      orgId: orgId,
      orgName: orgName,
      user: user,
    );
  }

  Future<void> removeOrgUser({
    required String orgId,
    required String userId,
  }) {
    return _dataSource.removeOrgUser(orgId: orgId, userId: userId);
  }

  Future<String?> fetchPhoneByEmployeeId({
    required String orgId,
    required String employeeId,
  }) {
    return _dataSource.fetchPhoneByEmployeeId(
      orgId: orgId,
      employeeId: employeeId,
    );
  }

  Future<OrganizationUser?> fetchCurrentUser({
    required String orgId,
    required String userId,
    String? phoneNumber,
  }) {
    return _dataSource.fetchCurrentUser(
      orgId: orgId,
      userId: userId,
      phoneNumber: phoneNumber,
    );
  }
}
