import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../contexts/organization_context.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/employee.dart';
import '../../../../core/models/employee_role_definition.dart';
import '../../../../core/navigation/organization_navigation_scope.dart';
import '../../../../core/repositories/employee_repository.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/realtime_list_cache_mixin.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_dropdown.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/page_container.dart';
import '../../../../core/widgets/page_header.dart';
import '../../bloc/employees_bloc.dart';
import '../../bloc/employees_event.dart';
import '../../bloc/employees_state.dart';

class EmployeeManagementPage extends StatelessWidget {
  const EmployeeManagementPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return OrganizationAwareWidget(
      builder: (context, orgContext) {
        final organizationId = orgContext.organizationId;
        final organizationName = orgContext.organizationName ?? 'Organization';
        final requesterName = orgContext.userInfo?['name'] as String?;

        if (organizationId == null) {
          return const Center(
            child: Text(
              'Organization not found',
              style: TextStyle(color: AppTheme.textPrimaryColor),
            ),
          );
        }

        final navigation = OrganizationNavigationScope.of(context);

        return BlocProvider(
          create: (context) => EmployeesBloc(
            employeeRepository: EmployeeRepository(),
          )..add(EmployeesRequested(organizationId: organizationId)),
          child: EmployeeManagementView(
            organizationId: organizationId,
            organizationName: organizationName,
            requestedBy: requesterName,
            userRole: orgContext.userRole ?? AppConstants.adminRole,
            onBack: onBack ?? navigation?.goHome,
            onCreateRoles: navigation == null
                ? null
                : () => navigation.goToView('organization-roles'),
          ),
        );
      },
    );
  }
}

class EmployeeManagementView extends StatefulWidget {
  const EmployeeManagementView({
    super.key,
    required this.organizationId,
    required this.organizationName,
    required this.userRole,
    this.requestedBy,
    this.onBack,
    this.onCreateRoles,
  });

  final String organizationId;
  final String organizationName;
  final int userRole;
  final String? requestedBy;
  final VoidCallback? onBack;
  final VoidCallback? onCreateRoles;

  @override
  State<EmployeeManagementView> createState() => _EmployeeManagementViewState();
}

