import 'package:core_models/core_models.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_ui/core_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:dash_mobile/data/datasources/payment_accounts_data_source.dart';
import 'package:dash_mobile/data/repositories/employees_repository.dart';
import 'package:dash_mobile/data/utils/financial_year_utils.dart';
import 'package:dash_mobile/domain/entities/payment_account.dart';
import 'package:dash_mobile/presentation/blocs/expenses/expenses_cubit.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum ExpenseFormType {
  vendorPayment,
  salaryDebit,
  generalExpense,
}

class ExpenseFormDialog extends StatefulWidget {
  const ExpenseFormDialog({
    super.key,
    this.type,
    this.vendorId,
    this.employeeId,
  });

  final ExpenseFormType? type;
  final String? vendorId;
  final String? employeeId;

  @override
  State<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<ExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _referenceNumberController = TextEditingController();

  ExpenseFormType _selectedType = ExpenseFormType.vendorPayment;
  Vendor? _selectedVendor;
  List<OrganizationEmployee> _selectedEmployees = [];
  ExpenseSubCategory? _selectedSubCategory;
  PaymentAccount? _selectedPaymentAccount;
  DateTime _selectedDate = DateTime.now();

  // Data lists
  List<Vendor> _vendors = [];
  List<OrganizationEmployee> _employees = [];
  List<ExpenseSubCategory> _subCategories = [];
  List<PaymentAccount> _paymentAccounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.type != null) {
      _selectedType = widget.type!;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final orgState = context.read<OrganizationContextCubit>().state;
      final organizationId = orgState.organization?.id;
      if (organizationId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No organization selected')),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      // Try to get data from ExpensesCubit if available
      try {
        final cubit = context.read<ExpensesCubit>();
        final state = cubit.state;
        _vendors = state.vendors;
        _employees = state.employees;
        _subCategories = state.subCategories;
        _paymentAccounts = state.paymentAccounts;
      } catch (_) {
        // Cubit not available, fetch from repositories
        // Handled below with fallback fetches.
      }

      // If cubit data is empty/stale, fallback to repositories per list
      if (_vendors.isEmpty) {
        final vendorsRepo = context.read<VendorsRepository>();
        _vendors = await vendorsRepo.fetchVendors(organizationId);
      }
      if (_employees.isEmpty) {
        final employeesRepo = context.read<EmployeesRepository>();
        _employees = await employeesRepo.fetchEmployees(organizationId);
      }
      final ledgerEmployees =
          await _fetchEmployeeAccountsFromLedgers(organizationId);
      if (ledgerEmployees.isNotEmpty) {
        final byId = <String, OrganizationEmployee>{
          for (final employee in _employees) employee.id: employee,
        };
        for (final employee in ledgerEmployees) {
          if (employee.id.isEmpty) continue;
          byId.putIfAbsent(employee.id, () => employee);
        }
        final merged = byId.values.toList();
        merged.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _employees = merged;
      }
      if (_subCategories.isEmpty) {
        final subCategoriesRepo =
            context.read<ExpenseSubCategoriesRepository>();
        _subCategories =
            await subCategoriesRepo.fetchSubCategories(organizationId);
      }
      if (_paymentAccounts.isEmpty) {
        final paymentAccountsDataSource =
            context.read<PaymentAccountsDataSource>();
        _paymentAccounts =
            await paymentAccountsDataSource.fetchAccounts(organizationId);
      }

      // Show only active payment accounts
      _paymentAccounts =
          _paymentAccounts.where((account) => account.isActive).toList();

      if (_selectedPaymentAccount == null && _paymentAccounts.isNotEmpty) {
        final primary = _paymentAccounts.where((a) => a.isPrimary).toList();
        _selectedPaymentAccount =
            primary.isNotEmpty ? primary.first : _paymentAccounts.first;
      }

      // Initialize selections from widget parameters
      if (widget.vendorId != null) {
        _selectedVendor = _vendors.firstWhere(
          (v) => v.id == widget.vendorId,
          orElse: () => _vendors.isNotEmpty
              ? _vendors.first
              : throw StateError('No vendors'),
        );
      }
      if (widget.employeeId != null) {
        final employee = _employees.firstWhere(
          (e) => e.id == widget.employeeId,
          orElse: () => _employees.isNotEmpty
              ? _employees.first
              : throw StateError('No employees'),
        );
        _selectedEmployees = [employee];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<List<OrganizationEmployee>> _fetchEmployeeAccountsFromLedgers(
    String organizationId,
  ) async {
    try {
      final snapshot = await firestore.FirebaseFirestore.instance
          .collection('COMBINED_ACCOUNTS')
          .where('organizationId', isEqualTo: organizationId)
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return [];
      final data = snapshot.docs.first.data();
      final accountsData = (data['accounts'] as List<dynamic>?) ?? [];
      final employees = <OrganizationEmployee>[];
      for (final account in accountsData) {
        if (account is! Map<String, dynamic>) continue;
        final typeRaw = (account['type'] as String? ?? '').toLowerCase();
        if (typeRaw != 'employee' && typeRaw != 'employees') continue;

        final id = (account['id'] as String?) ??
            (account['accountId'] as String?) ??
            (account['employeeId'] as String?) ??
            '';
        final name = (account['name'] as String?) ??
            (account['employeeName'] as String?) ??
            (account['accountName'] as String?) ??
            '';
        if (id.isEmpty && name.isEmpty) continue;

        employees.add(
          OrganizationEmployee(
            id: id.isNotEmpty ? id : name,
            organizationId: organizationId,
            name: name.isNotEmpty ? name : id,
            jobRoleIds: const [],
            jobRoles: const {},
            wage: const EmployeeWage(type: WageType.perMonth),
            openingBalance: 0,
            currentBalance: 0,
          ),
        );
      }

      return employees;
    } catch (_) {
      return [];
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _referenceNumberController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    return '$day $month $year';
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AuthColors.legacyAccent,
              onPrimary: AuthColors.textMain,
              surface: AuthColors.surface,
              onSurface: AuthColors.textMain,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }

    if (_selectedPaymentAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a payment account')),
      );
      return;
    }

    final orgState = context.read<OrganizationContextCubit>().state;
    final organizationId = orgState.organization?.id;
    if (organizationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No organization selected')),
      );
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final financialYear = FinancialYearUtils.getFinancialYear(_selectedDate);
    final transactionsDataSource = context.read<TransactionsDataSource>();

    try {
      Transaction? transaction;

      switch (_selectedType) {
        case ExpenseFormType.vendorPayment:
          if (_selectedVendor == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Select a vendor')),
            );
            return;
          }
          transaction = Transaction(
            id: '',
            organizationId: organizationId,
            vendorId: _selectedVendor!.id,
            vendorName: _selectedVendor!.name,
            ledgerType: LedgerType.vendorLedger,
            type: TransactionType.debit,
            category: TransactionCategory.vendorPayment,
            amount: amount,
            createdBy: userId,
            createdAt: _selectedDate,
            updatedAt: DateTime.now(),
            financialYear: financialYear,
            paymentAccountId: _selectedPaymentAccount!.id,
            paymentAccountType: _selectedPaymentAccount!.type.name,
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            referenceNumber: _referenceNumberController.text.trim().isEmpty
                ? null
                : _referenceNumberController.text.trim(),
          );
          break;
        case ExpenseFormType.salaryDebit:
          if (_selectedEmployees.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Select at least one employee')),
            );
            return;
          }
          final splitGroupId = 'split_${DateTime.now().microsecondsSinceEpoch}';
          final splitAmounts =
              _computeSplitAmounts(amount, _selectedEmployees.length);
          for (var i = 0; i < _selectedEmployees.length; i++) {
            final employee = _selectedEmployees[i];
            final metadata = <String, dynamic>{
              'employeeName': employee.name,
              'splitIndex': i + 1,
              'splitCount': _selectedEmployees.length,
            };
            transaction = Transaction(
              id: '',
              organizationId: organizationId,
              employeeId: employee.id,
              employeeName: employee.name,
              splitGroupId: splitGroupId,
              ledgerType: LedgerType.employeeLedger,
              type: TransactionType.debit,
              category: TransactionCategory.salaryDebit,
              amount: splitAmounts[i],
              createdBy: userId,
              createdAt: _selectedDate,
              updatedAt: DateTime.now(),
              financialYear: financialYear,
              paymentAccountId: _selectedPaymentAccount!.id,
              paymentAccountType: _selectedPaymentAccount!.type.name,
              description: _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
              referenceNumber: _referenceNumberController.text.trim().isEmpty
                  ? null
                  : _referenceNumberController.text.trim(),
              metadata: metadata,
            );
            await transactionsDataSource.createTransaction(transaction);
          }
          break;
        case ExpenseFormType.generalExpense:
          if (_selectedSubCategory == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Select a sub-category')),
            );
            return;
          }
          if (_descriptionController.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Enter a description')),
            );
            return;
          }
          transaction = Transaction(
            id: '',
            organizationId: organizationId,
            clientId: organizationId, // Use orgId as placeholder
            ledgerType: LedgerType.organizationLedger,
            type: TransactionType.debit,
            category: TransactionCategory.generalExpense,
            amount: amount,
            createdBy: userId,
            createdAt: _selectedDate,
            updatedAt: DateTime.now(),
            financialYear: financialYear,
            paymentAccountId: _selectedPaymentAccount!.id,
            paymentAccountType: _selectedPaymentAccount!.type.name,
            description: _descriptionController.text.trim(),
            referenceNumber: _referenceNumberController.text.trim().isEmpty
                ? null
                : _referenceNumberController.text.trim(),
            metadata: {
              'expenseCategory': 'general',
              'subCategoryId': _selectedSubCategory!.id,
              'subCategoryName': _selectedSubCategory!.name,
            },
          );
          break;
      }

      if (_selectedType != ExpenseFormType.salaryDebit && transaction != null) {
        await transactionsDataSource.createTransaction(transaction);
      }

      // Try to refresh ExpensesCubit if available
      try {
        context.read<ExpensesCubit>().load();
      } catch (_) {
        // Cubit not available, that's okay
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating expense: $e')),
        );
      }
    }
  }

  List<double> _computeSplitAmounts(double amount, int count) {
    final totalCents = (amount * 100).round();
    final baseCents = totalCents ~/ count;
    final remainder = totalCents % count;
    return List<double>.generate(
      count,
      (index) => (baseCents + (index < remainder ? 1 : 0)) / 100,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Dialog(
        backgroundColor: AuthColors.surface,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.paddingXXXL * 1.25),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppSpacing.paddingLG),
              Text(
                'Loading...',
                style: TextStyle(color: AuthColors.textMain),
              ),
            ],
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: AuthColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppSpacing.paddingXL),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                      color: AuthColors.textMainWithOpacity(0.12), width: 1),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'Add Expense',
                    style: TextStyle(
                      color: AuthColors.textMain,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: AuthColors.textDisabled),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.paddingXL),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Expense Type Selector
                      const Text(
                        'Expense Type',
                        style: TextStyle(
                          color: AuthColors.textSub,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.paddingSM),
                      _buildTypeSelector(),
                      const SizedBox(height: AppSpacing.paddingXL),
                      // Dynamic fields based on type
                      if (_selectedType == ExpenseFormType.vendorPayment) ...[
                        _buildVendorSelector(),
                      ] else if (_selectedType ==
                          ExpenseFormType.salaryDebit) ...[
                        _buildEmployeeSelector(),
                      ] else if (_selectedType ==
                          ExpenseFormType.generalExpense) ...[
                        _buildSubCategorySelector(),
                      ],
                      const SizedBox(height: AppSpacing.paddingLG),
                      // Amount
                      TextFormField(
                        controller: _amountController,
                        style: const TextStyle(color: AuthColors.textMain),
                        decoration: _inputDecoration('Amount *'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter amount';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null || amount <= 0) {
                            return 'Enter valid amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.paddingLG),
                      // Payment Account
                      _buildPaymentAccountSelector(),
                      const SizedBox(height: AppSpacing.paddingLG),
                      // Date
                      InkWell(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.paddingLG),
                          decoration: BoxDecoration(
                            color: AuthColors.surface,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusMD),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  color: AuthColors.textSub, size: 20),
                              const SizedBox(width: AppSpacing.paddingMD),
                              Text(
                                _formatDate(_selectedDate),
                                style:
                                    const TextStyle(color: AuthColors.textMain),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.paddingLG),
                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        style: const TextStyle(color: AuthColors.textMain),
                        decoration: _inputDecoration(
                          _selectedType == ExpenseFormType.generalExpense
                              ? 'Description *'
                              : 'Description',
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (_selectedType == ExpenseFormType.generalExpense &&
                              (value == null || value.trim().isEmpty)) {
                            return 'Enter description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.paddingLG),
                      // Reference Number
                      TextFormField(
                        controller: _referenceNumberController,
                        style: const TextStyle(color: AuthColors.textMain),
                        decoration: _inputDecoration('Reference Number'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.all(AppSpacing.paddingXL),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                      color: AuthColors.textMainWithOpacity(0.12), width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSpacing.paddingMD),
                  FilledButton(
                    onPressed: _isLoading ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AuthColors.legacyAccent,
                      foregroundColor: AuthColors.textMain,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Save Expense'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AuthColors.backgroundAlt,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTypeOption(
              ExpenseFormType.vendorPayment,
              'Vendor',
              Icons.store,
            ),
          ),
          Expanded(
            child: _buildTypeOption(
              ExpenseFormType.salaryDebit,
              'Salary',
              Icons.person,
            ),
          ),
          Expanded(
            child: _buildTypeOption(
              ExpenseFormType.generalExpense,
              'General',
              Icons.receipt,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption(
    ExpenseFormType type,
    String label,
    IconData icon,
  ) {
    final isSelected = _selectedType == type;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedType = type;
          _selectedVendor = null;
          _selectedEmployees = [];
          _selectedSubCategory = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingMD),
        decoration: BoxDecoration(
          color: isSelected
              ? AuthColors.secondary.withValues(alpha: 0.2)
              : AuthColors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          border: Border.all(
            color: isSelected ? AuthColors.secondary : AuthColors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color:
                    isSelected ? AuthColors.secondary : AuthColors.textDisabled,
                size: 20),
            const SizedBox(height: AppSpacing.paddingXS),
            Text(
              label,
              style: TextStyle(
                color:
                    isSelected ? AuthColors.textMain : AuthColors.textDisabled,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vendor *',
          style: TextStyle(
            color: AuthColors.textSub,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.paddingSM),
        DropdownButtonFormField<Vendor>(
          initialValue: _selectedVendor,
          dropdownColor: AuthColors.backgroundAlt,
          style: const TextStyle(color: AuthColors.textMain),
          decoration: _inputDecoration('Select vendor'),
          items: _vendors.map((vendor) {
            return DropdownMenuItem(
              value: vendor,
              child: Text(vendor.name),
            );
          }).toList(),
          onChanged: (vendor) {
            setState(() {
              _selectedVendor = vendor;
            });
          },
          validator: (value) => value == null ? 'Select a vendor' : null,
        ),
      ],
    );
  }

  String _employeeSelectionText() {
    if (_selectedEmployees.isEmpty) return 'Select employees';
    if (_selectedEmployees.length <= 2) {
      return _selectedEmployees.map((e) => e.name).join(', ');
    }
    return '${_selectedEmployees.length} employees selected';
  }

  Future<void> _openEmployeeSelectorDialog() async {
    if (_employees.isEmpty) return;
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => _EmployeeMultiSelectDialog(
        employees: _employees,
        initialSelectedIds: _selectedEmployees.map((e) => e.id).toSet(),
        searchFillColor: AuthColors.backgroundAlt,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedEmployees = _employees
            .where((employee) => result.contains(employee.id))
            .toList();
      });
    }
  }

  Widget _buildEmployeeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Employees *',
          style: TextStyle(
            color: AuthColors.textSub,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.paddingSM),
        if (_employees.isEmpty)
          const Text(
            'No employees available.',
            style: TextStyle(color: AuthColors.textSub),
          )
        else
          InkWell(
            onTap: _openEmployeeSelectorDialog,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AuthColors.backgroundAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AuthColors.textMainWithOpacity(0.12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _employeeSelectionText(),
                      style: TextStyle(
                        color: _selectedEmployees.isEmpty
                            ? AuthColors.textSub
                            : AuthColors.textMain,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: AuthColors.textSub),
                ],
              ),
            ),
          ),
        if (_selectedEmployees.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.paddingSM),
          Wrap(
            spacing: AppSpacing.paddingSM,
            runSpacing: AppSpacing.paddingSM,
            children: _selectedEmployees
                .map(
                  (employee) => Chip(
                    label: Text(employee.name),
                    backgroundColor: AuthColors.surface,
                    labelStyle: const TextStyle(color: AuthColors.textMain),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildSubCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Sub-Category *',
                style: TextStyle(
                  color: AuthColors.textSub,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.settings, size: 16),
              label: const Text('Manage'),
              onPressed: () async {
                await context.push('/expense-sub-categories');
                if (mounted) {
                  await _loadData();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.paddingSM),
        DropdownButtonFormField<ExpenseSubCategory>(
          initialValue: _selectedSubCategory,
          dropdownColor: AuthColors.backgroundAlt,
          style: const TextStyle(color: AuthColors.textMain),
          decoration: _inputDecoration('Select sub-category'),
          items: _subCategories.where((sc) => sc.isActive).map((subCategory) {
            return DropdownMenuItem(
              value: subCategory,
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Color(int.parse(subCategory.colorHex.substring(1),
                              radix: 16) +
                          0xFF000000),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.paddingSM),
                  Text(subCategory.name),
                ],
              ),
            );
          }).toList(),
          onChanged: (subCategory) {
            setState(() {
              _selectedSubCategory = subCategory;
            });
          },
          validator: (value) => value == null ? 'Select a sub-category' : null,
        ),
      ],
    );
  }

  Widget _buildPaymentAccountSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Account *',
          style: TextStyle(
            color: AuthColors.textSub,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.paddingSM),
        DropdownButtonFormField<PaymentAccount>(
          initialValue: _selectedPaymentAccount,
          dropdownColor: AuthColors.backgroundAlt,
          style: const TextStyle(color: AuthColors.textMain),
          decoration: _inputDecoration('Select payment account'),
          items: _paymentAccounts.map((account) {
            return DropdownMenuItem(
              value: account,
              child: Text(account.name),
            );
          }).toList(),
          onChanged: (account) {
            setState(() {
              _selectedPaymentAccount = account;
            });
          },
          validator: (value) =>
              value == null ? 'Select a payment account' : null,
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AuthColors.backgroundAlt,
      labelStyle: const TextStyle(color: AuthColors.textSub),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        borderSide: BorderSide.none,
      ),
    );
  }
}

