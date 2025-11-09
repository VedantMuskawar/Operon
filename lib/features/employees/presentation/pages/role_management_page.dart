import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../contexts/organization_context.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/employee_role_definition.dart';
import '../../../../core/navigation/organization_navigation_scope.dart';
import '../../../../core/repositories/employee_repository.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_dropdown.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/page_container.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/realtime_list_cache_mixin.dart';
import '../../bloc/roles_bloc.dart';
import '../../bloc/roles_event.dart';
import '../../bloc/roles_state.dart';

class RoleManagementPage extends StatelessWidget {
  const RoleManagementPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return OrganizationAwareWidget(
      builder: (context, orgContext) {
        final organizationId = orgContext.organizationId;
        final organizationName = orgContext.organizationName ?? 'Organization';

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
          create: (context) => RolesBloc(
            employeeRepository: EmployeeRepository(),
          )..add(RolesRequested(organizationId: organizationId)),
          child: RoleManagementView(
            organizationId: organizationId,
            organizationName: organizationName,
            userRole: orgContext.userRole ?? AppConstants.adminRole,
            onBack: onBack ?? navigation?.goHome,
          ),
        );
      },
    );
  }
}

class RoleManagementView extends StatefulWidget {
  const RoleManagementView({
    super.key,
    required this.organizationId,
    required this.organizationName,
    required this.userRole,
    this.onBack,
  });

  final String organizationId;
  final String organizationName;
  final int userRole;
  final VoidCallback? onBack;

  @override
  State<RoleManagementView> createState() => _RoleManagementViewState();
}

