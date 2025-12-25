import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_superadmin/domain/usecases/register_organization_with_admin.dart';
import 'package:dash_superadmin/presentation/blocs/auth/auth_bloc.dart';
import 'package:dash_superadmin/presentation/blocs/create_org/create_org_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CreateOrganizationDialog extends StatefulWidget {
  const CreateOrganizationDialog({super.key});

  @override
  State<CreateOrganizationDialog> createState() =>
      _CreateOrganizationDialogState();
}

class _CreateOrganizationDialogState extends State<CreateOrganizationDialog> {
  final _orgNameController = TextEditingController();
  final _industryController = TextEditingController();
  final _businessIdController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _adminPhoneController = TextEditingController();

  @override
  void dispose() {
    _orgNameController.dispose();
    _industryController.dispose();
    _businessIdController.dispose();
    _adminNameController.dispose();
    _adminPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final useCase = context.read<RegisterOrganizationWithAdminUseCase>();
    final authState = context.read<AuthBloc>().state;

    return BlocProvider(
      create: (_) => CreateOrgBloc(registerUseCase: useCase),
      child: BlocConsumer<CreateOrgBloc, CreateOrgState>(
        listener: (context, state) {
          if (state.status == ViewStatus.failure && state.message != null) {
            DashSnackbar.show(
              context,
              message: state.message!,
              isError: true,
            );
          }
          if (state.status == ViewStatus.success) {
            Navigator.of(context).pop(true);
            DashSnackbar.show(
              context,
              message: 'Organization created successfully',
            );
          }
        },
        builder: (context, state) {
          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            title: const Text('Add organization'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Input(
                      controller: _orgNameController,
                      label: 'Organization Name',
                      hint: 'Ex: Nova Tech Labs',
                      error: state.fieldErrors['organizationName'],
                    ),
                    const SizedBox(height: 12),
                    _Input(
                      controller: _industryController,
                      label: 'Industry',
                      hint: 'Ex: SaaS',
                      error: state.fieldErrors['industry'],
                    ),
                    const SizedBox(height: 12),
                    _Input(
                      controller: _businessIdController,
                      label: 'GST or Business ID',
                      hint: 'Optional',
                    ),
                    const SizedBox(height: 16),
                    _Input(
                      controller: _adminNameController,
                      label: 'Admin Name',
                      hint: 'Ex: Rhea Kapoor',
                      error: state.fieldErrors['adminName'],
                    ),
                    const SizedBox(height: 12),
                    _Input(
                      controller: _adminPhoneController,
                      label: 'Admin Phone (+91)',
                      hint: '10-digit number',
                      keyboardType: TextInputType.number,
                      error: state.fieldErrors['adminPhone'],
                    ),
                    if (state.fieldErrors['creator'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        state.fieldErrors['creator']!,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.redAccent),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: state.status == ViewStatus.loading
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: state.status == ViewStatus.loading
                    ? null
                    : () {
                        final userId = authState.userProfile?.id ?? '';
                        context.read<CreateOrgBloc>().add(
                              CreateOrgSubmitted(
                                organizationName: _orgNameController.text,
                                industry: _industryController.text,
                                businessId: _businessIdController.text,
                                adminName: _adminNameController.text,
                                adminPhone: _adminPhoneController.text,
                                creatorUserId: userId,
                              ),
                            );
                      },
                child: state.status == ViewStatus.loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.label,
    required this.hint,
    this.error,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? error;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashFormField(
          controller: controller,
          label: label,
          keyboardType: keyboardType,
        ),
        const SizedBox(height: 4),
        Text(
          hint,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(
            error!,
            style:
                theme.textTheme.bodySmall?.copyWith(color: Colors.redAccent),
          ),
        ],
      ],
    );
  }
}

