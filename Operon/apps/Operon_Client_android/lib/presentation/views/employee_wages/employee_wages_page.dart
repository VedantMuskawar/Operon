import 'dart:async';

import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/components/data_table.dart' as custom_table;
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/presentation/blocs/employee_wages/employee_wages_cubit.dart';
import 'package:dash_mobile/presentation/blocs/employee_wages/employee_wages_state.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/widgets/quick_nav_bar.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:dash_mobile/presentation/widgets/date_range_picker.dart';
import 'package:dash_mobile/presentation/views/employee_wages/credit_salary_dialog.dart';
import 'package:dash_mobile/presentation/views/employee_wages/record_bonus_dialog.dart';
import 'package:dash_mobile/presentation/views/employee_wages/employee_wages_analytics_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;

enum _WagesSortOption {
  dateNewest,
  dateOldest,
  amountHigh,
  amountLow,
  employeeAsc,
}

class EmployeeWagesPage extends StatefulWidget {
  const EmployeeWagesPage({super.key});

  @override
  State<EmployeeWagesPage> createState() => _EmployeeWagesPageState();
}

class _EmployeeWagesPageState extends State<EmployeeWagesPage> {
  final Map<String, String> _employeeNames = {};
  final TextEditingController _searchController = TextEditingController();
  late final PageController _pageController;
  double _currentPage = 0;
  String _query = '';
  _WagesSortOption _sortOption = _WagesSortOption.dateNewest;
  String? _currentOrgId;
  List<Transaction> _previousTransactions = [];
  late DateTime _startDate;
  late DateTime _endDate;

