import 'package:core_bloc/core_bloc.dart';
import 'package:dash_mobile/domain/entities/organization_employee.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_mobile/presentation/blocs/employees/employees_cubit.dart';
import 'package:dash_mobile/presentation/views/employees_page/employee_analytics_page.dart';
import 'package:dash_mobile/presentation/widgets/quick_nav_bar.dart';
import 'package:dash_mobile/presentation/widgets/quick_action_menu.dart';
import 'package:dash_mobile/presentation/widgets/modern_tile.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:dash_mobile/shared/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  late final TextEditingController _searchController;
  late final PageController _pageController;
  double _currentPage = 0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(_handleSearchChanged);
    _pageController = PageController()
      ..addListener(() {
        setState(() {
          _currentPage = _pageController.page ?? 0;
        });
      });
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  void _openEmployeeDialog() {
    _openEmployeeDialogInternal(context);
  }

  Future<void> _openEmployeeDialogInternal(
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

  List<OrganizationEmployee> _applySearch(List<OrganizationEmployee> employees) {
    if (_searchQuery.isEmpty) return employees;
    final query = _searchQuery.toLowerCase();
    return employees
        .where((e) => e.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        BlocListener<EmployeesCubit, EmployeesState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message!)),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        appBar: const ModernPageHeader(
          title: 'Employees',
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Builder(
              builder: (context) {
                final media = MediaQuery.of(context);
                final screenHeight = media.size.height;
                // Approximate available height: screen height minus status bar, header, nav, and padding
                final availableHeight = screenHeight - media.padding.top - 72 - media.padding.bottom - 80 - 24 - 48;
                // Reserve space for page indicator (24px) + spacing (16px) + scroll padding (48px)
                final pageViewHeight = (availableHeight - 24 - 16 - 48).clamp(400.0, 600.0);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Page Indicator (dots)
                    _PageIndicator(
                      pageCount: 2,
                      currentIndex: _currentPage,
                      onPageTap: (index) {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: pageViewHeight,
                      child: PageView(
                        controller: _pageController,
                        children: [
                          BlocBuilder<EmployeesCubit, EmployeesState>(
                            builder: (context, state) {
                              final allEmployees = state.employees;
                              final filteredEmployees = _applySearch(allEmployees);

                              return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
          children: [
                                    // Search Bar
                                    _buildSearchBar(),
                                    const SizedBox(height: 16),
                                    // Results count
                                    if (_searchQuery.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: Text(
                                          '${filteredEmployees.length} ${filteredEmployees.length == 1 ? 'employee' : 'employees'}',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.6),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    // Search Results or Recent Employees
                                    if (_searchQuery.isNotEmpty)
                                      _SearchResultsCard(
                                        employees: filteredEmployees,
                                        onClear: _clearSearch,
                                        searchQuery: _searchQuery,
                                      )
                                    else if (filteredEmployees.isEmpty && state.status != ViewStatus.loading)
                                      _EmptyEmployeesState(
                                        onAddEmployee: _openEmployeeDialog,
                                        canCreate: context.read<EmployeesCubit>().canCreate,
              )
            else
                                      _RecentEmployeesList(
                                        state: state,
                                        employees: filteredEmployees,
                                        onEdit: (emp) => _openEmployeeDialogInternal(context, employee: emp),
                                        onDelete: (emp) => context.read<EmployeesCubit>().deleteEmployee(emp.id),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SingleChildScrollView(
                            child: EmployeeAnalyticsPage(),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
                      ),
                    ),
                QuickNavBar(
                  currentIndex: -1, // -1 means no selection when on this page
                  onTap: (value) => context.go('/home', extra: value),
                ),
              ],
            ),
            // Quick Action Menu - only visible on Employees page
            if (_currentPage.round() == 0)
              Builder(
                builder: (context) {
                  final cubit = context.read<EmployeesCubit>();
                  
                  final actions = <QuickActionItem>[];

                  if (cubit.canCreate) {
                    actions.add(
                      QuickActionItem(
                        icon: Icons.add,
                        label: 'Add Employee',
                        onTap: _openEmployeeDialog,
                      ),
                    );
                  }
              
                  if (actions.isEmpty) return const SizedBox.shrink();
              
                  return QuickActionMenu(
                    actions: actions,
                  );
                },
              ),
          ],
        ),
      ),
      ),
      ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search, color: Colors.white54),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: _clearSearch,
              )
            : null,
        hintText: 'Search employees by name',
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF1B1B2C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _SearchResultsCard extends StatelessWidget {
  const _SearchResultsCard({
    required this.employees,
    required this.onClear,
    required this.searchQuery,
  });

  final List<OrganizationEmployee> employees;
  final VoidCallback onClear;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF131324),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Search Results',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: onClear,
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (employees.isEmpty)
            _EmptySearchState(query: searchQuery)
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: employees.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final employee = employees[index];
                return _EmployeeTile(employee: employee);
              },
            ),
        ],
      ),
    );
  }
}

class _RecentEmployeesList extends StatelessWidget {
  const _RecentEmployeesList({
    required this.state,
    required this.employees,
    required this.onEdit,
    required this.onDelete,
  });

