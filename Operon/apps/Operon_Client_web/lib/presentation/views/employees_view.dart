import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/domain/entities/employee_job_role.dart';
import 'package:dash_web/domain/entities/organization_employee.dart';
import 'package:dash_web/domain/entities/organization_job_role.dart';
import 'package:dash_web/data/repositories/job_roles_repository.dart';
import 'package:dash_web/domain/entities/wage_type.dart';
import 'package:dash_web/presentation/blocs/employees/employees_cubit.dart';
import 'package:dash_web/presentation/blocs/job_roles/job_roles_cubit.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/widgets/employee_detail_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class _SimpleRole {
  const _SimpleRole({required this.id, required this.title});
  final String id;
  final String title;
}

class EmployeesPageContent extends StatefulWidget {
  const EmployeesPageContent({super.key});

  @override
  State<EmployeesPageContent> createState() => _EmployeesPageContentState();
}

enum _SortOption {
  nameAsc,
  nameDesc,
  balanceHigh,
  balanceLow,
  roleAsc,
}

class _EmployeesPageContentState extends State<EmployeesPageContent> {
  String _query = '';
  _SortOption _sortOption = _SortOption.nameAsc;
  String? _selectedRoleFilter;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  List<OrganizationEmployee> _applyFiltersAndSort(
    List<OrganizationEmployee> employees,
    List<_SimpleRole> roles,
  ) {
    // Create a mutable copy to avoid "Unsupported operation: sort" error in web
    var filtered = List<OrganizationEmployee>.from(employees);

    // Apply search filter
    if (_query.isNotEmpty) {
      filtered = filtered
          .where((e) => e.name.toLowerCase().contains(_query.toLowerCase()))
          .toList();
    }

    // Apply role filter
    if (_selectedRoleFilter != null) {
      filtered = filtered
          .where((e) => e.jobRoleIds.contains(_selectedRoleFilter!))
          .toList();
    }

    // Apply sorting (create new mutable list for sorting)
    final sortedList = List<OrganizationEmployee>.from(filtered);
    switch (_sortOption) {
      case _SortOption.nameAsc:
        sortedList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _SortOption.nameDesc:
        sortedList.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case _SortOption.balanceHigh:
        sortedList.sort((a, b) => b.currentBalance.compareTo(a.currentBalance));
        break;
      case _SortOption.balanceLow:
        sortedList.sort((a, b) => a.currentBalance.compareTo(b.currentBalance));
        break;
      case _SortOption.roleAsc:
        sortedList.sort((a, b) => a.primaryJobRoleTitle.compareTo(b.primaryJobRoleTitle));
        break;
    }

    return sortedList;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EmployeesCubit, EmployeesState>(
      builder: (context, state) {
        if (state.status == ViewStatus.loading && state.employees.isEmpty) {
          return _LoadingState();
        }
        if (state.status == ViewStatus.failure && state.employees.isEmpty) {
          return _ErrorState(
            message: state.message ?? 'Failed to load employees',
            onRetry: () => context.read<EmployeesCubit>().loadEmployees(),
          );
        }

        final employees = state.employees;
        
        // Extract unique job roles from employees for filtering
        final roleMap = <String, String>{};
        for (final emp in employees) {
          for (final jobRoleId in emp.jobRoleIds) {
            final jobRole = emp.jobRoles[jobRoleId];
            if (jobRole != null && !roleMap.containsKey(jobRoleId)) {
              roleMap[jobRoleId] = jobRole.jobRoleTitle;
            }
          }
        }
        final uniqueRoles = roleMap.entries.map((e) => _SimpleRole(id: e.key, title: e.value)).toList();
        uniqueRoles.sort((a, b) => a.title.compareTo(b.title));
        
        final filtered = _applyFiltersAndSort(employees, uniqueRoles);

        return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Statistics Dashboard
            _EmployeesStatsHeader(employees: employees),
            const SizedBox(height: 32),
            
            // Top Action Bar with Filters
            Row(
              children: [
                // Search Bar
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      color: AuthColors.surface.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AuthColors.textSub.withOpacity(0.2),
                      ),
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      style: TextStyle(color: AuthColors.textMain),
                      decoration: InputDecoration(
                        hintText: 'Search employees by name...',
                        hintStyle: TextStyle(
                          color: AuthColors.textDisabled,
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        prefixIcon: Icon(Icons.search, color: AuthColors.textSub),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: AuthColors.textSub),
                                onPressed: () => setState(() => _query = ''),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Role Filter
                if (uniqueRoles.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AuthColors.surface.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AuthColors.textSub.withOpacity(0.2),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedRoleFilter,
                        hint: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.filter_list, size: 16, color: AuthColors.textSub),
                            const SizedBox(width: 6),
                            Text(
                              'All Roles',
                              style: TextStyle(color: AuthColors.textSub, fontSize: 14),
                            ),
                          ],
                        ),
                        dropdownColor: AuthColors.surface,
                        style: TextStyle(color: AuthColors.textMain, fontSize: 14),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('All Roles'),
                          ),
                          ...uniqueRoles.map((role) => DropdownMenuItem<String>(
                            value: role.id,
                            child: Text(role.title),
                          )),
                        ],
                        onChanged: (value) => setState(() => _selectedRoleFilter = value),
                        icon: Icon(Icons.arrow_drop_down, color: AuthColors.textSub, size: 20),
                        isDense: true,
                      ),
                    ),
                  ),
                if (uniqueRoles.isNotEmpty) const SizedBox(width: 12),
                // Sort Options
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AuthColors.surface.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AuthColors.textSub.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sort, size: 16, color: AuthColors.textSub),
                      const SizedBox(width: 6),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<_SortOption>(
                          value: _sortOption,
                          dropdownColor: AuthColors.surface,
                          style: TextStyle(color: AuthColors.textMain, fontSize: 14),
                          items: const [
                            DropdownMenuItem(
                              value: _SortOption.nameAsc,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.sort_by_alpha, size: 16, color: AuthColors.textSub),
                                  const SizedBox(width: 8),
                                  Text('Name (A-Z)'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: _SortOption.nameDesc,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.sort_by_alpha, size: 16, color: AuthColors.textSub),
                                  const SizedBox(width: 8),
                                  Text('Name (Z-A)'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: _SortOption.balanceHigh,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.trending_down, size: 16, color: AuthColors.textSub),
                                  const SizedBox(width: 8),
                                  Text('Balance (High to Low)'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: _SortOption.balanceLow,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.trending_up, size: 16, color: AuthColors.textSub),
                                  const SizedBox(width: 8),
                                  Text('Balance (Low to High)'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: _SortOption.roleAsc,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.badge, size: 16, color: AuthColors.textSub),
                                  SizedBox(width: 8),
                                  Text('Role'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _sortOption = value);
                            }
                          },
                          icon: Icon(Icons.arrow_drop_down, color: AuthColors.textSub, size: 20),
                          isDense: true,
                          hint: const Text('Sort'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Results count
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AuthColors.surface.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AuthColors.textSub.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    '${filtered.length} ${filtered.length == 1 ? 'employee' : 'employees'}',
                    style: TextStyle(
                      color: AuthColors.textSub,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Add Employee Button
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add Employee'),
                  onPressed: () => _showEmployeeDialog(context, null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AuthColors.primary,
                    foregroundColor: AuthColors.textMain,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Employee List
            if (filtered.isEmpty && (_query.isNotEmpty || _selectedRoleFilter != null))
              _EmptySearchState(query: _query)
            else if (filtered.isEmpty)
              _EmptyEmployeesState(
                onAddEmployee: () => _showEmployeeDialog(context, null),
              )
            else
              _EmployeeListView(
                employees: filtered,
                onTap: (emp) => _openEmployeeDetail(emp),
                onEdit: (emp) => _showEmployeeDialog(context, emp),
                onDelete: (emp) => _showDeleteConfirmation(context, emp),
              ),
            ],
          );
      },
    );
  }

  void _openEmployeeDetail(OrganizationEmployee employee) {
    showDialog(
      context: context,
      builder: (dialogContext) => EmployeeDetailModal(
        employee: employee,
        onEmployeeChanged: (updatedEmployee) {
          // Refresh employees list if needed
          context.read<EmployeesCubit>().loadEmployees();
        },
        onEdit: () => _showEmployeeDialog(context, employee),
      ),
    );
  }
}

