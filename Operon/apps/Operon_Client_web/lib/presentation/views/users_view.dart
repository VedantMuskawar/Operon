import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/repositories/app_access_roles_repository.dart';
import 'package:dash_web/data/repositories/employees_repository.dart';
import 'package:dash_web/data/repositories/users_repository.dart';
import 'package:dash_web/domain/entities/app_access_role.dart';
import 'package:dash_web/domain/entities/organization_employee.dart';
import 'package:dash_web/domain/entities/organization_user.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/blocs/users/users_cubit.dart';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';

class WebUsersView extends StatelessWidget {
  const WebUsersView({super.key});

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;

    if (organization == null) {
      return const Scaffold(
        body: Center(child: Text('No organization selected')),
      );
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider<UsersCubit>(
          create: (context) => UsersCubit(
            repository: context.read<UsersRepository>(),
            appAccessRolesRepository: context.read<AppAccessRolesRepository>(),
            organizationId: organization.id,
            organizationName: organization.name,
          )..load(),
        ),
      ],
      child: SectionWorkspaceLayout(
        panelTitle: 'Users',
        currentIndex: -1, // No home section active on Users page
        onNavTap: (index) => context.go('/home?section=$index'),
        child: const UsersPageContent(),
      ),
    );
  }
}

// Content widget for sidebar use (like RolesPageContent)
class UsersPageContent extends StatelessWidget {
  const UsersPageContent({super.key});

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    final appAccessRole = orgState.appAccessRole;
    final canManageUsers =
        appAccessRole?.isAdmin ?? appAccessRole?.canCreate('users') ?? false;

    if (organization == null) {
      return const Center(child: Text('No organization selected'));
    }