class _EmployeeMultiSelectDialog extends StatefulWidget {
  const _EmployeeMultiSelectDialog({
    required this.employees,
    required this.initialSelectedIds,
    required this.searchFillColor,
  });

  final List<OrganizationEmployee> employees;
  final Set<String> initialSelectedIds;
  final Color searchFillColor;

  @override
  State<_EmployeeMultiSelectDialog> createState() =>
      _EmployeeMultiSelectDialogState();
}

class _EmployeeMultiSelectDialogState
    extends State<_EmployeeMultiSelectDialog> {
  late final TextEditingController _searchController;
  late List<OrganizationEmployee> _filtered;
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filtered = List.of(widget.employees);
    _selectedIds = Set.of(widget.initialSelectedIds);
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_applyFilter)
      ..dispose();
    super.dispose();
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = List.of(widget.employees);
      } else {
        _filtered = widget.employees
            .where((employee) => employee.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final availableHeight = MediaQuery.of(context).size.height -
        MediaQuery.of(context).viewInsets.bottom;
    var dialogHeight = availableHeight * 0.7;
    if (dialogHeight < 280) dialogHeight = 280;
    if (dialogHeight > 520) dialogHeight = 520;

    return AlertDialog(
      backgroundColor: AuthColors.surface,
      title: const Text(
        'Select Employees',
        style: TextStyle(color: AuthColors.textMain),
      ),
      content: SizedBox(
        width: 520,
        height: dialogHeight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              style: const TextStyle(color: AuthColors.textMain),
              decoration: InputDecoration(
                labelText: 'Search employees',
                labelStyle: const TextStyle(color: AuthColors.textSub),
                filled: true,
                fillColor: widget.searchFillColor,
                prefixIcon: const Icon(Icons.search, color: AuthColors.textSub),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AuthColors.textMainWithOpacity(0.12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No employees found.',
                        style: TextStyle(color: AuthColors.textSub),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final employee = _filtered[index];
                        final isSelected = _selectedIds.contains(employee.id);
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedIds.add(employee.id);
                              } else {
                                _selectedIds.remove(employee.id);
                              }
                            });
                          },
                          title: Text(
                            employee.name,
                            style: const TextStyle(color: AuthColors.textMain),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        DashButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
          variant: DashButtonVariant.text,
        ),
        DashButton(
          label: 'Apply',
          onPressed: () => Navigator.of(context).pop(_selectedIds),
        ),
      ],
    );
  }
}
