import 'package:core_bloc/core_bloc.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum ViewMode { byPage, byRole }

enum CrudAction { create, edit, delete }

class AccessControlState extends BaseState {
  const AccessControlState({
    super.status = ViewStatus.initial,
    this.roles = const [],
    this.permissions = const {},
    this.sections = const {},
    this.viewMode = ViewMode.byPage,
    this.hasChanges = false,
    this.isSaving = false,
    this.showSaveSuccess = false,
    super.message,
  });

  final List<OrganizationRole> roles;
  final Map<String, Map<String, PageCrudPermissions>> permissions; // pageKey -> roleId -> permissions
  final Map<String, Map<String, bool>> sections; // sectionKey -> roleId -> hasAccess
  final ViewMode viewMode;
  final bool hasChanges;
  final bool isSaving;
  final bool showSaveSuccess;

  @override
  AccessControlState copyWith({
    ViewStatus? status,
    List<OrganizationRole>? roles,
    Map<String, Map<String, PageCrudPermissions>>? permissions,
    Map<String, Map<String, bool>>? sections,
    ViewMode? viewMode,
    bool? hasChanges,
    bool? isSaving,
    bool? showSaveSuccess,
    String? message,
  }) {
    return AccessControlState(
      status: status ?? this.status,
      roles: roles ?? this.roles,
      permissions: permissions ?? this.permissions,
      sections: sections ?? this.sections,
      viewMode: viewMode ?? this.viewMode,
      hasChanges: hasChanges ?? this.hasChanges,
      isSaving: isSaving ?? this.isSaving,
      showSaveSuccess: showSaveSuccess ?? this.showSaveSuccess,
      message: message ?? this.message,
    );
  }
}

class AccessControlCubit extends Cubit<AccessControlState> {
  AccessControlCubit({
    required RolesRepository rolesRepository,
    required String orgId,
  })  : _rolesRepository = rolesRepository,
        _orgId = orgId,
        super(const AccessControlState()) {
    load();
  }

  final RolesRepository _rolesRepository;
  final String _orgId;

  Map<String, Map<String, PageCrudPermissions>> _originalPermissions = {};
  Map<String, Map<String, bool>> _originalSections = {};

  Future<void> load() async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      final roles = await _rolesRepository.fetchRoles(_orgId);
      
      // Extract permissions from roles
      final permissions = <String, Map<String, PageCrudPermissions>>{};
      final sections = <String, Map<String, bool>>{};
      
      for (final role in roles) {
        if (role.isAdmin) continue; // Skip admin, they have full access
        
        // Extract page permissions
        for (final entry in role.permissions.pages.entries) {
          final pageKey = entry.key;
          final pagePerms = entry.value;
          
          if (!permissions.containsKey(pageKey)) {
            permissions[pageKey] = {};
          }
          permissions[pageKey]![role.id] = pagePerms;
        }
        
        // Extract section access
        for (final entry in role.permissions.sections.entries) {
          final sectionKey = entry.key;
          final hasAccess = entry.value;
          
          if (!sections.containsKey(sectionKey)) {
            sections[sectionKey] = {};
          }
          sections[sectionKey]![role.id] = hasAccess;
        }
      }
      
      _originalPermissions = _deepCopyPermissions(permissions);
      _originalSections = _deepCopySections(sections);
      