class _EmployeeManagementViewState
    extends RealtimeListCacheState<EmployeeManagementView, Employee> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  String? _roleFilter;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final bloc = context.read<EmployeesBloc>();
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      bloc.add(const EmployeesClearSearch());
    } else {
      bloc.add(EmployeesSearchQueryChanged(query));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EmployeesBloc, EmployeesState>(
      listener: (context, state) {
        if (state.status == EmployeesStatus.success) {
          applyRealtimeItems(
            state.visibleEmployees,
            searchQuery: state.searchQuery.isNotEmpty ? state.searchQuery : null,
          );
        } else if (state.status == EmployeesStatus.empty) {
          applyRealtimeEmpty(
            searchQuery: state.searchQuery.isNotEmpty ? state.searchQuery : null,
          );
        } else if (state.status == EmployeesStatus.initial) {
          resetRealtimeSnapshot();
        }

        if (state.clearError) {
          return;
        }
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      },
      builder: (context, state) {
        final employees =
            hasRealtimeData ? realtimeItems : state.visibleEmployees;
        final effectiveSearch =
            state.searchQuery.isNotEmpty ? state.searchQuery : realtimeSearchQuery ?? '';
        final hasRoles = state.roles.isNotEmpty;
        _roleFilter = state.roleFilter;

        return PageContainer(
          fullHeight: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Employees',
                role: _roleLabel(widget.userRole),
                onBack: widget.onBack,
                actions: [
                  CustomButton(
                    text: 'Add Employee',
                    icon: const Icon(Icons.add, size: 18),
                    variant: CustomButtonVariant.primary,
                    isDisabled: state.isCreateInProgress,
                    isLoading: state.isCreateInProgress,
                    onPressed: () => _handleAddEmployeePressed(state),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                'Manage employee directory for ${widget.organizationName}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
              ),
              if (!hasRoles)
                Padding(
                  padding: const EdgeInsets.only(top: AppTheme.spacingMd),
                  child: _buildNoRolesNotice(),
                ),
              const SizedBox(height: AppTheme.spacingLg),
              _buildSummary(state.metrics, state.status == EmployeesStatus.loading),
              const SizedBox(height: AppTheme.spacingLg),
              _buildToolbar(state),
              const SizedBox(height: AppTheme.spacingLg),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return _buildContent(
                      state,
                      employees,
                      searchQuery: effectiveSearch,
                      tableWidth: constraints.maxWidth,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummary(EmployeesMetrics metrics, bool isLoading) {
    final cards = [
      _SummaryCardData(
        title: 'Total Employees',
        value: metrics.total,
        icon: Icons.group_outlined,
        color: AppTheme.primaryColor,
      ),
      _SummaryCardData(
        title: 'Active',
        value: metrics.active,
        icon: Icons.verified_user_outlined,
        color: AppTheme.successColor,
      ),
      _SummaryCardData(
        title: 'Inactive',
        value: metrics.inactive,
        icon: Icons.pause_circle_outline,
        color: AppTheme.warningColor,
      ),
      _SummaryCardData(
        title: 'New (30 days)',
        value: metrics.newHires,
        icon: Icons.new_releases_outlined,
        color: AppTheme.accentColor,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 900;
        final spacing = AppTheme.spacingLg;

        final children = cards
            .map((data) => _SummaryCard(data: data, isLoading: isLoading))
            .toList();

        if (isCompact) {
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: children
                .map(
                  (child) => SizedBox(
                    width: constraints.maxWidth / 2 - spacing,
                    child: child,
                  ),
                )
                .toList(),
          );
        }

        return Row(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i < children.length - 1)
                const SizedBox(width: AppTheme.spacingLg),
            ],
          ],
        );
      },
    );
  }

  Widget _buildToolbar(EmployeesState state) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: const Color(0xFF181C1F),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: CustomTextField(
              controller: _searchController,
              hintText: 'Search employees by name, role, or contact…',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _searchController.text.isNotEmpty
                  ? const Icon(Icons.close, size: 18)
                  : null,
              onSuffixIconTap: _searchController.text.isNotEmpty
                  ? () {
                      _searchController.clear();
                      context.read<EmployeesBloc>().add(const EmployeesClearSearch());
                    }
                  : null,
              variant: CustomTextFieldVariant.search,
            ),
          ),
          const SizedBox(width: AppTheme.spacingLg),
          SizedBox(width: 200, child: _buildStatusDropdown(state.statusFilter)),
          const SizedBox(width: AppTheme.spacingLg),
          SizedBox(width: 220, child: _buildRoleDropdown(state.roles)),
          const SizedBox(width: AppTheme.spacingLg),
          CustomButton(
            text: 'Refresh',
            variant: CustomButtonVariant.secondary,
            isLoading: state.isRefreshing,
            isDisabled: state.status == EmployeesStatus.loading,
            onPressed: () {
              context.read<EmployeesBloc>().add(const EmployeesRefreshed());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown(String? selectedStatus) {
    return CustomDropdown<String?>(
      value: selectedStatus,
      labelText: 'Status',
      items: const [
        DropdownMenuItem<String?>(value: null, child: Text('All Statuses')),
        DropdownMenuItem<String?>(value: AppConstants.employeeStatusActive, child: Text('Active')),
        DropdownMenuItem<String?>(value: AppConstants.employeeStatusInactive, child: Text('Inactive')),
        DropdownMenuItem<String?>(value: AppConstants.employeeStatusInvited, child: Text('Invited')),
      ],
      onChanged: (value) {
        context.read<EmployeesBloc>().add(EmployeesStatusFilterChanged(value));
      },
    );
  }

  Widget _buildRoleDropdown(List<EmployeeRoleDefinition> roles) {
    return CustomDropdown<String?>(
      value: _roleFilter,
      labelText: 'Role',
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('All Roles')),
        ...roles.map(
          (role) => DropdownMenuItem<String?>(
            value: role.id,
            child: Text(role.name),
          ),
        ),
      ],
      onChanged: (value) {
        context.read<EmployeesBloc>().add(EmployeesRoleFilterChanged(value));
      },
    );
  }

  Widget _buildContent(
    EmployeesState state,
    List<Employee> employees, {
    required String searchQuery,
    required double tableWidth,
  }) {
    final bool waitingForFirstLoad = !hasRealtimeData &&
        (state.status == EmployeesStatus.initial ||
            state.status == EmployeesStatus.loading);

    if (waitingForFirstLoad) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (state.status == EmployeesStatus.failure) {
      return _buildError(state.errorMessage ?? 'Something went wrong');
    }

    final bool shouldShowEmpty =
        state.status == EmployeesStatus.empty || (hasRealtimeData && employees.isEmpty);

    if (shouldShowEmpty) {
      final hasSearch = searchQuery.isNotEmpty;
      return _buildEmpty(hasSearch);
    }

    final table = EmployeesTable(
      employees: employees,
      roles: state.roles,
      availableWidth: tableWidth,
      scrollController: _verticalScrollController,
      horizontalController: _horizontalScrollController,
      hasMore: state.hasMore,
      isLoadingMore: state.isFetchingMore,
      onLoadMore: () => context.read<EmployeesBloc>().add(const EmployeesLoadMore()),
    );

    final bool showOverlay = hasRealtimeData &&
        (state.status == EmployeesStatus.loading || state.isRefreshing);

    return withRealtimeBusyOverlay(
      child: table,
      showOverlay: showOverlay,
      overlayColor: Colors.black.withValues(alpha: 0.18),
      progressIndicator: const CircularProgressIndicator(
        color: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildEmpty(bool isSearch) {
    final icon = isSearch ? Icons.search_off : Icons.badge_outlined;
    final title = isSearch ? 'No matching employees' : 'No employees yet';
    final subtitle = isSearch
        ? 'Try a different search query or clear filters'
        : 'Use the “Add Employee” button to onboard your first team member.';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: AppTheme.textSecondaryColor),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(
            color: AppTheme.errorColor.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
            const SizedBox(height: AppTheme.spacingMd),
            const Text(
              'Unable to load employees',
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              message,
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingLg),
            CustomButton(
              text: 'Retry',
              variant: CustomButtonVariant.primary,
              onPressed: () => context.read<EmployeesBloc>().add(
                    EmployeesRequested(
                      organizationId: widget.organizationId,
                      forceRefresh: true,
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoRolesNotice() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3)),
        color: AppTheme.warningColor.withValues(alpha: 0.08),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppTheme.warningColor),
          const SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Text(
              'Define employee roles first so each team member has a wage configuration. You can manage roles from the Roles tab.',
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 13,
              ),
            ),
          ),
          if (widget.onCreateRoles != null) ...[
            const SizedBox(width: AppTheme.spacingSm),
            TextButton(
              onPressed: widget.onCreateRoles,
              child: const Text('Manage Roles'),
            ),
          ],
        ],
      ),
    );
  }

  void _handleAddEmployeePressed(EmployeesState state) {
    if (state.roles.isEmpty) {
      _showMissingRolesDialog();
      return;
    }

    _showAddEmployeeDialog(state);
  }

  Future<void> _showMissingRolesDialog() async {
    final shouldNavigate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1F24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          title: const Text(
            'Roles Required',
            style: TextStyle(color: AppTheme.textPrimaryColor),
          ),
          content: Text(
            'Create at least one role before adding employees. Roles define wage settings and permissions.',
            style: TextStyle(color: AppTheme.textSecondaryColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            if (widget.onCreateRoles != null)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Manage Roles'),
              ),
          ],
        );
      },
    );

    if (shouldNavigate == true) {
      widget.onCreateRoles?.call();
    }
  }

  void _showAddEmployeeDialog(EmployeesState state) async {
    final bloc = context.read<EmployeesBloc>();
    final result = await showDialog<EmployeeFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => EmployeeFormDialog(
        roles: state.roles,
        currency: AppConstants.defaultCurrency,
      ),
    );

    if (result == null) {
      return;
    }

    bloc.add(
      EmployeeCreateRequested(
        organizationId: widget.organizationId,
        name: result.name,
        roleId: result.roleId,
        startDate: result.startDate,
        openingBalance: result.openingBalance,
        currency: result.currency,
        status: result.status,
        contactEmail: result.email,
        contactPhone: result.phone,
        notes: result.notes,
        requestedBy: widget.requestedBy,
      ),
    );
  }

  String _roleLabel(int role) {
    switch (role) {
      case AppConstants.superAdminRole:
      case AppConstants.adminRole:
        return 'admin';
      case AppConstants.managerRole:
        return 'manager';
      default:
        return 'member';
    }
  }
}

