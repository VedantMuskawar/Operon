import 'package:core_ui/core_ui.dart' show AuthColors;
import 'package:dash_mobile/data/repositories/employees_repository.dart';
import 'package:dash_mobile/data/repositories/payment_accounts_repository.dart';
import 'package:dash_mobile/domain/entities/organization_employee.dart';
import 'package:dash_mobile/domain/entities/payment_account.dart';
import 'package:dash_mobile/presentation/blocs/employee_wages/employee_wages_cubit.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RecordBonusDialog extends StatefulWidget {
  const RecordBonusDialog({super.key});

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load employees: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load payment accounts: $e')),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an employee')),
      );
      return;
    }

    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (organization == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Organization not found')),
      );
      return;
    }

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text.trim());
      final cubit = context.read<EmployeeWagesCubit>();

      await cubit.createBonusTransaction(
        employeeId: _selectedEmployee!.id,
        employeeName: _selectedEmployee!.name,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bonus recorded successfully'),
            backgroundColor: AuthColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record bonus: $e'),
            backgroundColor: AuthColors.error,
          ),
        );
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
      fillColor: AuthColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        borderSide: BorderSide(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        borderSide: BorderSide(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        borderSide: const BorderSide(color: AuthColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        borderSide: const BorderSide(color: AuthColors.error, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        borderSide: const BorderSide(color: AuthColors.error, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AuthColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.paddingXXL),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.paddingSM),
                      decoration: BoxDecoration(
                        color: AuthColors.secondary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                      ),
                      child: const Icon(
                        Icons.card_giftcard,
                        color: AuthColors.secondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.paddingMD),
                    const Expanded(
                      child: Text(
                        'Record Bonus',
                        style: TextStyle(color: AuthColors.textMain, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: AuthColors.textSub),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.paddingXXL),

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
                        style: const TextStyle(color: AuthColors.textMain, fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                  onChanged: (employee) {
                    setState(() => _selectedEmployee = employee);
                  },
                  validator: (value) =>
                      value == null ? 'Please select an employee' : null,
                ),
                const SizedBox(height: AppSpacing.paddingLG),

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
                        style: const TextStyle(color: AuthColors.textMain, fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                  onChanged: (type) {
                    setState(() => _selectedBonusType = type);
                  },
                  validator: (value) =>
                      value == null ? 'Please select bonus type' : null,
                ),
                const SizedBox(height: AppSpacing.paddingLG),

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
                const SizedBox(height: AppSpacing.paddingLG),

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
                const SizedBox(height: AppSpacing.paddingLG),

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
                        style: const TextStyle(color: AuthColors.textMain, fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                  onChanged: (account) {
                    setState(() => _selectedPaymentAccount = account);
                  },
                ),
                const SizedBox(height: AppSpacing.paddingLG),

                TextFormField(
                  controller: _referenceNumberController,
                  decoration: _inputDecoration('Reference Number (Optional)'),
                  style: const TextStyle(color: AuthColors.textMain),
                ),
                const SizedBox(height: AppSpacing.paddingLG),

                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: _inputDecoration('Description (Optional)'),
                  style: const TextStyle(color: AuthColors.textMain),
                ),
                const SizedBox(height: AppSpacing.paddingXXL),

                FilledButton(
                  onPressed: _isLoading ? null : _submitBonus,
                  style: FilledButton.styleFrom(
                    backgroundColor: AuthColors.secondary,
                    foregroundColor: AuthColors.textMain,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingLG),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMD)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AuthColors.textMain),
                          ),
                        )
                      : const Text(
                          'Record Bonus',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