    return BlocListener<UsersCubit, UsersState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          DashSnackbar.show(
            context,
            message: state.message!,
            isError: true,
          );
        }
      },
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0x22FFFFFF),
              ),
              child: const Text(
                'You have read-only access to users.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          const SizedBox(height: 20),
          BlocBuilder<UsersCubit, UsersState>(
            builder: (context, state) {
              if (state.status == ViewStatus.loading) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SkeletonLoader(
                          height: 40,
                          width: double.infinity,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        const SizedBox(height: 16),
                        ...List.generate(6, (_) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SkeletonLoader(
                            height: 64,
                            width: double.infinity,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        )),
                      ],
                    ),
                  ),
                );
              }
              if (state.users.isEmpty) {
                return const EmptyState(
                  icon: Icons.people_outline,
                  title: 'No users yet',
                  message: 'Tap "Add User" to invite someone.',
                );
              }
              return AnimationLimiter(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final user = state.users[index];
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 200),
                      child: SlideAnimation(
                        verticalOffset: 50.0,
                        child: FadeInAnimation(
                          curve: Curves.easeOut,
                          child: _UserTile(
                            user: user,
                            canManage: canManageUsers,
                            onEdit: canManageUsers
                                ? () => _openUserDialog(context, user: user)
                                : null,
                            onDelete: canManageUsers
                                ? () => context.read<UsersCubit>().deleteUser(user.id)
                                : null,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openUserDialog(
    BuildContext context, {
    OrganizationUser? user,
  }) async {
    final usersCubit = context.read<UsersCubit>();
    await showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: usersCubit,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2A), Color(0xFF11111B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.person_outline, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.phone,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  user.appAccessRole?.name ?? 'No role',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                if (user.employeeId.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Employee ID: ${user.employeeId}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          if (canManage)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white54),
              onPressed: onEdit,
            ),
          if (canManage)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
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
  AppAccessRole? _selectedAppAccessRole;
  String? _selectedEmployeeId;
  bool _isSubmitting = false;
  bool _isLoadingEmployees = true;
  bool _isLoadingAppAccessRoles = true;
  List<OrganizationEmployee> _employees = const [];
  List<AppAccessRole> _appAccessRoles = const [];

  AppAccessRole? _currentAppAccessRole() {
    if (_selectedAppAccessRole != null) return _selectedAppAccessRole;
    if (widget.user != null && widget.user!.appAccessRole != null) {
      return widget.user!.appAccessRole;
    }
    return _appAccessRoles.isNotEmpty ? _appAccessRoles.first : null;
  }

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _selectedEmployeeId = user?.employeeId;
    _loadEmployees();
    _loadAppAccessRoles();
  }

  Future<void> _loadEmployees() async {
    final usersCubit = context.read<UsersCubit>();
    try {
      final employeesRepository = context.read<EmployeesRepository>();
      final orgId = usersCubit.organizationId;
      
      final employees = await employeesRepository.fetchEmployees(orgId);
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

  Future<void> _loadAppAccessRoles() async {
    final usersCubit = context.read<UsersCubit>();
    try {
      final appAccessRolesRepository = context.read<AppAccessRolesRepository>();
      final roles = await appAccessRolesRepository.fetchAppAccessRoles(
        usersCubit.organizationId,
      );
      if (mounted) {
        setState(() {
          _appAccessRoles = roles;
          _isLoadingAppAccessRoles = false;
          // Initialize selected role if user exists
          if (widget.user != null && widget.user!.appAccessRole != null) {
            _selectedAppAccessRole = widget.user!.appAccessRole;
          } else if (roles.isNotEmpty) {
            _selectedAppAccessRole = roles.first;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingAppAccessRoles = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.user != null;

    if (_isLoadingAppAccessRoles || _appAccessRoles.isEmpty) {
      return AlertDialog(
        backgroundColor: const Color(0xFF11111B),
        title: Text(
          isEditing ? 'Edit User' : 'Add User',
          style: const TextStyle(color: Colors.white),
        ),
        content: _isLoadingAppAccessRoles
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              )
            : const Text(
                'Create at least one app access role before adding users.',
                style: TextStyle(color: Colors.white70),
              ),
        actions: [
          DashButton(
            label: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            variant: DashButtonVariant.text,
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: const Color(0xFF11111B),
      title: Text(
        isEditing ? 'Edit User' : 'Add User',
        style: const TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Name'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Enter name'
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration('Phone number'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Enter phone number'
                        : null,
              ),
              const SizedBox(height: 12),
              
              // App Access Role Dropdown
              DropdownButtonFormField<AppAccessRole>(
                initialValue: _currentAppAccessRole(),
                dropdownColor: const Color(0xFF1B1B2C),
                style: const TextStyle(color: Colors.white),
                items: _appAccessRoles
                    .map(
                      (role) => DropdownMenuItem(
                        value: role,
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _hexToColor(role.colorHex),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(role.name),
                            if (role.isAdmin) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'ADMIN',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (role) {
                  setState(() {
                    _selectedAppAccessRole = role;
                  });
                },
                decoration: _inputDecoration('App Access Role *'),
                validator: (value) => value == null ? 'Select an app access role' : null,
              ),
              const SizedBox(height: 12),
              
              // Employee Selection (Required)
              if (_isLoadingEmployees)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_employees.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.orange.withValues(alpha: 0.1),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, 
                        color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No employees found. Create an employee first.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedEmployeeId,
                  dropdownColor: const Color(0xFF1B1B2C),
                  style: const TextStyle(color: Colors.white),
                  items: _employees
                      .map(
                        (employee) => DropdownMenuItem(
                          value: employee.id,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(employee.name),
                              if (employee.jobRoleTitles.isNotEmpty)
                                Text(
                                  employee.jobRoleTitles,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedEmployeeId = value;
                    });
                  },
                  decoration: _inputDecoration('Employee *'),
                  validator: (value) => value == null ? 'Select an employee' : null,
                ),
            ],
          ),
        ),
      ),
      actions: [
        DashButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
          variant: DashButtonVariant.text,
        ),
        DashButton(
          label: 'Save',
          onPressed: _isSubmitting
              ? null
              : () async {
                  if (!(_formKey.currentState?.validate() ?? false)) return;
                  final appAccessRole = _currentAppAccessRole();
                  if (appAccessRole == null) {
                    DashSnackbar.show(
                      context,
                      message: 'Select an app access role',
                      isError: true,
                    );
                    return;
                  }
                  if (_selectedEmployeeId == null) {
                    DashSnackbar.show(
                      context,
                      message: 'Select an employee (required)',
                      isError: true,
                    );
                    return;
                  }

                  setState(() => _isSubmitting = true);
                  try {
                    final usersCubit = context.read<UsersCubit>();
                    // Normalize phone number: add +91 prefix if not present
                    final phoneNumber = _normalizePhoneNumber(_phoneController.text.trim());
                    final user = OrganizationUser(
                      id: widget.user?.id ?? '',
                      name: _nameController.text.trim(),
                      phone: phoneNumber,
                      appAccessRoleId: appAccessRole.id,
                      appAccessRole: appAccessRole,
                      organizationId: usersCubit.organizationId,
                      employeeId: _selectedEmployeeId!,
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
          variant: DashButtonVariant.text,
        ),
      ],
    );
  }

  Color _hexToColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  /// Normalizes phone number by adding +91 prefix if not present
  /// Handles various formats: +91XXXXXXXXXX, 91XXXXXXXXXX, 0XXXXXXXXXX, XXXXXXXXXX
  String _normalizePhoneNumber(String phone) {
    if (phone.isEmpty) return phone;
    
    // Remove all spaces, dashes, and parentheses
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    // If already starts with +91, return as is
    if (cleaned.startsWith('+91')) {
      return cleaned;
    }
    
    // If starts with 91 (without +), add +
    if (cleaned.startsWith('91') && cleaned.length >= 12) {
      return '+$cleaned';
    }
    
    // If starts with 0, remove 0 and add +91
    if (cleaned.startsWith('0') && cleaned.length >= 11) {
      return '+91${cleaned.substring(1)}';
    }
    
    // If it's a 10-digit number, add +91 prefix
    if (RegExp(r'^\d{10}$').hasMatch(cleaned)) {
      return '+91$cleaned';
    }
    
    // For any other format, just add +91 if it doesn't start with +
    if (!cleaned.startsWith('+')) {
      return '+91$cleaned';
    }
    
    // Return as is if it already has a + prefix (international format)
    return cleaned;
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