class EmployeesTable extends StatelessWidget {
  const EmployeesTable({
    super.key,
    required this.employees,
    required this.roles,
    required this.availableWidth,
    required this.scrollController,
    required this.horizontalController,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  final List<Employee> employees;
  final List<EmployeeRoleDefinition> roles;
  final double availableWidth;
  final ScrollController scrollController;
  final ScrollController horizontalController;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  static const double _minTableWidth = 1200;

  Map<String, String> get _roleLookup => {
        for (final role in roles) role.id: role.name,
      };

  @override
  Widget build(BuildContext context) {
    final roleLookup = _roleLookup;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141618).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Scrollbar(
              controller: scrollController,
              thumbVisibility: employees.length > 12,
              child: SingleChildScrollView(
                controller: scrollController,
                child: SingleChildScrollView(
                  controller: horizontalController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: math.max(_minTableWidth, availableWidth),
                    child: DataTable(
                      headingRowHeight: 56,
                      dataRowMinHeight: 72,
                      dataRowMaxHeight: 88,
                      horizontalMargin: 0,
                      columnSpacing: 24,
                      dividerThickness: 1,
                      headingRowColor: MaterialStateProperty.all(
                        const Color(0xFF1F2937).withValues(alpha: 0.88),
                      ),
                      dataRowColor: MaterialStateProperty.resolveWith<Color?>(
                        (states) {
                          if (states.contains(MaterialState.hovered)) {
                            return AppTheme.borderColor.withValues(alpha: 0.24);
                          }
                          return Colors.transparent;
                        },
                      ),
                      columns: const [
                        DataColumn(label: _TableHeader('EMPLOYEE')),
                        DataColumn(label: _TableHeader('ROLE')),
                        DataColumn(label: _TableHeader('CONTACT')),
                        DataColumn(label: _TableHeader('START DATE')),
                        DataColumn(label: _TableHeader('OPENING BALANCE')),
                        DataColumn(label: _TableHeader('STATUS')),
                      ],
                      rows: employees
                          .map(
                            (employee) => DataRow(
                              cells: [
                                DataCell(_EmployeeCell(employee: employee)),
                                DataCell(_RoleCell(
                                  roleName: roleLookup[employee.roleId] ?? '—',
                                )),
                                DataCell(_ContactCell(employee: employee)),
                                DataCell(_DateCell(date: employee.startDate)),
                                DataCell(_OpeningBalanceCell(employee: employee)),
                                DataCell(_StatusChip(status: employee.status)),
                              ],
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (hasMore || isLoadingMore)
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: CustomButton(
                text: 'Load More',
                variant: CustomButtonVariant.secondary,
                isLoading: isLoadingMore,
                isDisabled: isLoadingMore,
                onPressed: onLoadMore,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmployeeCell extends StatelessWidget {
  const _EmployeeCell({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.accentColor.withValues(alpha: 0.15),
            child: Text(
              employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AppTheme.accentColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  employee.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  employee.id,
                  style: const TextStyle(
                    color: AppTheme.textTertiaryColor,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCell extends StatelessWidget {
  const _RoleCell({required this.roleName});

  final String roleName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Text(
        roleName,
        style: const TextStyle(
          color: AppTheme.textSecondaryColor,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ContactCell extends StatelessWidget {
  const _ContactCell({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final values = <String>[
      if ((employee.contactEmail ?? '').isNotEmpty) employee.contactEmail!,
      if ((employee.contactPhone ?? '').isNotEmpty) employee.contactPhone!,
    ];

    if (values.isEmpty) {
      return const Text('—', style: TextStyle(color: AppTheme.textTertiaryColor));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: values
            .map(
              (value) => Text(
                value,
                style: const TextStyle(color: AppTheme.textPrimaryColor, fontSize: 13),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _DateCell extends StatelessWidget {
  const _DateCell({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Text(
        _formatDate(date),
        style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _OpeningBalanceCell extends StatelessWidget {
  const _OpeningBalanceCell({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final formatted = '${employee.openingBalanceCurrency.toUpperCase()} '
        '${employee.openingBalance.toStringAsFixed(2)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Text(
        formatted,
        style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case AppConstants.employeeStatusActive:
        color = AppTheme.successColor;
        break;
      case AppConstants.employeeStatusInactive:
        color = AppTheme.warningColor;
        break;
      case AppConstants.employeeStatusInvited:
        color = AppTheme.accentColor;
        break;
      default:
        color = AppTheme.textTertiaryColor;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSm,
        vertical: AppTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textSecondaryColor,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _SummaryCardData {
  const _SummaryCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final int value;
  final IconData icon;
  final Color color;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data, required this.isLoading});

  final _SummaryCardData data;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        color: const Color(0xFF141618).withValues(alpha: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingSm),
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: Icon(data.icon, color: data.color, size: 24),
          ),
          const SizedBox(width: AppTheme.spacingLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                isLoading
                    ? Container(
                        height: 20,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      )
                    : Text(
                        data.value.toString(),
                        style: const TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
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

class EmployeeFormResult {
  const EmployeeFormResult({
    required this.name,
    required this.roleId,
    required this.startDate,
    required this.openingBalance,
    required this.currency,
    required this.status,
    this.email,
    this.phone,
    this.notes,
  });

  final String name;
  final String roleId;
  final DateTime startDate;
  final double openingBalance;
  final String currency;
  final String status;
  final String? email;
  final String? phone;
  final String? notes;
}

class EmployeeFormDialog extends StatefulWidget {
  const EmployeeFormDialog({super.key, required this.roles, required this.currency});

  final List<EmployeeRoleDefinition> roles;
  final String currency;

  @override
  State<EmployeeFormDialog> createState() => _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends State<EmployeeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _openingBalanceController = TextEditingController(text: '0');
  final TextEditingController _currencyController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  String? _selectedRoleId;
  DateTime _selectedDate = DateTime.now();
  String _status = AppConstants.employeeStatusActive;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _currencyController.text = widget.currency.toUpperCase();
    if (widget.roles.isNotEmpty) {
      _selectedRoleId = widget.roles.first.id;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _openingBalanceController.dispose();
    _currencyController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF101213),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacing2xl),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_add_alt_1, color: AppTheme.primaryColor),
                    const SizedBox(width: AppTheme.spacingSm),
                    const Text(
                      'Add Employee',
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: AppTheme.textSecondaryColor),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingXl),
                CustomTextField(
                  controller: _nameController,
                  focusNode: _nameFocus,
                  labelText: 'Full Name',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter employee name';
                    }
                    if (value.trim().length > AppConstants.maxNameLength) {
                      return 'Name must be under ${AppConstants.maxNameLength} characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spacingLg),
                CustomDropdown<String>(
                  value: _selectedRoleId,
                  labelText: 'Role',
                  items: widget.roles
                      .map(
                        (role) => DropdownMenuItem(
                          value: role.id,
                          child: Text(role.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _selectedRoleId = value),
                  validator: (value) => value == null ? 'Select a role' : null,
                ),
                const SizedBox(height: AppTheme.spacingLg),
                Row(
                  children: [
                    Expanded(child: _buildDatePicker(context)),
                    const SizedBox(width: AppTheme.spacingLg),
                    Expanded(child: _buildFormStatusDropdown()),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingLg),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _openingBalanceController,
                        labelText: 'Opening Balance',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter opening balance';
                          }
                          final parsed = double.tryParse(value.trim());
                          if (parsed == null) {
                            return 'Enter a valid number';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingLg),
                    SizedBox(
                      width: 120,
                      child: CustomTextField(
                        controller: _currencyController,
                        labelText: 'Currency',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          if (value.trim().length != 3) {
                            return 'ISO code (e.g., INR)';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingLg),
                CustomTextField(
                  controller: _emailController,
                  labelText: 'Email (optional)',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null;
                    }
                    final email = value.trim();
                    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    if (!emailRegex.hasMatch(email)) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spacingLg),
                CustomTextField(
                  controller: _phoneController,
                  labelText: 'Phone (optional)',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppTheme.spacingLg),
                CustomTextField(
                  controller: _notesController,
                  labelText: 'Notes (optional)',
                  maxLines: 3,
                  validator: (value) {
                    if (value != null && value.length > AppConstants.maxDescriptionLength) {
                      return 'Notes must be under ${AppConstants.maxDescriptionLength} characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spacingXl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CustomButton(
                      text: 'Cancel',
                      variant: CustomButtonVariant.ghost,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: AppTheme.spacingLg),
                    CustomButton(
                      text: 'Add Employee',
                      variant: CustomButtonVariant.primary,
                      isLoading: _isSubmitting,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return GestureDetector(
      onTap: _pickStartDate,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Start Date',
          labelStyle: const TextStyle(color: AppTheme.textSecondaryColor),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            borderSide: const BorderSide(color: AppTheme.primaryColor),
          ),
          filled: true,
          fillColor: const Color(0xFF0F1112),
        ),
        child: Row(
          children: [
            const Icon(Icons.event, size: 18, color: AppTheme.textSecondaryColor),
            const SizedBox(width: AppTheme.spacingSm),
            Text(
              _formatDate(_selectedDate),
              style: const TextStyle(color: AppTheme.textPrimaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormStatusDropdown() {
    return CustomDropdown<String>(
      value: _status,
      labelText: 'Status',
      items: const [
        DropdownMenuItem(value: AppConstants.employeeStatusActive, child: Text('Active')),
        DropdownMenuItem(value: AppConstants.employeeStatusInactive, child: Text('Inactive')),
        DropdownMenuItem(value: AppConstants.employeeStatusInvited, child: Text('Invited')),
      ],
      onChanged: (value) => setState(() => _status = value ?? _status),
    );
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              surface: Color(0xFF121417),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _submit() {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedRoleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a role before continuing'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final result = EmployeeFormResult(
      name: _nameController.text.trim(),
      roleId: _selectedRoleId!,
      startDate: _selectedDate,
      openingBalance: double.parse(_openingBalanceController.text.trim()),
      currency: _currencyController.text.trim().toUpperCase(),
      status: _status,
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    Navigator.of(context).pop(result);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

