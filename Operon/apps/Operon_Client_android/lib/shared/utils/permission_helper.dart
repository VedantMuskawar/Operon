import 'package:dash_mobile/domain/entities/organization_role.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Helper utility for checking page permissions
/// 
/// Usage in pages:
/// ```dart
/// final canCreate = PermissionHelper.canCreate(context, 'products');
/// final canEdit = PermissionHelper.canEdit(context, 'products');
/// final canDelete = PermissionHelper.canDelete(context, 'products');
/// final canAccess = PermissionHelper.canAccessPage(context, 'products');
/// ```
class PermissionHelper {
  /// Get the current role from context
  static OrganizationRole? _getRole(BuildContext context) {
    try {
      final orgState = context.read<OrganizationContextCubit>().state;
      return orgState.role;
    } catch (e) {
      return null;
    }
  }

  /// Check if user can create items on a page
  static bool canCreate(BuildContext context, String pageKey) {
    final role = _getRole(context);
    if (role == null) return false;
    if (role.isAdmin) return true;
    return role.canCreate(pageKey);
  }

  /// Check if user can edit items on a page
  static bool canEdit(BuildContext context, String pageKey) {
    final role = _getRole(context);
    if (role == null) return false;
    if (role.isAdmin) return true;
    return role.canEdit(pageKey);
  }

  /// Check if user can delete items on a page
  static bool canDelete(BuildContext context, String pageKey) {
    final role = _getRole(context);
    if (role == null) return false;
    if (role.isAdmin) return true;
    return role.canDelete(pageKey);
  }

  /// Check if user can access a page at all
  static bool canAccessPage(BuildContext context, String pageKey) {
    final role = _getRole(context);
    if (role == null) return false;
    if (role.isAdmin) return true;
    return role.canAccessPage(pageKey);
  }

  /// Check if user can access a navigation section
  static bool canAccessSection(BuildContext context, String sectionKey) {
    final role = _getRole(context);
    if (role == null) return false;
    if (role.isAdmin) return true;
    return role.canAccessSection(sectionKey);
  }

  /// Check if user is admin
  static bool isAdmin(BuildContext context) {
    final role = _getRole(context);
    return role?.isAdmin ?? false;
  }
}

