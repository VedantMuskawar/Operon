import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_mobile/presentation/blocs/access_control/access_control_cubit.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:dash_mobile/shared/constants/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

const _sections = [
  _SectionInfo('pendingOrders', 'Pending Orders', Icons.pending_actions, Color(0xFFFF6B6B)),
  _SectionInfo('scheduleOrders', 'Schedule', Icons.schedule, Color(0xFF4ECDC4)),
  _SectionInfo('ordersMap', 'Orders Map', Icons.map_outlined, Color(0xFF95E1D3)),
  _SectionInfo('analyticsDashboard', 'Analytics', Icons.analytics_outlined, Color(0xFFF38181)),
];

const _pages = [
  _PageInfo('pendingOrders', 'Pending Orders', Icons.pending_actions, Color(0xFFFF6B6B)),
  _PageInfo('scheduleOrders', 'Schedule Orders', Icons.schedule, Color(0xFF4ECDC4)),
  _PageInfo('products', 'Products', Icons.inventory_2_outlined, Color(0xFF6F4BFF)),
  _PageInfo('employees', 'Employees', Icons.people_outline, Color(0xFF5AD8A4)),
  _PageInfo('users', 'Users', Icons.person_outline, Color(0xFFFFC857)),
  _PageInfo('clients', 'Clients', Icons.business_outlined, Color(0xFF4BD6FF)),
  _PageInfo('zonesCity', 'Zones • City', Icons.location_city_outlined, Color(0xFF4BD6FF)),
  _PageInfo('zonesRegion', 'Zones • Region', Icons.map_outlined, Color(0xFFFF6B6B)),
  _PageInfo('zonesPrice', 'Zones • Price', Icons.attach_money_outlined, Color(0xFF95E1D3)),
  _PageInfo('vehicles', 'Vehicles', Icons.directions_car_outlined, Color(0xFFF38181)),
  _PageInfo('paymentAccounts', 'Payment Accounts', Icons.account_balance_wallet_outlined, Color(0xFF6F4BFF)),
  _PageInfo('roles', 'Roles', Icons.badge_outlined, Color(0xFF9C27B0)),
  _PageInfo('accessControl', 'Access Control', Icons.security, Color(0xFFE91E63)),
];

