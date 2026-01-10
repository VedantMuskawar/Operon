import 'package:core_bloc/core_bloc.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/repositories/employees_repository.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/blocs/production_batch_templates/production_batch_templates_cubit.dart';
import 'package:dash_web/presentation/blocs/production_batch_templates/production_batch_templates_state.dart';
import 'package:dash_web/presentation/widgets/production_batch_template_form.dart';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ProductionBatchTemplatesPage extends StatelessWidget {
  const ProductionBatchTemplatesPage({super.key});

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
      create: (context) => ProductionBatchTemplatesCubit(
        repository: context.read<ProductionBatchTemplatesRepository>(),
        organizationId: organization.id,
      )..loadTemplates(),
      child: SectionWorkspaceLayout(
        panelTitle: 'Production Batches',
        currentIndex: -1,
        onNavTap: (index) => context.go('/home?section=$index'),
        child: const _ProductionBatchTemplatesContent(),
      ),
    );
  }
}

// Content widget for sidebar use
class ProductionBatchTemplatesPageContent extends StatelessWidget {
  const ProductionBatchTemplatesPageContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProductionBatchTemplatesCubit,
        ProductionBatchTemplatesState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          DashSnackbar.show(context, message: state.message!, isError: true);
        }
      },
      child: const _ProductionBatchTemplatesContent(),
    );
  }
}

class _ProductionBatchTemplatesContent extends StatelessWidget {
  const _ProductionBatchTemplatesContent();

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;

    return BlocBuilder<ProductionBatchTemplatesCubit,
        ProductionBatchTemplatesState>(
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
                      context.read<ProductionBatchTemplatesCubit>().loadTemplates(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

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
                    'Production Batches',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (organization != null) {
                        final cubit = context.read<ProductionBatchTemplatesCubit>();
                        final employeesRepo = context.read<EmployeesRepository>();
                        showDialog(
                          context: context,
                          builder: (dialogContext) => BlocProvider.value(
                            value: cubit,
                            child: ProductionBatchTemplateForm(
                              organizationId: organization.id,
                              employeesRepository: employeesRepo,
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
                'Define reusable employee groups for production batches.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                    ),
              ),
              const SizedBox(height: 32),
              if (state.templates.isEmpty)
                SizedBox(
                  height: 400,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.group_outlined,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No batch templates yet',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your first batch template to get started',
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
                ...state.templates.map((template) {
                  return _BatchTemplateCard(
                    template: template,
                    onEdit: () {
                      if (organization != null) {
                        final cubit = context.read<ProductionBatchTemplatesCubit>();
                        final employeesRepo = context.read<EmployeesRepository>();
                        showDialog(
                          context: context,
                          builder: (dialogContext) => BlocProvider.value(
                            value: cubit,
                            child: ProductionBatchTemplateForm(
                              organizationId: organization.id,
                              employeesRepository: employeesRepo,
                              template: template,
                            ),
                          ),
                        );
                      }
                    },
                    onDelete: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Batch Template'),
                          content: Text(
                              'Are you sure you want to delete "${template.name}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        await context
                            .read<ProductionBatchTemplatesCubit>()
                            .deleteTemplate(template.batchId);
                      }
                    },
                  );
                }).toList(),
            ],
          ),
        );
      },
    );
  }
}

class _BatchTemplateCard extends StatelessWidget {
  const _BatchTemplateCard({
    required this.template,
    required this.onEdit,
    required this.onDelete,
  });

  final ProductionBatchTemplate template;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final employeeCount = template.employeeIds.length;
    final employeeNames = template.employeeNames ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$employeeCount employee${employeeCount != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                if (employeeNames.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: employeeNames.take(5).map((name) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          name,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (employeeNames.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+${employeeNames.length - 5} more',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                color: Colors.white.withValues(alpha: 0.7),
                tooltip: 'Edit',
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outlined),
                color: Colors.red.withValues(alpha: 0.7),
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

