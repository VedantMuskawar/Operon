import 'dart:async';

import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/components/data_table.dart' as custom_table;
import 'package:core_ui/core_ui.dart' show AnimatedFade, AuthColors, DashButton, DashButtonVariant, DashCard, DashSnackbar, SkeletonLoader;
import 'package:dash_web/presentation/blocs/employee_wages/employee_wages_cubit.dart';
import 'package:dash_web/presentation/blocs/employee_wages/employee_wages_state.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:dash_web/presentation/widgets/salary_voucher_modal.dart';
import 'package:dash_web/presentation/views/employee_wages/credit_salary_dialog.dart';
import 'package:dash_web/presentation/views/employee_wages/record_bonus_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;

class EmployeeWagesPage extends StatefulWidget {
  const EmployeeWagesPage({super.key});

  @override
  State<EmployeeWagesPage> createState() => _EmployeeWagesPageState();
}

enum _WagesSortOption {
  dateNewest,
  dateOldest,
  amountHigh,
  amountLow,
  employeeAsc,
}

class _EmployeeWagesPageState extends State<EmployeeWagesPage> {
  final Map<String, String> _employeeNames = {};
  String _query = '';
  _WagesSortOption _sortOption = _WagesSortOption.dateNewest;

  // Date range: default today–today
  late DateTime _startDate;
  late DateTime _endDate;

  // Pagination state (only when > 50 rows; 50 per page)
  int _currentPage = 0;
  static const int _itemsPerPage = 50;

