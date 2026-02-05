import 'package:operon_driver_android/data/datasources/users_data_source.dart';
import 'package:operon_driver_android/domain/entities/organization_user.dart';

class UsersRepository {
  UsersRepository({required UsersDataSource dataSource})
      : _dataSource = dataSource;

  final UsersDataSource _dataSource;

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
