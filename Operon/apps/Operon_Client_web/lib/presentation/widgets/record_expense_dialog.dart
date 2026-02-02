import 'package:core_models/core_models.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/datasources/payment_accounts_data_source.dart';
import 'package:dash_web/data/repositories/employees_repository.dart';
import 'package:dash_web/domain/entities/organization_employee.dart';
import 'package:dash_web/domain/entities/payment_account.dart';
import 'package:dash_web/presentation/blocs/expenses/expenses_cubit.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/data/repositories/dm_settings_repository.dart';
import 'package:dash_web/data/services/dm_print_service.dart';
import 'package:dash_web/presentation/widgets/fuel_ledger_pdf_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RecordExpenseDialog extends StatefulWidget {
  const RecordExpenseDialog({
    super.key,
    this.type,
    this.vendorId,
    this.employeeId,
  });

  final ExpenseFormType? type;
  final String? vendorId;
  final String? employeeId;

  @override
  State<RecordExpenseDialog> createState() => _RecordExpenseDialogState();
}

class _RecordExpenseDialogState extends State<RecordExpenseDialog> {
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
          Navigator.of(context).pop();
        }
        return;
      }

      final vendorsRepo = context.read<VendorsRepository>();
      final employeesRepo = context.read<EmployeesRepository>();
      final subCategoriesRepo = context.read<ExpenseSubCategoriesRepository>();
      final paymentAccountsDataSource = PaymentAccountsDataSource();

      _vendors = await vendorsRepo.fetchVendors(organizationId);
      _employees = await employeesRepo.fetchEmployees(organizationId);
      _subCategories = await subCategoriesRepo.fetchSubCategories(organizationId);
      _paymentAccounts = await paymentAccountsDataSource.fetchAccounts(organizationId);

      // Initialize selections from widget parameters
      if (widget.vendorId != null) {
        _selectedVendor = _vendors.firstWhereOrNull((v) => v.id == widget.vendorId);
      }
      if (widget.employeeId != null) {
        _selectedEmployee = _employees.firstWhereOrNull((e) => e.id == widget.employeeId);
      }
      // Set default payment account
      _selectedPaymentAccount = _paymentAccounts.firstWhereOrNull((pa) => pa.isPrimary) ??
          (_paymentAccounts.isNotEmpty ? _paymentAccounts.first : null);
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(context, message: 'Error loading data: $e', isError: true);
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
          data: DashTheme.light(),
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
      List<Transaction> invoices;
      
      if (_invoiceSelectionMode == 'dateRange') {
        // For date range mode, filter by date; only verified purchases can be paid
        invoices = await transactionsDataSource.fetchUnpaidVendorInvoices(
          organizationId: organizationId,
          vendorId: _selectedVendor!.id,
          startDate: _invoiceDateRangeStart,
          endDate: _invoiceDateRangeEnd,
          verifiedOnly: true,
        );
      } else {
        // For manual selection mode, fetch all unpaid invoices; only verified purchases can be paid
        invoices = await transactionsDataSource.fetchUnpaidVendorInvoices(
          organizationId: organizationId,
          vendorId: _selectedVendor!.id,
          verifiedOnly: true,
        );
      }

      // Filter by invoice number range if in manual selection mode and range is specified
      if (_invoiceSelectionMode == 'manualSelection') {
        final fromNumber = _fromInvoiceNumberController.text.trim();
        final toNumber = _toInvoiceNumberController.text.trim();
        
        if (fromNumber.isNotEmpty || toNumber.isNotEmpty) {
          invoices = invoices.where((invoice) {
            final invoiceNumber = invoice.referenceNumber ??
                invoice.metadata?['invoiceNumber']?.toString() ??
                invoice.metadata?['voucherNumber']?.toString() ??
                '';
            if (invoiceNumber.isEmpty) return false;
            
            final invoiceNumUpper = invoiceNumber.toUpperCase();
            final fromUpper = fromNumber.toUpperCase();
            final toUpper = toNumber.toUpperCase();
            
            bool matches = true;
            if (fromNumber.isNotEmpty) {
              matches = matches && invoiceNumUpper.compareTo(fromUpper) >= 0;
            }
            if (toNumber.isNotEmpty) {
              matches = matches && invoiceNumUpper.compareTo(toUpper) <= 0;
            }
            return matches;
          }).toList();
        }
      }

      setState(() {
        _availableInvoices = invoices;
        if (_invoiceSelectionMode == 'dateRange') {
          // Auto-select all invoices in date range mode
          _selectedInvoiceIds = invoices.map((inv) => inv.id).toSet();
        } else if (_invoiceSelectionMode == 'manualSelection') {
          // Auto-select all invoices that match the invoice number range
          _selectedInvoiceIds = invoices.map((inv) => inv.id).toSet();
        }
        _updatePaymentAmount();
      });
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(context, message: 'Error loading invoices: $e', isError: true);
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
      DashSnackbar.show(context, message: 'Enter a valid amount', isError: true);
      return;
    }

    if (_selectedPaymentAccount == null) {
      DashSnackbar.show(context, message: 'Select a payment account', isError: true);
      return;
    }

    final orgState = context.read<OrganizationContextCubit>().state;
    final organizationId = orgState.organization?.id;
    if (organizationId == null) {
      DashSnackbar.show(context, message: 'No organization selected', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    final cubit = context.read<ExpensesCubit>();

    try {
      switch (_selectedType) {
        case ExpenseFormType.vendorPayment:
          if (_selectedVendor == null) {
            DashSnackbar.show(context, message: 'Select a vendor', isError: true);
            setState(() => _isSubmitting = false);
            return;
          }
          await cubit.createVendorPayment(
            vendorId: _selectedVendor!.id,
            amount: amount,
            paymentAccountId: _selectedPaymentAccount!.id,
            date: _selectedDate,
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            referenceNumber: _referenceNumberController.text.trim().isEmpty
                ? null
                : _referenceNumberController.text.trim(),
            linkedInvoiceIds: _selectedInvoiceIds.isNotEmpty ? _selectedInvoiceIds.toList() : null,
            paymentMode: _selectedInvoiceIds.isNotEmpty ? _invoiceSelectionMode : null,
            dateRangeStart: _invoiceDateRangeStart,
            dateRangeEnd: _invoiceDateRangeEnd,
          );
          break;
        case ExpenseFormType.salaryDebit:
          if (_selectedEmployee == null) {
            DashSnackbar.show(context, message: 'Select an employee', isError: true);
            setState(() => _isSubmitting = false);
            return;
          }
          await cubit.createSalaryDebit(
            employeeId: _selectedEmployee!.id,
            amount: amount,
            paymentAccountId: _selectedPaymentAccount!.id,
            date: _selectedDate,
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
            DashSnackbar.show(context, message: 'Select a sub-category', isError: true);
            setState(() => _isSubmitting = false);
            return;
          }
          if (_descriptionController.text.trim().isEmpty) {
            DashSnackbar.show(context, message: 'Enter a description', isError: true);
            setState(() => _isSubmitting = false);
            return;
          }
          await cubit.createGeneralExpense(
            subCategoryId: _selectedSubCategory!.id,
            amount: amount,
            paymentAccountId: _selectedPaymentAccount!.id,
            date: _selectedDate,
            description: _descriptionController.text.trim(),
            referenceNumber: _referenceNumberController.text.trim().isEmpty
                ? null
                : _referenceNumberController.text.trim(),
          );
          break;
      }

      if (mounted) {
        DashSnackbar.show(context, message: 'Expense created successfully', isError: false);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(context, message: 'Error creating expense: $e', isError: true);
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _openFuelLedgerPdfDialog() {
    if (_selectedVendor == null) return;
    final orgState = context.read<OrganizationContextCubit>().state;
    final organizationId = orgState.organization?.id;
    if (organizationId == null) {
      DashSnackbar.show(context, message: 'No organization selected', isError: true);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => FuelLedgerPdfDialog(
        vendor: _selectedVendor!,
        organizationId: organizationId,
        transactionsRepository: context.read<TransactionsRepository>(),
        dmSettingsRepository: context.read<DmSettingsRepository>(),
        dmPrintService: context.read<DmPrintService>(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.5).clamp(500.0, 700.0);

    return AlertDialog(
      backgroundColor: AuthColors.surface,
      title: const Text(
        'Record Expense',
        style: TextStyle(color: AuthColors.textMain),
      ),
      content: SizedBox(
        width: dialogWidth,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                      const SizedBox(height: 8),
                      _buildTypeSelector(),
                      const SizedBox(height: 24),
                      // Dynamic fields based on type
                      if (_selectedType == ExpenseFormType.vendorPayment) ...[
                        _buildVendorSelector(),
                        if (_selectedVendor != null && _selectedVendor!.vendorType == VendorType.fuel) ...[
                          const SizedBox(height: 16),
                          DashButton(
                            label: 'Fuel Ledger PDF',
                            icon: Icons.picture_as_pdf,
                            onPressed: _openFuelLedgerPdfDialog,
                            variant: DashButtonVariant.outlined,
                          ),
                        ],
                        const SizedBox(height: 24),
                        _buildInvoiceSelectionSection(),
                      ] else if (_selectedType == ExpenseFormType.salaryDebit) ...[
                        _buildEmployeeSelector(),
                      ] else if (_selectedType == ExpenseFormType.generalExpense) ...[
                        _buildSubCategorySelector(),
                      ],
                      const SizedBox(height: 24),
                      // Amount
                      DashFormField(
                        controller: _amountController,
                        label: 'Amount *',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: AuthColors.textMain),
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
                      const SizedBox(height: 16),
                      // Payment Account
                      _buildPaymentAccountSelector(),
                      const SizedBox(height: 16),
                      // Date
                      InkWell(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AuthColors.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  color: AuthColors.textSub, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                _formatDate(_selectedDate),
                                style: const TextStyle(color: AuthColors.textMain),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Description
                      DashFormField(
                        controller: _descriptionController,
                        label: _selectedType == ExpenseFormType.generalExpense
                            ? 'Description *'
                            : 'Description',
                        maxLines: 3,
                        style: const TextStyle(color: AuthColors.textMain),
                        validator: (value) {
                          if (_selectedType == ExpenseFormType.generalExpense &&
                              (value == null || value.trim().isEmpty)) {
                            return 'Enter description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Reference Number
                      DashFormField(
                        controller: _referenceNumberController,
                        label: 'Reference Number',
                        style: const TextStyle(color: AuthColors.textMain),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        DashButton(
          label: 'Cancel',
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          variant: DashButtonVariant.text,
        ),
        DashButton(
          label: 'Save',
          onPressed: _isSubmitting ? null : _save,
          isLoading: _isSubmitting,
        ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AuthColors.surface,
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
              ? AuthColors.primaryWithOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AuthColors.primary
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AuthColors.primary : AuthColors.textSub, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AuthColors.textMain : AuthColors.textSub,
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
            color: AuthColors.textSub,
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
                title: Text('Pay Selected Invoices', style: TextStyle(color: AuthColors.textSub, fontSize: 14)),
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
                activeColor: AuthColors.primary,
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: Text('Pay by Date Range', style: TextStyle(color: AuthColors.textSub, fontSize: 14)),
                value: 'dateRange',
                groupValue: _invoiceSelectionMode,
                onChanged: (value) {
                  setState(() {
                    _invoiceSelectionMode = value!;
                    _selectedInvoiceIds.clear();
                  });
                  _loadUnpaidInvoices();
                },
                activeColor: AuthColors.primary,
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
                          data: DashTheme.light(),
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
                      color: AuthColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: AuthColors.textSub, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _invoiceDateRangeStart == null
                              ? 'Start Date'
                              : _formatDate(_invoiceDateRangeStart!),
                          style: TextStyle(
                            color: _invoiceDateRangeStart == null
                                ? AuthColors.textSub
                                : AuthColors.textMain,
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
                          data: DashTheme.light(),
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
                      color: AuthColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: AuthColors.textSub, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _invoiceDateRangeEnd == null
                              ? 'End Date'
                              : _formatDate(_invoiceDateRangeEnd!),
                          style: TextStyle(
                            color: _invoiceDateRangeEnd == null
                                ? AuthColors.textSub
                                : AuthColors.textMain,
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
                child: DashFormField(
                  controller: _fromInvoiceNumberController,
                  label: 'From Invoice Number',
                  style: TextStyle(color: AuthColors.textMain),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DashFormField(
                  controller: _toInvoiceNumberController,
                  label: 'To Invoice Number',
                  style: TextStyle(color: AuthColors.textMain),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DashButton(
            label: 'Search Invoices',
            icon: Icons.search,
            onPressed: _loadUnpaidInvoices,
            variant: DashButtonVariant.outlined,
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
              style: TextStyle(color: AuthColors.textSub, fontSize: 14),
            ),
          )
        else if (_availableInvoices.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _invoiceSelectionMode == 'manualSelection' && _fromInvoiceNumberController.text.trim().isEmpty && _toInvoiceNumberController.text.trim().isEmpty
                  ? 'Enter invoice number range and click Search'
                  : 'No unpaid invoices found',
              style: TextStyle(color: AuthColors.textSub, fontSize: 14),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AuthColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Found ${_availableInvoices.length} invoice${_availableInvoices.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: AuthColors.textSub,
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
                                style: TextStyle(color: AuthColors.textMain, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '${_formatDate(invoice.createdAt ?? DateTime.now())} | ₹${remainingAmount.toStringAsFixed(2)}',
                                style: TextStyle(color: AuthColors.textSub, fontSize: 11),
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
                      style: TextStyle(color: AuthColors.textSub, fontSize: 12, fontStyle: FontStyle.italic),
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
              color: AuthColors.primaryWithOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AuthColors.primaryWithOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Amount:',
                  style: TextStyle(color: AuthColors.textSub, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  '₹${_amountController.text.isEmpty ? "0.00" : _amountController.text}',
                  style: TextStyle(
                    color: AuthColors.primary,
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
            color: AuthColors.textSub,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<Vendor>(
          initialValue: _selectedVendor,
          dropdownColor: AuthColors.surface,
          style: TextStyle(color: AuthColors.textMain),
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
            });
            if (vendor != null) {
              _loadUnpaidInvoices();
            }
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
            color: AuthColors.textSub,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<OrganizationEmployee>(
          initialValue: _selectedEmployee,
          dropdownColor: AuthColors.surface,
          style: TextStyle(color: AuthColors.textMain),
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
            color: AuthColors.textSub,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<ExpenseSubCategory>(
          initialValue: _selectedSubCategory,
          dropdownColor: AuthColors.surface,
          style: TextStyle(color: AuthColors.textMain),
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
            color: AuthColors.textSub,
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
              ? AuthColors.primaryWithOpacity(0.2)
              : AuthColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AuthColors.primary
                : AuthColors.textMainWithOpacity(0.1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? AuthColors.primary : AuthColors.textSub, size: 18),
            const SizedBox(width: 8),
            Text(
              account.name,
              style: TextStyle(
                color: isSelected ? AuthColors.textMain : AuthColors.textSub,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (account.isPrimary) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: AuthColors.primaryWithOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Primary',
                  style: TextStyle(
                    color: AuthColors.primary,
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
      fillColor: AuthColors.surface,
      labelStyle: TextStyle(color: AuthColors.textSub),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}

// ExpenseFormType enum
enum ExpenseFormType {
  vendorPayment,
  salaryDebit,
  generalExpense,
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