  String? _currentOrgId;
  List<Transaction> _previousTransactions = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    
    if (organization != null && _currentOrgId != organization.id) {
      _currentOrgId = organization.id;
      _previousTransactions = [];
      _employeeNames.clear();
      _refreshTransactions();
    }
  }

  void _refreshTransactions() {
    final orgState = context.read<OrganizationContextCubit>().state;
    context.read<EmployeeWagesCubit>().watchTransactions(
          financialYear: orgState.financialYear,
          startDate: _startDate,
          endDate: _endDate,
        );
  }

  Future<void> _fetchEmployeeNames(List<Transaction> transactions) async {
    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    if (organization == null) return;

    try {
      final newEmployeeNames = <String, String>{};

      // Use denormalized employeeName when available
      for (final tx in transactions) {
        final employeeId = tx.employeeId;
        final employeeName = tx.employeeName;
        if (employeeId != null && employeeName != null && employeeName.isNotEmpty) {
          if (!_employeeNames.containsKey(employeeId)) {
            newEmployeeNames[employeeId] = employeeName;
          }
        }
      }

      // Get employee IDs that we don't have names for yet
      final missingIds = transactions
          .where((tx) => tx.employeeId != null &&
              !_employeeNames.containsKey(tx.employeeId) &&
              !newEmployeeNames.containsKey(tx.employeeId))
          .map((tx) => tx.employeeId!)
          .toSet()
          .toList();

      if (missingIds.isEmpty) {
        if (mounted && newEmployeeNames.isNotEmpty) {
          setState(() {
            _employeeNames.addAll(newEmployeeNames);
          });
        }
        return;
      }

      // Batch query employee names using whereIn on document IDs
      const chunkSize = 10;
      final queries = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
      for (var i = 0; i < missingIds.length; i += chunkSize) {
        final chunk = missingIds.sublist(
          i,
          (i + chunkSize).clamp(0, missingIds.length),
        );
        queries.add(
          FirebaseFirestore.instance
              .collection('EMPLOYEES')
              .where(FieldPath.documentId, whereIn: chunk)
              .get(),
        );
      }

      final snapshots = await Future.wait(queries);
      for (final snapshot in snapshots) {
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final name = data['employeeName'] as String? ?? 'Unknown Employee';
          newEmployeeNames[doc.id] = name;
        }
      }

      if (mounted && newEmployeeNames.isNotEmpty) {
        setState(() {
          _employeeNames.addAll(newEmployeeNames);
        });
      }
    } catch (e) {
      // Silently fail - employee names are not critical
      debugPrint('[EmployeeWagesPage] Error fetching employee names: $e');
    }
  }

  bool _areTransactionListsEqual(List<Transaction> a, List<Transaction> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  List<Transaction> _applyFiltersAndSort(List<Transaction> transactions) {
    var filtered = List<Transaction>.from(transactions);

    // Apply date range filter
    final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final end = DateTime(_endDate.year, _endDate.month, _endDate.day).add(const Duration(days: 1));
    filtered = filtered.where((tx) {
      final txDate = tx.createdAt ?? DateTime(1970);
      return !txDate.isBefore(start) && txDate.isBefore(end);
    }).toList();

    // Apply search filter
    if (_query.isNotEmpty) {
      final queryLower = _query.toLowerCase();
      filtered = filtered.where((tx) {
        final employeeName =
            (tx.employeeName ?? _employeeNames[tx.employeeId ?? ''] ?? '').toLowerCase();
        final description = (tx.description ?? '').toLowerCase();
        final category = tx.category.name.toLowerCase();
        return employeeName.contains(queryLower) ||
            description.contains(queryLower) ||
            category.contains(queryLower);
      }).toList();
    }

    // Apply sorting
    final sortedList = List<Transaction>.from(filtered);
    switch (_sortOption) {
      case _WagesSortOption.dateNewest:
        sortedList.sort((a, b) {
          final aDate = a.createdAt ?? DateTime(1970);
          final bDate = b.createdAt ?? DateTime(1970);
          return bDate.compareTo(aDate);
        });
        break;
      case _WagesSortOption.dateOldest:
        sortedList.sort((a, b) {
          final aDate = a.createdAt ?? DateTime(1970);
          final bDate = b.createdAt ?? DateTime(1970);
          return aDate.compareTo(bDate);
        });
        break;
      case _WagesSortOption.amountHigh:
        sortedList.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case _WagesSortOption.amountLow:
        sortedList.sort((a, b) => a.amount.compareTo(b.amount));
        break;
      case _WagesSortOption.employeeAsc:
        sortedList.sort((a, b) {
          final aName =
              (a.employeeName ?? _employeeNames[a.employeeId ?? ''] ?? '').toLowerCase();
          final bName =
              (b.employeeName ?? _employeeNames[b.employeeId ?? ''] ?? '').toLowerCase();
          return aName.compareTo(bName);
        });
        break;
    }

    return sortedList;
  }

  List<Transaction> _getPaginatedData(List<Transaction> allData) {
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, allData.length);
    if (startIndex >= allData.length) {
      return [];
    }
    return allData.sublist(startIndex, endIndex);
  }

  int _getTotalPages(int totalItems) {
    if (totalItems == 0) return 1;
    return ((totalItems - 1) ~/ _itemsPerPage) + 1;
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    return '$day $month $year';
  }

  Future<void> _deleteTransaction(String transactionId) async {
    try {
      await context.read<EmployeeWagesCubit>().deleteTransaction(transactionId);
      
      if (mounted) {
        DashSnackbar.show(
          context,
          message: 'Transaction deleted successfully',
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(
          context,
          message: 'Failed to delete transaction: $e',
          isError: true,
        );
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, Transaction transaction) {
    final employeeName =
        transaction.employeeName ?? _employeeNames[transaction.employeeId ?? ''] ?? 'Unknown Employee';
    final categoryName = transaction.category == TransactionCategory.salaryCredit
        ? 'Salary'
        : transaction.category == TransactionCategory.bonus
            ? 'Bonus'
            : transaction.category.name;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AuthColors.surface,
        title: const Text(
          'Delete Transaction',
          style: TextStyle(color: AuthColors.textMain),
        ),
        content: Text(
          'Are you sure you want to delete this transaction?\n\n'
          'Employee: $employeeName\n'
          'Type: $categoryName\n'
          'Amount: ${_formatCurrency(transaction.amount)}',
          style: const TextStyle(color: AuthColors.textSub),
        ),
        actions: [
          DashButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(dialogContext).pop(),
            variant: DashButtonVariant.text,
          ),
          DashButton(
            label: 'Delete',
            onPressed: () {
              _deleteTransaction(transaction.id);
              Navigator.of(dialogContext).pop();
            },
            variant: DashButtonVariant.text,
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: _endDate,
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = DateTime(picked.year, picked.month, picked.day);
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
        _currentPage = 0;
      });
      _refreshTransactions();
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() {
        _endDate = DateTime(picked.year, picked.month, picked.day);
        if (_startDate.isAfter(_endDate)) _startDate = _endDate;
        _currentPage = 0;
      });
      _refreshTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionWorkspaceLayout(
      panelTitle: 'Employee Wages',
      currentIndex: -1,
      onNavTap: (index) => context.go('/home?section=$index'),
      child: BlocBuilder<EmployeeWagesCubit, EmployeeWagesState>(
        builder: (context, state) {
          if (state.status == ViewStatus.loading && state.transactions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SkeletonLoader(
                      height: 40,
                      width: double.infinity,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(8, (_) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SkeletonLoader(
                        height: 56,
                        width: double.infinity,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    )),
                  ],
                ),
              ),
            );
          }
          if (state.status == ViewStatus.failure && state.transactions.isEmpty) {
            return _ErrorState(
              message: state.message ?? 'Failed to load transactions',
              onRetry: () {
                _refreshTransactions();
              },
            );
          }

          final transactions = state.transactions;
          
          // Fetch employee names when transactions change
          if (transactions.length != _previousTransactions.length ||
              !_areTransactionListsEqual(transactions, _previousTransactions)) {
            _previousTransactions = List.from(transactions);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fetchEmployeeNames(transactions);
            });
          }
          final filtered = _applyFiltersAndSort(transactions);
          final totalAmount = filtered.fold<double>(0.0, (acc, tx) => acc + tx.amount);
          final salaryCount = filtered.where((tx) => tx.category == TransactionCategory.salaryCredit).length;
          final bonusCount = filtered.where((tx) => tx.category == TransactionCategory.bonus).length;

          final usePagination = filtered.length > 50;
          final displayList = usePagination ? _getPaginatedData(filtered) : filtered;

          void openCreditSalary() {
            final cubit = context.read<EmployeeWagesCubit>();
            showDialog(
              context: context,
              builder: (dialogContext) => BlocProvider.value(
                value: cubit,
                child: CreditSalaryDialog(onSalaryCredited: () {}),
              ),
            );
          }

          void openRecordBonus() {
            final cubit = context.read<EmployeeWagesCubit>();
            showDialog(
              context: context,
              builder: (dialogContext) => BlocProvider.value(
                value: cubit,
                child: RecordBonusDialog(onBonusRecorded: () {}),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Summary Stats + Stacked Buttons (Credit Salary, Record Bonus)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _WagesStatsHeader(
                      totalAmount: totalAmount,
                      salaryCount: salaryCount,
                      bonusCount: bonusCount,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DashButton(
                        label: 'Credit Salary',
                        icon: Icons.payments,
                        onPressed: openCreditSalary,
                      ),
                      const SizedBox(height: 8),
                      DashButton(
                        label: 'Record Bonus',
                        icon: Icons.card_giftcard,
                        onPressed: openRecordBonus,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Row 2: Date range (left of search) + Search + Sort
              Row(
                children: [
                  // Date range – left of search
                  _DateRangeChips(
                    startDate: _startDate,
                    endDate: _endDate,
                    onStartTap: _selectStartDate,
                    onEndTap: _selectEndDate,
                    formatDate: _formatDate,
                  ),
                  const SizedBox(width: 12),
                  // Search Bar
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      decoration: BoxDecoration(
                        color: AuthColors.surface.withValues(alpha:0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
                      ),
                      child: TextField(
                        onChanged: (v) => setState(() {
                          _query = v;
                          _currentPage = 0;
                        }),
                        style: const TextStyle(color: AuthColors.textMain),
                        decoration: InputDecoration(
                          hintText: 'Search by employee, description...',
                          hintStyle: const TextStyle(color: AuthColors.textSub),
                          filled: true,
                          fillColor: Colors.transparent,
                          prefixIcon: const Icon(Icons.search, color: AuthColors.textSub),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: AuthColors.textSub),
                                  onPressed: () => setState(() => _query = ''),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Sort
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AuthColors.surface.withValues(alpha:0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sort, size: 16, color: AuthColors.textSub),
                        const SizedBox(width: 6),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<_WagesSortOption>(
                            value: _sortOption,
                            dropdownColor: AuthColors.surface,
                            style: const TextStyle(color: AuthColors.textMain, fontSize: 14),
                            items: const [
                              DropdownMenuItem(value: _WagesSortOption.dateNewest, child: Text('Date (Newest)')),
                              DropdownMenuItem(value: _WagesSortOption.dateOldest, child: Text('Date (Oldest)')),
                              DropdownMenuItem(value: _WagesSortOption.amountHigh, child: Text('Amount (High to Low)')),
                              DropdownMenuItem(value: _WagesSortOption.amountLow, child: Text('Amount (Low to High)')),
                              DropdownMenuItem(value: _WagesSortOption.employeeAsc, child: Text('Employee (A-Z)')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _sortOption = value;
                                  _currentPage = 0;
                                });
                              }
                            },
                            icon: const Icon(Icons.arrow_drop_down, color: AuthColors.textSub, size: 20),
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Transactions Table (core_ui DataTable) + conditional pagination
              if (filtered.isEmpty && _query.isNotEmpty)
                _EmptySearchState(query: _query)
              else if (filtered.isEmpty)
                _EmptyTransactionsState(onCreditSalary: openCreditSalary)
              else
                AnimatedFade(
                  duration: const Duration(milliseconds: 350),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _WagesDataTable(
                        transactions: displayList,
                        formatCurrency: _formatCurrency,
                        formatDate: _formatDate,
                        employeeNames: _employeeNames,
                        onDelete: (tx) => _showDeleteConfirmation(context, tx),
                      ),
                      if (usePagination) ...[
                        const SizedBox(height: 16),
                        _PaginationControls(
                          currentPage: _currentPage,
                          totalPages: _getTotalPages(filtered.length),
                          totalItems: filtered.length,
                          itemsPerPage: _itemsPerPage,
                          onPageChanged: (page) => setState(() => _currentPage = page),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DateRangeChips extends StatelessWidget {
  const _DateRangeChips({
    required this.startDate,
    required this.endDate,
    required this.onStartTap,
    required this.onEndTap,
    required this.formatDate,
  });

  final DateTime startDate;
  final DateTime endDate;
  final VoidCallback onStartTap;
  final VoidCallback onEndTap;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DateChip(label: 'Start', date: startDate, formatDate: formatDate, onTap: onStartTap),
        const SizedBox(width: 8),
        _DateChip(label: 'End', date: endDate, formatDate: formatDate, onTap: onEndTap),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.date,
    required this.formatDate,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final String Function(DateTime) formatDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AuthColors.surface.withValues(alpha:0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today, color: AuthColors.textSub, size: 16),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: const TextStyle(color: AuthColors.textSub, fontSize: 10)),
                  Text(formatDate(date), style: const TextStyle(color: AuthColors.textMain, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WagesStatsHeader extends StatelessWidget {
  const _WagesStatsHeader({
    required this.totalAmount,
    required this.salaryCount,
    required this.bonusCount,
  });

  final double totalAmount;
  final int salaryCount;
  final int bonusCount;

  @override
  Widget build(BuildContext context) {
    final formattedAmount = '₹${totalAmount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Total Amount',
            value: formattedAmount,
            color: AuthColors.warning,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            icon: Icons.payments,
            label: 'Salary Credits',
            value: salaryCount.toString(),
            color: AuthColors.successVariant,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            icon: Icons.card_giftcard,
            label: 'Bonuses',
            value: bonusCount.toString(),
            color: AuthColors.info,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DashCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AuthColors.textSub,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AuthColors.surface.withValues(alpha:0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AuthColors.error.withValues(alpha:0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: AuthColors.error.withValues(alpha:0.7)),
            const SizedBox(height: 16),
            const Text(
              'Failed to load employee wages',
              style: TextStyle(color: AuthColors.textMain, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(color: AuthColors.textSub, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            DashButton(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTransactionsState extends StatelessWidget {
  const _EmptyTransactionsState({required this.onCreditSalary});

  final VoidCallback onCreditSalary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: AuthColors.surface.withValues(alpha:0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AuthColors.primary.withValues(alpha:0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.payments_outlined, size: 40, color: AuthColors.primary),
            ),
            const SizedBox(height: 24),
            const Text(
              'No wages transactions yet',
              style: TextStyle(color: AuthColors.textMain, fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start by crediting salary to your employees',
              style: TextStyle(color: AuthColors.textSub, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            DashButton(
              label: 'Credit Salary',
              icon: Icons.payments,
              onPressed: onCreditSalary,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: AuthColors.textSub.withValues(alpha:0.5)),
            const SizedBox(height: 16),
            const Text('No results found', style: TextStyle(color: AuthColors.textMain, fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('No transactions match "$query"', style: const TextStyle(color: AuthColors.textSub, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _WagesDataTable extends StatelessWidget {
  const _WagesDataTable({
    required this.transactions,
    required this.formatCurrency,
    required this.formatDate,
    required this.employeeNames,
    required this.onDelete,
  });

  final List<Transaction> transactions;
  final String Function(double) formatCurrency;
  final String Function(DateTime) formatDate;
  final Map<String, String> employeeNames;
  final ValueChanged<Transaction> onDelete;

  @override
  Widget build(BuildContext context) {
    final columns = <custom_table.DataTableColumn<Transaction>>[
      custom_table.DataTableColumn<Transaction>(
        label: 'Date',
        icon: Icons.calendar_today,
        width: 120,
        cellBuilder: (context, tx, _) => Text(formatDate(tx.createdAt ?? DateTime.now()), style: const TextStyle(color: AuthColors.textMain, fontSize: 13)),
      ),
      custom_table.DataTableColumn<Transaction>(
        label: 'Employee',
        icon: Icons.person,
        width: 160,
        cellBuilder: (context, tx, _) {
          final name = tx.employeeName ?? employeeNames[tx.employeeId ?? ''] ?? 'Unknown Employee';
          return Text(name, style: const TextStyle(color: AuthColors.textMain, fontSize: 13, fontWeight: FontWeight.w600));
        },
      ),
      custom_table.DataTableColumn<Transaction>(
        label: 'Type',
        icon: Icons.category,
        width: 100,
        cellBuilder: (context, tx, _) {
          final isSalary = tx.category == TransactionCategory.salaryCredit;
          final label = isSalary ? 'Salary' : (tx.category == TransactionCategory.bonus ? 'Bonus' : tx.category.name);
          final color = isSalary ? AuthColors.primary : AuthColors.secondary;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
          );
        },
      ),
      custom_table.DataTableColumn<Transaction>(
        label: 'Amount',
        icon: Icons.currency_rupee,
        width: 120,
        numeric: true,
        cellBuilder: (context, tx, _) => Text(
          formatCurrency(tx.amount),
          style: const TextStyle(color: AuthColors.warning, fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
      custom_table.DataTableColumn<Transaction>(
        label: 'Description',
        icon: Icons.description,
        flex: 1,
        cellBuilder: (context, tx, _) => Text(tx.description ?? '-', style: const TextStyle(color: AuthColors.textSub, fontSize: 13)),
      ),
    ];

    final rowActions = [
      custom_table.DataTableRowAction<Transaction>(
        icon: Icons.receipt_long,
        tooltip: 'View voucher',
        color: AuthColors.primary,
        onTap: (tx, _) {
          final hasVoucher = tx.category == TransactionCategory.salaryDebit &&
              tx.metadata?['cashVoucherPhotoUrl'] != null &&
              (tx.metadata!['cashVoucherPhotoUrl'] as String).isNotEmpty;
          if (hasVoucher) {
            showSalaryVoucherModal(context, tx.id);
          } else {
            DashSnackbar.show(
              context,
              message: 'No voucher for this transaction',
              isError: false,
            );
          }
        },
      ),
      custom_table.DataTableRowAction<Transaction>(
        icon: Icons.delete_outline,
        onTap: (tx, _) => onDelete(tx),
        tooltip: 'Delete transaction',
        color: AuthColors.error,
      ),
    ];

    return custom_table.DataTable<Transaction>(
      columns: columns,
      rows: transactions,
      rowActions: rowActions,
      emptyStateMessage: 'No transactions in this range',
      emptyStateIcon: Icons.inbox_outlined,
    );
  }
}

class _PaginationControls extends StatelessWidget {
  const _PaginationControls({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.itemsPerPage,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final startItem = (currentPage * itemsPerPage) + 1;
    final endItem = ((currentPage + 1) * itemsPerPage).clamp(0, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AuthColors.surface.withValues(alpha:0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $startItem-$endItem of $totalItems',
            style: const TextStyle(color: AuthColors.textSub, fontSize: 14),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.first_page, size: 20),
                color: currentPage == 0 ? AuthColors.textDisabled : AuthColors.textSub,
                onPressed: currentPage == 0 ? null : () => onPageChanged(0),
                tooltip: 'First page',
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 24),
                color: currentPage == 0 ? AuthColors.textDisabled : AuthColors.textSub,
                onPressed: currentPage == 0 ? null : () => onPageChanged(currentPage - 1),
                tooltip: 'Previous page',
              ),
              ...List.generate(
                totalPages.clamp(0, 7),
                (index) {
                  int pageIndex;
                  if (totalPages <= 7) {
                    pageIndex = index;
                  } else if (currentPage < 4) {
                    pageIndex = index;
                  } else if (currentPage > totalPages - 4) {
                    pageIndex = totalPages - 7 + index;
                  } else {
                    pageIndex = currentPage - 3 + index;
                  }
                  final isCurrentPage = pageIndex == currentPage;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Material(
                      color: isCurrentPage ? AuthColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () => onPageChanged(pageIndex),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          child: Text(
                            '${pageIndex + 1}',
                            style: TextStyle(
                              color: isCurrentPage ? AuthColors.textMain : AuthColors.textSub,
                              fontSize: 14,
                              fontWeight: isCurrentPage ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 24),
                color: currentPage >= totalPages - 1 ? AuthColors.textDisabled : AuthColors.textSub,
                onPressed: currentPage >= totalPages - 1 ? null : () => onPageChanged(currentPage + 1),
                tooltip: 'Next page',
              ),
              IconButton(
                icon: const Icon(Icons.last_page, size: 20),
                color: currentPage >= totalPages - 1 ? AuthColors.textDisabled : AuthColors.textSub,
                onPressed: currentPage >= totalPages - 1 ? null : () => onPageChanged(totalPages - 1),
                tooltip: 'Last page',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

