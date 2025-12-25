import 'package:dash_mobile/data/datasources/user_organization_data_source.dart';
import 'package:dash_mobile/domain/entities/organization_membership.dart';

class UserOrganizationRepository {
  UserOrganizationRepository({
    UserOrganizationDataSource? dataSource,
  }) : _dataSource = dataSource ?? UserOrganizationDataSource();

  final UserOrganizationDataSource _dataSource;

  Future<List<OrganizationMembership>> loadOrganizationsForUser({
    required String userId,
    String? phoneNumber,
  }) async {
    final records = await _dataSource.fetchUserOrganizations(
      userUid: userId,
      phoneNumber: phoneNumber,
    );
    return records
        .map(
          (record) => OrganizationMembership(
            id: record.id,
            name: record.name,
            role: record.role,
          ),
        )
        .toList();
  }
}