class _RoleManagementViewState
    extends RealtimeListCacheState<RoleManagementView, EmployeeRoleDefinition> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _tableScrollController = ScrollController();
  final ScrollController _tableHorizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _tableScrollController.dispose();
    _tableHorizontalController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final bloc = context.read<RolesBloc>();
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      bloc.add(const RolesClearSearch());
    } else {
      bloc.add(RolesSearchQueryChanged(query));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RolesBloc, RolesState>(
      listener: (context, state) {
        if (state.status == RolesStatus.success) {
          applyRealtimeItems(
            state.visibleRoles,
            searchQuery: state.searchQuery.isNotEmpty ? state.searchQuery : null,
          );
        } else if (state.status == RolesStatus.empty) {
          applyRealtimeEmpty(
            searchQuery: state.searchQuery.isNotEmpty ? state.searchQuery : null,
          );
        } else if (state.status == RolesStatus.initial) {
          resetRealtimeSnapshot();
        }

        if (!state.clearError && state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      },
      builder: (context, state) {
        final roles = hasRealtimeData ? realtimeItems : state.visibleRoles;
        final effectiveSearch =
            state.searchQuery.isNotEmpty ? state.searchQuery : realtimeSearchQuery ?? '';

        return PageContainer(
          fullHeight: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Roles',
                role: _roleLabel(widget.userRole),
                onBack: widget.onBack,
                actions: [
                  CustomButton(
                    text: 'Add Role',
                    icon: const Icon(Icons.add, size: 18),
                    variant: CustomButtonVariant.primary,
                    isDisabled: state.isMutating,
                    onPressed: state.isMutating
                        ? null
                        : () => _showCreateRoleDialog(context),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                'Configure role definitions for ${widget.organizationName}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
              ),
              const SizedBox(height: AppTheme.spacingLg),
              _buildToolbar(state),
              const SizedBox(height: AppTheme.spacingLg),
              Expanded(
                child: _buildContent(
                  state,
                  roles,
                  searchQuery: effectiveSearch,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolbar(RolesState state) {
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
              hintText: 'Search roles by name, wage type, or permission…',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _searchController.text.isNotEmpty
                  ? const Icon(Icons.close, size: 18)
                  : null,
              onSuffixIconTap: _searchController.text.isNotEmpty
                  ? () {
                      _searchController.clear();
                      context.read<RolesBloc>().add(const RolesClearSearch());
                    }
                  : null,
              variant: CustomTextFieldVariant.search,
            ),
          ),
          const SizedBox(width: AppTheme.spacingLg),
          CustomButton(
            text: 'Refresh',
            variant: CustomButtonVariant.secondary,
            isLoading: state.isRefreshing,
            isDisabled: state.status == RolesStatus.loading,
            onPressed: () => context.read<RolesBloc>().add(const RolesRefreshed()),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    RolesState state,
    List<EmployeeRoleDefinition> roles, {
    required String searchQuery,
  }) {
    final bool waitingForFirstLoad = !hasRealtimeData &&
        (state.status == RolesStatus.initial || state.status == RolesStatus.loading);

    if (waitingForFirstLoad) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (state.status == RolesStatus.failure) {
      return _buildError(state.errorMessage ?? 'Something went wrong');
    }

    final bool shouldShowEmpty =
        state.status == RolesStatus.empty || (hasRealtimeData && roles.isEmpty);

    if (shouldShowEmpty) {
      final hasSearch = searchQuery.isNotEmpty;
      return _buildEmpty(hasSearch);
    }

    final table = RolesTable(
      roles: roles,
      scrollController: _tableScrollController,
      horizontalController: _tableHorizontalController,
      onEdit: _showEditRoleDialog,
      onDelete: _confirmDeleteRole,
    );

    final bool showOverlay = hasRealtimeData &&
        (state.status == RolesStatus.loading || state.isRefreshing || state.isMutating);

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
    final icon = isSearch ? Icons.search_off : Icons.manage_accounts_outlined;
    final title = isSearch ? 'No matching roles' : 'No roles defined yet';
    final subtitle = isSearch
        ? 'Try a different search term or clear filters.'
        : 'Create roles to assign wage configurations and permissions.';

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
          SizedBox(
            width: 360,
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
            ),
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
              'Unable to load roles',
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
              onPressed: () => context.read<RolesBloc>().add(
                    RolesRequested(
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

  void _showCreateRoleDialog(BuildContext context) async {
    final result = await showDialog<RoleFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RoleFormDialog(
        title: 'Create Role',
        primaryActionLabel: 'Create Role',
      ),
    );

    if (result == null) return;

    context.read<RolesBloc>().add(RoleCreateRequested(
          organizationId: widget.organizationId,
          name: result.name,
          description: result.description,
          permissions: result.permissions,
          priority: result.priority,
          wageType: result.wageType,
          compensationFrequency: result.compensationFrequency,
          quantity: result.quantity,
          wagePerQuantity: result.wagePerQuantity,
          monthlySalary: result.monthlySalary,
          monthlyBonus: result.monthlyBonus,
          createdBy: result.actor,
        ));
  }

  void _showEditRoleDialog(EmployeeRoleDefinition role) async {
    if (role.isSystem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('System roles cannot be edited'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    final result = await showDialog<RoleFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RoleFormDialog(
        title: 'Edit Role',
        primaryActionLabel: 'Save Changes',
        existing: role,
      ),
    );

    if (result == null) return;

    context.read<RolesBloc>().add(RoleUpdateRequested(
          organizationId: widget.organizationId,
          roleId: role.id,
          name: result.name,
          description: result.description,
          permissions: result.permissions,
          priority: result.priority,
          wageType: result.wageType,
          compensationFrequency: result.compensationFrequency,
          quantity: result.quantity,
          clearQuantity: result.clearQuantity,
          wagePerQuantity: result.wagePerQuantity,
          clearWagePerQuantity: result.clearWagePerQuantity,
          monthlySalary: result.monthlySalary,
          clearMonthlySalary: result.clearMonthlySalary,
          monthlyBonus: result.monthlyBonus,
          clearMonthlyBonus: result.clearMonthlyBonus,
          updatedBy: result.actor,
        ));
  }

  void _confirmDeleteRole(EmployeeRoleDefinition role) async {
    if (role.isSystem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('System roles cannot be deleted'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111315),
        title: const Text(
          'Delete Role',
          style: TextStyle(color: AppTheme.textPrimaryColor),
        ),
        content: Text(
          'Are you sure you want to delete the role "${role.name}"? This action cannot be undone.',
          style: const TextStyle(color: AppTheme.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    context.read<RolesBloc>().add(RoleDeleteRequested(
          organizationId: widget.organizationId,
          roleId: role.id,
        ));
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

class RolesTable extends StatelessWidget {
  const RolesTable({
    super.key,
    required this.roles,
    required this.scrollController,
    required this.horizontalController,
    required this.onEdit,
    required this.onDelete,
  });

  final List<EmployeeRoleDefinition> roles;
  final ScrollController scrollController;
  final ScrollController horizontalController;
  final void Function(EmployeeRoleDefinition) onEdit;
  final void Function(EmployeeRoleDefinition) onDelete;

  static const double _minTableWidth = 1100;

  @override
  Widget build(BuildContext context) {
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
      child: Scrollbar(
        controller: scrollController,
        thumbVisibility: roles.length > 12,
        child: SingleChildScrollView(
          controller: scrollController,
          child: SingleChildScrollView(
            controller: horizontalController,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: _minTableWidth),
              child: DataTable(
                headingRowHeight: 56,
                dataRowMinHeight: 72,
                dataRowMaxHeight: 96,
                horizontalMargin: 20,
                columnSpacing: 24,
                dividerThickness: 1,
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFF1F2937).withValues(alpha: 0.88),
                ),
                dataRowColor: WidgetStateProperty.resolveWith<Color?>(
                  (states) => states.contains(WidgetState.hovered)
                      ? AppTheme.borderColor.withValues(alpha: 0.24)
                      : Colors.transparent,
                ),
                columns: const [
                  DataColumn(label: _TableHeader('ROLE')),
                  DataColumn(label: _TableHeader('WAGE TYPE')),
                  DataColumn(label: _TableHeader('COMPENSATION')),
                  DataColumn(label: _TableHeader('PERMISSIONS')),
                  DataColumn(label: _TableHeader('PRIORITY')),
                  DataColumn(label: _TableHeader('SYSTEM')),
                  DataColumn(label: _TableHeader('ACTIONS')),
                ],
                rows: roles.map((role) => _buildRow(context, role)).toList(growable: false),
              ),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _buildRow(BuildContext context, EmployeeRoleDefinition role) {
    return DataRow(
      cells: [
        DataCell(_RoleCell(role: role)),
        DataCell(Text(
            '${_capitalize(role.wageType)} · ${_frequencyLabel(role.compensationFrequency)}')),
        DataCell(Text(_compensationSummary(role))),
        DataCell(Text(role.permissions.isEmpty
            ? '—'
            : role.permissions.join(', '))),
        DataCell(Text(role.priority?.toString() ?? '—')),
        DataCell(Text(role.isSystem ? 'Yes' : 'No')),
        DataCell(Row(
          children: [
            IconButton(
              tooltip: role.isSystem ? 'System roles cannot be edited' : 'Edit role',
              icon: const Icon(Icons.edit, size: 18),
              color: AppTheme.textSecondaryColor,
              onPressed: role.isSystem ? null : () => onEdit(role),
            ),
            IconButton(
              tooltip: role.isSystem ? 'System roles cannot be deleted' : 'Delete role',
              icon: const Icon(Icons.delete_outline, size: 18),
              color: AppTheme.errorColor,
              onPressed: role.isSystem ? null : () => onDelete(role),
            ),
          ],
        )),
      ],
    );
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  static String _frequencyLabel(String value) {
    switch (value) {
      case AppConstants.employeeCompFrequencyBiweekly:
        return 'Biweekly';
      case AppConstants.employeeCompFrequencyWeekly:
        return 'Weekly';
      case AppConstants.employeeCompFrequencyPerShift:
        return 'Per Shift';
      case AppConstants.employeeCompFrequencyMonthly:
      default:
        return 'Monthly';
    }
  }

  String _compensationSummary(EmployeeRoleDefinition role) {
    switch (role.wageType) {
      case AppConstants.employeeWageTypeHourly:
        if (role.wagePerQuantity != null) {
          return '${AppConstants.defaultCurrency} ${role.wagePerQuantity!.toStringAsFixed(2)} per hour · ${_frequencyLabel(role.compensationFrequency)}';
        }
        return 'Hourly · ${_frequencyLabel(role.compensationFrequency)}';
      case AppConstants.employeeWageTypeQuantity:
        final quantity = role.quantity ?? 0;
        final rate = role.wagePerQuantity;
        if (rate != null) {
          return '${quantity.toStringAsFixed(quantity == quantity.roundToDouble() ? 0 : 2)} units · ${AppConstants.defaultCurrency} ${rate.toStringAsFixed(2)} each · ${_frequencyLabel(role.compensationFrequency)}';
        }
        return '${quantity.toStringAsFixed(quantity == quantity.roundToDouble() ? 0 : 2)} units · ${_frequencyLabel(role.compensationFrequency)}';
      case AppConstants.employeeWageTypeMonthly:
      default:
        final salary = role.monthlySalary;
        final bonus = role.monthlyBonus;
        if (salary != null && bonus != null) {
          return '${AppConstants.defaultCurrency} ${salary.toStringAsFixed(2)} salary + ${AppConstants.defaultCurrency} ${bonus.toStringAsFixed(2)} bonus · ${_frequencyLabel(role.compensationFrequency)}';
        }
        if (salary != null) {
          return '${AppConstants.defaultCurrency} ${salary.toStringAsFixed(2)} salary · ${_frequencyLabel(role.compensationFrequency)}';
        }
        if (bonus != null) {
          return 'Bonus ${AppConstants.defaultCurrency} ${bonus.toStringAsFixed(2)} · ${_frequencyLabel(role.compensationFrequency)}';
        }
        return _frequencyLabel(role.compensationFrequency);
    }
  }
}

class _RoleCell extends StatelessWidget {
  const _RoleCell({required this.role});

  final EmployeeRoleDefinition role;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            role.name,
            style: const TextStyle(
              color: AppTheme.textPrimaryColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (role.description != null && role.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              role.description!,
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppTheme.textSecondaryColor,
        fontWeight: FontWeight.w700,
        fontSize: 11,
        letterSpacing: 0.6,
      ),
    );
  }
}

class RoleFormResult {
  const RoleFormResult({
    this.roleId,
    required this.name,
    required this.wageType,
    required this.compensationFrequency,
    this.description,
    this.permissions = const [],
    this.priority,
    this.quantity,
    this.clearQuantity = false,
    this.wagePerQuantity,
    this.clearWagePerQuantity = false,
    this.monthlySalary,
    this.clearMonthlySalary = false,
    this.monthlyBonus,
    this.clearMonthlyBonus = false,
    this.actor,
  });

  final String? roleId;
  final String name;
  final String wageType;
  final String compensationFrequency;
  final String? description;
  final List<String> permissions;
  final int? priority;
  final double? quantity;
  final bool clearQuantity;
  final double? wagePerQuantity;
  final bool clearWagePerQuantity;
  final double? monthlySalary;
  final bool clearMonthlySalary;
  final double? monthlyBonus;
  final bool clearMonthlyBonus;
  final String? actor;
}

class RoleFormDialog extends StatefulWidget {
  const RoleFormDialog({
    super.key,
    required this.title,
    required this.primaryActionLabel,
    this.existing,
  });

  final String title;
  final String primaryActionLabel;
  final EmployeeRoleDefinition? existing;

  @override
  State<RoleFormDialog> createState() => _RoleFormDialogState();
}

class _RoleFormDialogState extends State<RoleFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _permissionsController;
  late TextEditingController _priorityController;
  late TextEditingController _quantityController;
  late TextEditingController _wagePerQuantityController;
  late TextEditingController _monthlySalaryController;
  late TextEditingController _monthlyBonusController;
  late TextEditingController _actorController;

  late String _wageType;
  late String _compensationFrequency;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descriptionController = TextEditingController(text: existing?.description ?? '');
    _permissionsController = TextEditingController(
      text: existing?.permissions.join('\n') ?? '',
    );
    _priorityController = TextEditingController(
      text: existing?.priority?.toString() ?? '',
    );
    _quantityController = TextEditingController(
      text: existing?.quantity?.toString() ?? '',
    );
    _wagePerQuantityController = TextEditingController(
      text: existing?.wagePerQuantity?.toString() ?? '',
    );
    _monthlySalaryController = TextEditingController(
      text: existing?.monthlySalary?.toString() ?? '',
    );
    _monthlyBonusController = TextEditingController(
      text: existing?.monthlyBonus?.toString() ?? '',
    );
    _actorController = TextEditingController();
    _wageType = existing?.wageType ?? AppConstants.employeeWageTypeMonthly;
    _compensationFrequency =
        existing?.compensationFrequency ?? AppConstants.employeeCompFrequencyMonthly;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _permissionsController.dispose();
    _priorityController.dispose();
    _quantityController.dispose();
    _wagePerQuantityController.dispose();
    _monthlySalaryController.dispose();
    _monthlyBonusController.dispose();
    _actorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSystem = widget.existing?.isSystem ?? false;

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
                    const Icon(Icons.admin_panel_settings, color: AppTheme.primaryColor),
                    const SizedBox(height: AppTheme.spacingSm, width: AppTheme.spacingSm),
                    Text(
                      widget.title,
                      style: const TextStyle(
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
                if (isSystem)
                  Padding(
                    padding: const EdgeInsets.only(top: AppTheme.spacingSm),
                    child: Container(
                      padding: const EdgeInsets.all(AppTheme.spacingSm),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      ),
                      child: const Text(
                        'This is a system-managed role. Some fields are locked to protect default access.',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: AppTheme.spacingXl),
                CustomTextField(
                  controller: _nameController,
                  labelText: 'Role name',
                  readOnly: isSystem,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a role name';
                    }
                    if (value.trim().length > AppConstants.maxNameLength) {
                      return 'Name must be under ${AppConstants.maxNameLength} characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spacingLg),
                CustomTextField(
                  controller: _descriptionController,
                  labelText: 'Description (optional)',
                  maxLines: 3,
                  validator: (value) {
                    if (value != null && value.length > AppConstants.maxDescriptionLength) {
                      return 'Description must be under ${AppConstants.maxDescriptionLength} characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spacingLg),
                CustomDropdown<String>(
                  value: _wageType,
                  labelText: 'Wage type',
                  enabled: !isSystem,
                  items: const [
                    DropdownMenuItem(
                      value: AppConstants.employeeWageTypeHourly,
                      child: Text('Hourly'),
                    ),
                    DropdownMenuItem(
                      value: AppConstants.employeeWageTypeQuantity,
                      child: Text('Quantity Based'),
                    ),
                    DropdownMenuItem(
                      value: AppConstants.employeeWageTypeMonthly,
                      child: Text('Monthly'),
                    ),
                  ],
                  onChanged: isSystem
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _wageType = value;
                          });
                        },
                ),
                const SizedBox(height: AppTheme.spacingLg),
                CustomDropdown<String>(
                  value: _compensationFrequency,
                  labelText: 'Compensation frequency',
                  enabled: !isSystem,
                  items: const [
                    DropdownMenuItem(
                      value: AppConstants.employeeCompFrequencyMonthly,
                      child: Text('Monthly'),
                    ),
                    DropdownMenuItem(
                      value: AppConstants.employeeCompFrequencyBiweekly,
                      child: Text('Biweekly'),
                    ),
                    DropdownMenuItem(
                      value: AppConstants.employeeCompFrequencyWeekly,
                      child: Text('Weekly'),
                    ),
                    DropdownMenuItem(
                      value: AppConstants.employeeCompFrequencyPerShift,
                      child: Text('Per Shift / Job'),
                    ),
                  ],
                  onChanged: isSystem
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _compensationFrequency = value);
                        },
                ),
                const SizedBox(height: AppTheme.spacingLg),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _priorityController,
                        labelText: 'Priority (optional)',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return null;
                          }
                          final parsed = int.tryParse(value.trim());
                          if (parsed == null) {
                            return 'Enter a valid number';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingLg),
                    Expanded(
                      child: CustomTextField(
                        controller: _actorController,
                        labelText: 'Your name (optional)',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingLg),
                _buildCompensationFields(),
                const SizedBox(height: AppTheme.spacingLg),
                CustomTextField(
                  controller: _permissionsController,
                  labelText: 'Permissions (one per line, optional)',
                  maxLines: 4,
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
                      text: widget.primaryActionLabel,
                      variant: CustomButtonVariant.primary,
                      isLoading: _isSubmitting,
                      onPressed: _isSubmitting ? null : _submit,
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

  Widget _buildCompensationFields() {
    switch (_wageType) {
      case AppConstants.employeeWageTypeHourly:
        return Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _wagePerQuantityController,
                labelText: 'Hourly rate (${AppConstants.defaultCurrency})',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter hourly rate';
                  }
                  final parsed = double.tryParse(value.trim());
                  if (parsed == null) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: AppTheme.spacingLg),
            Expanded(
              child: CustomTextField(
                controller: _quantityController,
                labelText: 'Default hours (optional)',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        );
      case AppConstants.employeeWageTypeQuantity:
        return Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _quantityController,
                labelText: 'Quantity per cycle',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a quantity';
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
            Expanded(
              child: CustomTextField(
                controller: _wagePerQuantityController,
                labelText: 'Amount per quantity (${AppConstants.defaultCurrency})',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter amount';
                  }
                  final parsed = double.tryParse(value.trim());
                  if (parsed == null) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              ),
            ),
          ],
        );
      case AppConstants.employeeWageTypeMonthly:
      default:
        return Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _monthlySalaryController,
                labelText: 'Monthly salary (${AppConstants.defaultCurrency})',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: AppTheme.spacingLg),
            Expanded(
              child: CustomTextField(
                controller: _monthlyBonusController,
                labelText: 'Monthly bonus (${AppConstants.defaultCurrency}, optional)',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        );
    }
  }

  void _submit() {
    if (_isSubmitting) return;
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() => _isSubmitting = true);

    final permissions = _permissionsController.text
        .split(RegExp(r'[\n,]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    double? parseDouble(String text) => text.trim().isEmpty ? null : double.tryParse(text.trim());

    final quantityText = _quantityController.text.trim();
    final wagePerQuantityText = _wagePerQuantityController.text.trim();
    final monthlySalaryText = _monthlySalaryController.text.trim();
    final monthlyBonusText = _monthlyBonusController.text.trim();

    final quantityValue = parseDouble(quantityText);
    final wagePerQuantityValue = parseDouble(wagePerQuantityText);
    final monthlySalaryValue = parseDouble(monthlySalaryText);
    final monthlyBonusValue = parseDouble(monthlyBonusText);

    final result = RoleFormResult(
      roleId: widget.existing?.id,
      name: _nameController.text.trim(),
      wageType: _wageType,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      permissions: permissions,
      priority: _priorityController.text.trim().isEmpty
          ? null
          : int.tryParse(_priorityController.text.trim()),
      quantity: quantityValue,
      clearQuantity: quantityText.isEmpty,
      wagePerQuantity: wagePerQuantityValue,
      clearWagePerQuantity: wagePerQuantityText.isEmpty,
      monthlySalary: monthlySalaryValue,
      clearMonthlySalary: monthlySalaryText.isEmpty,
      monthlyBonus: monthlyBonusValue,
      clearMonthlyBonus: monthlyBonusText.isEmpty,
      actor: _actorController.text.trim().isEmpty ? null : _actorController.text.trim(),
      compensationFrequency: _compensationFrequency,
    );

    Navigator.of(context).pop(result);
  }
}

