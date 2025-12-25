import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/repositories/app_access_roles_repository.dart';
import 'package:dash_web/domain/entities/app_access_role.dart';
import 'package:dash_web/domain/entities/organization_role.dart' show PageCrudPermissions, RolePermissions;
import 'package:dash_web/presentation/blocs/access_control/access_control_cubit.dart';
import 'package:dash_web/presentation/blocs/app_access_roles/app_access_roles_cubit.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

// Navigation Sections
const _sections = [
  _ItemInfo('pendingOrders', 'Pending Orders', Icons.pending_actions, Color(0xFFFF6B6B)),
  _ItemInfo('scheduleOrders', 'Schedule', Icons.schedule, Color(0xFF4ECDC4)),
  _ItemInfo('ordersMap', 'Orders Map', Icons.map_outlined, Color(0xFF95E1D3)),
  _ItemInfo('analyticsDashboard', 'Analytics', Icons.analytics_outlined, Color(0xFFF38181)),
];

// Pages
const _pages = [
  _ItemInfo('products', 'Products', Icons.inventory_2_outlined, Color(0xFF6F4BFF)),
  _ItemInfo('employees', 'Employees', Icons.people_outline, Color(0xFF5AD8A4)),
  _ItemInfo('users', 'Users', Icons.person_outline, Color(0xFFFFC857)),
  _ItemInfo('clients', 'Clients', Icons.business_outlined, Color(0xFF4BD6FF)),
  _ItemInfo('zonesCity', 'Zones • City', Icons.location_city_outlined, Color(0xFF4BD6FF)),
  _ItemInfo('zonesRegion', 'Zones • Region', Icons.map_outlined, Color(0xFFFF6B6B)),
  _ItemInfo('zonesPrice', 'Zones • Price', Icons.attach_money_outlined, Color(0xFF95E1D3)),
  _ItemInfo('vehicles', 'Vehicles', Icons.directions_car_outlined, Color(0xFFF38181)),
  _ItemInfo('paymentAccounts', 'Payment Accounts', Icons.account_balance_wallet_outlined, Color(0xFF6F4BFF)),
  _ItemInfo('roles', 'Roles', Icons.badge_outlined, Color(0xFF9C27B0)),
];

class _ItemInfo {
  const _ItemInfo(this.key, this.label, this.icon, this.color);
  final String key;
  final String label;
  final IconData icon;
  final Color color;
}

class AccessControlPage extends StatefulWidget {
  const AccessControlPage({super.key});

  @override
  State<AccessControlPage> createState() => _AccessControlPageState();
}

class _AccessControlPageState extends State<AccessControlPage> {
  String? _selectedRoleId;

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final orgId = orgState.organization?.id;
    
    if (orgId == null) {
      return SectionWorkspaceLayout(
        panelTitle: 'Access Control',
        currentIndex: -1,
        onNavTap: (index) => context.go('/home?section=$index'),
        child: const Center(child: Text('No organization selected')),
      );
    }
    
    return BlocProvider(
      create: (context) => AppAccessRolesCubit(
        repository: context.read<AppAccessRolesRepository>(),
        orgId: orgId,
      ),
      child: MultiBlocListener(
        listeners: [
          BlocListener<AccessControlCubit, AccessControlState>(
            listener: (context, state) {
              if (state.status == ViewStatus.failure && state.message != null) {
                DashSnackbar.show(context, message: state.message!, isError: true);
              }
              if (state.status == ViewStatus.success && state.showSaveSuccess) {
                DashSnackbar.show(
                  context,
                  message: 'Permissions saved successfully',
                  isError: false,
                );
              }
            },
          ),
          BlocListener<AppAccessRolesCubit, AppAccessRolesState>(
            listener: (context, state) {
              if (state.status == ViewStatus.failure && state.message != null) {
                DashSnackbar.show(context, message: state.message!, isError: true);
              }
              if (state.status == ViewStatus.success) {
                context.read<AccessControlCubit>().load();
                // Reset selection if selected role was deleted
                if (_selectedRoleId != null) {
                  final stillExists = state.roles.any((r) => r.id == _selectedRoleId);
                  if (!stillExists) {
                    setState(() => _selectedRoleId = null);
                  }
                }
              }
            },
          ),
        ],
        child: BlocBuilder<AccessControlCubit, AccessControlState>(
          builder: (context, state) {
            // Auto-select first non-admin role if none selected
            if (_selectedRoleId == null && state.roles.isNotEmpty) {
              final firstNonAdmin = state.roles.firstWhere(
                (r) => !r.isAdmin,
                orElse: () => state.roles.first,
              );
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => _selectedRoleId = firstNonAdmin.id);
                }
              });
            }