  static const int _itemsPerPage = 50;
  int _wagesCurrentPage = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day);
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text;
        _wagesCurrentPage = 0;
      });
    });
    _pageController = PageController()
      ..addListener(() {
        setState(() {
          _currentPage = _pageController.page ?? 0;
        });
      });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
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
      context.read<EmployeeWagesCubit>().watchTransactions();
    }
  }

  Future<void> _fetchEmployeeNames(List<Transaction> transactions) async {
    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    if (organization == null) return;

    try {
      final employeeIds = transactions
          .where((tx) => tx.employeeId != null && !_employeeNames.containsKey(tx.employeeId))
          .map((tx) => tx.employeeId!)
          .toSet();

      if (employeeIds.isEmpty) return;

      final employeeDocs = await Future.wait(
        employeeIds.map((id) => FirebaseFirestore.instance
            .collection('EMPLOYEES')
            .doc(id)
            .get()),
      );

      final newEmployeeNames = <String, String>{};
      for (final doc in employeeDocs) {
        if (doc.exists) {
          final data = doc.data();
          final name = data?['employeeName'] as String? ?? 'Unknown Employee';
          newEmployeeNames[doc.id] = name;
        }
      }

      if (mounted && newEmployeeNames.isNotEmpty) {
        setState(() {
          _employeeNames.addAll(newEmployeeNames);
        });
      }
    } catch (e) {
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

    // Apply date range filter (default today–today)
    final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final end = DateTime(_endDate.year, _endDate.month, _endDate.day).add(const Duration(days: 1));
    filtered = filtered.where((tx) {
      final txDate = tx.createdAt ?? DateTime(1970);
      return !txDate.isBefore(start) && txDate.isBefore(end);
    }).toList();

    if (_query.isNotEmpty) {
      final queryLower = _query.toLowerCase();
      filtered = filtered.where((tx) {
        final employeeName = (_employeeNames[tx.employeeId ?? ''] ?? '').toLowerCase();
        final description = (tx.description ?? '').toLowerCase();
        final category = tx.category.name.toLowerCase();
        return employeeName.contains(queryLower) ||
            description.contains(queryLower) ||
            category.contains(queryLower);
      }).toList();
    }

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
          final aName = (_employeeNames[a.employeeId ?? ''] ?? '').toLowerCase();
          final bName = (_employeeNames[b.employeeId ?? ''] ?? '').toLowerCase();
          return aName.compareTo(bName);
        });
        break;
    }

    return sortedList;
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

  List<Transaction> _getPaginatedData(List<Transaction> all) {
    final start = _wagesCurrentPage * _itemsPerPage;
    final end = (start + _itemsPerPage).clamp(0, all.length);
    if (start >= all.length) return [];
    return all.sublist(start, end);
  }

  int _getTotalPages(int n) {
    if (n == 0) return 1;
    return ((n - 1) ~/ _itemsPerPage) + 1;
  }

  Future<void> _deleteTransaction(String transactionId) async {
    try {
      await context.read<EmployeeWagesCubit>().deleteTransaction(transactionId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction deleted successfully'),
            backgroundColor: AuthColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete transaction: $e'),
            backgroundColor: AuthColors.error,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, Transaction transaction) {
    final employeeName = _employeeNames[transaction.employeeId ?? ''] ?? 'Unknown Employee';
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
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _deleteTransaction(transaction.id);
              Navigator.of(dialogContext).pop();
            },
            style: TextButton.styleFrom(foregroundColor: AuthColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openCreditSalaryDialog() {
    final cubit = context.read<EmployeeWagesCubit>();
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: cubit,
        child: const CreditSalaryDialog(),
      ),
    );
  }

  void _openRecordBonusDialog() {
    final cubit = context.read<EmployeeWagesCubit>();
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: cubit,
        child: const RecordBonusDialog(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        BlocListener<EmployeeWagesCubit, EmployeeWagesState>(
          listener: (context, state) {
            if (state.status == ViewStatus.failure && state.message != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message!)),
              );
            }
          },
          child: Scaffold(
            backgroundColor: AuthColors.background,
            appBar: const ModernPageHeader(
              title: 'Employee Wages',
            ),
            body: SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Builder(
              builder: (context) {
                final media = MediaQuery.of(context);
                final screenHeight = media.size.height;
                final availableHeight = screenHeight - media.padding.top - 72 - media.padding.bottom - 80 - 24 - 48;
                final pageViewHeight = (availableHeight - 24 - 16 - 48).clamp(400.0, 600.0);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Page Indicator
                    _PageIndicator(
                      pageCount: 2,
                      currentIndex: _currentPage,
                      onPageTap: (index) {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: pageViewHeight,
                      child: PageView(
                        controller: _pageController,
                        children: [
                          // Transactions List Page
                          BlocBuilder<EmployeeWagesCubit, EmployeeWagesState>(
                            builder: (context, state) {
                              if (state.status == ViewStatus.loading && state.transactions.isEmpty) {
                                return const _LoadingState();
                              }
                              if (state.status == ViewStatus.failure && state.transactions.isEmpty) {
                                return _ErrorState(
                                  message: state.message ?? 'Failed to load transactions',
                                  onRetry: () {
                                    context.read<EmployeeWagesCubit>().loadTransactions();
                                  },
                                );
                              }

                              final transactions = state.transactions;
                              
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

                              return SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Row 1: Stats + Stacked buttons
                                    _AndroidWagesStatsRow(
                                      totalAmount: totalAmount,
                                      salaryCount: salaryCount,
                                      bonusCount: bonusCount,
                                      formatCurrency: _formatCurrency,
                                      onCreditSalary: _openCreditSalaryDialog,
                                      onRecordBonus: _openRecordBonusDialog,
                                    ),
                                    const SizedBox(height: 16),
                                    // Row 2: Date range (left of search) + Search + Sort
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: DateRangePicker(
                                            startDate: _startDate,
                                            endDate: _endDate,
                                            onStartDateChanged: (d) {
                                              if (d != null) {
                                                setState(() {
                                                  _startDate = d;
                                                  if (_endDate.isBefore(_startDate)) _endDate = _startDate;
                                                  _wagesCurrentPage = 0;
                                                });
                                              }
                                            },
                                            onEndDateChanged: (d) {
                                              if (d != null) {
                                                setState(() {
                                                  _endDate = d;
                                                  if (_startDate.isAfter(_endDate)) _startDate = _endDate;
                                                  _wagesCurrentPage = 0;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          flex: 3,
                                          child: TextField(
                                            controller: _searchController,
                                            style: const TextStyle(color: AuthColors.textMain),
                                            decoration: InputDecoration(
                                              prefixIcon: const Icon(Icons.search, color: AuthColors.textSub),
                                              suffixIcon: _query.isNotEmpty
                                                  ? IconButton(
                                                      icon: const Icon(Icons.close, color: AuthColors.textSub),
                                                      onPressed: () => _searchController.clear(),
                                                    )
                                                  : null,
                                              hintText: 'Search...',
                                              hintStyle: const TextStyle(color: AuthColors.textSub),
                                              filled: true,
                                              fillColor: AuthColors.surface,
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(14),
                                                borderSide: BorderSide.none,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: AuthColors.surface,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<_WagesSortOption>(
                                              value: _sortOption,
                                              dropdownColor: AuthColors.surface,
                                              style: const TextStyle(color: AuthColors.textMain, fontSize: 13),
                                              isExpanded: true,
                                              items: const [
                                                DropdownMenuItem(value: _WagesSortOption.dateNewest, child: Text('Newest')),
                                                DropdownMenuItem(value: _WagesSortOption.dateOldest, child: Text('Oldest')),
                                                DropdownMenuItem(value: _WagesSortOption.amountHigh, child: Text('Amt ↑')),
                                                DropdownMenuItem(value: _WagesSortOption.amountLow, child: Text('Amt ↓')),
                                                DropdownMenuItem(value: _WagesSortOption.employeeAsc, child: Text('A–Z')),
                                              ],
                                              onChanged: (v) {
                                                if (v != null) setState(() { _sortOption = v; _wagesCurrentPage = 0; });
                                              },
                                              icon: const Icon(Icons.sort, color: AuthColors.textSub, size: 18),
                                              isDense: true,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    if (filtered.isEmpty && _query.isNotEmpty)
                                      _EmptySearchState(query: _query)
                                    else if (filtered.isEmpty)
                                      _EmptyTransactionsState(onCreditSalary: _openCreditSalaryDialog)
                                    else
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: _WagesDataTable(
                                              transactions: displayList,
                                              employeeNames: _employeeNames,
                                              formatCurrency: _formatCurrency,
                                              formatDate: _formatDate,
                                              onDelete: (tx) => _showDeleteConfirmation(context, tx),
                                            ),
                                          ),
                                          if (usePagination) ...[
                                            const SizedBox(height: 12),
                                            _PaginationControls(
                                              currentPage: _wagesCurrentPage,
                                              totalPages: _getTotalPages(filtered.length),
                                              totalItems: filtered.length,
                                              itemsPerPage: _itemsPerPage,
                                              onPageChanged: (p) => setState(() => _wagesCurrentPage = p),
                                            ),
                                          ],
                                        ],
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                          // Analytics Page
                          const EmployeeWagesAnalyticsPage(),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
                      ),
                    ),
                  QuickNavBar(
                    currentIndex: 0,
                    onTap: (value) => context.go('/home', extra: value),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
      ],
    );
  }
}

class _AndroidWagesStatsRow extends StatelessWidget {
  const _AndroidWagesStatsRow({
    required this.totalAmount,
    required this.salaryCount,
    required this.bonusCount,
    required this.formatCurrency,
    required this.onCreditSalary,
    required this.onRecordBonus,
  });

  final double totalAmount;
  final int salaryCount;
  final int bonusCount;
  final String Function(double) formatCurrency;
  final VoidCallback onCreditSalary;
  final VoidCallback onRecordBonus;

  @override
  Widget build(BuildContext context) {
    final formatted = formatCurrency(totalAmount);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MiniStat(label: 'Total Amount', value: formatted, color: AuthColors.warning),
              const SizedBox(height: 8),
              Row(
                children: [
                  _MiniStat(label: 'Salary', value: salaryCount.toString(), color: AuthColors.successVariant),
                  const SizedBox(width: 12),
                  _MiniStat(label: 'Bonuses', value: bonusCount.toString(), color: AuthColors.info),
                ],
              ),
            ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 140,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.payments, size: 18),
                label: const Text('Credit Salary'),
                onPressed: onCreditSalary,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AuthColors.primary,
                  foregroundColor: AuthColors.textMain,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 140,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.card_giftcard, size: 18),
                label: const Text('Record Bonus'),
                onPressed: onRecordBonus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AuthColors.accentPurple,
                  foregroundColor: AuthColors.textMain,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(value, style: const TextStyle(color: AuthColors.textMain, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: AuthColors.textSub, fontSize: 11)),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.pageCount,
    required this.currentIndex,
    required this.onPageTap,
  });

  final int pageCount;
  final double currentIndex;
  final ValueChanged<int> onPageTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        pageCount,
        (index) {
          final isActive = currentIndex.round() == index;
          return GestureDetector(
            onTap: () => onPageTap(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive ? AuthColors.primary : AuthColors.textDisabled,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            const Text(
              'Loading employee wages...',
              style: TextStyle(color: AuthColors.textSub, fontSize: 16),
            ),
          ],
        ),
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
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AuthColors.error.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            const Text(
              'Failed to load employee wages',
              style: TextStyle(color: AuthColors.textMain, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: AuthColors.textSub, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AuthColors.primary,
                foregroundColor: AuthColors.textMain,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
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
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AuthColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.payments_outlined, size: 40, color: AuthColors.primary),
            ),
            const SizedBox(height: 24),
            const Text(
              'No wages transactions yet',
              style: TextStyle(color: AuthColors.textMain, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start by crediting salary to your employees',
              style: TextStyle(color: AuthColors.textSub, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.payments, size: 20),
              label: const Text('Credit Salary'),
              onPressed: onCreditSalary,
              style: ElevatedButton.styleFrom(
                backgroundColor: AuthColors.primary,
                foregroundColor: AuthColors.textMain,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
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
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: AuthColors.textSub.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'No results found',
              style: TextStyle(color: AuthColors.textMain, fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'No transactions match "$query"',
              style: const TextStyle(color: AuthColors.textSub, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _WagesDataTable extends StatelessWidget {
  const _WagesDataTable({
    required this.transactions,
    required this.employeeNames,
    required this.formatCurrency,
    required this.formatDate,
    required this.onDelete,
  });

  final List<Transaction> transactions;
  final Map<String, String> employeeNames;
  final String Function(double) formatCurrency;
  final String Function(DateTime) formatDate;
  final ValueChanged<Transaction> onDelete;

  @override
  Widget build(BuildContext context) {
    final columns = <custom_table.DataTableColumn<Transaction>>[
      custom_table.DataTableColumn<Transaction>(
        label: 'Date',
        icon: Icons.calendar_today,
        width: 100,
        cellBuilder: (context, tx, _) => Text(formatDate(tx.createdAt ?? DateTime.now()), style: const TextStyle(color: AuthColors.textMain, fontSize: 12)),
      ),
      custom_table.DataTableColumn<Transaction>(
        label: 'Employee',
        icon: Icons.person,
        width: 130,
        cellBuilder: (context, tx, _) {
          final name = employeeNames[tx.employeeId ?? ''] ?? 'Unknown';
          return Text(name, style: const TextStyle(color: AuthColors.textMain, fontSize: 12, fontWeight: FontWeight.w600));
        },
      ),
      custom_table.DataTableColumn<Transaction>(
        label: 'Type',
        icon: Icons.category,
        width: 80,
        cellBuilder: (context, tx, _) {
          final isSalary = tx.category == TransactionCategory.salaryCredit;
          final label = isSalary ? 'Salary' : (tx.category == TransactionCategory.bonus ? 'Bonus' : tx.category.name);
          final color = isSalary ? AuthColors.primary : AuthColors.accentPurple;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
            child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11)),
          );
        },
      ),
      custom_table.DataTableColumn<Transaction>(
        label: 'Amount',
        icon: Icons.currency_rupee,
        width: 90,
        numeric: true,
        cellBuilder: (context, tx, _) => Text(formatCurrency(tx.amount), style: const TextStyle(color: AuthColors.warning, fontWeight: FontWeight.w700, fontSize: 12)),
      ),
      custom_table.DataTableColumn<Transaction>(
        label: 'Description',
        icon: Icons.description,
        flex: 1,
        cellBuilder: (context, tx, _) => Text(tx.description ?? '-', style: const TextStyle(color: AuthColors.textSub, fontSize: 12)),
      ),
    ];
    final rowActions = [
      custom_table.DataTableRowAction<Transaction>(
        icon: Icons.delete_outline,
        onTap: (tx, _) => onDelete(tx),
        tooltip: 'Delete',
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
    final start = (currentPage * itemsPerPage) + 1;
    final end = ((currentPage + 1) * itemsPerPage).clamp(0, totalItems);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$start–$end of $totalItems', style: const TextStyle(color: AuthColors.textSub, fontSize: 13)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 22),
                onPressed: currentPage == 0 ? null : () => onPageChanged(currentPage - 1),
                color: currentPage == 0 ? AuthColors.textDisabled : AuthColors.textSub,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('${currentPage + 1} / $totalPages', style: const TextStyle(color: AuthColors.textMain, fontSize: 13)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 22),
                onPressed: currentPage >= totalPages - 1 ? null : () => onPageChanged(currentPage + 1),
                color: currentPage >= totalPages - 1 ? AuthColors.textDisabled : AuthColors.textSub,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

