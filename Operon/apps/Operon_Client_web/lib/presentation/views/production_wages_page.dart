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
              ElevatedButton(
                onPressed: () => context.go('/org-selection'),
                child: const Text('Select Organization'),
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
                ElevatedButton(
                  onPressed: () =>
                      context.read<ProductionBatchesCubit>().loadBatches(),
                  child: const Text('Retry'),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Production Wages',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  ElevatedButton.icon(
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
                    icon: const Icon(Icons.add),
                    label: const Text('New Batch'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Record and manage production batches for wage calculation.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                    ),
              ),
              const SizedBox(height: 24),
              _FiltersBar(),
              const SizedBox(height: 24),
              if (filteredBatches.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          state.batches.isEmpty
                              ? 'No production batches yet'
                              : 'No batches match your filters',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.batches.isEmpty
                              ? 'Create your first production batch to get started'
                              : 'Try adjusting your filters',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...filteredBatches.map((batch) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ProductionBatchCard(
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
                    ),
                  );
                }).toList(),
            ],
          ),
        );
      },
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar();

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
                  value: state.selectedStatus,
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
              TextButton.icon(
                onPressed: () {
                  // TODO: Implement date range picker
                },
                icon: const Icon(Icons.date_range, size: 18),
                label: const Text('Date Range'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                ),
              ),
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

