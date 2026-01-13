import 'package:core_models/core_models.dart';

/// App Access Role - Controls user permissions in the application
/// 
/// This role defines what a user can access and do in the app.
/// Separate from job roles which describe organizational positions.
class AppAccessRole {
  const AppAccessRole({
    required this.id,
    required this.name,
    required this.colorHex,
    this.description,
    this.isAdmin = false,
    this.permissions = const RolePermissions(),
  });

  final String id;
  final String name;                    // e.g., "Admin", "Manager", "Operator", "Viewer"
  final String? description;            // Optional description
  final String colorHex;                // For UI display
  final bool isAdmin;                   // Is this an admin role (full access)
  final RolePermissions permissions;    // App access permissions

  /// Check if user can access a navigation section
  bool canAccessSection(String sectionName) {
    if (isAdmin) return true;
    return permissions.canAccessSection(sectionName);
  }

  /// Check if user can create items on a page
  bool canCreate(String pageName) {
    if (isAdmin) return true;
    return permissions.canCreate(pageName);
  }

  /// Check if user can edit items on a page
  bool canEdit(String pageName) {
    if (isAdmin) return true;
    return permissions.canEdit(pageName);
  }

  /// Check if user can delete items on a page
  bool canDelete(String pageName) {
    if (isAdmin) return true;
    return permissions.canDelete(pageName);
  }

  /// Check if user can access a page at all
  bool canAccessPage(String pageName) {
    if (isAdmin) return true;
    return permissions.permissionFor(pageName) != null;
  }

  Map<String, dynamic> toJson() {
    return {
      'roleId': id,
      'name': name,
      if (description != null) 'description': description,
      'colorHex': colorHex,
      'isAdmin': isAdmin,
      'permissions': permissions.toJson(),
    };
  }

  factory AppAccessRole.fromJson(Map<String, dynamic> json, String docId) {
    return AppAccessRole(
      id: json['roleId'] as String? ?? docId,
      name: json['name'] as String? ?? 'Untitled',
      description: json['description'] as String?,
      colorHex: json['colorHex'] as String? ?? '#6F4BFF',
      isAdmin: json['isAdmin'] as bool? ?? false,
      permissions: RolePermissions.fromJson(
        json['permissions'] as Map<String, dynamic>?,
      ),
    );
  }

  AppAccessRole copyWith({
    String? id,
    String? name,
    String? description,
    String? colorHex,
    bool? isAdmin,
    RolePermissions? permissions,
  }) {
    return AppAccessRole(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      colorHex: colorHex ?? this.colorHex,
      isAdmin: isAdmin ?? this.isAdmin,
      permissions: permissions ?? this.permissions,
    );
  }
}