            return SectionWorkspaceLayout(
              panelTitle: 'Access Control',
              currentIndex: -1,
              onNavTap: (index) => context.go('/home?section=$index'),
              child: state.status == ViewStatus.loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Panel: Role Management
                        Expanded(
                          flex: 1,
                          child: _RoleManagementPanel(
                            selectedRoleId: _selectedRoleId,
                            onRoleSelected: (roleId) => setState(() => _selectedRoleId = roleId),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Right Panel: Permission Assignment
                        Expanded(
                          flex: 2,
                          child: _selectedRoleId == null
                              ? _EmptyPermissionPanel()
                              : _PermissionAssignmentPanel(
                                  roleId: _selectedRoleId!,
                                  roles: state.roles,
                                  permissions: state.permissions,
                                  sections: state.sections,
                                  hasChanges: state.hasChanges,
                                  isSaving: state.isSaving,
                                  onPermissionChanged: (pageKey, roleId, action, value) =>
                                      context.read<AccessControlCubit>().updatePermission(
                                            pageKey,
                                            roleId,
                                            action,
                                            value,
                                          ),
                                  onSectionChanged: (sectionKey, roleId, value) =>
                                      context.read<AccessControlCubit>().updateSectionAccess(
                                            sectionKey,
                                            roleId,
                                            value,
                                          ),
                                  onSave: () => context.read<AccessControlCubit>().saveChanges(),
                                ),
                        ),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

// Left Panel: Role Management
class _RoleManagementPanel extends StatelessWidget {
  const _RoleManagementPanel({
    required this.selectedRoleId,
    required this.onRoleSelected,
  });

  final String? selectedRoleId;
  final ValueChanged<String> onRoleSelected;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppAccessRolesCubit, AppAccessRolesState>(
      builder: (context, rolesState) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A1A2A), Color(0xFF11111B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6F4BFF), Color(0xFF5A3FE0)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.badge_outlined, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'App Access Roles',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6F4BFF), Color(0xFF5A3FE0)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6F4BFF).withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _openRoleDialog(context),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Add Role',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (rolesState.status == ViewStatus.loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (rolesState.roles.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'No roles yet.\nClick "Add Role" to create one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rolesState.roles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final role = rolesState.roles[index];
                    final isSelected = role.id == selectedRoleId;
                    return _RoleCard(
                      role: role,
                      isSelected: isSelected,
                      onTap: () => onRoleSelected(role.id),
                      onEdit: () => _openRoleDialog(context, role: role),
                      onDelete: () => _confirmDeleteRole(context, role),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openRoleDialog(
    BuildContext context, {
    AppAccessRole? role,
  }) async {
    final cubit = context.read<AppAccessRolesCubit>();
    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (dialogContext) => BlocProvider.value(
        value: cubit,
        child: _RoleDialog(role: role),
      ),
    );
  }

  Future<void> _confirmDeleteRole(BuildContext context, AppAccessRole role) async {
    if (role.isAdmin) {
      DashSnackbar.show(
        context,
        message: 'Cannot delete Admin role',
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF11111B),
        title: const Text(
          'Delete Role',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${role.name}"? This action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await context.read<AppAccessRolesCubit>().deleteAppAccessRole(role.id);
        if (context.mounted) {
          DashSnackbar.show(
            context,
            message: 'Role "${role.name}" deleted successfully',
            isError: false,
          );
        }
      } catch (e) {
        if (context.mounted) {
          DashSnackbar.show(
            context,
            message: 'Failed to delete role: ${e.toString()}',
            isError: true,
          );
        }
      }
    }
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final AppAccessRole role;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Color _hexToColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(role.colorHex);
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.3),
                          color.withValues(alpha: 0.15),
                        ],
                      )
                    : null,
                color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? color.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.1),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              role.name,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            if (role.isAdmin) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.shield, color: Colors.amber, size: 16),
                            ],
                          ],
                        ),
                        if (role.description != null && role.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            role.description!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8), // Space for buttons
                ],
              ),
            ),
          ),
          // Action buttons positioned to prevent InkWell interference
          Positioned(
            right: 8,
            top: 8,
            bottom: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onEdit(),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.edit_outlined, size: 18, color: Colors.white70),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: role.isAdmin
                        ? null
                        : () {
                            onDelete();
                          },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: role.isAdmin
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.redAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: role.isAdmin ? Colors.white30 : Colors.redAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Right Panel: Permission Assignment
class _PermissionAssignmentPanel extends StatelessWidget {
  const _PermissionAssignmentPanel({
    required this.roleId,
    required this.roles,
    required this.permissions,
    required this.sections,
    required this.hasChanges,
    required this.isSaving,
    required this.onPermissionChanged,
    required this.onSectionChanged,
    required this.onSave,
  });

