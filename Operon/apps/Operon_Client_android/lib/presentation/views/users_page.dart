import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/data/repositories/employees_repository.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_mobile/domain/entities/organization_user.dart';
import 'package:dash_mobile/presentation/blocs/users/users_cubit.dart';
import 'package:dash_mobile/presentation/blocs/roles/roles_cubit.dart';
import 'package:dash_mobile/shared/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final roleDetails =
        context.watch<OrganizationContextCubit>().state.appAccessRole;
    final canManageUsers = roleDetails?.isAdmin ?? roleDetails?.canCreate('users') ?? false;

    return BlocListener<UsersCubit, UsersState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message!)),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: const ModernPageHeader(
          title: 'Users',
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
            if (canManageUsers)
              SizedBox(
                width: double.infinity,
                child: DashButton(
                  label: 'Add User',
                  onPressed: () => _openUserDialog(context),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.paddingMD),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                  color: AuthColors.textMainWithOpacity(0.13),
                ),
                child: const Text(
                  'You have read-only access to users.',
                  style: TextStyle(color: AuthColors.textSub),
                ),
              ),
            const SizedBox(height: AppSpacing.paddingXL),
            BlocBuilder<UsersCubit, UsersState>(
              builder: (context, state) {
                if (state.status == ViewStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.users.isEmpty) {
                  return Center(
                    child: Text(
                      'No users yet. Tap “Add User” to invite someone.',
                      style: TextStyle(
                        color: AuthColors.textMainWithOpacity(0.6),
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (int i = 0; i < state.users.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.paddingMD),
                      _UserTile(
                        user: state.users[i],
                        canManage: canManageUsers,
                        onEdit: canManageUsers
                            ? () => _openUserDialog(context, user: state.users[i])
                            : null,
                        onDelete: canManageUsers
                            ? () => context.read<UsersCubit>().deleteUser(state.users[i].id)
                            : null,
                      ),
                    ],
                  ],
                );
              },
            ),
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
              currentIndex: -1, // -1 means no selection when on this page
              onItemTapped: (value) => context.go('/home', extra: value),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _openUserDialog(
    BuildContext context, {
    OrganizationUser? user,
  }) async {
    final usersCubit = context.read<UsersCubit>();
    final rolesCubit = context.read<RolesCubit>();
    await showDialog(
      context: context,
      builder: (dialogContext) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: usersCubit),
          BlocProvider.value(value: rolesCubit),
        ],
        child: _UserDialog(user: user),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.canManage,
    this.onEdit,
    this.onDelete,
  });

  final OrganizationUser user;
  final bool canManage;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.paddingLG),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AuthColors.surface, AuthColors.background],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AuthColors.textMainWithOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.person_outline, color: AuthColors.textMain),
          ),
          const SizedBox(width: AppSpacing.paddingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.paddingXS),
                Text(
                  user.phone,
                  style: const TextStyle(color: AuthColors.textSub, fontSize: 12),
                ),
                const SizedBox(height: AppSpacing.paddingXS),
                Text(
                  user.roleTitle,
                  style: const TextStyle(color: AuthColors.textDisabled, fontSize: 12),
                ),
              ],
            ),
          ),
          if (canManage)
            IconButton(
              icon: const Icon(Icons.edit, color: AuthColors.textSub),
              onPressed: onEdit,
            ),
          if (canManage)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AuthColors.error),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

class _UserDialog extends StatefulWidget {
  const _UserDialog({this.user});

  final OrganizationUser? user;

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  OrganizationRole? _selectedRole;
  String? _selectedEmployeeId;
  bool _isSubmitting = false;
  bool _isLoadingEmployees = true;
  List<OrganizationEmployee> _employees = const [];

