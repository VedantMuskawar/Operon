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
              DashButton(
                label: 'Retry',
                onPressed: () =>
                    context.read<ProductionBatchTemplatesCubit>().loadTemplates(),
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
                          color: AuthColors.textMain,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  DashButton(
                    label: 'New Batch',
                    icon: Icons.add,
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
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Define reusable employee groups for production batches.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AuthColors.textSub,
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
                          color: AuthColors.textSub.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No batch templates yet',
                          style: TextStyle(
                            color: AuthColors.textSub,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create your first batch template to get started',
                          style: TextStyle(
                            color: AuthColors.textSub,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...state.templates.map((template) {
                  return _BatchTemplateDataListItem(
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
                          backgroundColor: AuthColors.surface,
                          title: const Text(
                            'Delete Batch Template',
                            style: TextStyle(color: AuthColors.textMain),
                          ),
                          content: Text(
                            'Are you sure you want to delete "${template.name}"?',
                            style: const TextStyle(color: AuthColors.textSub),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel', style: TextStyle(color: AuthColors.textSub)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                foregroundColor: AuthColors.error,
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
                }),
            ],
          ),
        );
      },
    );
  }
}

class _BatchTemplateDataListItem extends StatelessWidget {
  const _BatchTemplateDataListItem({
    required this.template,
    required this.onEdit,
    required this.onDelete,
  });

  final ProductionBatchTemplate template;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _formatSubtitle() {
    final employeeCount = template.employeeIds.length;
    final parts = <String>[];
    parts.add('$employeeCount employee${employeeCount != 1 ? 's' : ''}');
    if (template.employeeNames != null && template.employeeNames!.isNotEmpty) {
      final names = template.employeeNames!.take(3).join(', ');
      parts.add(names);
      if (template.employeeNames!.length > 3) {
        parts.add('+${template.employeeNames!.length - 3} more');
      }
    }
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuthColors.background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: DataList(
        title: template.name,
        subtitle: _formatSubtitle(),
        leading: DataListAvatar(
          initial: template.name.isNotEmpty ? template.name[0] : 'B',
          radius: 28,
          statusRingColor: AuthColors.primary,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DataListStatusDot(
              color: AuthColors.primary,
              size: 8,
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                color: AuthColors.textSub,
                size: 20,
              ),
              onPressed: onEdit,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: AuthColors.error,
                size: 20,
              ),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}

