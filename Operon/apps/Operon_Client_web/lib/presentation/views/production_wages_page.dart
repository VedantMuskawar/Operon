import 'package:core_bloc/core_bloc.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/repositories/employees_repository.dart';
import 'package:dash_web/data/repositories/products_repository.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/blocs/production_batches/production_batches_cubit.dart';
import 'package:dash_web/presentation/blocs/production_batches/production_batches_state.dart';
import 'package:dash_web/presentation/widgets/production_batch_card.dart';
import 'package:dash_web/presentation/widgets/production_batch_detail_modal.dart';
import 'package:dash_web/presentation/widgets/production_batch_form.dart';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ProductionWagesPage extends StatelessWidget {
  const ProductionWagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;

    if (organization == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('No organization selected'),
              const SizedBox(height: 16),
              DashButton(
                label: 'Select Organization',
                onPressed: () => context.go('/org-selection'),
              ),
            ],
          ),
        ),
      );
    }

    return BlocProvider(
      create: (context) => ProductionBatchesCubit(
        repository: context.read<ProductionBatchesRepository>(),
        organizationId: organization.id,
        wageSettingsRepository: context.read<WageSettingsRepository>(),
        wageCalculationService: WageCalculationService(
          employeeWagesDataSource: EmployeeWagesDataSource(),
          productionBatchesDataSource: ProductionBatchesDataSource(),
          tripWagesDataSource: TripWagesDataSource(),
          employeeAttendanceDataSource: EmployeeAttendanceDataSource(),
        ),
      )..loadBatches(),
      child: SectionWorkspaceLayout(
        panelTitle: 'Production Wages',
        currentIndex: -1,
        onNavTap: (index) => context.go('/home?section=$index'),
        child: const _ProductionWagesContent(),
      ),
    );
  }
}

// Content widget for sidebar use
class ProductionWagesPageContent extends StatelessWidget {
  const ProductionWagesPageContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProductionBatchesCubit, ProductionBatchesState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          DashSnackbar.show(context, message: state.message!, isError: true);
        }
      },
      child: const _ProductionWagesContent(),
    );
  }
}

String _getProductionWagesTabEmptyTitle(WorkflowTab tab) {
  switch (tab) {
    case WorkflowTab.all:
      return 'No production batches yet';
    case WorkflowTab.needsAction:
      return 'No batches need action';
    case WorkflowTab.recorded:
      return 'No recorded batches';
    case WorkflowTab.calculated:
      return 'No calculated batches';
    case WorkflowTab.approved:
      return 'No approved batches';
    case WorkflowTab.processed:
      return 'No processed batches';
  }
}

String _getProductionWagesTabEmptyMessage(WorkflowTab tab) {
  switch (tab) {
    case WorkflowTab.all:
      return 'Create your first production batch to get started';
    case WorkflowTab.needsAction:
      return 'All batches are up to date';
    case WorkflowTab.recorded:
      return 'Recorded batches will appear here';
    case WorkflowTab.calculated:
      return 'Calculated batches will appear here';
    case WorkflowTab.approved:
      return 'Approved batches will appear here';
    case WorkflowTab.processed:
      return 'Processed batches will appear here';
  }
}

Widget _buildEmptyState(
  BuildContext context,
  ProductionBatchesState state,
  dynamic organization,
) {
  final hasFilters = state.searchQuery != null ||
      state.startDate != null ||
      state.endDate != null ||
      state.startDate2 != null ||
      state.endDate2 != null ||
      state.selectedTab != WorkflowTab.all;

  final title = state.batches.isEmpty
      ? 'No production batches yet'
      : hasFilters
          ? 'No batches match your filters'
          : _getProductionWagesTabEmptyTitle(state.selectedTab);
  final message = state.batches.isEmpty
      ? 'Create your first production batch to get started'
      : hasFilters
          ? 'Try adjusting your filters or clearing them'
          : _getProductionWagesTabEmptyMessage(state.selectedTab);

  Widget? action;
  if (hasFilters) {
    action = DashButton(
      icon: Icons.clear_all,
      label: 'Clear Filters',
      onPressed: () => context.read<ProductionBatchesCubit>().clearAllFilters(),
    );
  } else if (state.batches.isEmpty) {
    action = DashButton(
      icon: Icons.add,
      label: 'Create First Batch',
      onPressed: () {
        if (organization != null) {
          final cubit = context.read<ProductionBatchesCubit>();
          final employeesRepo = context.read<EmployeesRepository>();
          final productsRepo = context.read<ProductsRepository>();
          final wageSettingsRepo = context.read<WageSettingsRepository>();
          showDialog(
            context: context,
            builder: (dialogContext) => BlocProvider.value(
              value: cubit,
              child: ProductionBatchForm(
                organizationId: organization.id,
                employeesRepository: employeesRepo,
                productsRepository: productsRepo,
                wageSettingsRepository: wageSettingsRepo,
              ),
            ),
          );
        }
      },
    );
  }

  return Center(
    child: EmptyState(
      icon: Icons.inventory_2_outlined,
      title: title,
      message: message,
      action: action,
    ),
  );
}