class AccessControlPage extends StatelessWidget {
  const AccessControlPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AccessControlCubit, AccessControlState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message!)),
          );
        }
        if (state.status == ViewStatus.success && state.showSaveSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permissions saved successfully'),
              backgroundColor: AuthColors.success,
            ),
          );
        }
      },
      child: BlocBuilder<AccessControlCubit, AccessControlState>(
        builder: (context, state) {
          return Scaffold(
            backgroundColor: AuthColors.background,
            appBar: const ModernPageHeader(
              title: 'Access Control',
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.paddingLG),
                      child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ViewModeSelector(
                  currentMode: state.viewMode,
                  onModeChanged: (mode) =>
                      context.read<AccessControlCubit>().setViewMode(mode),
                ),
                const SizedBox(height: AppSpacing.paddingXXL),
                if (state.status == ViewStatus.loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.paddingXXXL * 1.25),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (state.viewMode == ViewMode.byPage)
                  _ByPageView(
                    roles: state.roles,
                    permissions: state.permissions,
                    sections: state.sections,
                    onPermissionChanged: (pageKey, roleId, permission, value) =>
                        context.read<AccessControlCubit>().updatePermission(
                              pageKey,
                              roleId,
                              permission,
                              value,
                            ),
                    onSectionChanged: (sectionKey, roleId, value) =>
                        context.read<AccessControlCubit>().updateSectionAccess(
                              sectionKey,
                              roleId,
                              value,
                            ),
                  )
                else
                  _ByRoleView(
                    roles: state.roles,
                    permissions: state.permissions,
                    sections: state.sections,
                    onPermissionChanged: (pageKey, roleId, permission, value) =>
                        context.read<AccessControlCubit>().updatePermission(
                              pageKey,
                              roleId,
                              permission,
                              value,
                            ),
                    onSectionChanged: (sectionKey, roleId, value) =>
                        context.read<AccessControlCubit>().updateSectionAccess(
                              sectionKey,
                              roleId,
                              value,
                            ),
                  ),
                if (state.hasChanges) ...[
                  const SizedBox(height: AppSpacing.paddingXXL),
                  _SaveButton(
                    onSave: () => context.read<AccessControlCubit>().saveChanges(),
                    isSaving: state.isSaving,
                  ),
                ],
                      ],
                    ),
                  ),
                ),
                  FloatingNavBar(
                    items: const [
                      NavBarItem(
                        icon: Icons.home_rounded,
                        label: 'Home',
                        heroTag: 'nav_home',
                      ),
                      NavBarItem(
                        icon: Icons.pending_actions_rounded,
                        label: 'Pending',
                        heroTag: 'nav_pending',
                      ),
                      NavBarItem(
                        icon: Icons.schedule_rounded,
                        label: 'Schedule',
                        heroTag: 'nav_schedule',
                      ),
                      NavBarItem(
                        icon: Icons.map_rounded,
                        label: 'Map',
                        heroTag: 'nav_map',
                      ),
                      NavBarItem(
                        icon: Icons.event_available_rounded,
                        label: 'Cash Ledger',
                        heroTag: 'nav_cash_ledger',
                      ),
                    ],
                    currentIndex: -1,
                    onItemTapped: (value) => context.go('/home', extra: value),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ViewModeSelector extends StatelessWidget {
  const _ViewModeSelector({
    required this.currentMode,
    required this.onModeChanged,
  });

  final ViewMode currentMode;
  final ValueChanged<ViewMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.paddingXS),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeButton(
            label: 'By Page',
            icon: Icons.grid_view_outlined,
            isSelected: currentMode == ViewMode.byPage,
            onTap: () => onModeChanged(ViewMode.byPage),
          ),
          const SizedBox(width: AppSpacing.paddingSM),
          _ModeButton(
            label: 'By Role',
            icon: Icons.group_outlined,
            isSelected: currentMode == ViewMode.byRole,
            onTap: () => onModeChanged(ViewMode.byRole),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingXL, vertical: AppSpacing.paddingMD),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [AuthColors.accentPurple, AuthColors.accentPurple.withOpacity(0.8)],
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.white70),
              const SizedBox(width: AppSpacing.paddingSM),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AuthColors.textMain : AuthColors.textSub,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ByPageView extends StatelessWidget {
  const _ByPageView({
    required this.roles,
    required this.permissions,
    required this.sections,
    required this.onPermissionChanged,
    required this.onSectionChanged,
  });

  final List<OrganizationRole> roles;
  final Map<String, Map<String, PageCrudPermissions>> permissions;
  final Map<String, Map<String, bool>> sections;
  final Function(String, String, CrudAction, bool) onPermissionChanged;
  final Function(String, String, bool) onSectionChanged;


  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Navigation Sections',
          icon: Icons.dashboard_outlined,
          count: _sections.length,
        ),
        const SizedBox(height: AppSpacing.paddingLG),
        ..._sections.map((section) => _SectionPermissionCard(
              section: section,
              roles: roles,
              permissions: permissions,
              sections: sections,
              onChanged: (roleId, value) => onSectionChanged(section.key, roleId, value),
            )),
        const SizedBox(height: AppSpacing.paddingXXXL),
        _SectionHeader(
          title: 'Pages',
          icon: Icons.pages_outlined,
          count: _pages.length,
        ),
        const SizedBox(height: AppSpacing.paddingLG),
        ..._pages.map((page) => _PagePermissionCard(
              page: page,
              roles: roles,
              permissions: permissions,
              onChanged: (roleId, action, value) =>
                  onPermissionChanged(page.key, roleId, action, value),
            )),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.count,
  });

  final String title;
  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.paddingMD),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6F4BFF), Color(0xFF5A3FE0)],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: AppSpacing.paddingMD),
        Text(
          title,
          style: const TextStyle(
            color: AuthColors.textMain,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: AppSpacing.paddingSM),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingSM, vertical: AppSpacing.paddingXS),
          decoration: BoxDecoration(
            color: AuthColors.textMainWithOpacity(0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
          ),
          child: Text(
            '$count',
            style: AppTypography.withColor(
              AppTypography.withWeight(AppTypography.labelSmall, FontWeight.w600),
              AuthColors.textSub,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionPermissionCard extends StatelessWidget {
  const _SectionPermissionCard({
    required this.section,
    required this.roles,
    required this.permissions,
    required this.sections,
    required this.onChanged,
  });

  final _SectionInfo section;
  final List<OrganizationRole> roles;
  final Map<String, Map<String, PageCrudPermissions>> permissions;
  final Map<String, Map<String, bool>> sections;
  final Function(String, bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.paddingLG),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            section.color.withOpacity(0.15),
            section.color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
        border: Border.all(
          color: section.color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: section.color.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.paddingXL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.paddingMD),
                  decoration: BoxDecoration(
                    color: section.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                  ),
                  child: Icon(section.icon, color: section.color, size: 24),
                ),
                const SizedBox(width: AppSpacing.paddingLG),
                Expanded(
                  child: Text(
                    section.label,
                    style: AppTypography.withColor(
                      AppTypography.withWeight(AppTypography.h3, FontWeight.w700),
                      AuthColors.textMain,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.paddingXL),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: roles.map((role) {
                final hasAccess = sections[section.key]?[role.id] ?? false;
                return _RoleToggleChip(
                  role: role,
                  hasAccess: hasAccess,
                  onChanged: (value) => onChanged(role.id, value),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PagePermissionCard extends StatelessWidget {
  const _PagePermissionCard({
    required this.page,
    required this.roles,
    required this.permissions,
    required this.onChanged,
  });

  final _PageInfo page;
  final List<OrganizationRole> roles;
  final Map<String, Map<String, PageCrudPermissions>> permissions;
  final Function(String, CrudAction, bool) onChanged;

  bool get _isAdminOnly => page.key == 'roles' || page.key == 'accessControl' || page.key == 'users' || page.key == 'paymentAccounts';

  @override
  Widget build(BuildContext context) {
    if (_isAdminOnly) {
      return Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.paddingXL),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.withOpacity(0.15),
              Colors.amber.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
          border: Border.all(
            color: Colors.amber.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.paddingXL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.paddingMD),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.withOpacity(0.3),
                          Colors.amber.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                    ),
                    child: Icon(page.icon, color: Colors.amber, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.paddingLG),
                  Expanded(
                    child: Text(
                      page.label,
                      style: AppTypography.withColor(
                        AppTypography.withWeight(AppTypography.h3, FontWeight.w700),
                        AuthColors.textMain,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.paddingLG),
              Container(
                padding: const EdgeInsets.all(AppSpacing.paddingLG),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                  border: Border.all(
                    color: Colors.amber.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield, color: Colors.amber, size: 20),
                    const SizedBox(width: AppSpacing.paddingMD),
                    Expanded(
                      child: Text(
                        'Admin-only page. Only users with Admin role can access this page.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.paddingXL),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1A1A2A),
            Color(0xFF0A0A0A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
        border: Border.all(color: Colors.white10, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.paddingXL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.paddingMD),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        page.color.withOpacity(0.3),
                        page.color.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                  ),
                  child: Icon(page.icon, color: page.color, size: 24),
                ),
                const SizedBox(width: AppSpacing.paddingLG),
                Expanded(
                  child: Text(
                    page.label,
                    style: AppTypography.withColor(
                      AppTypography.withWeight(AppTypography.h3, FontWeight.w700),
                      AuthColors.textMain,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.paddingXXL),
            ...roles.map((role) {
              final rolePerms = permissions[page.key]?[role.id] ??
                  const PageCrudPermissions();
              return _RolePermissionRow(
                role: role,
                permissions: rolePerms,
                onChanged: (action, value) => onChanged(role.id, action, value),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _RoleToggleChip extends StatelessWidget {
  const _RoleToggleChip({
    required this.role,
    required this.hasAccess,
    required this.onChanged,
  });

  final OrganizationRole role;
  final bool hasAccess;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: role.isAdmin ? null : () => onChanged(!hasAccess),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingLG, vertical: AppSpacing.paddingMD),
          decoration: BoxDecoration(
            color: hasAccess
                ? const Color(0xFF4CAF50).withOpacity(0.2)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            border: Border.all(
              color: hasAccess
                  ? const Color(0xFF4CAF50)
                  : Colors.white.withOpacity(0.1),
              width: hasAccess ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _hexToColor(role.colorHex),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.paddingSM),
              Text(
                role.title,
                style: AppTypography.withColor(
                  AppTypography.withWeight(
                    AppTypography.bodySmall,
                    hasAccess ? FontWeight.w600 : FontWeight.w500,
                  ),
                  hasAccess ? AuthColors.textMain : AuthColors.textSub,
                ),
              ),
              if (hasAccess) ...[
                const SizedBox(width: AppSpacing.gapSM),
                const Icon(
                  Icons.check_circle,
                  size: 16,
                  color: Color(0xFF4CAF50),
                ),
              ],
              if (role.isAdmin) ...[
                const SizedBox(width: AppSpacing.gapSM),
                const Icon(
                  Icons.shield,
                  size: 14,
                  color: Colors.amber,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RolePermissionRow extends StatelessWidget {
  const _RolePermissionRow({
    required this.role,
    required this.permissions,
    required this.onChanged,
  });

  final OrganizationRole role;
  final PageCrudPermissions permissions;
  final Function(CrudAction, bool) onChanged;

  @override
  Widget build(BuildContext context) {
    if (role.isAdmin) {
      return Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.paddingLG),
        padding: const EdgeInsets.all(AppSpacing.paddingLG),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.withOpacity(0.15),
              Colors.amber.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
          border: Border.all(
            color: Colors.amber.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _hexToColor(role.colorHex),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.paddingMD),
            Expanded(
              child: Text(
                role.title,
                style: AppTypography.withColor(
                  AppTypography.withWeight(AppTypography.body, FontWeight.w600),
                  AuthColors.textMain,
                ),
              ),
            ),
            const Icon(Icons.shield, color: Colors.amber, size: 18),
            const SizedBox(width: AppSpacing.paddingSM),
            Text(
              'Full Access',
              style: AppTypography.withColor(
                AppTypography.withWeight(AppTypography.labelSmall, FontWeight.w600),
                AuthColors.warning,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.paddingLG),
      padding: const EdgeInsets.all(AppSpacing.paddingLG),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _hexToColor(role.colorHex),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.paddingMD),
              Expanded(
                child: Text(
                  role.title,
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.paddingMD),
          Row(
            children: [
              Expanded(
                child: _CrudToggle(
                  label: 'Create',
                  icon: Icons.add_circle_outline,
                  enabled: permissions.create,
                  onChanged: (value) => onChanged(CrudAction.create, value),
                ),
              ),
              const SizedBox(width: AppSpacing.paddingSM),
              Expanded(
                child: _CrudToggle(
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                  enabled: permissions.edit,
                  onChanged: (value) => onChanged(CrudAction.edit, value),
                ),
              ),
              const SizedBox(width: AppSpacing.paddingSM),
              Expanded(
                child: _CrudToggle(
                  label: 'Delete',
                  icon: Icons.delete_outline,
                  enabled: permissions.delete,
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
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!enabled),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingMD, horizontal: AppSpacing.paddingSM),
          decoration: BoxDecoration(
            color: enabled
                ? const Color(0xFF6F4BFF).withOpacity(0.2)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            border: Border.all(
              color: enabled
                  ? const Color(0xFF6F4BFF)
                  : Colors.white.withOpacity(0.1),
              width: enabled ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: enabled ? const Color(0xFF6F4BFF) : Colors.white54,
              ),
              const SizedBox(height: AppSpacing.paddingXS),
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
                const Icon(
                  Icons.check_circle,
                  size: 12,
                  color: Color(0xFF6F4BFF),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ByRoleView extends StatelessWidget {
  const _ByRoleView({
    required this.roles,
    required this.permissions,
    required this.sections,
    required this.onPermissionChanged,
    required this.onSectionChanged,
  });

  final List<OrganizationRole> roles;
  final Map<String, Map<String, PageCrudPermissions>> permissions;
  final Map<String, Map<String, bool>> sections;
  final Function(String, String, CrudAction, bool) onPermissionChanged;
  final Function(String, String, bool) onSectionChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: roles.map((role) {
        return _RoleCard(
          role: role,
          permissions: permissions,
          sections: sections,
          onPermissionChanged: (pageKey, action, value) =>
              onPermissionChanged(pageKey, role.id, action, value),
          onSectionChanged: (sectionKey, value) =>
              onSectionChanged(sectionKey, role.id, value),
        );
      }).toList(),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.permissions,
    required this.sections,
    required this.onPermissionChanged,
    required this.onSectionChanged,
  });

  final OrganizationRole role;
  final Map<String, Map<String, PageCrudPermissions>> permissions;
  final Map<String, Map<String, bool>> sections;
  final Function(String, CrudAction, bool) onPermissionChanged;
  final Function(String, bool) onSectionChanged;

  @override
  Widget build(BuildContext context) {
    if (role.isAdmin) {
      return Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.paddingXL),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.withOpacity(0.2),
              Colors.amber.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
          border: Border.all(
            color: Colors.amber.withOpacity(0.4),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.paddingXXL),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _hexToColor(role.colorHex),
                      _hexToColor(role.colorHex).withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                ),
                child: const Icon(Icons.shield, color: Colors.white, size: 32),
              ),
              const SizedBox(width: AppSpacing.paddingXL),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.title,
                      style: AppTypography.withColor(
                        AppTypography.withWeight(AppTypography.h2, FontWeight.w700),
                        AuthColors.textMain,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.paddingSM),
                    Text(
                      'Full access to all pages and sections',
                      style: AppTypography.withColor(AppTypography.body, AuthColors.textSub),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.verified, color: Colors.amber, size: 32),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.paddingXL),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1A1A2A),
            Color(0xFF0A0A0A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
        border: Border.all(
          color: _hexToColor(role.colorHex).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _hexToColor(role.colorHex).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.paddingXXL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _hexToColor(role.colorHex),
                        _hexToColor(role.colorHex).withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                    boxShadow: [
                      BoxShadow(
                        color: _hexToColor(role.colorHex).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.badge, color: AuthColors.textMain, size: 28),
                ),
                const SizedBox(width: AppSpacing.paddingLG),
                Expanded(
                  child: Text(
                    role.title,
                    style: AppTypography.withColor(
                      AppTypography.withWeight(AppTypography.h2, FontWeight.w700),
                      AuthColors.textMain,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.paddingXXL),
            Text(
              'Navigation Sections',
              style: AppTypography.withColor(
                AppTypography.withWeight(AppTypography.body, FontWeight.w600),
                AuthColors.textSub,
              ),
            ),
            const SizedBox(height: AppSpacing.paddingMD),
            ..._sections.map((section) {
              final hasAccess = sections[section.key]?[role.id] ?? false;
              return _SectionToggleTile(
                section: section,
                hasAccess: hasAccess,
                onChanged: (value) => onSectionChanged(section.key, value),
              );
            }),
            const SizedBox(height: AppSpacing.paddingXXL),
            Text(
              'Page Permissions',
              style: AppTypography.withColor(
                AppTypography.withWeight(AppTypography.body, FontWeight.w600),
                AuthColors.textSub,
              ),
            ),
            const SizedBox(height: AppSpacing.paddingMD),
            ..._pages.map((page) {
              final isAdminOnly = page.key == 'roles' || 
                  page.key == 'accessControl' || 
                  page.key == 'users' || 
                  page.key == 'paymentAccounts';
              
              if (isAdminOnly) {
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.paddingMD),
                  padding: const EdgeInsets.all(AppSpacing.paddingLG),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                    border: Border.all(
                      color: Colors.amber.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.paddingSM),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                        ),
                        child: Icon(page.icon, color: Colors.amber, size: 20),
                      ),
                      const SizedBox(width: AppSpacing.paddingMD),
                      Expanded(
                        child: Text(
                          page.label,
                          style: const TextStyle(
                            color: AuthColors.textMain,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const Icon(Icons.shield, color: Colors.amber, size: 18),
                      const SizedBox(width: AppSpacing.paddingSM),
                      const Text(
                        'Admin Only',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              final rolePerms = permissions[page.key]?[role.id] ??
                  const PageCrudPermissions();
              return _PagePermissionTile(
                page: page,
                permissions: rolePerms,
                onChanged: (action, value) => onPermissionChanged(page.key, action, value),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.onSave,
    required this.isSaving,
  });

  final VoidCallback onSave;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6F4BFF), Color(0xFF5A3FE0)],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6F4BFF).withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isSaving ? null : onSave,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingLG),
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
                  const SizedBox(width: AppSpacing.paddingSM),
                  const Text(
                    'Save Changes',
                    style: TextStyle(
                      color: AuthColors.textMain,
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
    );
  }
}

class _SectionInfo {
  const _SectionInfo(this.key, this.label, this.icon, this.color);
  final String key;
  final String label;
  final IconData icon;
  final Color color;
}

class _PageInfo {
  const _PageInfo(this.key, this.label, this.icon, this.color);
  final String key;
  final String label;
  final IconData icon;
  final Color color;
}

class _SectionToggleTile extends StatelessWidget {
  const _SectionToggleTile({
    required this.section,
    required this.hasAccess,
    required this.onChanged,
  });

  final _SectionInfo section;
  final bool hasAccess;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.paddingMD),
      padding: const EdgeInsets.all(AppSpacing.paddingLG),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border.all(
          color: hasAccess
              ? section.color.withOpacity(0.3)
              : Colors.white.withOpacity(0.08),
          width: hasAccess ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.paddingSM),
            decoration: BoxDecoration(
              color: section.color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            ),
            child: Icon(section.icon, color: section.color, size: 20),
          ),
          const SizedBox(width: AppSpacing.paddingMD),
          Expanded(
            child: Text(
              section.label,
              style: const TextStyle(
                color: AuthColors.textMain,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          Switch(
            value: hasAccess,
            onChanged: onChanged,
            activeThumbColor: section.color,
          ),
        ],
      ),
    );
  }
}

class _PagePermissionTile extends StatelessWidget {
  const _PagePermissionTile({
    required this.page,
    required this.permissions,
    required this.onChanged,
  });

  final _PageInfo page;
  final PageCrudPermissions permissions;
  final Function(CrudAction, bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.paddingLG),
      padding: const EdgeInsets.all(AppSpacing.paddingLG),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.paddingSM),
                decoration: BoxDecoration(
                  color: page.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                ),
                child: Icon(page.icon, color: page.color, size: 20),
              ),
              const SizedBox(width: AppSpacing.paddingMD),
              Expanded(
                child: Text(
                  page.label,
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.paddingMD),
          Row(
            children: [
              Expanded(
                child: _CrudToggle(
                  label: 'Create',
                  icon: Icons.add_circle_outline,
                  enabled: permissions.create,
                  onChanged: (value) => onChanged(CrudAction.create, value),
                ),
              ),
              const SizedBox(width: AppSpacing.paddingSM),
              Expanded(
                child: _CrudToggle(
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                  enabled: permissions.edit,
                  onChanged: (value) => onChanged(CrudAction.edit, value),
                ),
              ),
              const SizedBox(width: AppSpacing.paddingSM),
              Expanded(
                child: _CrudToggle(
                  label: 'Delete',
                  icon: Icons.delete_outline,
                  enabled: permissions.delete,
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

Color _hexToColor(String hex) {
  final buffer = StringBuffer();
  if (hex.length == 6 || hex.length == 7) buffer.write('ff');
  buffer.write(hex.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}