  final EmployeesState state;
  final List<OrganizationEmployee> employees;
  final ValueChanged<OrganizationEmployee> onEdit;
  final ValueChanged<OrganizationEmployee> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'All employees',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (state.status == ViewStatus.loading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (employees.isEmpty && state.status != ViewStatus.loading)
          const SizedBox.shrink()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: employees.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final employee = employees[index];
              return _EmployeeTile(
                employee: employee,
                onEdit: () => onEdit(employee),
                onDelete: () => onDelete(employee),
              );
            },
          ),
      ],
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({
    required this.employee,
    this.onEdit,
    this.onDelete,
  });

  final OrganizationEmployee employee;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  Color _getEmployeeColor() {
    final hash = employee.roleTitle.hashCode;
    final colors = [
      const Color(0xFF6F4BFF),
      const Color(0xFF5AD8A4),
      const Color(0xFFFF9800),
      const Color(0xFF2196F3),
      const Color(0xFFE91E63),
    ];
    return colors[hash.abs() % colors.length];
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final employeeColor = _getEmployeeColor();
    final balanceDifference = employee.currentBalance - employee.openingBalance;
    final isPositive = balanceDifference >= 0;

    return ModernTile(
      onTap: () => context.pushNamed('employee-detail', extra: employee),
      accentColor: employeeColor,
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: AppSpacing.avatarMD,
                height: AppSpacing.avatarMD,
            decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        employeeColor,
                        employeeColor.withOpacity(0.7),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: employeeColor.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: -1,
                      ),
                    ],
                  ),
                child: Center(
                  child: Text(
                    _getInitials(employee.name),
                    style: AppTypography.h4.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.itemSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            employee.name,
                            style: AppTypography.h4,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Role Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: employeeColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: employeeColor.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            employee.roleTitle,
                            style: TextStyle(
                              color: employeeColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.paddingXS),
                    // Balance
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: AppSpacing.paddingXS / 2),
                        Expanded(
                          child: Text(
                            '₹${employee.currentBalance.toStringAsFixed(2)}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (balanceDifference != 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isPositive
                                  ? AppColors.success.withOpacity(0.15)
                                  : AppColors.error.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                                  size: 10,
                                  color: isPositive ? AppColors.success : AppColors.error,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '₹${balanceDifference.abs().toStringAsFixed(2)}',
                                  style: AppTypography.caption.copyWith(
                                    color: isPositive ? AppColors.success : AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action buttons
              if (onEdit != null || onDelete != null)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: AppColors.textTertiary,
                    size: AppSpacing.iconSM,
                  ),
                  color: AppColors.cardBackgroundElevated,
                  onSelected: (value) {
                    if (value == 'edit' && onEdit != null) {
                      onEdit!();
                    } else if (value == 'delete' && onDelete != null) {
                      onDelete!();
                    }
                  },
                  itemBuilder: (context) => [
                    if (onEdit != null)
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              color: AppColors.textSecondary,
                              size: 18,
                            ),
                            SizedBox(width: AppSpacing.paddingXS),
                            Text(
                              'Edit',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (onDelete != null)
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              color: AppColors.error,
                              size: 18,
                            ),
                            SizedBox(width: AppSpacing.paddingXS),
                            Text(
                              'Delete',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
          // Salary info if available
          if (employee.salaryAmount != null) ...[
            SizedBox(height: AppSpacing.paddingSM),
            Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  size: 12,
                  color: AppColors.textTertiary,
                ),
                SizedBox(width: AppSpacing.paddingXS / 2),
                Text(
                  'Salary: ₹${employee.salaryAmount!.toStringAsFixed(2)}/${_getSalaryTypeLabel(employee.salaryType)}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _getSalaryTypeLabel(SalaryType type) {
    switch (type) {
      case SalaryType.salaryMonthly:
        return 'month';
      case SalaryType.wages:
        return 'wages';
    }
  }
}

class _EmptyEmployeesState extends StatelessWidget {
  const _EmptyEmployeesState({
    required this.onAddEmployee,
    required this.canCreate,
  });

  final VoidCallback onAddEmployee;
  final bool canCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1B1B2C).withOpacity(0.6),
            const Color(0xFF161622).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF6F4BFF).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.badge_outlined,
              size: 32,
              color: Color(0xFF6F4BFF),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No employees yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            canCreate
                ? 'Start by adding your first employee to the system'
                : 'No employees to display.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          if (canCreate) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add Employee'),
              onPressed: onAddEmployee,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6F4BFF),
                foregroundColor: Colors.white,
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
        ],
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No results found',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No employees match "$query"',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.pageCount,
    required this.currentIndex,
    required this.onPageTap,
  });

  final int pageCount;
  final double currentIndex;
  final ValueChanged<int> onPageTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        pageCount,
        (index) {
          final isActive = currentIndex.round() == index;
          return GestureDetector(
            onTap: () => onPageTap(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF6F4BFF) : Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          );
        },
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
      backgroundColor: const Color(0xFF0A0A0A),
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