void _showEmployeeDialog(BuildContext context, OrganizationEmployee? employee) {
  final orgState = context.read<OrganizationContextCubit>().state;
  final orgId = orgState.organization?.id;
  if (orgId == null) return;

  // Capture the EmployeesCubit from the outer context
  final employeesCubit = context.read<EmployeesCubit>();

  showDialog(
    context: context,
    builder: (dialogContext) => MultiBlocProvider(
      providers: [
        BlocProvider<JobRolesCubit>(
          create: (_) => JobRolesCubit(
            repository: context.read<JobRolesRepository>(),
            orgId: orgId,
          )..load(),
        ),
      ],
      child: _EmployeeDialog(
        employee: employee,
        orgId: orgId,
        employeesCubit: employeesCubit,
      ),
    ),
  );
}

void _showDeleteConfirmation(BuildContext context, OrganizationEmployee employee) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AuthColors.surface,
      title: Text(
        'Delete Employee',
        style: TextStyle(color: AuthColors.textMain),
      ),
      content: Text(
        'Are you sure you want to delete ${employee.name}?',
        style: TextStyle(color: AuthColors.textSub),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            context.read<EmployeesCubit>().deleteEmployee(employee.id);
            Navigator.of(dialogContext).pop();
          },
          style: TextButton.styleFrom(
            foregroundColor: AuthColors.error,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

class _EmployeeDialog extends StatefulWidget {
  const _EmployeeDialog({
    this.employee,
    required this.orgId,
    required this.employeesCubit,
  });

  final OrganizationEmployee? employee;
  final String orgId;
  final EmployeesCubit employeesCubit;

  @override
  State<_EmployeeDialog> createState() => _EmployeeDialogState();
}

class _EmployeeDialogState extends State<_EmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _openingBalanceController;
  late final TextEditingController _wageAmountController;
  
  // Multiple job roles support
  Set<String> _selectedJobRoleIds = {};
  String? _primaryJobRoleId;
  bool _hasInitializedRoles = false;
  
  // Wage structure
  WageType _selectedWageType = WageType.perMonth;

  @override
  void initState() {
    super.initState();
    final employee = widget.employee;
    _nameController = TextEditingController(text: employee?.name ?? '');
    _openingBalanceController = TextEditingController(
      text: employee != null ? employee.openingBalance.toStringAsFixed(2) : '',
    );
    
    // Initialize wage from employee or default
    if (employee != null) {
      _selectedWageType = employee.wage.type;
      _wageAmountController = TextEditingController(
        text: employee.wage.baseAmount?.toStringAsFixed(2) ?? 
              employee.wage.rate?.toStringAsFixed(2) ?? '',
      );
      _selectedJobRoleIds = employee.jobRoleIds.toSet();
      _primaryJobRoleId = employee.primaryJobRoleId;
    } else {
      _wageAmountController = TextEditingController();
      _selectedWageType = WageType.perMonth;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _openingBalanceController.dispose();
    _wageAmountController.dispose();
    super.dispose();
  }

  void _initializeJobRoles(List<OrganizationJobRole> jobRoles) {
    if (_hasInitializedRoles || jobRoles.isEmpty) return;

    if (widget.employee != null) {
      // Already initialized from employee in initState
      _hasInitializedRoles = true;
    } else if (jobRoles.isNotEmpty) {
      // Default: select first role as primary
      _selectedJobRoleIds = {jobRoles.first.id};
      _primaryJobRoleId = jobRoles.first.id;
      _hasInitializedRoles = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobRolesState = context.watch<JobRolesCubit>().state;
    final jobRoles = jobRolesState.jobRoles;
    final isEditing = widget.employee != null;

    if (jobRoles.isNotEmpty && !_hasInitializedRoles) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _initializeJobRoles(jobRoles);
          });
        }
      });
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AuthColors.surface,
              AuthColors.background,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              spreadRadius: -10,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1B1C2C),
                    Color(0xFF161622),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6F4BFF).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEditing ? Icons.edit : Icons.person_add,
                      color: const Color(0xFF6F4BFF),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit Employee' : 'Add Employee',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Employee name', Icons.person_outline),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Enter employee name'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      
                      // Job Roles Multi-Select
                      Text(
                        'Job Roles *',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B1B2C),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedJobRoleIds.isEmpty 
                                ? Colors.red.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: jobRoles.length,
                          itemBuilder: (context, index) {
                            final jobRole = jobRoles[index];
                            final isSelected = _selectedJobRoleIds.contains(jobRole.id);
                            final isPrimary = _primaryJobRoleId == jobRole.id;
                            
                            return CheckboxListTile(
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      jobRole.title,
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  if (isPrimary)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6F4BFF).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Primary',
                                        style: TextStyle(
                                          color: Color(0xFF6F4BFF),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              value: isSelected,
                              activeColor: const Color(0xFF6F4BFF),
                              checkColor: Colors.white,
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedJobRoleIds.add(jobRole.id);
                                    // If no primary yet, set this as primary
                                    _primaryJobRoleId ??= jobRole.id;
                                  } else {
                                    _selectedJobRoleIds.remove(jobRole.id);
                                    // If removing primary, assign new primary
                                    if (isPrimary && _selectedJobRoleIds.isNotEmpty) {
                                      _primaryJobRoleId = _selectedJobRoleIds.first;
                                    } else if (_selectedJobRoleIds.isEmpty) {
                                      _primaryJobRoleId = null;
                                    }
                                  }
                                });
                              },
                              secondary: isSelected
                                  ? IconButton(
                                      icon: const Icon(Icons.star, size: 20),
                                      color: isPrimary 
                                          ? const Color(0xFF6F4BFF)
                                          : Colors.white54,
                                      onPressed: _selectedJobRoleIds.length > 1
                                          ? () {
                                              setState(() {
                                                _primaryJobRoleId = jobRole.id;
                                              });
                                            }
                                          : null,
                                      tooltip: 'Set as primary',
                                    )
                                  : null,
                            );
                          },
                        ),
                      ),
                      if (_selectedJobRoleIds.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Select at least one job role',
                            style: TextStyle(
                              color: Colors.red.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _openingBalanceController,
                        enabled: !isEditing,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Opening balance', Icons.account_balance_wallet_outlined),
                        validator: (value) {
                          if (isEditing) return null;
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter opening balance';
                          }
                          if (double.tryParse(value.trim()) == null) {
                            return 'Enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Wage Type Selection
                      DropdownButtonFormField<WageType>(
                        initialValue: _selectedWageType,
                        dropdownColor: const Color(0xFF1B1B2C),
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Wage Type', Icons.payments_outlined),
                        items: WageType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(_getWageTypeDisplayName(type)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedWageType = value;
                              _wageAmountController.clear();
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Conditional Wage Amount Field
                      if (_selectedWageType == WageType.perMonth ||
                          _selectedWageType == WageType.perTrip ||
                          _selectedWageType == WageType.perBatch ||
                          _selectedWageType == WageType.perHour ||
                          _selectedWageType == WageType.perKm)
                        TextFormField(
                          controller: _wageAmountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration(
                            _getWageAmountLabel(_selectedWageType),
                            Icons.attach_money,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter ${_getWageAmountLabel(_selectedWageType).toLowerCase()}';
                            }
                            if (double.tryParse(value.trim()) == null) {
                              return 'Enter a valid number';
                            }
                            return null;
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Footer Actions
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AuthColors.textSub,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: Icon(isEditing ? Icons.check : Icons.add, size: 18),
                    label: Text(isEditing ? 'Save Changes' : 'Create Employee'),
                    onPressed: () {
                      if (!(_formKey.currentState?.validate() ?? false)) return;
                      
                      if (_selectedJobRoleIds.isEmpty) {
                        DashSnackbar.show(
                          context,
                          message: 'Select at least one job role',
                          isError: true,
                        );
                        return;
                      }
                      
                      if (_primaryJobRoleId == null) {
                        DashSnackbar.show(
                          context,
                          message: 'Select a primary job role',
                          isError: true,
                        );
                        return;
                      }

                      // Build job roles map
                      final jobRolesMap = <String, EmployeeJobRole>{};
                      for (final jobRoleId in _selectedJobRoleIds) {
                        final jobRole = jobRoles.firstWhere((r) => r.id == jobRoleId);
                        jobRolesMap[jobRoleId] = EmployeeJobRole(
                          jobRoleId: jobRoleId,
                          jobRoleTitle: jobRole.title,
                          assignedAt: DateTime.now(),
                          isPrimary: jobRoleId == _primaryJobRoleId,
                        );
                      }

                      // Build wage structure
                      final wageAmount = double.tryParse(_wageAmountController.text.trim());
                      final wage = EmployeeWage(
                        type: _selectedWageType,
                        baseAmount: _selectedWageType == WageType.perMonth ? wageAmount : null,
                        rate: _selectedWageType != WageType.perMonth ? wageAmount : null,
                      );

                      final employee = OrganizationEmployee(
                        id: widget.employee?.id ??
                            DateTime.now().millisecondsSinceEpoch.toString(),
                        organizationId: widget.employee?.organizationId ?? widget.orgId,
                        name: _nameController.text.trim(),
                        jobRoleIds: _selectedJobRoleIds.toList(),
                        jobRoles: jobRolesMap,
                        wage: wage,
                        openingBalance: widget.employee?.openingBalance ??
                            double.parse(_openingBalanceController.text.trim()),
                        currentBalance: widget.employee?.currentBalance ??
                            double.parse(_openingBalanceController.text.trim()),
                      );

                      if (widget.employee == null) {
                        widget.employeesCubit.createEmployee(employee);
                      } else {
                        widget.employeesCubit.updateEmployee(employee);
                      }
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AuthColors.primary,
                      foregroundColor: AuthColors.textMain,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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

  String _getWageTypeDisplayName(WageType type) {
    switch (type) {
      case WageType.perMonth:
        return 'Per Month';
      case WageType.perTrip:
        return 'Per Trip';
      case WageType.perBatch:
        return 'Per Batch';
      case WageType.perHour:
        return 'Per Hour';
      case WageType.perKm:
        return 'Per Kilometer';
      case WageType.commission:
        return 'Commission';
      case WageType.hybrid:
        return 'Hybrid';
    }
  }

  String _getWageAmountLabel(WageType type) {
    switch (type) {
      case WageType.perMonth:
        return 'Monthly Salary';
      case WageType.perTrip:
        return 'Amount per Trip';
      case WageType.perBatch:
        return 'Amount per Batch';
      case WageType.perHour:
        return 'Hourly Rate';
      case WageType.perKm:
        return 'Rate per Kilometer';
      case WageType.commission:
        return 'Commission %';
      case WageType.hybrid:
        return 'Base Amount';
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.white54, size: 20),
      filled: true,
      fillColor: AuthColors.surface,
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFF6F4BFF),
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.redAccent,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
    );
  }
}

class _EmployeesStatsHeader extends StatelessWidget {
  const _EmployeesStatsHeader({required this.employees});

  final List<OrganizationEmployee> employees;

  @override
  Widget build(BuildContext context) {
    final totalEmployees = employees.length;
    final totalOpeningBalance = employees.fold<double>(
      0.0,
      (sum, emp) => sum + emp.openingBalance,
    );
    final totalCurrentBalance = employees.fold<double>(
      0.0,
      (sum, emp) => sum + emp.currentBalance,
    );
    final avgBalance = employees.isNotEmpty
        ? totalCurrentBalance / employees.length
        : 0.0;
    final balanceDifference = totalCurrentBalance - totalOpeningBalance;
    final balanceChangePercent = totalOpeningBalance != 0
        ? (balanceDifference / totalOpeningBalance * 100)
        : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1000;
        return isWide
            ? Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.people_outline,
                      label: 'Total Employees',
                      value: totalEmployees.toString(),
                      color: AuthColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Total Opening Balance',
                      value: '₹${totalOpeningBalance.toStringAsFixed(2)}',
                      color: AuthColors.success,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.trending_up,
                      label: 'Total Current Balance',
                      value: '₹${totalCurrentBalance.toStringAsFixed(2)}',
                      subtitle: balanceDifference != 0
                          ? '${balanceDifference >= 0 ? '+' : ''}₹${balanceDifference.abs().toStringAsFixed(2)} (${balanceChangePercent >= 0 ? '+' : ''}${balanceChangePercent.abs().toStringAsFixed(1)}%)'
                          : null,
                      subtitleColor: balanceDifference >= 0 ? AuthColors.success : AuthColors.error,
                      color: AuthColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.analytics_outlined,
                      label: 'Average Balance',
                      value: '₹${avgBalance.toStringAsFixed(2)}',
                      color: AuthColors.primary,
                    ),
                  ),
                ],
              )
            : Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _StatCard(
                    icon: Icons.people_outline,
                    label: 'Total Employees',
                    value: totalEmployees.toString(),
                    color: AuthColors.primary,
                  ),
                  _StatCard(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Total Opening Balance',
                    value: '₹${totalOpeningBalance.toStringAsFixed(2)}',
                    color: AuthColors.success,
                  ),
                  _StatCard(
                    icon: Icons.trending_up,
                    label: 'Total Current Balance',
                    value: '₹${totalCurrentBalance.toStringAsFixed(2)}',
                    subtitle: balanceDifference != 0
                        ? '${balanceDifference >= 0 ? '+' : ''}₹${balanceDifference.abs().toStringAsFixed(2)} (${balanceChangePercent >= 0 ? '+' : ''}${balanceChangePercent.abs().toStringAsFixed(1)}%)'
                        : null,
                    subtitleColor: balanceDifference >= 0 ? AuthColors.success : AuthColors.error,
                    color: AuthColors.secondary,
                  ),
                  _StatCard(
                    icon: Icons.analytics_outlined,
                    label: 'Average Balance',
                    value: '₹${avgBalance.toStringAsFixed(2)}',
                    color: AuthColors.primary,
                  ),
                ],
              );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
    this.subtitleColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? subtitle;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AuthColors.surface,
            AuthColors.background,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AuthColors.textSub.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: AuthColors.background.withOpacity(0.5),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AuthColors.textSub,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: subtitleColor ?? AuthColors.textSub,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Loading employees...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B2C).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.redAccent.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.redAccent.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load employees',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6F4BFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyEmployeesState extends StatelessWidget {
  const _EmptyEmployeesState({required this.onAddEmployee});

  final VoidCallback onAddEmployee;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1B1B2C).withValues(alpha: 0.6),
              const Color(0xFF161622).withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF6F4BFF).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline,
                size: 40,
                color: Color(0xFF6F4BFF),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No employees yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start by adding your first employee to the system',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add Employee'),
              onPressed: onAddEmployee,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6F4BFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'No results found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No employees match "$query"',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeListView extends StatelessWidget {
  const _EmployeeListView({
    required this.employees,
    this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final List<OrganizationEmployee> employees;
  final ValueChanged<OrganizationEmployee>? onTap;
  final ValueChanged<OrganizationEmployee> onEdit;
  final ValueChanged<OrganizationEmployee> onDelete;

  Color _getRoleColor(String? roleTitle) {
    if (roleTitle == null || roleTitle.isEmpty) return AuthColors.primary;
    final hash = roleTitle.hashCode;
    final colors = [
      AuthColors.primary,
      AuthColors.success,
      AuthColors.secondary,
      AuthColors.primary,
      AuthColors.error,
    ];
    return colors[hash.abs() % colors.length];
  }

  String _getWageTypeDisplayName(WageType type) {
    switch (type) {
      case WageType.perMonth:
        return 'Per Month';
      case WageType.perTrip:
        return 'Per Trip';
      case WageType.perBatch:
        return 'Per Batch';
      case WageType.perHour:
        return 'Per Hour';
      case WageType.perKm:
        return 'Per Kilometer';
      case WageType.commission:
        return 'Commission';
      case WageType.hybrid:
        return 'Hybrid';
    }
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: employees.length,
      itemBuilder: (context, index) {
        final employee = employees[index];
        final roleColor = _getRoleColor(employee.primaryJobRoleTitle);
        final balanceDifference = employee.currentBalance - employee.openingBalance;
        final isPositive = balanceDifference >= 0;
        final roleTitle = employee.primaryJobRoleTitle.isNotEmpty
            ? employee.primaryJobRoleTitle
            : employee.jobRoleTitles;
        final subtitleParts = <String>[];
        if (roleTitle.isNotEmpty) subtitleParts.add(roleTitle);
        subtitleParts.add('₹${employee.currentBalance.toStringAsFixed(2)}');
        final subtitle = subtitleParts.join(' • ');

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AuthColors.background,
            borderRadius: BorderRadius.circular(18),
          ),
          child: DataList(
            title: employee.name,
            subtitle: subtitle,
            leading: DataListAvatar(
              initial: _getInitials(employee.name),
              radius: 28,
              statusRingColor: roleColor,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (balanceDifference != 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: isPositive
                            ? AuthColors.success.withOpacity(0.15)
                            : AuthColors.error.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 10,
                            color: isPositive ? AuthColors.success : AuthColors.error,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '₹${balanceDifference.abs().toStringAsFixed(2)}',
                            style: TextStyle(
                              color: isPositive ? AuthColors.success : AuthColors.error,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                IconButton(
                  icon: Icon(Icons.visibility_outlined, size: 20, color: AuthColors.textSub),
                  onPressed: () => onTap?.call(employee),
                  tooltip: 'View Details',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.edit_outlined, size: 20, color: AuthColors.textSub),
                  onPressed: () => onEdit(employee),
                  tooltip: 'Edit',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 20, color: AuthColors.error),
                  onPressed: () => onDelete(employee),
                  tooltip: 'Delete',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            onTap: () => onTap?.call(employee),
          ),
        );
      },
    );
  }
}
