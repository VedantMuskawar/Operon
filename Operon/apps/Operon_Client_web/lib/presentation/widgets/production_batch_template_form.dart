import 'package:core_models/core_models.dart';
import 'package:dash_web/data/repositories/employees_repository.dart';
import 'package:dash_web/domain/entities/organization_employee.dart';
import 'package:dash_web/presentation/blocs/production_batch_templates/production_batch_templates_cubit.dart';
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
      final employees =
          await widget.employeesRepository.fetchEmployees(widget.organizationId);
      setState(() {
        _employees = employees;
        _isLoadingEmployees = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load employees: $e')),
        );
        setState(() => _isLoadingEmployees = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedEmployeeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one employee')),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.template != null
                ? 'Batch template updated successfully'
                : 'Batch template created successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
      backgroundColor: const Color(0xFF1B1B2C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
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
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Batch Name',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF6F4BFF),
                      width: 2,
                    ),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
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
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              if (_isLoadingEmployees)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_employees.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'No employees available',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
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
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: employee.primaryJobRoleTitle.isNotEmpty
                            ? Text(
                                employee.primaryJobRoleTitle,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
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
                        activeColor: const Color(0xFF6F4BFF),
                        checkColor: Colors.white,
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                '${_selectedEmployeeIds.length} employee${_selectedEmployeeIds.length != 1 ? 's' : ''} selected',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6F4BFF),
                      foregroundColor: Colors.white,
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
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
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

