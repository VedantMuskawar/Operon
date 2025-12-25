import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/domain/entities/organization_employee.dart';
import 'package:dash_mobile/domain/entities/organization_role.dart';
import 'package:dash_mobile/presentation/blocs/employees/employees_cubit.dart';
import 'package:dash_mobile/presentation/widgets/page_workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class EmployeesPage extends StatelessWidget {
  const EmployeesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<EmployeesCubit>();
    return BlocListener<EmployeesCubit, EmployeesState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message!)),
          );
        }
      },
      child: PageWorkspaceLayout(
        title: 'Employees',
        currentIndex: 4,
        onBack: () => context.go('/home'),
        onNavTap: (value) => context.go('/home', extra: value),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xFF13131E),
                border: Border.all(color: Colors.white12),
              ),
              child: const Text(
                'Maintain workforce data with role-linked permissions and balances.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 20),
            if (cubit.canCreate)
              SizedBox(
                width: double.infinity,
                child: DashButton(
                  label: 'Add Employee',
                  onPressed: () => _openEmployeeDialog(context),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0x22FFFFFF),
                ),
                child: const Text(
                  'You have read-only access.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            const SizedBox(height: 20),
            BlocBuilder<EmployeesCubit, EmployeesState>(
              builder: (context, state) {
                if (state.status == ViewStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.employees.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Text(
                      cubit.canCreate
                          ? 'No employees yet. Tap “Add Employee”.'
                          : 'No employees to display.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.employees.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final employee = state.employees[index];
                    return _EmployeeTile(
                      employee: employee,
                      canEdit: cubit.canEdit,
                      canDelete: cubit.canDelete,
                      onEdit: () => _openEmployeeDialog(
                        context,
                        employee: employee,
                      ),
                      onDelete: () =>
                          context.read<EmployeesCubit>().deleteEmployee(
                                employee.id,
                              ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEmployeeDialog(
    BuildContext context, {
    OrganizationEmployee? employee,
  }) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<EmployeesCubit>(),
        child: _EmployeeDialog(employee: employee),
      ),
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({
    required this.employee,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  final OrganizationEmployee employee;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
            child: const Icon(Icons.badge_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  employee.roleTitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Opening ₹${employee.openingBalance.toStringAsFixed(2)} • Current ₹${employee.currentBalance.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          if (canEdit || canDelete)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (canEdit)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white54),
                    onPressed: onEdit,
                  ),
                if (canEdit && canDelete) const SizedBox(height: 8),
                if (canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: onDelete,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EmployeeDialog extends StatefulWidget {
  const _EmployeeDialog({this.employee});

  final OrganizationEmployee? employee;

  @override
  State<_EmployeeDialog> createState() => _EmployeeDialogState();
}

class _EmployeeDialogState extends State<_EmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _openingBalanceController;
  late final TextEditingController _salaryController;
  String? _selectedRoleId;
  bool _hasInitializedRole = false;

  @override
  void initState() {
    super.initState();
    final employee = widget.employee;
    _nameController = TextEditingController(text: employee?.name ?? '');
    _openingBalanceController = TextEditingController(
      text: employee != null ? employee.openingBalance.toStringAsFixed(2) : '',
    );
    _salaryController = TextEditingController(
      text: employee?.salaryAmount?.toStringAsFixed(2) ?? '',
    );
  }

  void _initializeRole(List<OrganizationRole> roles) {
    if (_hasInitializedRole || roles.isEmpty) return;
    
    if (widget.employee != null) {
      // Editing: find matching role
      final match = roles.where(
        (role) => role.id == widget.employee?.roleId,
      );
      if (match.isNotEmpty) {
        _selectedRoleId = match.first.id;
        _hasInitializedRole = true;
      }
    } else {
      // Creating: select first role by default
      _selectedRoleId = roles.first.id;
      _hasInitializedRole = true;
    }
  }

  OrganizationRole? _findSelectedRole(List<OrganizationRole> roles) {
    if (_selectedRoleId == null) return null;
    try {
      return roles.firstWhere((role) => role.id == _selectedRoleId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EmployeesCubit>();
    final roles = context.watch<EmployeesCubit>().state.roles;
    final isEditing = widget.employee != null;
    
    // Initialize role selection when roles are loaded
    if (roles.isNotEmpty && !_hasInitializedRole) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _initializeRole(roles);
          });
        }
      });
    }

    final selectedRole = _findSelectedRole(roles);

    return AlertDialog(
      backgroundColor: const Color(0xFF11111B),
      title: Text(
        isEditing ? 'Edit Employee' : 'Add Employee',
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
                decoration: _inputDecoration('Employee name'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Enter employee name'
                        : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedRoleId,
                dropdownColor: const Color(0xFF1B1B2C),
                style: const TextStyle(color: Colors.white),
                items: roles
                    .map(
                      (role) => DropdownMenuItem(
                        value: role.id,
                        child: Text(role.title),
                      ),
                    )
                    .toList(),
                onChanged: (cubit.canEdit || cubit.canCreate)
                    ? (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedRoleId = value;
                        });
                      }
                    : null,
                decoration: _inputDecoration('Role'),
                validator: (value) =>
                    value == null ? 'Select a role' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _openingBalanceController,
                enabled: !isEditing && cubit.canCreate,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Opening balance'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter opening balance';
                  }
                  final parsed = double.tryParse(value);
                  if (parsed == null) return 'Enter valid number';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              if (selectedRole?.salaryType == SalaryType.salaryMonthly)
                TextFormField(
                  controller: _salaryController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Salary amount'),
                  validator: (value) {
                    final parsed = double.tryParse(value ?? '');
                    if (parsed == null || parsed < 0) {
                      return 'Enter a valid salary';
                    }
                    return null;
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: (cubit.canCreate && !isEditing) ||
                  (cubit.canEdit && isEditing)
              ? () {
                  if (!(_formKey.currentState?.validate() ?? false)) return;
                  final selectedRole = _findSelectedRole(roles);
                  if (selectedRole == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Select a role')),
                    );
                    return;
                  }

                  final salaryAmount = selectedRole.salaryType ==
                          SalaryType.salaryMonthly
                      ? double.tryParse(_salaryController.text.trim()) ?? 0
                      : null;

                  final organizationId =
                      context.read<EmployeesCubit>().organizationId;
                  final employee = OrganizationEmployee(
                    id: widget.employee?.id ??
                        DateTime.now().millisecondsSinceEpoch.toString(),
                    organizationId: widget.employee?.organizationId ??
                        organizationId,
                    name: _nameController.text.trim(),
                    roleId: selectedRole.id,
                    roleTitle: selectedRole.title,
                    openingBalance: widget.employee?.openingBalance ??
                        double.parse(_openingBalanceController.text.trim()),
                    currentBalance:
                        widget.employee?.currentBalance ??
                            double.parse(_openingBalanceController.text.trim()),
                    salaryType: selectedRole.salaryType,
                    salaryAmount: salaryAmount,
                  );

                  if (widget.employee == null) {
                    context.read<EmployeesCubit>().createEmployee(employee);
                  } else {
                    context.read<EmployeesCubit>().updateEmployee(employee);
                  }
                  Navigator.of(context).pop();
                }
              : null,
          child: Text(isEditing ? 'Save' : 'Create'),
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

