import 'package:dash_web/domain/entities/app_access_role.dart';

/// Organization User - Represents a user's membership in an organization
/// 
/// Every user must be linked to an employee.
/// App access is controlled via appAccessRoleId.
class OrganizationUser {
  const OrganizationUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.organizationId,
    required this.employeeId,        // ✅ Always required - user must link to employee
    this.trackingEmployeeId,
    this.ledgerEmployeeIds = const <String>[],
    this.defaultLedgerEmployeeId,
    this.appAccessRoleId,            // App access role (for permissions)
    this.appAccessRole,              // Denormalized app access role (loaded separately)
  });

  final String id;
  final String name;
  final String phone;
  final String organizationId;
  final String employeeId;           // ✅ Always linked to an employee
  final String? trackingEmployeeId;
  final List<String> ledgerEmployeeIds;
  final String? defaultLedgerEmployeeId;
  final String? appAccessRoleId;     // App access role ID (for permissions)
  final AppAccessRole? appAccessRole; // Denormalized app access role

  /// Check if user is admin (based on app access role)
  bool get isAdmin => appAccessRole?.isAdmin ?? false;

  /// Check if user can access a navigation section
  bool canAccessSection(String sectionName) {
    return appAccessRole?.canAccessSection(sectionName) ?? false;
  }

  /// Check if user can create items on a page
  bool canCreate(String pageName) {
    return appAccessRole?.canCreate(pageName) ?? false;
  }

  /// Check if user can edit items on a page
  bool canEdit(String pageName) {
    return appAccessRole?.canEdit(pageName) ?? false;
  }

  /// Check if user can delete items on a page
  bool canDelete(String pageName) {
    return appAccessRole?.canDelete(pageName) ?? false;
  }

  /// Check if user can access a page at all
  bool canAccessPage(String pageName) {
    return appAccessRole?.canAccessPage(pageName) ?? false;
  }

  factory OrganizationUser.fromMap(
    Map<String, dynamic> map,
    String id,
    String organizationId,
  ) {
    final legacyEmployeeId = map['employee_id'] as String? ?? '';
    final trackingEmployeeId =
      (map['trackingEmployeeId'] as String?) ??
        (legacyEmployeeId.isNotEmpty ? legacyEmployeeId : null);

    final rawLedgerIds = map['ledgerEmployeeIds'];
    final parsedLedgerIds = rawLedgerIds is List
      ? rawLedgerIds
        .whereType<Object>()
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList()
      : <String>[];

    final defaultLedgerEmployeeId =
      (map['defaultLedgerEmployeeId'] as String?) ??
        (parsedLedgerIds.isNotEmpty
          ? parsedLedgerIds.first
          : trackingEmployeeId);

    final ledgerEmployeeIds = parsedLedgerIds.isNotEmpty
      ? parsedLedgerIds
      : [
        if (trackingEmployeeId != null && trackingEmployeeId.isNotEmpty)
          trackingEmployeeId,
        ];

    return OrganizationUser(
      id: id,
      name: map['user_name'] as String? ?? 'Unnamed',
      phone: map['phone'] as String? ?? '',
      organizationId: map['organization_id'] as String? ?? organizationId,
      employeeId: legacyEmployeeId,
      trackingEmployeeId: trackingEmployeeId,
      ledgerEmployeeIds: ledgerEmployeeIds,
      defaultLedgerEmployeeId: defaultLedgerEmployeeId,
      appAccessRoleId: map['app_access_role_id'] as String? ?? map['role_id'] as String?, // Backward compat
      // appAccessRole is loaded separately, not from map
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_name': name,
      'phone': phone,
      'organization_id': organizationId,
      'employee_id': employeeId,
      if (trackingEmployeeId != null) 'trackingEmployeeId': trackingEmployeeId,
      if (ledgerEmployeeIds.isNotEmpty) 'ledgerEmployeeIds': ledgerEmployeeIds,
      if (defaultLedgerEmployeeId != null)
        'defaultLedgerEmployeeId': defaultLedgerEmployeeId,
      if (appAccessRoleId != null) 'app_access_role_id': appAccessRoleId,
      // Note: appAccessRole is not stored in map (it's loaded separately)
    };
  }

  OrganizationUser copyWith({
    String? id,
    String? name,
    String? phone,
    String? organizationId,
    String? employeeId,
    String? trackingEmployeeId,
    List<String>? ledgerEmployeeIds,
    String? defaultLedgerEmployeeId,
    String? appAccessRoleId,
    AppAccessRole? appAccessRole,
  }) {
    return OrganizationUser(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      organizationId: organizationId ?? this.organizationId,
      employeeId: employeeId ?? this.employeeId,
      trackingEmployeeId: trackingEmployeeId ?? this.trackingEmployeeId,
      ledgerEmployeeIds: ledgerEmployeeIds ?? this.ledgerEmployeeIds,
      defaultLedgerEmployeeId:
          defaultLedgerEmployeeId ?? this.defaultLedgerEmployeeId,
      appAccessRoleId: appAccessRoleId ?? this.appAccessRoleId,
      appAccessRole: appAccessRole ?? this.appAccessRole,
    );
  }
}
