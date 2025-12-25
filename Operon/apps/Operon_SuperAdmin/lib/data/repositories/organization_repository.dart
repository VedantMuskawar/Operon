import 'dart:math';

import 'package:dash_superadmin/data/datasources/organization_remote_data_source.dart';
import 'package:dash_superadmin/domain/entities/admin_form.dart';
import 'package:dash_superadmin/domain/entities/organization_form.dart';
import 'package:dash_superadmin/domain/entities/organization_summary.dart';

class OrganizationRepository {
  OrganizationRepository({
    OrganizationRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource =
            remoteDataSource ?? OrganizationRemoteDataSource();

  final OrganizationRemoteDataSource _remoteDataSource;

  Future<String> createOrganization({
    required OrganizationForm form,
    required String creatorUserId,
  }) {
    return _remoteDataSource.createOrganization(
      name: form.name,
      industry: form.industry,
      businessId: form.businessId,
      creatorUserId: creatorUserId,
      orgCode: _generateOrgCode(),
    );
  }

  Future<String> createOrUpdateAdmin(AdminForm form) {
    final normalizedPhone = form.phone.trim();
    return _remoteDataSource.createOrUpdateAdmin(
      name: form.name,
      phone: normalizedPhone,
    );
  }

  Future<void> linkUserWithOrganization({
    required String userId,
    required String organizationId,
    required String organizationName,
    required String userName,
    required String role,
    String? appAccessRoleId,
  }) {
    return _remoteDataSource.linkUserOrganization(
      userId: userId,
      organizationId: organizationId,
      organizationName: organizationName,
      userName: userName,
      roleInOrg: role,
      appAccessRoleId: appAccessRoleId,
    );
  }

  /// Creates the default Admin App Access Role for a new organization
  Future<void> createDefaultAdminAppAccessRole(String organizationId) {
    return _remoteDataSource.createDefaultAdminAppAccessRole(organizationId);
  }

  Stream<List<OrganizationSummary>> watchOrganizations() {
    return _remoteDataSource.watchOrganizations().map(
          (records) => records
              .map(
                (record) => OrganizationSummary(
                  id: record.id,
                  name: record.name,
                  industry: record.industry,
                  orgCode: record.orgCode,
                  createdAt: record.createdAt,
                ),
              )
              .toList(),
        );
  }

  Future<void> deleteOrganization(String organizationId) {
    return _remoteDataSource.deleteOrganization(organizationId);
  }

  Future<void> updateOrganization({
    required String organizationId,
    required String name,
    required String industry,
    String? businessId,
  }) {
    return _remoteDataSource.updateOrganization(
      organizationId: organizationId,
      name: name,
      industry: industry,
      businessId: businessId,
    );
  }

  String _generateOrgCode() {
    const characters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    final buffer = StringBuffer('ORG-');
    for (var i = 0; i < 6; i++) {
      buffer.write(characters[rand.nextInt(characters.length)]);
    }
    return buffer.toString();
  }
}