  final String roleId;
  final List<AppAccessRole> roles;
  final Map<String, Map<String, PageCrudPermissions>> permissions;
  final Map<String, Map<String, bool>> sections;
  final bool hasChanges;
  final bool isSaving;
  final Function(String, String, CrudAction, bool) onPermissionChanged;
  final Function(String, String, bool) onSectionChanged;
  final VoidCallback onSave;

  AppAccessRole? get selectedRole {
    try {
      return roles.firstWhere((r) => r.id == roleId);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = selectedRole;
    if (role == null) return const SizedBox.shrink();

    if (role.isAdmin) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.withValues(alpha: 0.2),
              Colors.amber.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.amber.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield, color: Colors.amber, size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              'Admin Role',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This role has full access to all pages and sections.\nNo permissions need to be configured.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2A), Color(0xFF11111B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _hexToColor(role.colorHex).withValues(alpha: 0.3),
                      _hexToColor(role.colorHex).withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.security,
                  color: _hexToColor(role.colorHex),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Permissions for ${role.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Configure what this role can access and do',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Navigation Sections
          _PermissionSection(
            title: 'Navigation Sections',
            icon: Icons.dashboard_outlined,
            items: _sections,
            roleId: roleId,
            sections: sections,
            onChanged: (key, value) => onSectionChanged(key, roleId, value),
          ),
          const SizedBox(height: 32),
          
          // Pages
          _PermissionSection(
            title: 'Pages',
            icon: Icons.pages_outlined,
            items: _pages,
            roleId: roleId,
            permissions: permissions,
            onPermissionChanged: (pageKey, action, value) =>
                onPermissionChanged(pageKey, roleId, action, value),
          ),
          
          // Save Button
          if (hasChanges) ...[
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6F4BFF), Color(0xFF5A3FE0)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6F4BFF).withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isSaving ? null : onSave,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isSaving)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        else ...[
                          const Icon(Icons.save, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Save Changes',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _hexToColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

class _PermissionSection extends StatelessWidget {
  const _PermissionSection({
    required this.title,
    required this.icon,
    required this.items,
    required this.roleId,
    this.sections,
    this.permissions,
    this.onChanged,
    this.onPermissionChanged,
  });

  final String title;
  final IconData icon;
  final List<_ItemInfo> items;
  final String roleId;
  final Map<String, Map<String, bool>>? sections;
  final Map<String, Map<String, PageCrudPermissions>>? permissions;
  final Function(String, bool)? onChanged;
  final Function(String, CrudAction, bool)? onPermissionChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6F4BFF), Color(0xFF5A3FE0)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...items.map((item) {
          if (sections != null && onChanged != null) {
            // Section access toggle
            final hasAccess = sections![item.key]?[roleId] ?? false;
            return _SectionPermissionItem(
              item: item,
              hasAccess: hasAccess,
              onChanged: (value) => onChanged!(item.key, value),
            );
          } else if (permissions != null && onPermissionChanged != null) {
            // Page CRUD permissions
            final rolePerms = permissions![item.key]?[roleId] ?? const PageCrudPermissions();
            return _PagePermissionItem(
              item: item,
              permissions: rolePerms,
              onChanged: (action, value) => onPermissionChanged!(item.key, action, value),
            );
          }
          return const SizedBox.shrink();
        }),
      ],
    );
  }
}

class _SectionPermissionItem extends StatelessWidget {
  const _SectionPermissionItem({
    required this.item,
    required this.hasAccess,
    required this.onChanged,
  });

  final _ItemInfo item;
  final bool hasAccess;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasAccess
              ? item.color.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.1),
          width: hasAccess ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              item.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          Switch(
            value: hasAccess,
            onChanged: onChanged,
            activeColor: item.color,
          ),
        ],
      ),
    );
  }
}

class _PagePermissionItem extends StatelessWidget {
  const _PagePermissionItem({
    required this.item,
    required this.permissions,
    required this.onChanged,
  });

