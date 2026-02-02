import 'package:core_ui/core_ui.dart' show AuthColors, DashButton, DashDialogHeader, DashSnackbar;
import 'package:dash_web/data/repositories/employees_repository.dart';
import 'package:dash_web/data/repositories/payment_accounts_repository.dart';
import 'package:dash_web/domain/entities/organization_employee.dart';
import 'package:dash_web/domain/entities/payment_account.dart';
import 'package:dash_web/presentation/blocs/employee_wages/employee_wages_cubit.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RecordBonusDialog extends StatefulWidget {
  final VoidCallback? onBonusRecorded;

  const RecordBonusDialog({
    super.key,
    this.onBonusRecorded,
  });

  @override
  State<RecordBonusDialog> createState() => _RecordBonusDialogState();
}

class _RecordBonusDialogState extends State<RecordBonusDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceNumberController = TextEditingController();
  final _descriptionController = TextEditingController();

  OrganizationEmployee? _selectedEmployee;
  PaymentAccount? _selectedPaymentAccount;
  String? _selectedBonusType;
  DateTime _paymentDate = DateTime.now();
  List<OrganizationEmployee> _employees = [];
  List<PaymentAccount> _paymentAccounts = [];
  bool _isLoading = false;

  static const List<String> _bonusTypes = [
    'Performance',
    'Festival',
    'Annual',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _loadPaymentAccounts();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceNumberController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    if (organization == null) return;

    try {
      final employeesRepo = context.read<EmployeesRepository>();
      final employees = await employeesRepo.fetchEmployees(organization.id);
      setState(() {
        _employees = employees;
      });
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(context, message: 'Failed to load employees: $e', isError: true);
      }
    }
  }

  Future<void> _loadPaymentAccounts() async {
    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    if (organization == null) return;

    try {
      final accountsRepo = context.read<PaymentAccountsRepository>();
      final accounts = await accountsRepo.fetchAccounts(organization.id);
      final activeAccounts = accounts.where((a) => a.isActive).toList();
      setState(() {
        _paymentAccounts = activeAccounts;
        if (activeAccounts.isNotEmpty) {
          _selectedPaymentAccount = activeAccounts.firstWhere(
            (a) => a.isPrimary,
            orElse: () => activeAccounts.first,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(context, message: 'Failed to load payment accounts: $e', isError: true);
      }
    }
  }

  Future<void> _selectPaymentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _paymentDate = picked;
      });
    }
  }

  Future<void> _submitBonus() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployee == null) {
      DashSnackbar.show(context, message: 'Please select an employee', isError: true);
      return;
    }

    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (organization == null) {
      DashSnackbar.show(context, message: 'Organization not found', isError: true);
      return;
    }

    if (currentUser == null) {
      DashSnackbar.show(context, message: 'User not authenticated', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text.trim());
      final cubit = context.read<EmployeeWagesCubit>();

      await cubit.createBonusTransaction(
        employeeId: _selectedEmployee!.id,
        amount: amount,
        paymentDate: _paymentDate,
        createdBy: currentUser.uid,
        bonusType: _selectedBonusType,
        paymentAccountId: _selectedPaymentAccount?.id,
        paymentAccountType: _selectedPaymentAccount?.type.name,
        referenceNumber: _referenceNumberController.text.trim().isEmpty
            ? null
            : _referenceNumberController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      if (mounted) {
        DashSnackbar.show(context, message: 'Bonus recorded successfully', isError: false);
        Navigator.of(context).pop();
        widget.onBonusRecorded?.call();
      }
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(context, message: 'Failed to record bonus: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AuthColors.textSub),
      filled: true,
      fillColor: AuthColors.surface.withValues(alpha: 0.6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AuthColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AuthColors.error, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AuthColors.error, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AuthColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DashDialogHeader(
                title: 'Record Bonus',
                icon: Icons.card_giftcard,
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 24),

              // Employee Dropdown
              DropdownButtonFormField<OrganizationEmployee>(
                initialValue: _selectedEmployee,
                decoration: _inputDecoration('Employee'),
                dropdownColor: AuthColors.surface,
                style: const TextStyle(color: AuthColors.textMain),
                items: _employees.map((employee) {
                  return DropdownMenuItem<OrganizationEmployee>(
                    value: employee,
                    child: Text(
                      employee.name,
                      style: const TextStyle(
                        color: AuthColors.textMain,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (employee) {
                  setState(() => _selectedEmployee = employee);
                },
                validator: (value) =>
                    value == null ? 'Please select an employee' : null,
              ),
              const SizedBox(height: 16),

              // Bonus Type
              DropdownButtonFormField<String>(
                initialValue: _selectedBonusType,
                decoration: _inputDecoration('Bonus Type'),
                dropdownColor: AuthColors.surface,
                style: const TextStyle(color: AuthColors.textMain),
                items: _bonusTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(
                      type,
                      style: const TextStyle(
                        color: AuthColors.textMain,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (type) {
                  setState(() => _selectedBonusType = type);
                },
                validator: (value) =>
                    value == null ? 'Please select bonus type' : null,
              ),
              const SizedBox(height: 16),

              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDecoration('Bonus Amount'),
                style: const TextStyle(color: AuthColors.textMain),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter bonus amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Payment Date
              InkWell(
                onTap: _selectPaymentDate,
                child: InputDecorator(
                  decoration: _inputDecoration('Payment Date'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDate(_paymentDate),
                        style: const TextStyle(color: AuthColors.textMain),
                      ),
                      const Icon(Icons.calendar_today, color: AuthColors.textSub),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Payment Account
              DropdownButtonFormField<PaymentAccount>(
                initialValue: _selectedPaymentAccount,
                decoration: _inputDecoration('Payment Account'),
                dropdownColor: AuthColors.surface,
                style: const TextStyle(color: AuthColors.textMain),
                items: _paymentAccounts.map((account) {
                  return DropdownMenuItem<PaymentAccount>(
                    value: account,
                    child: Text(
                      account.name,
                      style: const TextStyle(
                        color: AuthColors.textMain,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (account) {
                  setState(() => _selectedPaymentAccount = account);
                },
              ),
              const SizedBox(height: 16),

              // Reference Number
              TextFormField(
                controller: _referenceNumberController,
                decoration: _inputDecoration('Reference Number (Optional)'),
                style: const TextStyle(color: AuthColors.textMain),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: _inputDecoration('Description (Optional)'),
                style: const TextStyle(color: AuthColors.textMain),
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: DashButton(
                  label: 'Record Bonus',
                  onPressed: _submitBonus,
                  isLoading: _isLoading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

