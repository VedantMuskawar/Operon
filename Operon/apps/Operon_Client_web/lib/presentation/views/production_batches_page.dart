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
import 'package:dash_web/presentation/blocs/weekly_ledger/weekly_ledger_cubit.dart';
import 'package:dash_web/presentation/widgets/production_batch_form.dart';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:dash_web/presentation/widgets/weekly_ledger_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ProductionBatchesPage extends StatelessWidget {
  const ProductionBatchesPage({super.key});

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

    return MultiBlocProvider(
      providers: [
        BlocProvider(
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
        ),
        BlocProvider(
          create: (context) => WeeklyLedgerCubit(
            productionBatchesRepository: context.read<ProductionBatchesRepository>(),
            tripWagesRepository: context.read<TripWagesRepository>(),
            employeesRepository: context.read<EmployeesRepository>(),
            deliveryMemoRepository: context.read<DeliveryMemoRepository>(),
            employeeWagesRepository: context.read<EmployeeWagesRepository>(),
            organizationId: organization.id,
          ),
        ),
      ],
      child: SectionWorkspaceLayout(
        panelTitle: 'Production Wages',
        currentIndex: -1,
        onNavTap: (index) => context.go('/home?section=$index'),
        child: const _ProductionBatchesContent(),
      ),
    );
  }
}

class _ProductionBatchesContent extends StatefulWidget {
  const _ProductionBatchesContent();

  @override
  State<_ProductionBatchesContent> createState() =>
      _ProductionBatchesContentState();
}

class _ProductionBatchesContentState extends State<_ProductionBatchesContent> {
  int _sectionIndex = 0;

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;

    return BlocListener<ProductionBatchesCubit, ProductionBatchesState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          DashSnackbar.show(context, message: state.message!, isError: true);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: FloatingNavBar(
                  items: const [
                    NavBarItem(
                      icon: Icons.inventory_2_outlined,
                      label: 'Batches',
                      heroTag: 'prod_batches',
                    ),
                    NavBarItem(
                      icon: Icons.calendar_view_week_outlined,
                      label: 'Weekly Ledger',
                      heroTag: 'prod_weekly_ledger',
                    ),
                  ],
                  currentIndex: _sectionIndex,
                  onItemTapped: (index) => setState(() => _sectionIndex = index),
                ),
              ),
            ),
          ),
          _sectionIndex == 0
              ? _BatchesSection(organization: organization)
              : const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: _WeeklyLedgerBlock(),
                ),
        ],
      ),
    );
  }
}

class _BatchesSection extends StatelessWidget {
  const _BatchesSection({this.organization});

  final dynamic organization;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductionBatchesCubit, ProductionBatchesState>(
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
                  ...List.generate(8, (_) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SkeletonLoader(
                      height: 56,
                      width: double.infinity,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  )),
                ],
              ),
            ),
          );
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

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _FiltersBar(
                trailing: DashButton(
                  icon: Icons.add,
                  label: 'New Batch',
                  onPressed: () {
                    if (organization != null) {
                      final cubit = context.read<ProductionBatchesCubit>();
                      final employeesRepo = context.read<EmployeesRepository>();
                      final productsRepo = context.read<ProductsRepository>();
                      final wageSettingsRepo =
                          context.read<WageSettingsRepository>();
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
              ),
              const SizedBox(height: 24),
              if (filteredBatches.isEmpty)
                EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: state.batches.isEmpty
                      ? 'No production batches yet'
                      : 'No batches match your filters',
                  message: state.batches.isEmpty
                      ? 'Create your first production batch to get started'
                      : 'Try adjusting your filters',
                )
              else
                ...filteredBatches.map((batch) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ProductionBatchCard(
                      batch: batch,
                      onTap: () {
                        context
                            .read<ProductionBatchesCubit>()
                            .setSelectedBatch(batch);
                        showDialog(
                          context: context,
                          builder: (dialogContext) => BlocProvider.value(
                            value: context.read<ProductionBatchesCubit>(),
                            child: ProductionBatchDetailModal(
                              batch: batch,
                              organizationId: organization?.id ?? '',
                              employeesRepository:
                                  context.read<EmployeesRepository>(),
                              productsRepository:
                                  context.read<ProductsRepository>(),
                              wageSettingsRepository:
                                  context.read<WageSettingsRepository>(),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({this.trailing});

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductionBatchesCubit, ProductionBatchesState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              // Status Filter
              Expanded(
                child: DropdownButtonFormField<ProductionBatchStatus?>(
                  initialValue: state.selectedStatus,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
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
                        color: Color(0xFF6F4BFF),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  dropdownColor: const Color(0xFF1B1B2C),
                  style: const TextStyle(color: Colors.white),
                  items: [
                    const DropdownMenuItem<ProductionBatchStatus?>(
                      value: null,
                      child: Text('All Statuses'),
                    ),
                    ...ProductionBatchStatus.values.map((status) {
                      return DropdownMenuItem<ProductionBatchStatus?>(
                        value: status,
                        child: Text(_getStatusLabel(status)),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    context.read<ProductionBatchesCubit>().setStatusFilter(value);
                  },
                ),
              ),
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
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
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
                        color: Color(0xFF6F4BFF),
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
              // Date Range (simplified - can be enhanced with date range picker)
              DashButton(
                icon: Icons.date_range,
                label: 'Date Range',
                onPressed: () {
                  // Feature planned: Date range picker for filtering batches
                  DashSnackbar.show(context, message: 'Date range picker coming soon');
                },
                variant: DashButtonVariant.text,
              ),
              if (trailing != null) ...[
                const SizedBox(width: 16),
                trailing!,
              ],
            ],
          ),
        );
      },
    );
  }

  static String _getStatusLabel(ProductionBatchStatus status) {
    switch (status) {
      case ProductionBatchStatus.recorded:
        return 'Recorded';
      case ProductionBatchStatus.calculated:
        return 'Calculated';
      case ProductionBatchStatus.approved:
        return 'Approved';
      case ProductionBatchStatus.processed:
        return 'Processed';
    }
  }
}

class _WeeklyLedgerBlock extends StatelessWidget {
  const _WeeklyLedgerBlock();

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    if (organization == null) return const SizedBox.shrink();
    final cubit = context.read<WeeklyLedgerCubit>();
    return WeeklyLedgerSection(
      organizationId: organization.id,
      weeklyLedgerCubit: cubit,
    );
  }
}