  final _ItemInfo item;
  final PageCrudPermissions permissions;
  final Function(CrudAction, bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CrudToggle(
                  label: 'Create',
                  icon: Icons.add_circle_outline,
                  enabled: permissions.create,
                  color: item.color,
                  onChanged: (value) => onChanged(CrudAction.create, value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CrudToggle(
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                  enabled: permissions.edit,
                  color: item.color,
                  onChanged: (value) => onChanged(CrudAction.edit, value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CrudToggle(
                  label: 'Delete',
                  icon: Icons.delete_outline,
                  enabled: permissions.delete,
                  color: item.color,
                  onChanged: (value) => onChanged(CrudAction.delete, value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CrudToggle extends StatelessWidget {
  const _CrudToggle({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final Color color;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!enabled),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: enabled
                ? color.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: enabled
                  ? color
                  : Colors.white.withValues(alpha: 0.1),
              width: enabled ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: enabled ? color : Colors.white54,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: enabled ? Colors.white : Colors.white70,
                  fontWeight: enabled ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
              if (enabled) ...[
                const SizedBox(height: 2),
                Icon(
                  Icons.check_circle,
                  size: 12,
                  color: color,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPermissionPanel extends StatelessWidget {
  const _EmptyPermissionPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2A), Color(0xFF11111B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.touch_app_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'Select a role to configure permissions',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Role Dialog
class _RoleDialog extends StatefulWidget {
  const _RoleDialog({this.role});

  final AppAccessRole? role;

  @override
  State<_RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends State<_RoleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late String _colorHex;
  bool _isAdmin = false;
  bool _isSubmitting = false;

  static const _colorOptions = [
    '#6F4BFF',
    '#5AD8A4',
    '#FFC857',
    '#FF6B6B',
    '#4BD6FF',
    '#9C27B0',
    '#E91E63',
  ];

  @override
  void initState() {
    super.initState();
    final role = widget.role;
    _nameController = TextEditingController(text: role?.name ?? '');
    _descriptionController = TextEditingController(text: role?.description ?? '');
    _colorHex = role?.colorHex ?? _colorOptions.first;
    _isAdmin = role?.isAdmin ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.role != null;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.9).clamp(400.0, 600.0);

    return AlertDialog(
      backgroundColor: const Color(0xFF11111B),
      title: Text(
        isEditing ? 'Edit App Access Role' : 'Add App Access Role',
        style: const TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Role Name *'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Enter a role name'
                          : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Description (optional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                _ColorSelector(
                  colors: _colorOptions,
                  selected: _colorHex,
                  onSelected: (value) => setState(() => _colorHex = value),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text(
                    'Admin Role (Full Access)',
                    style: TextStyle(color: Colors.white70),
                  ),
                  subtitle: const Text(
                    'Admin roles have full access to all pages and sections',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  value: _isAdmin,
                  onChanged: isEditing && widget.role?.isAdmin == true
                      ? null
                      : (value) => setState(() => _isAdmin = value),
                  activeThumbColor: const Color(0xFF6F4BFF),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () async {
                  if (!(_formKey.currentState?.validate() ?? false)) return;

                  setState(() => _isSubmitting = true);

                  try {
                    final role = AppAccessRole(
                      id: widget.role?.id ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                      name: _nameController.text.trim(),
                      description: _descriptionController.text.trim().isEmpty
                          ? null
                          : _descriptionController.text.trim(),
                      colorHex: _colorHex,
                      isAdmin: _isAdmin,
                      permissions: widget.role?.permissions ?? const RolePermissions(),
                    );

                    final cubit = context.read<AppAccessRolesCubit>();
                    if (isEditing) {
                      await cubit.updateAppAccessRole(role);
                    } else {
                      await cubit.createAppAccessRole(role);
                    }

                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  } catch (e) {
                    if (mounted) {
                      DashSnackbar.show(
                        context,
                        message:
                            'Failed to ${isEditing ? 'update' : 'create'} role: ${e.toString()}',
                        isError: true,
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _isSubmitting = false);
                    }
                  }
                },
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFF1B1B2C),
      labelStyle: const TextStyle(color: Colors.white70),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}

class _ColorSelector extends StatelessWidget {
  const _ColorSelector({
    required this.colors,
    required this.selected,
    required this.onSelected,
  });

  final List<String> colors;
  final String selected;
  final ValueChanged<String> onSelected;

  Color _hexToColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Accent Color',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: colors.map((color) {
            final isActive = color == selected;
            return GestureDetector(
              onTap: () => onSelected(color),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _hexToColor(color),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive ? Colors.white : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: _hexToColor(color).withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: isActive
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