      emit(state.copyWith(
        status: ViewStatus.success,
        roles: roles,
        permissions: permissions,
        sections: sections,
        hasChanges: false,
      ));
    } catch (error) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to load access control data.',
      ));
    }
  }

  void setViewMode(ViewMode mode) {
    emit(state.copyWith(viewMode: mode));
  }

  void updatePermission(
    String pageKey,
    String roleId,
    CrudAction action,
    bool value,
  ) {
    final updatedPermissions = _deepCopyPermissions(state.permissions);
    
    if (!updatedPermissions.containsKey(pageKey)) {
      updatedPermissions[pageKey] = {};
    }
    
    final rolePerms = updatedPermissions[pageKey]![roleId] ?? 
        const PageCrudPermissions();
    
    final updatedPerms = rolePerms.copyWith(
      create: action == CrudAction.create ? value : rolePerms.create,
      edit: action == CrudAction.edit ? value : rolePerms.edit,
      delete: action == CrudAction.delete ? value : rolePerms.delete,
    );
    
    updatedPermissions[pageKey]![roleId] = updatedPerms;
    
    final hasChanges = _hasChanges(updatedPermissions, state.sections);
    
    emit(state.copyWith(
      permissions: updatedPermissions,
      hasChanges: hasChanges,
    ));
  }

  void updateSectionAccess(
    String sectionKey,
    String roleId,
    bool value,
  ) {
    final updatedSections = _deepCopySections(state.sections);
    
    if (!updatedSections.containsKey(sectionKey)) {
      updatedSections[sectionKey] = {};
    }
    
    updatedSections[sectionKey]![roleId] = value;
    
    final hasChanges = _hasChanges(state.permissions, updatedSections);
    
    emit(state.copyWith(
      sections: updatedSections,
      hasChanges: hasChanges,
    ));
  }

  Future<void> saveChanges() async {
    emit(state.copyWith(isSaving: true, message: null));
    
    try {
      // Update all roles with new permissions
      for (final role in state.roles) {
        if (role.isAdmin) continue;
        
        // Build updated page permissions
        final updatedPages = <String, PageCrudPermissions>{};
        for (final pageEntry in state.permissions.entries) {
          final pageKey = pageEntry.key;
          final rolePerms = pageEntry.value[role.id];
          if (rolePerms != null) {
            updatedPages[pageKey] = rolePerms;
          }
        }
        
        // Build updated section access
        final updatedSections = <String, bool>{};
        for (final sectionEntry in state.sections.entries) {
          final sectionKey = sectionEntry.key;
          final hasAccess = sectionEntry.value[role.id] ?? false;
          updatedSections[sectionKey] = hasAccess;
        }
        
        final updatedPermissions = RolePermissions(
          sections: updatedSections,
          pages: updatedPages,
        );
        
        final updatedRole = role.copyWith(permissions: updatedPermissions);
        await _rolesRepository.updateRole(_orgId, updatedRole);
      }
      
      // Update originals to match current state
      _originalPermissions = _deepCopyPermissions(state.permissions);
      _originalSections = _deepCopySections(state.sections);
      
      emit(state.copyWith(
        isSaving: false,
        hasChanges: false,
        showSaveSuccess: true,
      ));
      
      // Reset success flag after a moment
      await Future.delayed(const Duration(seconds: 1));
      emit(state.copyWith(showSaveSuccess: false));
    } catch (error) {
      emit(state.copyWith(
        isSaving: false,
        status: ViewStatus.failure,
        message: 'Failed to save changes. Please try again.',
      ));
    }
  }

  bool _hasChanges(
    Map<String, Map<String, PageCrudPermissions>> currentPermissions,
    Map<String, Map<String, bool>> currentSections,
  ) {
    // Compare permissions
    if (currentPermissions.length != _originalPermissions.length) {
      return true;
    }
    
    for (final pageEntry in currentPermissions.entries) {
      final pageKey = pageEntry.key;
      final rolePerms = pageEntry.value;
      final originalRolePerms = _originalPermissions[pageKey];
      
      if (originalRolePerms == null) return true;
      if (rolePerms.length != originalRolePerms.length) return true;
      
      for (final roleEntry in rolePerms.entries) {
        final roleId = roleEntry.key;
        final perms = roleEntry.value;
        final originalPerms = originalRolePerms[roleId];
        
        if (originalPerms == null ||
            originalPerms.create != perms.create ||
            originalPerms.edit != perms.edit ||
            originalPerms.delete != perms.delete) {
          return true;
        }
      }
    }
    
    // Compare sections
    if (currentSections.length != _originalSections.length) {
      return true;
    }
    
    for (final sectionEntry in currentSections.entries) {
      final sectionKey = sectionEntry.key;
      final roleAccess = sectionEntry.value;
      final originalRoleAccess = _originalSections[sectionKey];
      
      if (originalRoleAccess == null) return true;
      if (roleAccess.length != originalRoleAccess.length) return true;
      
      for (final roleEntry in roleAccess.entries) {
        final roleId = roleEntry.key;
        final hasAccess = roleEntry.value;
        final originalAccess = originalRoleAccess[roleId];
        
        if (originalAccess != hasAccess) {
          return true;
        }
      }
    }
    
    return false;
  }

  Map<String, Map<String, PageCrudPermissions>> _deepCopyPermissions(
    Map<String, Map<String, PageCrudPermissions>> source,
  ) {
    final copy = <String, Map<String, PageCrudPermissions>>{};
    for (final entry in source.entries) {
      copy[entry.key] = Map<String, PageCrudPermissions>.from(entry.value);
    }
    return copy;
  }

  Map<String, Map<String, bool>> _deepCopySections(
    Map<String, Map<String, bool>> source,
  ) {
    final copy = <String, Map<String, bool>>{};
    for (final entry in source.entries) {
      copy[entry.key] = Map<String, bool>.from(entry.value);
    }
    return copy;
  }
}

