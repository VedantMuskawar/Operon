class OrganizationUser {
  const OrganizationUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.roleId,
    required this.roleTitle,
    required this.organizationId,
    this.employeeId,
  });

  final String id;
  final String name;
  final String phone;
  final String roleId;
  final String roleTitle;
  final String organizationId;
  final String? employeeId;

  bool get isAdmin => roleTitle.toUpperCase() == 'ADMIN';

  factory OrganizationUser.fromMap(
    Map<String, dynamic> map,
    String id,
    String organizationId,
  ) {
    return OrganizationUser(
      id: id,
      name: map['user_name'] as String? ?? 'Unnamed',
      phone: map['phone'] as String? ?? '',
      roleId: map['role_id'] as String? ?? '',
      roleTitle: map['role_in_org'] as String? ?? '',
      organizationId:
          map['organization_id'] as String? ?? organizationId,
      employeeId: map['employee_id'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_name': name,
      'phone': phone,
      'role_id': roleId,
      'role_in_org': roleTitle,
      'employee_id': employeeId,
      'organization_id': organizationId,
    };
  }
}

