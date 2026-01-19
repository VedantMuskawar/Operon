class OrganizationMembership {
  const OrganizationMembership({
    required this.id,
    required this.name,
    required this.role,
    this.appAccessRoleId,
  });

  final String id;
  final String name;
  final String role; // Keep for backward compatibility
  final String? appAccessRoleId; // Direct reference to App Access Role

  /// Get the App Access Role ID, with fallback to role if not set
  String get effectiveAppAccessRoleId => appAccessRoleId ?? role;
}

