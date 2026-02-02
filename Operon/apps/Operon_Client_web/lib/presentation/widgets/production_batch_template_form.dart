import 'package:core_models/core_models.dart';
import 'package:dash_web/data/repositories/employees_repository.dart';
import 'package:dash_web/domain/entities/organization_employee.dart';
import 'package:dash_web/presentation/blocs/production_batch_templates/production_batch_templates_cubit.dart';
import 'package:core_ui/core_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProductionBatchTemplateForm extends StatefulWidget {
  const ProductionBatchTemplateForm({
    super.key,
    required this.organizationId,
    required this.employeesRepository,
    this.template,
  });

  final String organizationId;
  final EmployeesRepository employeesRepository;
  final ProductionBatchTemplate? template;

  @override
  State<ProductionBatchTemplateForm> createState() =>
      _ProductionBatchTemplateFormState();
}

class _ProductionBatchTemplateFormState
    extends State<ProductionBatchTemplateForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  List<OrganizationEmployee> _employees = [];
  Set<String> _selectedEmployeeIds = {};
  bool _isLoading = false;
  bool _isLoadingEmployees = true;

  @override
  void initState() {
    super.initState();
    if (widget.template != null) {
      _nameController.text = widget.template!.name;
      _selectedEmployeeIds = Set.from(widget.template!.employeeIds);
    }
    _loadEmployees();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoadingEmployees = true);
    try {
      final allEmployees =
          await widget.employeesRepository.fetchEmployees(widget.organizationId);
      // Filter employees to only show those with "Production" role
      final filteredEmployees = allEmployees.where((employee) {
        // Check if any of the employee's job roles contains "Production"
        return employee.jobRoles.values.any(
          (jobRole) => jobRole.jobRoleTitle
              .toLowerCase()
              .contains('production'),
        ) || employee.primaryJobRoleTitle
            .toLowerCase()
            .contains('production');
      }).toList();
      setState(() {
        _employees = filteredEmployees;
        _isLoadingEmployees = false;
      });
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(context, message: 'Failed to load employees: $e', isError: true);
        setState(() => _isLoadingEmployees = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedEmployeeIds.isEmpty) {
      DashSnackbar.show(context, message: 'Please select at least one employee', isError: true);
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      DashSnackbar.show(context, message: 'User not authenticated', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final selectedEmployees = _employees
          .where((e) => _selectedEmployeeIds.contains(e.id))
          .toList();
      final employeeNames = selectedEmployees.map((e) => e.name).toList();

      final now = DateTime.now();
      final template = ProductionBatchTemplate(
        batchId: widget.template?.batchId ?? '',
        organizationId: widget.organizationId,
        name: _nameController.text.trim(),
        employeeIds: _selectedEmployeeIds.toList(),
        employeeNames: employeeNames,
        createdAt: widget.template?.createdAt ?? now,
        updatedAt: now,
      );

      final cubit = context.read<ProductionBatchTemplatesCubit>();

      if (widget.template != null) {
        // Update existing template
        await cubit.updateTemplate(
          widget.template!.batchId,
          {
            'name': template.name,
            'employeeIds': template.employeeIds,
            'employeeNames': template.employeeNames,
          },
        );
      } else {
        // Create new template
        await cubit.createTemplate(template);
      }

      if (mounted) {
        Navigator.of(context).pop();
        DashSnackbar.show(
          context,
          message: widget.template != null
              ? 'Batch template updated successfully'
              : 'Batch template created successfully',
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(context, message: 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AuthColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: AuthColors.textMain.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    widget.template != null
                        ? 'Edit Batch Template'
                        : 'Create Batch Template',
                    style: const TextStyle(
                      color: AuthColors.textMain,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AuthColors.textSub),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Batch Name',
                  labelStyle: const TextStyle(color: AuthColors.textSub),
                  filled: true,
                  fillColor: AuthColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AuthColors.textMain.withOpacity(0.1),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AuthColors.textMain.withOpacity(0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AuthColors.primary,
                      width: 2,
                    ),
                  ),
                ),
                style: const TextStyle(color: AuthColors.textMain),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a batch name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Select Employees',
                style: TextStyle(
                  color: AuthColors.textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              if (_isLoadingEmployees)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(color: AuthColors.primary),
                  ),
                )
              else if (_employees.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AuthColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AuthColors.textMain.withOpacity(0.1),
                    ),
                  ),
                  child: const Text(
                    'No employees available',
                    style: TextStyle(color: AuthColors.textSub),
                  ),
                )
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: AuthColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AuthColors.textMain.withOpacity(0.1),
                    ),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _employees.length,
                    itemBuilder: (context, index) {
                      final employee = _employees[index];
                      final isSelected =
                          _selectedEmployeeIds.contains(employee.id);
                      return CheckboxListTile(
                        title: Text(
                          employee.name,
                          style: const TextStyle(color: AuthColors.textMain),
                        ),
                        subtitle: employee.primaryJobRoleTitle.isNotEmpty
                            ? Text(
                                employee.primaryJobRoleTitle,
                                style: const TextStyle(
                                  color: AuthColors.textSub,
                                ),
                              )
                            : null,
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedEmployeeIds.add(employee.id);
                            } else {
                              _selectedEmployeeIds.remove(employee.id);
                            }
                          });
                        },
                        activeColor: AuthColors.primary,
                        checkColor: AuthColors.textMain,
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                '${_selectedEmployeeIds.length} employee${_selectedEmployeeIds.length != 1 ? 's' : ''} selected',
                style: const TextStyle(
                  color: AuthColors.textSub,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  DashButton(
                    label: 'Cancel',
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    variant: DashButtonVariant.text,
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AuthColors.primary,
                      foregroundColor: AuthColors.textMain,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AuthColors.textMain),
                            ),
                          )
                        : Text(widget.template != null ? 'Update' : 'Create'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

