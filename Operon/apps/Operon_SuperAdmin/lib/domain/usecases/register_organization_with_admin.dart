import 'package:dash_superadmin/data/repositories/organization_repository.dart';
import 'package:dash_superadmin/domain/entities/admin_form.dart';
import 'package:dash_superadmin/domain/entities/organization_form.dart';

class RegisterOrganizationResult {
  const RegisterOrganizationResult({
    required this.organizationId,
    required this.adminUserId,
  });

  final String organizationId;
  final String adminUserId;
}

class RegisterOrganizationWithAdminUseCase {
  RegisterOrganizationWithAdminUseCase({
    required OrganizationRepository repository,
  }) : _repository = repository;

  final OrganizationRepository _repository;

  Future<RegisterOrganizationResult> call({
    required OrganizationForm organization,
    required AdminForm admin,
    required String creatorUserId,
  }) async {
    final organizationId = await _repository.createOrganization(
      form: organization,
      creatorUserId: creatorUserId,
    );

    final adminUserId =
        await _repository.createOrUpdateAdmin(admin.normalized());

    // Create default Admin App Access Role for the organization first
    await _repository.createDefaultAdminAppAccessRole(organizationId);

    // Link admin user with app_access_role_id pointing to the default admin role
    await _repository.linkUserWithOrganization(
      userId: adminUserId,
      organizationId: organizationId,
      organizationName: organization.name,
      userName: admin.name,
      role: 'ADMIN',
      appAccessRoleId: 'admin', // Fixed ID of the default admin role
    );

    return RegisterOrganizationResult(
      organizationId: organizationId,
      adminUserId: adminUserId,
    );
  }
}

