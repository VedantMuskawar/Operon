import 'dart:async';
import 'dart:io';
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
  Timer? _invoiceSearchDebounce;

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
    _invoiceSearchDebounce?.cancel();
    _amountController.dispose();
    _descriptionController.dispose();
    _referenceNumberController.dispose();
    _fromInvoiceNumberController.dispose();
    _toInvoiceNumberController.dispose();
    super.dispose();
  }

  void _scheduleInvoiceSearch() {
    _invoiceSearchDebounce?.cancel();
    _invoiceSearchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        _loadUnpaidInvoices();
      }
    });
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
      final paymentAccountsDataSource =
          context.read<PaymentAccountsDataSource>();

      _vendors = await vendorsRepo.fetchVendors(organizationId);
      _employees = await employeesRepo.fetchEmployees(organizationId);
      _subCategories =
          await subCategoriesRepo.fetchSubCategories(organizationId);
      _paymentAccounts =
          await paymentAccountsDataSource.fetchAccounts(organizationId);

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
          if (_selectedEmployees.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Select at least one employee')),
            );
            setState(() => _isSubmitting = false);
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
                              _buildEmployeeSelector(),
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
          _selectedEmployees = [];
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
                child: Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Pay Selected Invoices',
                            style:
                                TextStyle(color: AuthColors.textSub, fontSize: 14)),
                        value: 'manualSelection',
                        activeColor: AuthColors.primary,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Pay by Date Range',
                            style:
                                TextStyle(color: AuthColors.textSub, fontSize: 14)),
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
                  onChanged: (_) {
                    _scheduleInvoiceSearch();
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.paddingMD),
              Expanded(
                child: TextFormField(
                  controller: _toInvoiceNumberController,
                  style: const TextStyle(color: AuthColors.textMain),
                  decoration: _inputDecoration('To Invoice Number'),
                  onChanged: (_) {
                    _scheduleInvoiceSearch();
                  },
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
          dropdownColor: AuthColors.surface,
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
        searchFillColor: AuthColors.background,
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
                color: AuthColors.surface,
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
                    backgroundColor: AuthColors.background,
                    labelStyle: const TextStyle(color: AuthColors.textMain),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
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
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                child: Image.file(
                  _cashVoucherPhoto!,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
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
        DropdownButtonFormField<ExpenseSubCategory>(
          initialValue: _selectedSubCategory,
          dropdownColor: AuthColors.surface,
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
                      color: AuthColors.primary,
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _paymentAccounts.map((account) {
            return _buildPaymentAccountOption(account);
          }).toList(),
        ),
        if (_selectedPaymentAccount == null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.paddingSM),
            child: Text(
              'Select a payment account',
              style: TextStyle(
                  color: AuthColors.error.withValues(alpha: 0.8), fontSize: 12),
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
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.paddingMD, vertical: AppSpacing.paddingMD),
        decoration: BoxDecoration(
          color: isSelected
              ? AuthColors.primaryWithOpacity(0.2)
              : AuthColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          border: Border.all(
            color: isSelected
                ? AuthColors.primary
                : AuthColors.textMain.withValues(alpha: 0.1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isSelected ? AuthColors.primary : AuthColors.textSub,
                size: 18),
            const SizedBox(width: AppSpacing.paddingSM),
            Text(
              account.name,
              style: TextStyle(
                color: isSelected ? AuthColors.textMain : AuthColors.textSub,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (account.isPrimary) ...[
              const SizedBox(width: AppSpacing.paddingXS),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.paddingXS,
                    vertical: AppSpacing.paddingXS),
                decoration: BoxDecoration(
                  color: AuthColors.primaryWithOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
                ),
                child: const Text(
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

extension FirstWhereOrNull<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    try {
      return firstWhere(test);
    } catch (e) {
      return null;
    }
  }
}