  OrganizationRole? _currentRole(List<OrganizationRole> roles) {
    if (_selectedRole != null) return _selectedRole;
    if (widget.user != null) {
      try {
        return roles.firstWhere(
          (role) => role.title == widget.user!.roleTitle,
        );
      } catch (_) {
        return roles.isNotEmpty ? roles.first : null;
      }
    }
    return roles.isNotEmpty ? roles.first : null;
  }

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _selectedEmployeeId = user?.employeeId;
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    final employeesRepository = context.read<EmployeesRepository>();
    final usersCubit = context.read<UsersCubit>();
    try {
      final employees =
          await employeesRepository.fetchEmployees(usersCubit.organizationId);
      if (mounted) {
        setState(() {
          _employees = employees;
          _isLoadingEmployees = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingEmployees = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rolesState = context.watch<RolesCubit>().state;
    final roles = [
      ...rolesState.roles,
    ];
    final hasAdmin =
        roles.any((role) => role.title.toUpperCase() == 'ADMIN');
    if (!hasAdmin) {
      roles.add(
        const OrganizationRole(
          id: 'admin-default',
          title: 'ADMIN',
          salaryType: SalaryType.salaryMonthly,
          colorHex: '#6F4BFF',
          permissions: RolePermissions(),
        ),
      );
    }
    final isEditing = widget.user != null;

    if (roles.isEmpty) {
      return AlertDialog(
        backgroundColor: AuthColors.surface,
        title: const Text('Add User', style: TextStyle(color: AuthColors.textMain)),
        content: const Text(
          'Create at least one role before adding users.',
          style: TextStyle(color: AuthColors.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: AuthColors.textSub)),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: AuthColors.surface,
      title: Text(
        isEditing ? 'Edit User' : 'Add User',
        style: const TextStyle(color: AuthColors.textMain),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: AuthColors.textMain),
                decoration: _inputDecoration('Name'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Enter name'
                        : null,
              ),
              const SizedBox(height: AppSpacing.paddingMD),
              TextFormField(
                controller: _phoneController,
                style: const TextStyle(color: AuthColors.textMain),
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration('Phone number'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Enter phone number'
                        : null,
              ),
              const SizedBox(height: AppSpacing.paddingMD),
              DropdownButtonFormField<OrganizationRole>(
                initialValue: _currentRole(roles),
                dropdownColor: AuthColors.surface,
                style: const TextStyle(color: AuthColors.textMain),
                items: roles
                    .map(
                      (role) => DropdownMenuItem(
                        value: role,
                        child: Text(role.title),
                      ),
                    )
                    .toList(),
                onChanged: (role) => setState(() {
                  _selectedRole = role;
                  if (role?.title.toUpperCase() == 'ADMIN') {
                    _selectedEmployeeId = null;
                  }
                }),
                decoration: _inputDecoration('Role'),
                validator: (value) =>
                    value == null ? 'Select a role' : null,
              ),
              if (_shouldShowEmployeeDropdown(roles))
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.paddingMD),
                  child: _buildEmployeeDropdown(roles),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AuthColors.textSub)),
        ),
        DashButton(
          label: isEditing ? 'Save' : 'Create',
          onPressed: _isSubmitting
              ? null
              : () async {
                  if (!(_formKey.currentState?.validate() ?? false)) return;
                  final role = _currentRole(roles);
                  if (role == null) return;
                  if (role.title.toUpperCase() != 'ADMIN' &&
                      _selectedEmployeeId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Select an employee for non-admin users.',
                        ),
                      ),
                    );
                    return;
                  }

                  setState(() => _isSubmitting = true);
                  try {
                    final usersCubit = context.read<UsersCubit>();
                    final user = OrganizationUser(
                      id: widget.user?.id ?? '',
                      name: _nameController.text.trim(),
                      phone: _phoneController.text.trim(),
                      roleId: role.id,
                      roleTitle: role.title,
                      organizationId: usersCubit.organizationId,
                      employeeId: role.title.toUpperCase() == 'ADMIN'
                          ? null
                          : _selectedEmployeeId,
                    );
                    await usersCubit.upsertUser(user);
                    if (mounted) Navigator.of(context).pop();
                  } finally {
                    if (mounted) {
                      setState(() => _isSubmitting = false);
                    }
                  }
                },
          isLoading: _isSubmitting,
        ),
      ],
    );
  }

  bool _shouldShowEmployeeDropdown(List<OrganizationRole> roles) {
    final role = _currentRole(roles);
    return role != null && role.title.toUpperCase() != 'ADMIN';
  }

  Widget _buildEmployeeDropdown(List<OrganizationRole> roles) {
    if (_isLoadingEmployees) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.paddingSM),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_employees.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.paddingMD),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          color: AuthColors.surface,
          border: Border.all(
            color: AuthColors.textMain.withOpacity(0.1),
          ),
        ),
        child: const Text(
          'No employees found. Add employees first.',
          style: TextStyle(color: AuthColors.textSub),
        ),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: _selectedEmployeeId,
      dropdownColor: AuthColors.surface,
      style: const TextStyle(color: AuthColors.textMain),
      items: _employees
          .map(
            (employee) => DropdownMenuItem(
              value: employee.id,
              child: Text(employee.name),
            ),
          )
          .toList(),
      onChanged: (value) => setState(() => _selectedEmployeeId = value),
      decoration: _inputDecoration('Linked Employee'),
      validator: (value) =>
          _shouldShowEmployeeDropdown(roles) && value == null
              ? 'Select employee'
              : null,
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AuthColors.surface,
      labelStyle: const TextStyle(color: AuthColors.textSub),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        borderSide: BorderSide.none,
      ),
    );
  }
}

