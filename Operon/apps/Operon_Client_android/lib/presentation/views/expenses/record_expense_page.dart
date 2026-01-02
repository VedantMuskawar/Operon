import 'package:core_models/core_models.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:dash_mobile/data/datasources/payment_accounts_data_source.dart';
import 'package:dash_mobile/data/repositories/employees_repository.dart';
import 'package:dash_mobile/data/utils/financial_year_utils.dart';
import 'package:dash_mobile/domain/entities/organization_employee.dart';
import 'package:dash_mobile/domain/entities/payment_account.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/widgets/page_workspace_layout.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum ExpenseFormType {
  vendorPayment,
  salaryDebit,
  generalExpense,
}

class RecordExpensePage extends StatefulWidget {
  const RecordExpensePage({
    super.key,
    this.type,
    this.vendorId,
    this.employeeId,
  });

  final ExpenseFormType? type;
  final String? vendorId;
  final String? employeeId;

  @override
  State<RecordExpensePage> createState() => _RecordExpensePageState();
}

class _RecordExpensePageState extends State<RecordExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _referenceNumberController = TextEditingController();

  ExpenseFormType _selectedType = ExpenseFormType.vendorPayment;
  Vendor? _selectedVendor;
  OrganizationEmployee? _selectedEmployee;
  ExpenseSubCategory? _selectedSubCategory;
  PaymentAccount? _selectedPaymentAccount;
  DateTime _selectedDate = DateTime.now();

  // Data lists
  List<Vendor> _vendors = [];
  List<OrganizationEmployee> _employees = [];
  List<ExpenseSubCategory> _subCategories = [];
  List<PaymentAccount> _paymentAccounts = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.type != null) {
      _selectedType = widget.type!;
    }
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _referenceNumberController.dispose();
    super.dispose();
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
          context.go('/home');
        }
        return;
      }

      final vendorsRepo = context.read<VendorsRepository>();
      final employeesRepo = context.read<EmployeesRepository>();
      final subCategoriesRepo = context.read<ExpenseSubCategoriesRepository>();
      final paymentAccountsDataSource = context.read<PaymentAccountsDataSource>();

      _vendors = await vendorsRepo.fetchVendors(organizationId);
      _employees = await employeesRepo.fetchEmployees(organizationId);
      _subCategories = await subCategoriesRepo.fetchSubCategories(organizationId);
      _paymentAccounts = await paymentAccountsDataSource.fetchAccounts(organizationId);

      // Initialize selections from widget parameters
      if (widget.vendorId != null) {
        _selectedVendor = _vendors.firstWhere(
          (v) => v.id == widget.vendorId,
          orElse: () => _vendors.isNotEmpty ? _vendors.first : throw StateError('No vendors'),
        );
      }
      if (widget.employeeId != null) {
        _selectedEmployee = _employees.firstWhere(
          (e) => e.id == widget.employeeId,
          orElse: () => _employees.isNotEmpty ? _employees.first : throw StateError('No employees'),
        );
      }
      // Set default payment account
      _selectedPaymentAccount = _paymentAccounts.firstWhereOrNull((pa) => pa.isPrimary) ??
          (_paymentAccounts.isNotEmpty ? _paymentAccounts.first : null);
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

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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
              primary: Color(0xFF6F4BFF),
              onPrimary: Colors.white,
              surface: Color(0xFF1B1B2C),
              onSurface: Colors.white,
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
    if (_isSubmitting) return;

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

    setState(() => _isSubmitting = true);

    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final financialYear = FinancialYearUtils.getFinancialYear(_selectedDate);
    final transactionsDataSource = context.read<TransactionsDataSource>();

    try {
      Transaction transaction;
      
      switch (_selectedType) {
        case ExpenseFormType.vendorPayment:
          if (_selectedVendor == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Select a vendor')),
            );
            setState(() => _isSubmitting = false);
            return;
          }
          transaction = Transaction(
            id: '',
            organizationId: organizationId,
            vendorId: _selectedVendor!.id,
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
          if (_selectedEmployee == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Select an employee')),
            );
            setState(() => _isSubmitting = false);
            return;
          }
          transaction = Transaction(
            id: '',
            organizationId: organizationId,
            employeeId: _selectedEmployee!.id,
            ledgerType: LedgerType.employeeLedger,
            type: TransactionType.debit,
            category: TransactionCategory.salaryDebit,
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
        case ExpenseFormType.generalExpense:
          if (_selectedSubCategory == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Select a sub-category')),
            );
            setState(() => _isSubmitting = false);
            return;
          }
          if (_descriptionController.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Enter a description')),
            );
            setState(() => _isSubmitting = false);
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

      await transactionsDataSource.createTransaction(transaction);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense created successfully')),
        );
        context.go('/expenses');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating expense: $e')),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageWorkspaceLayout(
      title: 'Record Expense',
      currentIndex: 0,
      onBack: () => context.go('/home'),
      onNavTap: (value) => context.go('/home', extra: value),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Expense Type Selector
                    const Text(
                      'Expense Type',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTypeSelector(),
                    const SizedBox(height: 24),
                    // Dynamic fields based on type
                    if (_selectedType == ExpenseFormType.vendorPayment) ...[
                      _buildVendorSelector(),
                    ] else if (_selectedType == ExpenseFormType.salaryDebit) ...[
                      _buildEmployeeSelector(),
                    ] else if (_selectedType == ExpenseFormType.generalExpense) ...[
                      _buildSubCategorySelector(),
                    ],
                    const SizedBox(height: 24),
                    // Amount
                    TextFormField(
                      controller: _amountController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Amount *'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
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
                    const SizedBox(height: 24),
                    // Payment Account
                    _buildPaymentAccountSelector(),
                    const SizedBox(height: 24),
                    // Date
                    InkWell(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B1B2C),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                color: Colors.white54, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              _formatDate(_selectedDate),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      style: const TextStyle(color: Colors.white),
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
                    const SizedBox(height: 24),
                    // Reference Number
                    TextFormField(
                      controller: _referenceNumberController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Reference Number'),
                    ),
                    const SizedBox(height: 32),
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6F4BFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Save Expense',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B2C),
        borderRadius: BorderRadius.circular(12),
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
          _selectedEmployee = null;
          _selectedSubCategory = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6F4BFF).withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6F4BFF)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF6F4BFF) : Colors.white54, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
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
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<Vendor>(
          value: _selectedVendor,
          dropdownColor: const Color(0xFF1B1B2C),
          style: const TextStyle(color: Colors.white),
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

  Widget _buildEmployeeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Employee *',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<OrganizationEmployee>(
          value: _selectedEmployee,
          dropdownColor: const Color(0xFF1B1B2C),
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('Select employee'),
          items: _employees.map((employee) {
            return DropdownMenuItem(
              value: employee,
              child: Text(employee.name),
            );
          }).toList(),
          onChanged: (employee) {
            setState(() {
              _selectedEmployee = employee;
            });
          },
          validator: (value) => value == null ? 'Select an employee' : null,
        ),
      ],
    );
  }

  Widget _buildSubCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sub-Category *',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<ExpenseSubCategory>(
          value: _selectedSubCategory,
          dropdownColor: const Color(0xFF1B1B2C),
          style: const TextStyle(color: Colors.white),
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
                      color: Color(int.parse(subCategory.colorHex.substring(1), radix: 16) + 0xFF000000),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
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
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<PaymentAccount>(
          value: _selectedPaymentAccount,
          dropdownColor: const Color(0xFF1B1B2C),
          style: const TextStyle(color: Colors.white),
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
          validator: (value) => value == null ? 'Select a payment account' : null,
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFF1B1B2C),
      labelStyle: const TextStyle(color: Colors.white70),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}

extension FirstWhereOrNull<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    try {
      return firstWhere(test);
    } catch (e) {
      return null;
    }
  }
}

