import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:dash_mobile/data/datasources/payment_accounts_data_source.dart';
import 'package:dash_mobile/data/repositories/employees_repository.dart';
import 'package:dash_mobile/data/utils/financial_year_utils.dart';
import 'package:dash_mobile/domain/entities/payment_account.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/data/services/storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:dash_mobile/presentation/widgets/fuel_ledger_pdf_dialog.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:dash_mobile/data/repositories/dm_settings_repository.dart';
import 'package:dash_mobile/data/services/dm_print_service.dart';

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

  /// Cash voucher photo for salary expense (optional).
  File? _cashVoucherPhoto;
  static final ImagePicker _imagePicker = ImagePicker();

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
        final paymentAccountsDataSource = PaymentAccountsDataSource();

      _vendors = await vendorsRepo.fetchVendors(organizationId);
      _employees = await employeesRepo.fetchEmployees(organizationId);
      _subCategories =
          await subCategoriesRepo.fetchSubCategories(organizationId);
      _paymentAccounts =
          await paymentAccountsDataSource.fetchAccounts(organizationId);

        await _loadLedgerAccounts(organizationId);

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
        _selectedEmployee = employee;
      }
      // Set default payment account
      _selectedPaymentAccount =
          _paymentAccounts.firstWhereOrNull((pa) => pa.isPrimary) ??
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

  Future<void> _loadLedgerAccounts(String organizationId) async {
    setState(() => _isLoadingLedgerAccounts = true);
    try {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load ledger accounts: $e')),
        );
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
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AuthColors.primary,
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

  Future<void> _loadUnpaidInvoices() async {
    if (_selectedVendor == null) return;

    setState(() => _isLoadingInvoices = true);
    try {
      final orgState = context.read<OrganizationContextCubit>().state;
      final organizationId = orgState.organization?.id;
      if (organizationId == null) return;

      final transactionsDataSource = context.read<TransactionsDataSource>();
      List<Transaction> invoices;
      if (_invoiceSelectionMode == 'dateRange') {
        invoices = await transactionsDataSource.fetchUnpaidVendorInvoices(
          organizationId: organizationId,
          vendorId: _selectedVendor!.id,
          startDate: _invoiceDateRangeStart,
          endDate: _invoiceDateRangeEnd,
          verifiedOnly: true,
        );
      } else {
        // Manual selection: fetch all unpaid, then filter by voucher range
        invoices = await transactionsDataSource.fetchUnpaidVendorInvoices(
          organizationId: organizationId,
          vendorId: _selectedVendor!.id,
          verifiedOnly: true,
        );
      }

      // Filter by invoice/voucher number range when in manual selection and range is specified
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
            final fromUpper = fromNumber.toUpperCase();
            final toUpper = toNumber.toUpperCase();
            final invUpper = invoiceNumber.toUpperCase();
            bool matches = true;
            if (fromNumber.isNotEmpty) {
              matches = matches && invUpper.compareTo(fromUpper) >= 0;
            }
            if (toNumber.isNotEmpty) {
              matches = matches && invUpper.compareTo(toUpper) <= 0;
            }
            return matches;
          }).toList();
        }
      }

      setState(() {
        _availableInvoices = invoices;
        if (_invoiceSelectionMode == 'dateRange') {
          _selectedInvoiceIds = invoices.map((inv) => inv.id).toSet();
        } else if (_invoiceSelectionMode == 'manualSelection') {
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
      Transaction? transaction;
      final salaryTransactionIds = <String>[];

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
            if (_invoiceDateRangeStart != null &&
                _invoiceDateRangeEnd != null) {
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
            metadata: metadata,
          );
          break;
        case ExpenseFormType.salaryDebit:
          if (_selectedEmployee == null && _selectedLedgerAccount == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Select an employee or an account')),
            );
            setState(() => _isSubmitting = false);
            return;
          }

          final splitGroupId = 'split_${DateTime.now().microsecondsSinceEpoch}';

          if (_selectedEmployee != null) {
            final metadata = <String, dynamic>{
              'employeeName': _selectedEmployee!.name,
              if (_selectedLedgerAccount != null)
                'ledgerAccount': _selectedLedgerAccount!.toJson(),
              'splitIndex': 1,
              'splitCount': 1,
            };

            transaction = Transaction(
              id: '',
              organizationId: organizationId,
              employeeId: _selectedEmployee!.id,
              employeeName: _selectedEmployee!.name,
              splitGroupId: splitGroupId,
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
              metadata: metadata,
            );
            final transactionId =
                await transactionsDataSource.createTransaction(transaction);
            salaryTransactionIds.add(transactionId);
            break;
          }

          final accountEmployees = _extractEmployeesFromLedgerAccount(
            _selectedLedgerAccount!,
          );
          if (accountEmployees.length < 2) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Selected account must include at least 2 employees')),
            );
            setState(() => _isSubmitting = false);
            return;
          }

          final selectedTwo = accountEmployees.take(2).toList();
          final splitAmounts =
              _computeSplitAmounts(amount, selectedTwo.length);

          for (var i = 0; i < selectedTwo.length; i++) {
            final employee = selectedTwo[i];
            final metadata = <String, dynamic>{
              'employeeName': employee.name,
              'ledgerAccount': _selectedLedgerAccount!.toJson(),
              'splitIndex': i + 1,
              'splitCount': selectedTwo.length,
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
            final transactionId =
                await transactionsDataSource.createTransaction(transaction);
            salaryTransactionIds.add(transactionId);
          }
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

      if (_selectedType != ExpenseFormType.salaryDebit) {
        if (transaction == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Expense data is incomplete.')),
            );
          }
          setState(() => _isSubmitting = false);
          return;
        }
        await transactionsDataSource.createTransaction(transaction);
      }

      // Upload cash voucher photo for salary expense if provided
      if (_selectedType == ExpenseFormType.salaryDebit &&
          _cashVoucherPhoto != null &&
          mounted) {
        try {
          final storageService = StorageService();
          for (final transactionId in salaryTransactionIds) {
            final downloadUrl = await storageService.uploadExpenseVoucher(
              imageFile: _cashVoucherPhoto!,
              organizationId: organizationId,
              transactionId: transactionId,
            );
            if (!mounted) {
              return;
            }
            await context
                .read<TransactionsRepository>()
                .updateTransactionMetadata(
              transactionId,
              {'cashVoucherPhotoUrl': downloadUrl},
            );
          }
        } catch (uploadError) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Expense saved but voucher upload failed: $uploadError',
                ),
                backgroundColor: AuthColors.warning,
              ),
            );
          }
        }
      }

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

  void _openFuelLedgerPdfDialog() {
    if (_selectedVendor == null) return;
    final orgState = context.read<OrganizationContextCubit>().state;
    final organizationId = orgState.organization?.id;
    if (organizationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No organization selected')),
      );
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
    return Scaffold(
      backgroundColor: AuthColors.background,
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
                      padding: const EdgeInsets.all(AppSpacing.paddingLG),
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
                            const SizedBox(height: AppSpacing.paddingXXL),
                            // Dynamic fields based on type
                            if (_selectedType ==
                                ExpenseFormType.vendorPayment) ...[
                              _buildVendorSelector(),
                              if (_selectedVendor != null &&
                                  _selectedVendor!.vendorType ==
                                      VendorType.fuel) ...[
                                const SizedBox(height: AppSpacing.paddingLG),
                                FilledButton.icon(
                                  onPressed: () => _openFuelLedgerPdfDialog(),
                                  icon: const Icon(Icons.picture_as_pdf,
                                      size: 20),
                                  label: const Text('Fuel Ledger PDF'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AuthColors.transparent,
                                    foregroundColor: AuthColors.primary,
                                    shadowColor: AuthColors.transparent,
                                    side: const BorderSide(
                                        color: AuthColors.primary),
                                  ),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.paddingXXL),
                              _buildInvoiceSelectionSection(),
                            ] else if (_selectedType ==
                                ExpenseFormType.salaryDebit) ...[
                              _buildSalarySelectors(),
                              const SizedBox(height: AppSpacing.paddingLG),
                              _buildCashVoucherSection(),
                            ] else if (_selectedType ==
                                ExpenseFormType.generalExpense) ...[
                              _buildSubCategorySelector(),
                            ],
                            const SizedBox(height: AppSpacing.paddingXXL),
                            // Amount
                            TextFormField(
                              controller: _amountController,
                              style:
                                  const TextStyle(color: AuthColors.textMain),
                              decoration: _inputDecoration('Amount *'),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
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
                            const SizedBox(height: AppSpacing.paddingXXL),
                            // Payment Account
                            _buildPaymentAccountSelector(),
                            const SizedBox(height: AppSpacing.paddingXXL),
                            // Date
                            InkWell(
                              onTap: _selectDate,
                              child: Container(
                                padding:
                                    const EdgeInsets.all(AppSpacing.paddingLG),
                                decoration: BoxDecoration(
                                  color: AuthColors.surface,
                                  borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusMD),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today,
                                        color: AuthColors.textSub, size: 20),
                                    const SizedBox(width: AppSpacing.paddingMD),
                                    Text(
                                      _formatDate(_selectedDate),
                                      style: const TextStyle(
                                          color: AuthColors.textMain),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.paddingXXL),
                            // Description
                            TextFormField(
                              controller: _descriptionController,
                              style:
                                  const TextStyle(color: AuthColors.textMain),
                              decoration: _inputDecoration(
                                _selectedType == ExpenseFormType.generalExpense
                                    ? 'Description *'
                                    : 'Description',
                              ),
                              maxLines: 3,
                              validator: (value) {
                                if (_selectedType ==
                                        ExpenseFormType.generalExpense &&
                                    (value == null || value.trim().isEmpty)) {
                                  return 'Enter description';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.paddingXXL),
                            // Reference Number
                            TextFormField(
                              controller: _referenceNumberController,
                              style:
                                  const TextStyle(color: AuthColors.textMain),
                              decoration: _inputDecoration('Reference Number'),
                            ),
                            const SizedBox(height: AppSpacing.paddingXXXL),
                            // Save Button
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _isSubmitting ? null : _save,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AuthColors.primary,
                                  foregroundColor: AuthColors.textMain,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: AppSpacing.paddingLG),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppSpacing.radiusMD),
                                  ),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  AuthColors.textMain),
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
            FloatingNavBar(
              items: const [
                NavBarItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  heroTag: 'nav_home',
                ),
                NavBarItem(
                  icon: Icons.pending_actions_rounded,
                  label: 'Pending',
                  heroTag: 'nav_pending',
                ),
                NavBarItem(
                  icon: Icons.schedule_rounded,
                  label: 'Schedule',
                  heroTag: 'nav_schedule',
                ),
                NavBarItem(
                  icon: Icons.map_rounded,
                  label: 'Map',
                  heroTag: 'nav_map',
                ),
                NavBarItem(
                  icon: Icons.event_available_rounded,
                  label: 'Cash Ledger',
                  heroTag: 'nav_cash_ledger',
                ),
              ],
              currentIndex: 0,
              onItemTapped: (value) => context.go('/home', extra: value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AuthColors.surface,
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
          _selectedEmployee = null;
          _selectedLedgerAccount = null;
          _selectedSubCategory = null;
          if (type != ExpenseFormType.salaryDebit) _cashVoucherPhoto = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingMD),
        decoration: BoxDecoration(
          color: isSelected
              ? AuthColors.primaryWithOpacity(0.2)
              : AuthColors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
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
            const SizedBox(height: AppSpacing.paddingXS),
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
        const SizedBox(height: AppSpacing.paddingSM),
        // Mode toggle
        Row(
          children: [
            Expanded(
              child: RadioGroup<String>(
                groupValue: _invoiceSelectionMode,
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _invoiceSelectionMode = value;
                    _selectedInvoiceIds.clear();
                    if (value == 'manualSelection') {
                      _invoiceDateRangeStart = null;
                      _invoiceDateRangeEnd = null;
                      _fromInvoiceNumberController.clear();
                      _toInvoiceNumberController.clear();
                      _availableInvoices.clear();
                    }
                  });
                  if (value == 'dateRange') {
                    _loadUnpaidInvoices();
                  }
                },
                child: const Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text('Pay Selected Invoices',
                            style: TextStyle(
                                color: AuthColors.textSub, fontSize: 14)),
                        value: 'manualSelection',
                        activeColor: AuthColors.primary,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text('Pay by Date Range',
                            style: TextStyle(
                                color: AuthColors.textSub, fontSize: 14)),
                        value: 'dateRange',
                        activeColor: AuthColors.primary,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
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
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: AuthColors.primary,
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
                        _invoiceDateRangeStart = picked;
                      });
                      _loadUnpaidInvoices();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.paddingMD),
                    decoration: BoxDecoration(
                      color: AuthColors.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                      border: Border.all(
                          color: AuthColors.textMain.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            color: AuthColors.textSub, size: 18),
                        const SizedBox(width: AppSpacing.paddingSM),
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
              const SizedBox(width: AppSpacing.paddingMD),
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
                              primary: AuthColors.primary,
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
                        _invoiceDateRangeEnd = picked;
                      });
                      _loadUnpaidInvoices();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.paddingMD),
                    decoration: BoxDecoration(
                      color: AuthColors.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                      border: Border.all(
                          color: AuthColors.textMain.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            color: AuthColors.textSub, size: 18),
                        const SizedBox(width: AppSpacing.paddingSM),
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
                child: TextFormField(
                  controller: _fromInvoiceNumberController,
                  style: const TextStyle(color: AuthColors.textMain),
                  decoration: _inputDecoration('From Invoice Number'),
                ),
              ),
              const SizedBox(width: AppSpacing.paddingMD),
              Expanded(
                child: TextFormField(
                  controller: _toInvoiceNumberController,
                  style: const TextStyle(color: AuthColors.textMain),
                  decoration: _inputDecoration('To Invoice Number'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.paddingMD),
          TextButton.icon(
            onPressed: _loadUnpaidInvoices,
            icon: const Icon(Icons.search, size: 18, color: AuthColors.primary),
            label: const Text('Search Invoices',
                style: TextStyle(color: AuthColors.primary)),
          ),
          const SizedBox(height: 16),
        ],
        // Invoice list / summary
        if (_isLoadingInvoices)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.paddingLG),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_invoiceSelectionMode == 'dateRange' &&
            (_invoiceDateRangeStart == null || _invoiceDateRangeEnd == null))
          const Padding(
            padding: EdgeInsets.all(AppSpacing.paddingLG),
            child: Text(
              'Select date range to view invoices',
              style: TextStyle(color: AuthColors.textSub, fontSize: 14),
            ),
          )
        else if (_availableInvoices.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.paddingLG),
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
            padding: const EdgeInsets.all(AppSpacing.paddingLG),
            decoration: BoxDecoration(
              color: AuthColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              border: Border.all(
                color: AuthColors.textMain.withValues(alpha: 0.1),
              ),
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
                const SizedBox(height: AppSpacing.paddingMD),
                ..._availableInvoices.take(5).map((invoice) {
                  final remainingAmount = _getInvoiceRemainingAmount(invoice);
                  final invoiceNumber = invoice.referenceNumber ??
                      invoice.metadata?['invoiceNumber'] ??
                      'N/A';
                  return Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppSpacing.paddingSM),
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
                    padding: const EdgeInsets.only(top: AppSpacing.paddingSM),
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
          const SizedBox(height: AppSpacing.paddingMD),
          Container(
            padding: const EdgeInsets.all(AppSpacing.paddingMD),
            decoration: BoxDecoration(
              color: AuthColors.primaryWithOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
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
            const SizedBox(height: AppSpacing.paddingSM),
            InkWell(
              onTap: _vendors.isEmpty
                  ? null
                  : () async {
                      final selection =
                          await _showSearchableSelectionDialog<Vendor>(
                        title: 'Select Vendor',
                        items: _vendors,
                        itemLabel: (vendor) => vendor.name,
                      );
                      if (selection == null) return;
                      setState(() {
                        _selectedVendor = selection;
                        _selectedInvoiceIds.clear();
                        _availableInvoices.clear();
                        _fromInvoiceNumberController.clear();
                        _toInvoiceNumberController.clear();
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
        const SizedBox(height: AppSpacing.paddingSM),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _openEmployeeSearchDialog,
                icon: const Icon(Icons.person_outline, size: 18),
                label: const Text('EMPLOYEE'),
                style: FilledButton.styleFrom(
                  backgroundColor: AuthColors.transparent,
                  foregroundColor: AuthColors.primary,
                  shadowColor: AuthColors.transparent,
                  side: const BorderSide(color: AuthColors.primary),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.paddingMD),
            Expanded(
              child: FilledButton.icon(
                onPressed:
                    _isLoadingLedgerAccounts ? null : _openAccountSearchDialog,
                icon: const Icon(Icons.account_balance_wallet_outlined,
                    size: 18),
                label: const Text('ACCOUNT'),
                style: FilledButton.styleFrom(
                  backgroundColor: AuthColors.transparent,
                  foregroundColor: AuthColors.primary,
                  shadowColor: AuthColors.transparent,
                  side: const BorderSide(color: AuthColors.primary),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.paddingMD),
        _selectionSummaryRow(
          label: 'Employee',
          value: _selectedEmployee?.name ?? 'Not selected',
          icon: Icons.person,
          isSelected: _selectedEmployee != null,
        ),
        const SizedBox(height: AppSpacing.paddingSM),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No employees available')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading ledger accounts...')),
      );
      return;
    }

    if (_ledgerAccounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No ledger accounts available')),
      );
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.paddingMD,
        vertical: AppSpacing.paddingMD,
      ),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
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
          const SizedBox(width: AppSpacing.paddingSM),
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

  Future<void> _pickCashVoucherPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AuthColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: AuthColors.textMain),
              title: const Text('Choose from Gallery',
                  style: TextStyle(color: AuthColors.textMain)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AuthColors.textMain),
              title: const Text('Take Photo',
                  style: TextStyle(color: AuthColors.textMain)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (picked != null && mounted) {
        setState(() => _cashVoucherPhoto = File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
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
        const SizedBox(height: AppSpacing.paddingSM),
        FilledButton.icon(
          onPressed: _pickCashVoucherPhoto,
          icon: const Icon(Icons.camera_alt, size: 20),
          label:
              Text(_cashVoucherPhoto == null ? 'Take photo' : 'Change photo'),
          style: FilledButton.styleFrom(
            backgroundColor: AuthColors.transparent,
            foregroundColor: AuthColors.primary,
            shadowColor: AuthColors.transparent,
            side: const BorderSide(color: AuthColors.primary),
          ),
        ),
        if (_cashVoucherPhoto != null) ...[
          const SizedBox(height: AppSpacing.paddingMD),
          Row(
            children: [
              RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                  child: Image.file(
                    _cashVoucherPhoto!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.paddingMD),
              TextButton.icon(
                onPressed: () => setState(() => _cashVoucherPhoto = null),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Remove'),
                style: TextButton.styleFrom(foregroundColor: AuthColors.error),
              ),
            ],
          ),
        ],
      ],
    );
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
            const SizedBox(height: AppSpacing.paddingSM),
            InkWell(
              onTap: activeSubCategories.isEmpty
                  ? null
                  : () async {
                      final selection =
                          await _showSearchableSelectionDialog<
                              ExpenseSubCategory>(
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
                        padding:
                            const EdgeInsets.only(right: AppSpacing.paddingSM),
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
            const SizedBox(height: AppSpacing.paddingSM),
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
                padding: const EdgeInsets.only(top: AppSpacing.paddingSM),
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AuthColors.surface,
      labelStyle: const TextStyle(color: AuthColors.textSub),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        borderSide: BorderSide.none,
      ),
    );
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

        void applyFilter(String query, void Function(void Function()) setState) {
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
              insetPadding: const EdgeInsets.all(AppSpacing.paddingLG),
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 520,
                  maxHeight: 560,
                ),
                padding: const EdgeInsets.all(AppSpacing.paddingLG),
                decoration: BoxDecoration(
                  color: AuthColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                  border: Border.all(
                      color: AuthColors.textMainWithOpacity(0.1)),
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
                    const SizedBox(height: AppSpacing.paddingSM),
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
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMD),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(color: AuthColors.textMain),
                    ),
                    const SizedBox(height: AppSpacing.paddingSM),
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
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.paddingSM),
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
  combined,
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