class _ProductionWagesContent extends StatelessWidget {
  const _ProductionWagesContent();

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;

    return BlocBuilder<ProductionBatchesCubit, ProductionBatchesState>(
      builder: (context, state) {
        if (state.status == ViewStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.status == ViewStatus.failure && state.message != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: ${state.message}'),
                const SizedBox(height: 16),
                DashButton(
                  label: 'Retry',
                  onPressed: () =>
                      context.read<ProductionBatchesCubit>().loadBatches(),
                ),
              ],
            ),
          );
        }

        final filteredBatches = state.filteredBatches;

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // Statistics Cards
              const _StatisticsCards(),
              const SizedBox(height: 24),
              // Workflow Tabs
              const _WorkflowTabs(),
              const SizedBox(height: 24),
              // Filters Bar
              const _FiltersBar(),
              const SizedBox(height: 24),
              // Batches List
              Expanded(
                child: filteredBatches.isEmpty
                    ? _buildEmptyState(context, state, organization)
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          // Use 2 columns if screen width >= 1024px, otherwise 1 column
                          final screenWidth = MediaQuery.of(context).size.width;
                          final isTwoColumn = screenWidth >= 1024;
                          final crossAxisCount = isTwoColumn ? 2 : 1;
                          
                          // Calculate aspect ratio (width/height) based on layout
                          // Cards typically have more content vertically, so we estimate:
                          // - Single column: ~1.0 (square-ish to tall)
                          // - Two columns: ~1.3-1.4 (wider relative to height)
                          final aspectRatio = isTwoColumn ? 1.35 : 1.0;
                          
                          return GridView.builder(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: aspectRatio,
                            ),
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: filteredBatches.length,
                            itemBuilder: (context, index) {
                              final batch = filteredBatches[index];
                              return ProductionBatchCard(
                                batch: batch,
                                onTap: () {
                                  context.read<ProductionBatchesCubit>().setSelectedBatch(batch);
                                  showDialog(
                                    context: context,
                                    builder: (dialogContext) => BlocProvider.value(
                                      value: context.read<ProductionBatchesCubit>(),
                                      child: ProductionBatchDetailModal(
                                        batch: batch,
                                        organizationId: organization?.id ?? '',
                                        employeesRepository: context.read<EmployeesRepository>(),
                                        productsRepository: context.read<ProductsRepository>(),
                                        wageSettingsRepository: context.read<WageSettingsRepository>(),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
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
}

class _StatisticsCards extends StatelessWidget {
  const _StatisticsCards();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductionBatchesCubit, ProductionBatchesState>(
      builder: (context, state) {
        return Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.inventory_2_outlined,
                label: 'Total Batches',
                value: state.totalBatches.toString(),
                color: AuthColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                icon: Icons.calculate_outlined,
                label: 'Pending Calculations',
                value: state.pendingCalculations.toString(),
                color: AuthColors.warning,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                icon: Icons.check_circle_outline,
                label: 'Pending Approvals',
                value: state.pendingApprovals.toString(),
                color: AuthColors.info,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                icon: Icons.today_outlined,
                label: 'Processed Today',
                value: state.processedToday.toString(),
                color: AuthColors.success,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Total Wages Processed',
                value: '₹${state.totalWagesProcessed.toStringAsFixed(0)}',
                color: AuthColors.accentPurple,
              ),
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
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DashCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AuthColors.textMainWithOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
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

class _WorkflowTabs extends StatelessWidget {
  const _WorkflowTabs();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductionBatchesCubit, ProductionBatchesState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AuthColors.textMainWithOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AuthColors.textMainWithOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              _TabButton(
                label: 'All',
                isSelected: state.selectedTab == WorkflowTab.all,
                count: state.batches.length,
                onTap: () => context.read<ProductionBatchesCubit>().setSelectedTab(WorkflowTab.all),
              ),
              _TabButton(
                label: 'Needs Action',
                isSelected: state.selectedTab == WorkflowTab.needsAction,
                count: state.needsActionCount,
                onTap: () => context.read<ProductionBatchesCubit>().setSelectedTab(WorkflowTab.needsAction),
              ),
              _TabButton(
                label: 'Recorded',
                isSelected: state.selectedTab == WorkflowTab.recorded,
                count: state.pendingCalculations,
                onTap: () => context.read<ProductionBatchesCubit>().setSelectedTab(WorkflowTab.recorded),
              ),
              _TabButton(
                label: 'Calculated',
                isSelected: state.selectedTab == WorkflowTab.calculated,
                count: state.pendingApprovals,
                onTap: () => context.read<ProductionBatchesCubit>().setSelectedTab(WorkflowTab.calculated),
              ),
              _TabButton(
                label: 'Approved',
                isSelected: state.selectedTab == WorkflowTab.approved,
                count: state.batches.where((b) => b.status == ProductionBatchStatus.approved).length,
                onTap: () => context.read<ProductionBatchesCubit>().setSelectedTab(WorkflowTab.approved),
              ),
              _TabButton(
                label: 'Processed',
                isSelected: state.selectedTab == WorkflowTab.processed,
                count: state.batches.where((b) => b.status == ProductionBatchStatus.processed).length,
                onTap: () => context.read<ProductionBatchesCubit>().setSelectedTab(WorkflowTab.processed),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.count,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AuthColors.primary.withValues(alpha: 0.2)
                : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AuthColors.textMain : AuthColors.textMainWithOpacity(0.7),
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AuthColors.primary
                        : AuthColors.textMainWithOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: isSelected ? AuthColors.textMain : AuthColors.textMainWithOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar();

  Future<void> _showDateRangePicker(BuildContext context, {bool isSecond = false}) async {
    final cubit = context.read<ProductionBatchesCubit>();
    final state = cubit.state;

    final initialRange = isSecond
        ? (state.startDate2 != null && state.endDate2 != null
            ? DateTimeRange(start: state.startDate2!, end: state.endDate2!)
            : null)
        : (state.startDate != null && state.endDate != null
            ? DateTimeRange(start: state.startDate!, end: state.endDate!)
            : null);

    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: initialRange,
      builder: (context, child) {
        return Theme(
          data: DashTheme.light(),
          child: child!,
        );
      },
    );

    if (pickedRange != null) {
      if (isSecond) {
        cubit.setDateRange2(pickedRange.start, pickedRange.end);
      } else {
        cubit.setDateRange(pickedRange.start, pickedRange.end);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;

    return BlocBuilder<ProductionBatchesCubit, ProductionBatchesState>(
      builder: (context, state) {
        final hasActiveFilters = state.searchQuery != null ||
            state.startDate != null ||
            state.endDate != null ||
            state.startDate2 != null ||
            state.endDate2 != null;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AuthColors.textMainWithOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AuthColors.textMainWithOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              // First Date Range
              DashButton(
                icon: Icons.date_range,
                label: state.startDate != null && state.endDate != null
                    ? '${state.startDate!.day}/${state.startDate!.month}/${state.startDate!.year} - ${state.endDate!.day}/${state.endDate!.month}/${state.endDate!.year}'
                    : 'Date Range',
                onPressed: () => _showDateRangePicker(context, isSecond: false),
                variant: DashButtonVariant.outlined,
              ),
              if (state.startDate != null && state.endDate != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    context.read<ProductionBatchesCubit>().clearDateRange();
                  },
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: 'Clear date range',
                  color: Colors.white70,
                ),
              ],
              const SizedBox(width: 16),
              // Second Date Range
              DashButton(
                icon: Icons.date_range,
                label: state.startDate2 != null && state.endDate2 != null
                    ? '${state.startDate2!.day}/${state.startDate2!.month}/${state.startDate2!.year} - ${state.endDate2!.day}/${state.endDate2!.month}/${state.endDate2!.year}'
                    : 'Date Range 2',
                onPressed: () => _showDateRangePicker(context, isSecond: true),
                variant: DashButtonVariant.outlined,
              ),
              if (state.startDate2 != null && state.endDate2 != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    context.read<ProductionBatchesCubit>().clearDateRange2();
                  },
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: 'Clear date range 2',
                  color: Colors.white70,
                ),
              ],
              const SizedBox(width: 16),
              // Search
              Expanded(
                flex: 2,
                child: TextField(
                  onChanged: (value) {
                    context.read<ProductionBatchesCubit>().setSearchQuery(
                          value.isEmpty ? null : value,
                        );
                  },
                  decoration: InputDecoration(
                    labelText: 'Search',
                    hintText: 'Batch ID, employee, product...',
                    labelStyle: const TextStyle(color: AuthColors.textSub),
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    prefixIcon: const Icon(Icons.search, color: AuthColors.textSub),
                    filled: true,
                    fillColor: AuthColors.textMainWithOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: AuthColors.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              // New Batch Button
              DashButton(
                icon: Icons.add,
                label: 'New Batch',
                onPressed: () {
                  if (organization != null) {
                    final cubit = context.read<ProductionBatchesCubit>();
                    final employeesRepo = context.read<EmployeesRepository>();
                    final productsRepo = context.read<ProductsRepository>();
                    final wageSettingsRepo = context.read<WageSettingsRepository>();
                    showDialog(
                      context: context,
                      builder: (dialogContext) => BlocProvider.value(
                        value: cubit,
                        child: ProductionBatchForm(
                          organizationId: organization.id,
                          employeesRepository: employeesRepo,
                          productsRepository: productsRepo,
                          wageSettingsRepository: wageSettingsRepo,
                        ),
                      ),
                    );
                  }
                },
              ),
              if (hasActiveFilters) ...[
                const SizedBox(width: 8),
                DashButton(
                  icon: Icons.clear_all,
                  label: 'Clear All',
                  onPressed: () {
                    context.read<ProductionBatchesCubit>().clearAllFilters();
                  },
                  variant: DashButtonVariant.text,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

