import 'package:core_models/core_models.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:dash_mobile/data/datasources/payment_accounts_data_source.dart';
import 'package:dash_mobile/data/repositories/employees_repository.dart';
import 'package:dash_mobile/data/utils/financial_year_utils.dart';
import 'package:dash_mobile/domain/entities/organization_employee.dart';
import 'package:dash_mobile/domain/entities/payment_account.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:dash_mobile/presentation/widgets/quick_nav_bar.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';

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

  // Invoice selection state
  String _invoiceSelectionMode = 'manualSelection'; // 'dateRange' or 'manualSelection'
  DateTime? _invoiceDateRangeStart;
  DateTime? _invoiceDateRangeEnd;
  final TextEditingController _fromInvoiceNumberController = TextEditingController();
  final TextEditingController _toInvoiceNumberController = TextEditingController();
  List<Transaction> _availableInvoices = [];
  Set<String> _selectedInvoiceIds = {};
  bool _isLoadingInvoices = false;

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
    _fromInvoiceNumberController.dispose();
    _toInvoiceNumberController.dispose();
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

  Future<void> _loadUnpaidInvoices() async {
    if (_selectedVendor == null) return;

    setState(() => _isLoadingInvoices = true);
    try {
      final orgState = context.read<OrganizationContextCubit>().state;
      final organizationId = orgState.organization?.id;
      if (organizationId == null) return;

      final transactionsDataSource = TransactionsDataSource();
      final invoices = await transactionsDataSource.fetchUnpaidVendorInvoices(
        organizationId: organizationId,
        vendorId: _selectedVendor!.id,
        startDate: _invoiceDateRangeStart,
        endDate: _invoiceDateRangeEnd,
      );

      setState(() {
        _availableInvoices = invoices;
        if (_invoiceSelectionMode == 'dateRange') {
          // Auto-select all invoices in date range mode
          _selectedInvoiceIds = invoices.map((inv) => inv.id).toSet();
        }
        _updatePaymentAmount();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading invoices: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingInvoices = false);
      }
    }
  }

  void _updatePaymentAmount() {
    double total = 0;
    for (final invoiceId in _selectedInvoiceIds) {
      final invoice = _availableInvoices.firstWhere((inv) => inv.id == invoiceId);
      final metadata = invoice.metadata;
      final paidAmount = (metadata?['paidAmount'] as num?)?.toDouble() ?? 0;
      final remainingAmount = invoice.amount - paidAmount;
      total += remainingAmount;
    }
    _amountController.text = total.toStringAsFixed(2);
  }

  double _getInvoiceRemainingAmount(Transaction invoice) {
    final metadata = invoice.metadata;
    final paidAmount = (metadata?['paidAmount'] as num?)?.toDouble() ?? 0;
    return invoice.amount - paidAmount;
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
          // Build metadata for invoice linking
          Map<String, dynamic>? metadata;
          List<String>? linkedInvoiceIds;
          if (_selectedInvoiceIds.isNotEmpty) {
            linkedInvoiceIds = _selectedInvoiceIds.toList();
            metadata = {
              'linkedInvoiceIds': linkedInvoiceIds,
              'paymentMode': _invoiceSelectionMode,
            };
            if (_invoiceDateRangeStart != null && _invoiceDateRangeEnd != null) {
              metadata['dateRange'] = {
                'startDate': _invoiceDateRangeStart!.toIso8601String(),
                'endDate': _invoiceDateRangeEnd!.toIso8601String(),
              };
            }
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
            metadata: metadata,
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
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: const ModernPageHeader(
        title: 'Record Expense',
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
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
                      const SizedBox(height: 24),
                      _buildInvoiceSelectionSection(),
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
            ),
            QuickNavBar(
              currentIndex: 0,
              onTap: (value) => context.go('/home', extra: value),
            ),
          ],
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

  Widget _buildInvoiceSelectionSection() {
    if (_selectedVendor == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Invoice Selection',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        // Mode toggle
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Pay Selected Invoices', style: TextStyle(color: Colors.white70, fontSize: 14)),
                value: 'manualSelection',
                groupValue: _invoiceSelectionMode,
                onChanged: (value) {
                  setState(() {
                    _invoiceSelectionMode = value!;
                    _invoiceDateRangeStart = null;
                    _invoiceDateRangeEnd = null;
                    _fromInvoiceNumberController.clear();
                    _toInvoiceNumberController.clear();
                    _selectedInvoiceIds.clear();
                    _availableInvoices.clear();
                  });
                },
                activeColor: const Color(0xFF6F4BFF),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Pay by Date Range', style: TextStyle(color: Colors.white70, fontSize: 14)),
                value: 'dateRange',
                groupValue: _invoiceSelectionMode,
                onChanged: (value) {
                  setState(() {
                    _invoiceSelectionMode = value!;
                    _selectedInvoiceIds.clear();
                  });
                  _loadUnpaidInvoices();
                },
                activeColor: const Color(0xFF6F4BFF),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Date range picker (only for date range mode)
        if (_invoiceSelectionMode == 'dateRange') ...[
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _invoiceDateRangeStart ?? DateTime.now().subtract(const Duration(days: 30)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
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
                        _invoiceDateRangeStart = picked;
                      });
                      _loadUnpaidInvoices();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1B2C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.white54, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _invoiceDateRangeStart == null
                              ? 'Start Date'
                              : _formatDate(_invoiceDateRangeStart!),
                          style: TextStyle(
                            color: _invoiceDateRangeStart == null
                                ? Colors.white54
                                : Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _invoiceDateRangeEnd ?? DateTime.now(),
                      firstDate: _invoiceDateRangeStart ?? DateTime(2020),
                      lastDate: DateTime.now(),
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
                        _invoiceDateRangeEnd = picked;
                      });
                      _loadUnpaidInvoices();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1B2C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.white54, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _invoiceDateRangeEnd == null
                              ? 'End Date'
                              : _formatDate(_invoiceDateRangeEnd!),
                          style: TextStyle(
                            color: _invoiceDateRangeEnd == null
                                ? Colors.white54
                                : Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        // Invoice number range inputs (only for manual selection mode)
        if (_invoiceSelectionMode == 'manualSelection') ...[
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _fromInvoiceNumberController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('From Invoice Number'),
                  onChanged: (_) {
                    // Debounce or trigger search on field change
                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (mounted) {
                        _loadUnpaidInvoices();
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _toInvoiceNumberController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('To Invoice Number'),
                  onChanged: (_) {
                    // Debounce or trigger search on field change
                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (mounted) {
                        _loadUnpaidInvoices();
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _loadUnpaidInvoices,
            icon: const Icon(Icons.search, size: 18, color: Color(0xFF6F4BFF)),
            label: const Text('Search Invoices', style: TextStyle(color: Color(0xFF6F4BFF))),
          ),
          const SizedBox(height: 16),
        ],
        // Invoice list / summary
        if (_isLoadingInvoices)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_invoiceSelectionMode == 'dateRange' && (_invoiceDateRangeStart == null || _invoiceDateRangeEnd == null))
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Select date range to view invoices',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          )
        else if (_availableInvoices.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _invoiceSelectionMode == 'manualSelection' && _fromInvoiceNumberController.text.trim().isEmpty && _toInvoiceNumberController.text.trim().isEmpty
                  ? 'Enter invoice number range and click Search'
                  : 'No unpaid invoices found',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B2C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Found ${_availableInvoices.length} invoice${_availableInvoices.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ..._availableInvoices.take(5).map((invoice) {
                  final remainingAmount = _getInvoiceRemainingAmount(invoice);
                  final invoiceNumber = invoice.referenceNumber ?? invoice.metadata?['invoiceNumber'] ?? 'N/A';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                invoiceNumber,
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '${_formatDate(invoice.createdAt ?? DateTime.now())} | ₹${remainingAmount.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (_availableInvoices.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '... and ${_availableInvoices.length - 5} more',
                      style: const TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
        // Total amount display
        if (_selectedInvoiceIds.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF6F4BFF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6F4BFF).withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount:',
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  '₹${_amountController.text.isEmpty ? "0.00" : _amountController.text}',
                  style: const TextStyle(
                    color: Color(0xFF6F4BFF),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
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
          initialValue: _selectedVendor,
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
              _selectedInvoiceIds.clear();
              _availableInvoices.clear();
              _fromInvoiceNumberController.clear();
              _toInvoiceNumberController.clear();
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
          initialValue: _selectedEmployee,
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
          initialValue: _selectedSubCategory,
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _paymentAccounts.map((account) {
            return _buildPaymentAccountOption(account);
          }).toList(),
        ),
        if (_selectedPaymentAccount == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Select a payment account',
              style: TextStyle(color: Colors.red.withOpacity(0.8), fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildPaymentAccountOption(PaymentAccount account) {
    final isSelected = _selectedPaymentAccount?.id == account.id;
    IconData icon;
    switch (account.type) {
      case PaymentAccountType.bank:
        icon = Icons.account_balance;
        break;
      case PaymentAccountType.cash:
        icon = Icons.money;
        break;
      case PaymentAccountType.upi:
        icon = Icons.qr_code;
        break;
      case PaymentAccountType.other:
        icon = Icons.payment;
        break;
    }
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentAccount = account;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6F4BFF).withOpacity(0.2)
              : const Color(0xFF1B1B2C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6F4BFF)
                : Colors.white.withOpacity(0.1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF6F4BFF) : Colors.white54, size: 18),
            const SizedBox(width: 8),
            Text(
              account.name,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (account.isPrimary) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6F4BFF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Primary',
                  style: TextStyle(
                    color: Color(0xFF6F4BFF),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
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

