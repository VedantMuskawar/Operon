import 'package:core_models/core_models.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/datasources/payment_accounts_data_source.dart';
import 'package:dash_web/data/repositories/employees_repository.dart';
import 'package:dash_web/domain/entities/payment_account.dart';
import 'package:dash_web/presentation/blocs/expenses/expenses_cubit.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/data/repositories/dm_settings_repository.dart';
import 'package:dash_web/data/services/dm_print_service.dart';
import 'package:dash_web/presentation/widgets/fuel_ledger_pdf_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:dash_web/presentation/widgets/cash_voucher_camera_dialog.dart';
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

  static final Map<String, List<Vendor>> _vendorsCache = {};
  static final Map<String, List<OrganizationEmployee>> _employeesCache = {};
  static final Map<String, List<ExpenseSubCategory>> _subCategoriesCache = {};
  static final Map<String, List<PaymentAccount>> _paymentAccountsCache = {};
  static final Map<String, List<_LedgerAccountOption>> _ledgerAccountsCache =
      {};

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
  List<_LedgerAccountOption> _ledgerAccounts = [];
  _LedgerAccountOption? _selectedLedgerAccount;
  bool _isLoadingLedgerAccounts = false;
  bool _isLoading = true;
  bool _isSubmitting = false;

  // Invoice selection state
  String _invoiceSelectionMode =
      'manualSelection'; // 'dateRange' or 'manualSelection'
  DateTime? _invoiceDateRangeStart;
  DateTime? _invoiceDateRangeEnd;
  final TextEditingController _fromInvoiceNumberController =
      TextEditingController();
  final TextEditingController _toInvoiceNumberController =
      TextEditingController();
  List<Transaction> _availableInvoices = [];
  Set<String> _selectedInvoiceIds = {};
  bool _isLoadingInvoices = false;

  /// Cash voucher photo bytes for salary expense (optional).
  Uint8List? _cashVoucherPhotoBytes;

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

      final vendorsFuture = _vendorsCache[organizationId] != null
          ? Future.value(_vendorsCache[organizationId]!)
          : vendorsRepo.fetchVendors(organizationId);
      final employeesFuture = _employeesCache[organizationId] != null
          ? Future.value(_employeesCache[organizationId]!)
          : employeesRepo.fetchEmployees(organizationId);
      final subCategoriesFuture = _subCategoriesCache[organizationId] != null
          ? Future.value(_subCategoriesCache[organizationId]!)
          : subCategoriesRepo.fetchSubCategories(organizationId);
      final paymentAccountsFuture =
          _paymentAccountsCache[organizationId] != null
              ? Future.value(_paymentAccountsCache[organizationId]!)
              : paymentAccountsDataSource.fetchAccounts(organizationId);

      final results = await Future.wait([
        vendorsFuture,
        employeesFuture,
        subCategoriesFuture,
        paymentAccountsFuture,
      ]);

      _vendors = results[0] as List<Vendor>;
      _employees = results[1] as List<OrganizationEmployee>;
      _subCategories = results[2] as List<ExpenseSubCategory>;
      _paymentAccounts = results[3] as List<PaymentAccount>;

      _vendorsCache[organizationId] = _vendors;
      _employeesCache[organizationId] = _employees;
      _subCategoriesCache[organizationId] = _subCategories;
      _paymentAccountsCache[organizationId] = _paymentAccounts;

      await _loadLedgerAccounts(organizationId);

      // Initialize selections from widget parameters
      if (widget.vendorId != null) {
        _selectedVendor =
            _vendors.firstWhereOrNull((v) => v.id == widget.vendorId);
      }
      if (widget.employeeId != null) {
        final employee =
            _employees.firstWhereOrNull((e) => e.id == widget.employeeId);
        if (employee != null) {
          _selectedEmployee = employee;
        }
      }
      // Set default payment account
      _selectedPaymentAccount =
          _paymentAccounts.firstWhereOrNull((pa) => pa.isPrimary) ??
              (_paymentAccounts.isNotEmpty ? _paymentAccounts.first : null);
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(context,
            message: 'Error loading data: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadLedgerAccounts(String organizationId) async {
    setState(() => _isLoadingLedgerAccounts = true);
    try {
      final cachedAccounts = _ledgerAccountsCache[organizationId];
      if (cachedAccounts != null) {
        if (!mounted) return;
        setState(() {
          _ledgerAccounts = cachedAccounts;
          if (_selectedLedgerAccount != null &&
              !_ledgerAccounts
                  .any((a) => a.key == _selectedLedgerAccount!.key)) {
            _selectedLedgerAccount = null;
          }
          _isLoadingLedgerAccounts = false;
        });
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('COMBINED_ACCOUNTS')
          .where('organizationId', isEqualTo: organizationId)
          .orderBy('updatedAt', descending: true)
          .get();

      final Map<String, _LedgerAccountOption> deduped = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final id = (data['accountId'] as String?) ?? doc.id;
        final name = (data['accountName'] as String?) ??
            (data['ledgerName'] as String?) ??
            'Combined Account';
        final accountsData = (data['accounts'] as List<dynamic>?) ?? [];
        final accounts =
            accountsData.whereType<Map<String, dynamic>>().toList();
        if (id.isEmpty) continue;
        final option = _LedgerAccountOption(
          id: id,
          name: name,
          type: _LedgerAccountType.combined,
          accounts: accounts,
        );
        deduped[option.key] = option;
      }

      final list = deduped.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _ledgerAccountsCache[organizationId] = list;
        _ledgerAccounts = list;
        if (_selectedLedgerAccount != null &&
            !_ledgerAccounts.any((a) => a.key == _selectedLedgerAccount!.key)) {
          _selectedLedgerAccount = null;
        }
        _isLoadingLedgerAccounts = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLedgerAccounts = false);
        DashSnackbar.show(context,
            message: 'Failed to load ledger accounts: $e', isError: true);
      }
    }
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
        DashSnackbar.show(context,
            message: 'Error loading invoices: $e', isError: true);
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
      final invoice =
          _availableInvoices.firstWhere((inv) => inv.id == invoiceId);
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
      DashSnackbar.show(context,
          message: 'Enter a valid amount', isError: true);
      return;
    }

    if (_selectedPaymentAccount == null) {
      DashSnackbar.show(context,
          message: 'Select a payment account', isError: true);
      return;
    }

    final orgState = context.read<OrganizationContextCubit>().state;
    final organizationId = orgState.organization?.id;
    if (organizationId == null) {
      DashSnackbar.show(context,
          message: 'No organization selected', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    final cubit = context.read<ExpensesCubit>();

    try {
      switch (_selectedType) {
        case ExpenseFormType.vendorPayment:
          if (_selectedVendor == null) {
            DashSnackbar.show(context,
                message: 'Select a vendor', isError: true);
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
            linkedInvoiceIds: _selectedInvoiceIds.isNotEmpty
                ? _selectedInvoiceIds.toList()
                : null,
            paymentMode:
                _selectedInvoiceIds.isNotEmpty ? _invoiceSelectionMode : null,
            dateRangeStart: _invoiceDateRangeStart,
            dateRangeEnd: _invoiceDateRangeEnd,
          );
          break;
        case ExpenseFormType.salaryDebit:
          List<String> transactionIds = [];
          if (_selectedEmployee == null && _selectedLedgerAccount == null) {
            DashSnackbar.show(context,
                message: 'Select an employee or an account', isError: true);
            setState(() => _isSubmitting = false);
            return;
          }

          if (_selectedEmployee != null) {
            final employeeNames = {
              _selectedEmployee!.id: _selectedEmployee!.name,
            };
            transactionIds = await cubit.createSalaryDebitSplit(
              employeeIds: [_selectedEmployee!.id],
              employeeNames: employeeNames,
              amount: amount,
              paymentAccountId: _selectedPaymentAccount!.id,
              date: _selectedDate,
              description: _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
              referenceNumber: _referenceNumberController.text.trim().isEmpty
                  ? null
                  : _referenceNumberController.text.trim(),
              ledgerAccount: _selectedLedgerAccount?.toJson(),
            );

            if (transactionIds.isEmpty) {
              setState(() => _isSubmitting = false);
              return;
            }
          } else {
            final accountEmployees = _extractEmployeesFromLedgerAccount(
              _selectedLedgerAccount!,
            );
            if (accountEmployees.length < 2) {
              DashSnackbar.show(context,
                  message: 'Selected account must include at least 2 employees',
                  isError: true);
              setState(() => _isSubmitting = false);
              return;
            }

            final selectedTwo = accountEmployees.take(2).toList();
            final employeeIds = selectedTwo.map((e) => e.id).toList();
            final employeeNames = {
              for (final employee in selectedTwo) employee.id: employee.name,
            };

            transactionIds = await cubit.createSalaryDebitSplit(
              employeeIds: employeeIds,
              employeeNames: employeeNames,
              amount: amount,
              paymentAccountId: _selectedPaymentAccount!.id,
              date: _selectedDate,
              description: _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
              referenceNumber: _referenceNumberController.text.trim().isEmpty
                  ? null
                  : _referenceNumberController.text.trim(),
              ledgerAccount: _selectedLedgerAccount!.toJson(),
            );

            if (transactionIds.isEmpty) {
              setState(() => _isSubmitting = false);
              return;
            }
          }
          if (_cashVoucherPhotoBytes != null && mounted) {
            try {
              for (final transactionId in transactionIds) {
                final url = await _uploadCashVoucherPhoto(transactionId);
                if (url != null && mounted) {
                  await context
                      .read<TransactionsRepository>()
                      .updateTransactionMetadata(
                    transactionId,
                    {'cashVoucherPhotoUrl': url},
                  );
                }
              }
            } catch (e) {
              if (mounted) {
                DashSnackbar.show(
                  context,
                  message: 'Expense saved but voucher upload failed: $e',
                  isError: false,
                );
              }
            }
          }
          break;
        case ExpenseFormType.generalExpense:
          if (_selectedSubCategory == null) {
            DashSnackbar.show(context,
                message: 'Select a sub-category', isError: true);
            setState(() => _isSubmitting = false);
            return;
          }
          if (_descriptionController.text.trim().isEmpty) {
            DashSnackbar.show(context,
                message: 'Enter a description', isError: true);
            setState(() => _isSubmitting = false);
            return;
          }
          await cubit.createGeneralExpense(
            subCategoryId: _selectedSubCategory!.id,
            subCategoryName: _selectedSubCategory!.name,
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
        DashSnackbar.show(context,
            message: 'Expense created successfully', isError: false);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(context,
            message: 'Error creating expense: $e', isError: true);
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _openFuelLedgerPdfDialog() {
    if (_selectedVendor == null) return;
    final orgState = context.read<OrganizationContextCubit>().state;
    final organizationId = orgState.organization?.id;
    if (organizationId == null) {
      DashSnackbar.show(context,
          message: 'No organization selected', isError: true);
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

  Future<void> _pickCashVoucherPhoto() async {
    try {
      // getUserMedia is called from the main page so the browser prompts for camera permission
      final result = await showCashVoucherCameraDialog(context);
      if (result != null && mounted) {
        setState(() => _cashVoucherPhotoBytes = result);
      }
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(context,
            message: 'Failed to take photo: $e', isError: true);
      }
    }
  }

  Future<String?> _uploadCashVoucherPhoto(String transactionId) async {
    if (_cashVoucherPhotoBytes == null) return null;
    final orgState = context.read<OrganizationContextCubit>().state;
    final organizationId = orgState.organization?.id;
    if (organizationId == null) return null;
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('organizations')
          .child(organizationId)
          .child('expenses')
          .child(transactionId)
          .child('cash_voucher.jpg');
      await storageRef.putData(
        _cashVoucherPhotoBytes!,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return storageRef.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload voucher photo: $e');
    }
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
                        if (_selectedVendor != null &&
                            _selectedVendor!.vendorType == VendorType.fuel) ...[
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
                      ] else if (_selectedType ==
                          ExpenseFormType.salaryDebit) ...[
                        _buildSalarySelectors(),
                        const SizedBox(height: 16),
                        _buildCashVoucherSection(),
                      ] else if (_selectedType ==
                          ExpenseFormType.generalExpense) ...[
                        _buildSubCategorySelector(),
                      ],
                      const SizedBox(height: 24),
                      // Amount
                      DashFormField(
                        controller: _amountController,
                        label: 'Amount *',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: const TextStyle(color: AuthColors.textMain),
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
                                style:
                                    const TextStyle(color: AuthColors.textMain),
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
          _selectedLedgerAccount = null;
          _selectedSubCategory = null;
          if (type != ExpenseFormType.salaryDebit) {
            _cashVoucherPhotoBytes = null;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AuthColors.primaryWithOpacity(0.2)
              : AuthColors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AuthColors.primary : AuthColors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected ? AuthColors.primary : AuthColors.textSub,
                size: 20),
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

  Widget _buildCashVoucherSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cash Voucher',
          style: TextStyle(
            color: AuthColors.textSub,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DashButton(
          label: _cashVoucherPhotoBytes == null
              ? 'Open camera'
              : 'Take photo again',
          icon: Icons.camera_alt,
          onPressed: _pickCashVoucherPhoto,
          variant: DashButtonVariant.outlined,
        ),
        if (_cashVoucherPhotoBytes != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  _cashVoucherPhotoBytes!,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              DashButton(
                label: 'Remove',
                icon: Icons.delete_outline,
                onPressed: () => setState(() => _cashVoucherPhotoBytes = null),
                variant: DashButtonVariant.text,
              ),
            ],
          ),
        ],
      ],
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
                title: const Text('Pay Selected Invoices',
                    style: TextStyle(color: AuthColors.textSub, fontSize: 14)),
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
                title: const Text('Pay by Date Range',
                    style: TextStyle(color: AuthColors.textSub, fontSize: 14)),
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
                      initialDate: _invoiceDateRangeStart ??
                          DateTime.now().subtract(const Duration(days: 30)),
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
                      border: Border.all(
                          color: AuthColors.textMainWithOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            color: AuthColors.textSub, size: 18),
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
                      border: Border.all(
                          color: AuthColors.textMainWithOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            color: AuthColors.textSub, size: 18),
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
                  style: const TextStyle(color: AuthColors.textMain),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DashFormField(
                  controller: _toInvoiceNumberController,
                  label: 'To Invoice Number',
                  style: const TextStyle(color: AuthColors.textMain),
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
        else if (_invoiceSelectionMode == 'dateRange' &&
            (_invoiceDateRangeStart == null || _invoiceDateRangeEnd == null))
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
              _invoiceSelectionMode == 'manualSelection' &&
                      _fromInvoiceNumberController.text.trim().isEmpty &&
                      _toInvoiceNumberController.text.trim().isEmpty
                  ? 'Enter invoice number range and click Search'
                  : 'No unpaid invoices found',
              style: const TextStyle(color: AuthColors.textSub, fontSize: 14),
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
                  style: const TextStyle(
                    color: AuthColors.textSub,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ..._availableInvoices.take(5).map((invoice) {
                  final remainingAmount = _getInvoiceRemainingAmount(invoice);
                  final invoiceNumber = invoice.referenceNumber ??
                      invoice.metadata?['invoiceNumber'] ??
                      'N/A';
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
                                style: const TextStyle(
                                    color: AuthColors.textMain,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '${_formatDate(invoice.createdAt ?? DateTime.now())} | ₹${remainingAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: AuthColors.textSub, fontSize: 11),
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
                      style: const TextStyle(
                          color: AuthColors.textSub,
                          fontSize: 12,
                          fontStyle: FontStyle.italic),
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
                const Text(
                  'Total Amount:',
                  style: TextStyle(
                      color: AuthColors.textSub,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  '₹${_amountController.text.isEmpty ? "0.00" : _amountController.text}',
                  style: const TextStyle(
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
    return FormField<Vendor>(
      initialValue: _selectedVendor,
      validator: (value) => value == null ? 'Select a vendor' : null,
      builder: (fieldState) {
        final selected = fieldState.value;
        final showError = fieldState.errorText != null;
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
            InkWell(
              onTap: _vendors.isEmpty
                  ? null
                  : () async {
                      final selection = await _showSearchableSelectionDialog(
                        title: 'Select Vendor',
                        items: _vendors,
                        itemLabel: (vendor) => vendor.name,
                      );
                      if (selection == null) return;
                      setState(() {
                        _selectedVendor = selection;
                        _selectedInvoiceIds.clear();
                        _availableInvoices.clear();
                      });
                      fieldState.didChange(selection);
                      _loadUnpaidInvoices();
                    },
              child: InputDecorator(
                decoration: _inputDecoration('Select vendor').copyWith(
                  errorText: showError ? fieldState.errorText : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selected?.name ?? 'Select vendor',
                        style: TextStyle(
                          color: selected == null
                              ? AuthColors.textSub
                              : AuthColors.textMain,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down,
                        color: AuthColors.textSub),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSalarySelectors() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Salary Details',
          style: TextStyle(
            color: AuthColors.textSub,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DashButton(
                label: 'EMPLOYEE',
                icon: Icons.person_outline,
                onPressed: _openEmployeeSearchDialog,
                variant: DashButtonVariant.outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DashButton(
                label: 'ACCOUNT',
                icon: Icons.account_balance_wallet_outlined,
                onPressed:
                    _isLoadingLedgerAccounts ? null : _openAccountSearchDialog,
                variant: DashButtonVariant.outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _selectionSummaryRow(
          label: 'Employee',
          value: _selectedEmployee?.name ?? 'Not selected',
          icon: Icons.person,
          isSelected: _selectedEmployee != null,
        ),
        const SizedBox(height: 8),
        _selectionSummaryRow(
          label: 'Account',
          value: _selectedLedgerAccount?.name ?? 'Not selected',
          icon: _selectedLedgerAccount == null
              ? Icons.account_balance_wallet_outlined
              : _ledgerAccountIcon(_selectedLedgerAccount!.type),
          isSelected: _selectedLedgerAccount != null,
        ),
      ],
    );
  }

  Future<void> _openEmployeeSearchDialog() async {
    if (_employees.isEmpty) {
      DashSnackbar.show(context,
          message: 'No employees available', isError: true);
      return;
    }
    final selection =
        await _showSearchableSelectionDialog<OrganizationEmployee>(
      title: 'Select Employee',
      items: _employees,
      itemLabel: (employee) => employee.name,
    );
    if (selection != null && mounted) {
      setState(() => _selectedEmployee = selection);
    }
  }

  Future<void> _openAccountSearchDialog() async {
    if (_isLoadingLedgerAccounts) {
      DashSnackbar.show(context,
          message: 'Loading ledger accounts...', isError: false);
      return;
    }
    if (_ledgerAccounts.isEmpty) {
      DashSnackbar.show(context,
          message: 'No ledger accounts available', isError: true);
      return;
    }
    final selection =
        await _showSearchableSelectionDialog<_LedgerAccountOption>(
      title: 'Select Ledger Account',
      items: _ledgerAccounts,
      itemLabel: (account) => account.name,
      leadingBuilder: (account) => Icon(
        _ledgerAccountIcon(account.type),
        color: AuthColors.textSub,
        size: 18,
      ),
    );
    if (selection != null && mounted) {
      setState(() => _selectedLedgerAccount = selection);
    }
  }

  Widget _selectionSummaryRow({
    required String label,
    required String value,
    required IconData icon,
    required bool isSelected,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AuthColors.primaryWithOpacity(0.5)
              : AuthColors.textMainWithOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          Icon(icon,
              color: isSelected ? AuthColors.primary : AuthColors.textSub),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style:
                      const TextStyle(color: AuthColors.textSub, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: isSelected
                        ? AuthColors.textMain
                        : AuthColors.textDisabled,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_LedgerEmployeeRef> _extractEmployeesFromLedgerAccount(
    _LedgerAccountOption account,
  ) {
    final employees = <_LedgerEmployeeRef>[];
    for (final entry in account.accounts) {
      final typeRaw = (entry['type'] as String?) ?? '';
      final normalized = typeRaw.toLowerCase();
      if (normalized != 'employee' && normalized != 'employees') continue;
      final id = (entry['id'] as String?) ??
          (entry['accountId'] as String?) ??
          (entry['employeeId'] as String?) ??
          '';
      final name = (entry['name'] as String?) ??
          (entry['employeeName'] as String?) ??
          (entry['accountName'] as String?) ??
          '';
      if (id.isEmpty && name.isEmpty) continue;
      employees.add(
        _LedgerEmployeeRef(
          id: id.isNotEmpty ? id : name,
          name: name.isNotEmpty ? name : id,
        ),
      );
    }
    return employees;
  }

  Widget _buildSubCategorySelector() {
    final activeSubCategories =
        _subCategories.where((subCategory) => subCategory.isActive).toList();

    return FormField<ExpenseSubCategory>(
      initialValue: _selectedSubCategory,
      validator: (value) => value == null ? 'Select a sub-category' : null,
      builder: (fieldState) {
        final selected = fieldState.value;
        final showError = fieldState.errorText != null;
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
            InkWell(
              onTap: activeSubCategories.isEmpty
                  ? null
                  : () async {
                      final selection = await _showSearchableSelectionDialog(
                        title: 'Select Sub-Category',
                        items: activeSubCategories,
                        itemLabel: (subCategory) => subCategory.name,
                        leadingBuilder: (subCategory) =>
                            _buildColorDot(subCategory.colorHex, size: 12),
                      );
                      if (selection == null) return;
                      setState(() {
                        _selectedSubCategory = selection;
                      });
                      fieldState.didChange(selection);
                    },
              child: InputDecorator(
                decoration: _inputDecoration('Select sub-category').copyWith(
                  errorText: showError ? fieldState.errorText : null,
                ),
                child: Row(
                  children: [
                    if (selected != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildColorDot(selected.colorHex, size: 12),
                      ),
                    Expanded(
                      child: Text(
                        selected?.name ?? 'Select sub-category',
                        style: TextStyle(
                          color: selected == null
                              ? AuthColors.textSub
                              : AuthColors.textMain,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down,
                        color: AuthColors.textSub),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPaymentAccountSelector() {
    return FormField<PaymentAccount>(
      initialValue: _selectedPaymentAccount,
      validator: (value) => value == null ? 'Select a payment account' : null,
      builder: (fieldState) {
        final selected = fieldState.value;
        final showError = fieldState.errorText != null;
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
            if (_paymentAccounts.isEmpty)
              const Text(
                'No payment accounts available.',
                style: TextStyle(color: AuthColors.textSub, fontSize: 12),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _paymentAccounts.map((account) {
                  final isSelected = selected?.id == account.id;
                  return ChoiceChip(
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedPaymentAccount = account;
                      });
                      fieldState.didChange(account);
                    },
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _paymentAccountIcon(account.type),
                          size: 16,
                          color: isSelected
                              ? AuthColors.textMain
                              : AuthColors.textSub,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          account.name,
                          style: TextStyle(
                            color: isSelected
                                ? AuthColors.textMain
                                : AuthColors.textSub,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                        if (account.isPrimary) ...[
                          const SizedBox(width: 6),
                          Text(
                            'Primary',
                            style: TextStyle(
                              color: isSelected
                                  ? AuthColors.primary
                                  : AuthColors.textDisabled,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    selectedColor: AuthColors.primaryWithOpacity(0.18),
                    backgroundColor: AuthColors.surface,
                    side: BorderSide(
                      color: isSelected
                          ? AuthColors.primary
                          : AuthColors.textMainWithOpacity(0.1),
                    ),
                  );
                }).toList(),
              ),
            if (showError)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  fieldState.errorText ?? '',
                  style: const TextStyle(
                    color: AuthColors.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  IconData _paymentAccountIcon(PaymentAccountType type) {
    switch (type) {
      case PaymentAccountType.bank:
        return Icons.account_balance;
      case PaymentAccountType.cash:
        return Icons.money;
      case PaymentAccountType.upi:
        return Icons.qr_code;
      case PaymentAccountType.other:
        return Icons.payment;
    }
  }

  IconData _ledgerAccountIcon(_LedgerAccountType type) {
    switch (type) {
      case _LedgerAccountType.client:
        return Icons.person_outline;
      case _LedgerAccountType.vendor:
        return Icons.storefront;
      case _LedgerAccountType.employee:
        return Icons.badge_outlined;
      case _LedgerAccountType.combined:
        return Icons.account_balance_wallet_outlined;
    }
  }

  Widget _buildColorDot(String colorHex, {double size = 10}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AuthColors.primary,
        shape: BoxShape.circle,
      ),
    );
  }

  Future<T?> _showSearchableSelectionDialog<T>({
    required String title,
    required List<T> items,
    required String Function(T item) itemLabel,
    Widget Function(T item)? leadingBuilder,
  }) {
    return showDialog<T>(
      context: context,
      barrierColor: AuthColors.background.withValues(alpha: 0.7),
      builder: (dialogContext) {
        final searchController = TextEditingController();
        List<T> filteredItems = List<T>.from(items);

        void applyFilter(
            String query, void Function(void Function()) setState) {
          final normalized = query.trim().toLowerCase();
          setState(() {
            if (normalized.isEmpty) {
              filteredItems = List<T>.from(items);
            } else {
              filteredItems = items
                  .where((item) =>
                      itemLabel(item).toLowerCase().contains(normalized))
                  .toList();
            }
          });
        }

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: AuthColors.transparent,
              insetPadding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 520,
                  maxHeight: 560,
                ),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AuthColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: AuthColors.textMainWithOpacity(0.1)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: AuthColors.textMain,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close,
                              color: AuthColors.textSub),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchController,
                      onChanged: (value) => applyFilter(value, setState),
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: const Icon(Icons.search,
                            color: AuthColors.textSub, size: 18),
                        filled: true,
                        fillColor: AuthColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(color: AuthColors.textMain),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filteredItems.isEmpty
                          ? const Center(
                              child: Text(
                                'No results found',
                                style: TextStyle(
                                  color: AuthColors.textSub,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filteredItems.length,
                              separatorBuilder: (_, __) => Divider(
                                color: AuthColors.textMainWithOpacity(0.08),
                                height: 1,
                              ),
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                return ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  leading: leadingBuilder?.call(item),
                                  title: Text(
                                    itemLabel(item),
                                    style: const TextStyle(
                                      color: AuthColors.textMain,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  onTap: () =>
                                      Navigator.of(dialogContext).pop(item),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AuthColors.surface,
      labelStyle: const TextStyle(color: AuthColors.textSub),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}

class _LedgerAccountOption {
  const _LedgerAccountOption({
    required this.id,
    required this.name,
    required this.type,
    this.accounts = const [],
  });

  final String id;
  final String name;
  final _LedgerAccountType type;
  final List<Map<String, dynamic>> accounts;

  String get key => '${type.name}:$id';

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'id': id,
        'name': name,
        if (accounts.isNotEmpty) 'accounts': accounts,
      };
}

class _LedgerEmployeeRef {
  const _LedgerEmployeeRef({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

enum _LedgerAccountType {
  client,
  vendor,
  employee,
  combined;

  // No extra helpers needed here.
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
