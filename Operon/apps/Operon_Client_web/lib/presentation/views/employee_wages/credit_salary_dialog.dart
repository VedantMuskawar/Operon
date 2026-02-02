import 'package:core_ui/core_ui.dart' show AuthColors, DashButton, DashSnackbar;
import 'package:dash_web/data/repositories/employees_repository.dart';
import 'package:dash_web/data/repositories/payment_accounts_repository.dart';
import 'package:dash_web/domain/entities/organization_employee.dart';
import 'package:dash_web/domain/entities/payment_account.dart';
import 'package:dash_web/presentation/blocs/employee_wages/employee_wages_cubit.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CreditSalaryDialog extends StatefulWidget {
  final VoidCallback? onSalaryCredited;

  const CreditSalaryDialog({
    super.key,
    this.onSalaryCredited,
  });

  @override
  State<CreditSalaryDialog> createState() => _CreditSalaryDialogState();
}

class _CreditSalaryDialogState extends State<CreditSalaryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceNumberController = TextEditingController();
  final _descriptionController = TextEditingController();

  OrganizationEmployee? _selectedEmployee;
  PaymentAccount? _selectedPaymentAccount;
  DateTime _selectedSalaryMonth = DateTime.now().subtract(Duration(days: DateTime.now().day));
  DateTime _paymentDate = DateTime.now();
  List<OrganizationEmployee> _employees = [];
  List<PaymentAccount> _paymentAccounts = [];
  bool _isLoading = false;
  bool _isCheckingSalary = false;

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

  Future<void> _selectSalaryMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedSalaryMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null) {
      setState(() {
        _selectedSalaryMonth = DateTime(picked.year, picked.month, 1);
        // Default payment date to last day of selected month
        final lastDay = DateTime(picked.year, picked.month + 1, 0);
        _paymentDate = lastDay;
      });
      _checkSalaryCredit();
    }
  }

  Future<void> _selectPaymentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: _selectedSalaryMonth,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _paymentDate = picked;
      });
    }
  }

  Future<void> _checkSalaryCredit() async {
    if (_selectedEmployee == null) return;

    setState(() => _isCheckingSalary = true);
    try {
      final orgState = context.read<OrganizationContextCubit>().state;
      final organization = orgState.organization;
      if (organization == null) return;

      final cubit = context.read<EmployeeWagesCubit>();
      final alreadyCredited = await cubit.isSalaryCreditedForMonth(
        employeeId: _selectedEmployee!.id,
        year: _selectedSalaryMonth.year,
        month: _selectedSalaryMonth.month,
      );

      if (mounted && alreadyCredited) {
        DashSnackbar.show(
          context,
          message: 'Salary already credited for this month',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('Error checking salary credit: $e');
    } finally {
      if (mounted) {
        setState(() => _isCheckingSalary = false);
      }
    }
  }

  void _onEmployeeChanged(OrganizationEmployee? employee) {
    setState(() {
      _selectedEmployee = employee;
      if (employee != null && employee.wage.baseAmount != null) {
        _amountController.text = employee.wage.baseAmount!.toStringAsFixed(2);
      }
    });
    _checkSalaryCredit();
  }

  Future<void> _submitSalary() async {
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

      await cubit.createSalaryTransaction(
        employeeId: _selectedEmployee!.id,
        amount: amount,
        paymentDate: _paymentDate,
        createdBy: currentUser.uid,
        paymentAccountId: _selectedPaymentAccount?.id,
        paymentAccountType: _selectedPaymentAccount?.type.name,
        referenceNumber: _referenceNumberController.text.trim().isEmpty
            ? null
            : _referenceNumberController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? 'Salary for ${_formatMonth(_selectedSalaryMonth)}'
            : _descriptionController.text.trim(),
        metadata: {
          'salaryMonth': '${_selectedSalaryMonth.year}-${_selectedSalaryMonth.month.toString().padLeft(2, '0')}',
        },
      );

      if (mounted) {
        DashSnackbar.show(context, message: 'Salary credited successfully', isError: false);
        Navigator.of(context).pop();
        widget.onSalaryCredited?.call();
      }
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(context, message: 'Failed to credit salary: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatMonth(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.year}';
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
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AuthColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.payments,
                      color: AuthColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Credit Salary',
                      style: TextStyle(
                        color: AuthColors.textMain,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AuthColors.textSub),
                  ),
                ],
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
                onChanged: _onEmployeeChanged,
                validator: (value) =>
                    value == null ? 'Please select an employee' : null,
              ),
              const SizedBox(height: 16),

              // Salary Month
              InkWell(
                onTap: _selectSalaryMonth,
                child: InputDecorator(
                  decoration: _inputDecoration('Salary Month'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatMonth(_selectedSalaryMonth),
                        style: const TextStyle(color: AuthColors.textMain),
                      ),
                      if (_isCheckingSalary)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(Icons.calendar_today, color: AuthColors.textSub),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDecoration('Salary Amount'),
                style: const TextStyle(color: AuthColors.textMain),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter salary amount';
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
                  label: 'Credit Salary',
                  onPressed: _submitSalary,
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

