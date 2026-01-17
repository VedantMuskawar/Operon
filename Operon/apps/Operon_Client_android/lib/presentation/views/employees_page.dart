import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
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
  late final ScrollController _scrollController;
  double _currentPage = 0;
  String _searchQuery = '';
  bool _isLoadingMore = false;

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
    _scrollController = ScrollController()
      ..addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * 0.8) {
      // Load more if needed - for now just a placeholder
      // Future pagination support can be added here
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _pageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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
        backgroundColor: AuthColors.background,
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

                              return CustomScrollView(
                                controller: _scrollController,
                                slivers: [
                                  SliverToBoxAdapter(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildSearchBar(),
                                        const SizedBox(height: 16),
                                        if (_searchQuery.isEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 12),
                                            child: Text(
                                              '${filteredEmployees.length} ${filteredEmployees.length == 1 ? 'employee' : 'employees'}',
                                              style: TextStyle(
                                                color: AuthColors.textSub,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (_searchQuery.isNotEmpty)
                                    SliverToBoxAdapter(
                                      child: _SearchResultsCard(
                                        employees: filteredEmployees,
                                        onClear: _clearSearch,
                                        searchQuery: _searchQuery,
                                      ),
                                    )
                                  else if (filteredEmployees.isEmpty && state.status != ViewStatus.loading)
                                    SliverFillRemaining(
                                      child: _EmptyEmployeesState(
                                        onAddEmployee: _openEmployeeDialog,
                                        canCreate: context.read<EmployeesCubit>().canCreate,
                                      ),
                                    )
                                  else ...[
                                    SliverToBoxAdapter(
                                      child: Row(
                                        children: [
                                          const Expanded(
                                            child: Text(
                                              'All employees',
                                              style: TextStyle(
                                                color: AuthColors.textMain,
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
                                    ),
                                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                                    SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) {
                                          if (index >= filteredEmployees.length) {
                                            return _isLoadingMore
                                                ? const Padding(
                                                    padding: EdgeInsets.all(16),
                                                    child: Center(child: CircularProgressIndicator()),
                                                  )
                                                : const SizedBox.shrink();
                                          }
                                          final employee = filteredEmployees[index];
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 12),
                                            child: _EmployeeTile(
                                              employee: employee,
                                              onEdit: () => _openEmployeeDialogInternal(context, employee: employee),
                                              onDelete: () => context.read<EmployeesCubit>().deleteEmployee(employee.id),
                                            ),
                                          );
                                        },
                                        childCount: filteredEmployees.length + (_isLoadingMore ? 1 : 0),
                                      ),
                                    ),
                                  ],
                                ],
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
      style: TextStyle(color: AuthColors.textMain),
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.search, color: AuthColors.textSub),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.close, color: AuthColors.textSub),
                onPressed: _clearSearch,
              )
            : null,
        hintText: 'Search employees by name',
        hintStyle: TextStyle(color: AuthColors.textDisabled),
        filled: true,
        fillColor: AuthColors.surface,
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
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AuthColors.textSub.withOpacity(0.2)),
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
                    color: AuthColors.textMain,
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
            ...employees.map((employee) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _EmployeeTile(employee: employee),
                )),
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
                  color: AuthColors.textMain,
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
      AuthColors.primary,
      AuthColors.success,
      AuthColors.secondary,
      AuthColors.primary,
      AuthColors.error,
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
    final subtitleParts = <String>[];
    subtitleParts.add(employee.roleTitle);
    subtitleParts.add('₹${employee.currentBalance.toStringAsFixed(2)}');
    if (employee.salaryAmount != null) {
      subtitleParts.add('Salary: ₹${employee.salaryAmount!.toStringAsFixed(2)}/${_getSalaryTypeLabel(employee.salaryType)}');
    }
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
          statusRingColor: employeeColor,
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
            if (onEdit != null || onDelete != null)
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: AuthColors.textSub,
                  size: 20,
                ),
                color: AuthColors.surface,
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
                            color: AuthColors.textSub,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Edit',
                            style: TextStyle(color: AuthColors.textSub),
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
                            color: AuthColors.error,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Delete',
                            style: TextStyle(color: AuthColors.error),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
        onTap: () => context.pushNamed('employee-detail', extra: employee),
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
            AuthColors.surface.withOpacity(0.6),
            AuthColors.backgroundAlt.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AuthColors.textSub.withOpacity(0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AuthColors.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.badge_outlined,
              size: 32,
              color: AuthColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No employees yet',
            style: TextStyle(
              color: AuthColors.textMain,
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
              color: AuthColors.textSub,
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
            color: AuthColors.textSub.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: TextStyle(
              color: AuthColors.textMain,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No employees match "$query"',
            style: TextStyle(
              color: AuthColors.textSub,
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
                color: isActive ? AuthColors.primary : AuthColors.textSub.withOpacity(0.3),
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
      backgroundColor: AuthColors.surface,
      title: Text(
        isEditing ? 'Edit Employee' : 'Add Employee',
        style: TextStyle(color: AuthColors.textMain),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                style: TextStyle(color: AuthColors.textMain),
                decoration: _inputDecoration('Employee name'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Enter employee name'
                        : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedRoleId,
                dropdownColor: AuthColors.surface,
                style: TextStyle(color: AuthColors.textMain),
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
                style: TextStyle(color: AuthColors.textMain),
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
                  style: TextStyle(color: AuthColors.textMain),
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
      fillColor: AuthColors.surface,
      labelStyle: TextStyle(color: AuthColors.textSub),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}
