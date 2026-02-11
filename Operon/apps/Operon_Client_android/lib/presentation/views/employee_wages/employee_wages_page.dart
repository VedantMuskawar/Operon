import 'dart:async';

import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/presentation/blocs/employee_wages/employee_wages_cubit.dart';
import 'package:dash_mobile/presentation/blocs/employee_wages/employee_wages_state.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/widgets/empty/empty_state_widget.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:dash_mobile/presentation/widgets/standard_search_bar.dart';
import 'package:dash_mobile/presentation/views/employee_wages/employee_wages_analytics_page.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:dash_mobile/shared/constants/app_typography.dart';
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

  // Cached computed values
  List<Transaction>? _cachedFilteredTransactions;
  double? _cachedTotalAmount;
  int? _cachedSalaryCount;
  int? _cachedBonusCount;
  List<Transaction>? _lastTransactionsForCache;
  String? _lastQueryForCache;
  _WagesSortOption? _lastSortOptionForCache;
  DateTime? _lastStartDateForCache;
  DateTime? _lastEndDateForCache;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day);
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

  /// Batch futures to limit concurrency and prevent overwhelming the network
  Future<List<T>> _batchFutures<T>(List<Future<T>> futures, {int batchSize = 10}) async {
    final results = <T>[];
    for (int i = 0; i < futures.length; i += batchSize) {
      final batch = futures.skip(i).take(batchSize).toList();
      final batchResults = await Future.wait(batch);
      results.addAll(batchResults);
    }
    return results;
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

      // Process futures in batches to limit concurrent network requests
      final futures = employeeIds.map((id) => FirebaseFirestore.instance
          .collection('EMPLOYEES')
          .doc(id)
          .get()).toList();
      
      final employeeDocs = await _batchFutures(futures, batchSize: 10);

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
    // Single-pass filtering: combine date range and search filters
    final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final end = DateTime(_endDate.year, _endDate.month, _endDate.day).add(const Duration(days: 1));
    final queryLower = _query.toLowerCase();
    final hasQuery = _query.isNotEmpty;

    final filtered = <Transaction>[];
    for (final tx in transactions) {
      // Date range filter
      final txDate = tx.createdAt ?? DateTime(1970);
      if (txDate.isBefore(start) || !txDate.isBefore(end)) {
        continue;
      }

      // Search filter (if query exists)
      if (hasQuery) {
        final employeeName = (_employeeNames[tx.employeeId ?? ''] ?? '').toLowerCase();
        final description = (tx.description ?? '').toLowerCase();
        final category = tx.category.name.toLowerCase();
        if (!employeeName.contains(queryLower) &&
            !description.contains(queryLower) &&
            !category.contains(queryLower)) {
          continue;
        }
      }

      filtered.add(tx);
    }

    // Sort the filtered list
    switch (_sortOption) {
      case _WagesSortOption.dateNewest:
        filtered.sort((a, b) {
          final aDate = a.createdAt ?? DateTime(1970);
          final bDate = b.createdAt ?? DateTime(1970);
          return bDate.compareTo(aDate);
        });
        break;
      case _WagesSortOption.dateOldest:
        filtered.sort((a, b) {
          final aDate = a.createdAt ?? DateTime(1970);
          final bDate = b.createdAt ?? DateTime(1970);
          return aDate.compareTo(bDate);
        });
        break;
      case _WagesSortOption.amountHigh:
        filtered.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case _WagesSortOption.amountLow:
        filtered.sort((a, b) => a.amount.compareTo(b.amount));
        break;
      case _WagesSortOption.employeeAsc:
        filtered.sort((a, b) {
          final aName = (_employeeNames[a.employeeId ?? ''] ?? '').toLowerCase();
          final bName = (_employeeNames[b.employeeId ?? ''] ?? '').toLowerCase();
          return aName.compareTo(bName);
        });
        break;
    }

    return filtered;
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

  Future<void> _handleDateRangePicker() async {
    final currentRange = DateTimeRange(start: _startDate, end: _endDate);
    
    final range = await showLedgerDateRangeModal(
      context,
      initialRange: currentRange,
    );
    
    if (range != null && mounted) {
      setState(() {
        _startDate = DateTime(range.start.year, range.start.month, range.start.day);
        _endDate = DateTime(range.end.year, range.end.month, range.end.day);
        _wagesCurrentPage = 0;
        // Invalidate cache when date changes
        _lastStartDateForCache = null;
        _lastEndDateForCache = null;
      });
    }
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
                        child: RefreshIndicator(
                          onRefresh: () => context.read<EmployeeWagesCubit>().loadTransactions(),
                          color: AuthColors.primary,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(AppSpacing.paddingLG),
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
                    const SizedBox(height: AppSpacing.paddingLG),
                    SizedBox(
                      height: pageViewHeight,
                      child: PageView(
                        controller: _pageController,
                        children: [
                          // Transactions List Page
                          BlocBuilder<EmployeeWagesCubit, EmployeeWagesState>(
                            buildWhen: (previous, current) =>
                                previous.transactions != current.transactions ||
                                previous.status != current.status,
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
                                // Invalidate cache when transactions change
                                _lastTransactionsForCache = null;
                              }
                              
                              // Update cached values if needed (compute synchronously in build)
                              // Use more reliable comparison: check if transactions list actually changed
                              final transactionsChanged = _lastTransactionsForCache == null ||
                                  !_areTransactionListsEqual(_lastTransactionsForCache!, transactions);
                              
                              if (_cachedFilteredTransactions == null ||
                                  transactionsChanged ||
                                  _lastQueryForCache != _query ||
                                  _lastSortOptionForCache != _sortOption ||
                                  _lastStartDateForCache != _startDate ||
                                  _lastEndDateForCache != _endDate) {
                                final filtered = _applyFiltersAndSort(transactions);
                                
                                // Compute totals in single pass
                                double totalAmount = 0.0;
                                int salaryCount = 0;
                                int bonusCount = 0;
                                for (final tx in filtered) {
                                  totalAmount += tx.amount;
                                  if (tx.category == TransactionCategory.salaryCredit) {
                                    salaryCount++;
                                  } else if (tx.category == TransactionCategory.bonus) {
                                    bonusCount++;
                                  }
                                }
                                
                                // Update cache
                                _cachedFilteredTransactions = filtered;
                                _cachedTotalAmount = totalAmount;
                                _cachedSalaryCount = salaryCount;
                                _cachedBonusCount = bonusCount;
                                _lastTransactionsForCache = List.from(transactions); // Store copy for comparison
                                _lastQueryForCache = _query;
                                _lastSortOptionForCache = _sortOption;
                                _lastStartDateForCache = _startDate;
                                _lastEndDateForCache = _endDate;
                              }
                              
                              final filtered = _cachedFilteredTransactions ?? [];
                              final totalAmount = _cachedTotalAmount ?? 0.0;
                              final salaryCount = _cachedSalaryCount ?? 0;
                              final bonusCount = _cachedBonusCount ?? 0;
                              final usePagination = filtered.length > 50;
                              final displayList = usePagination ? _getPaginatedData(filtered) : filtered;

                              return SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Summary stats row (Cash Ledger style)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _WagesSummaryCard(
                                            label: 'Total',
                                            amount: totalAmount,
                                            color: AuthColors.warning,
                                            formatCurrency: _formatCurrency,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.paddingSM),
                                        Expanded(
                                          child: _WagesSummaryCard(
                                            label: 'Salary',
                                            value: salaryCount.toString(),
                                            color: AuthColors.successVariant,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.paddingSM),
                                        Expanded(
                                          child: _WagesSummaryCard(
                                            label: 'Bonuses',
                                            value: bonusCount.toString(),
                                            color: AuthColors.info,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.paddingMD),
                                    // Search + Date row (Cash Ledger style)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: AuthColors.surface.withOpacity(0.6),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: AuthColors.surface.withOpacity(0.8),
                                                width: 1,
                                              ),
                                            ),
                                            child: StandardSearchBar(
                                              controller: _searchController,
                                              hintText: 'Search by employee, amount...',
                                              onChanged: (value) {
                                                setState(() {
                                                  _query = value;
                                                  _wagesCurrentPage = 0;
                                                  _lastQueryForCache = null;
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.paddingSM),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: AuthColors.surface.withOpacity(0.6),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: AuthColors.surface.withOpacity(0.8),
                                              width: 1,
                                            ),
                                          ),
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.calendar_today,
                                              color: AuthColors.textMain,
                                              size: 20,
                                            ),
                                            tooltip: 'Select date range',
                                            onPressed: _handleDateRangePicker,
                                            padding: const EdgeInsets.all(12),
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.paddingXS),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: AuthColors.surface.withOpacity(0.6),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: AuthColors.surface.withOpacity(0.8),
                                              width: 1,
                                            ),
                                          ),
                                          child: PopupMenuButton<_WagesSortOption>(
                                            tooltip: 'Sort',
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(Icons.sort, color: AuthColors.textMain, size: 20),
                                            onSelected: (v) {
                                              setState(() {
                                                _sortOption = v;
                                                _wagesCurrentPage = 0;
                                                _lastSortOptionForCache = null;
                                              });
                                            },
                                            itemBuilder: (context) => [
                                              const PopupMenuItem(value: _WagesSortOption.dateNewest, child: Text('Newest')),
                                              const PopupMenuItem(value: _WagesSortOption.dateOldest, child: Text('Oldest')),
                                              const PopupMenuItem(value: _WagesSortOption.amountHigh, child: Text('Amt ↑')),
                                              const PopupMenuItem(value: _WagesSortOption.amountLow, child: Text('Amt ↓')),
                                              const PopupMenuItem(value: _WagesSortOption.employeeAsc, child: Text('A–Z')),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.paddingMD),
                                    // Column headers (Cash Ledger style)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: AppSpacing.paddingSM,
                                        horizontal: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AuthColors.surface.withOpacity(0.4),
                                      ),
                                      child: const Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'Employee',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AuthColors.textSub,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 70,
                                            child: Text(
                                              'Type',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AuthColors.textSub,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 90,
                                            child: Text(
                                              'Amount',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AuthColors.warning,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.5,
                                              ),
                                              textAlign: TextAlign.end,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (filtered.isEmpty && _query.isNotEmpty)
                                      EmptyStateWidget(
                                        icon: Icons.search_off,
                                        title: 'No results found',
                                        message: 'No transactions match "$_query"',
                                      )
                                    else if (filtered.isEmpty)
                                      const EmptyStateWidget(
                                        icon: Icons.payments_outlined,
                                        title: 'No wages transactions yet',
                                        message: 'No transactions found for the selected date range',
                                      )
                                    else ...[
                                      ...displayList.asMap().entries.map(
                                            (e) => _WagesTransactionTableRow(
                                              transaction: e.value,
                                              employeeName: _employeeNames[e.value.employeeId ?? ''] ?? 'Unknown',
                                              formatCurrency: _formatCurrency,
                                              formatDate: _formatDate,
                                              isEven: e.key.isEven,
                                            ),
                                          ),
                                      _WagesTableFooter(
                                        totalAmount: totalAmount,
                                        formatCurrency: _formatCurrency,
                                      ),
                                      if (usePagination) ...[
                                        const SizedBox(height: AppSpacing.paddingMD),
                                        _PaginationControls(
                                          currentPage: _wagesCurrentPage,
                                          totalPages: _getTotalPages(filtered.length),
                                          totalItems: filtered.length,
                                          itemsPerPage: _itemsPerPage,
                                          onPageChanged: (p) => setState(() => _wagesCurrentPage = p),
                                        ),
                                      ],
                                    ],
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
            ],
          ),
        ),
      ),
      ),
      ],
    );
  }
}

/// Summary card widget (Cash Ledger style)
class _WagesSummaryCard extends StatelessWidget {
  const _WagesSummaryCard({
    required this.label,
    required this.color,
    this.amount,
    this.formatCurrency,
    this.value,
  }) : assert(amount != null && formatCurrency != null || value != null);

  final String label;
  final double? amount;
  final String Function(double)? formatCurrency;
  final String? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final displayValue = amount != null && formatCurrency != null
        ? formatCurrency!(amount!)
        : (value ?? '');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.paddingSM),
      decoration: BoxDecoration(
        color: AuthColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AuthColors.textSub,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            displayValue,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Transaction table row (Cash Ledger style)
class _WagesTransactionTableRow extends StatelessWidget {
  const _WagesTransactionTableRow({
    required this.transaction,
    required this.employeeName,
    required this.formatCurrency,
    required this.formatDate,
    required this.isEven,
  });

  final Transaction transaction;
  final String employeeName;
  final String Function(double) formatCurrency;
  final String Function(DateTime) formatDate;
  final bool isEven;

  @override
  Widget build(BuildContext context) {
    final date = transaction.createdAt ?? DateTime.now();
    final isSalary = transaction.category == TransactionCategory.salaryCredit;
    final typeLabel = isSalary ? 'Salary' : 'Bonus';

    return Container(
      decoration: BoxDecoration(
        color: isEven
            ? Colors.transparent
            : AuthColors.surface.withOpacity(0.2),
        border: Border(
          bottom: BorderSide(
            color: AuthColors.surface.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employeeName,
                    style: AppTypography.withColor(
                      AppTypography.body,
                      AuthColors.textMain,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatDate(date)}${transaction.referenceNumber != null ? ' • ${transaction.referenceNumber}' : ''}',
                    style: const TextStyle(
                      color: AuthColors.textSub,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 70,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.gapSM,
                  vertical: AppSpacing.paddingXS,
                ),
                decoration: BoxDecoration(
                  color: (isSalary ? AuthColors.primary : AuthColors.secondary)
                      .withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
                ),
                child: Text(
                  typeLabel,
                  style: TextStyle(
                    color: isSalary ? AuthColors.primary : AuthColors.secondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            SizedBox(
              width: 90,
              child: Text(
                formatCurrency(transaction.amount),
                style: AppTypography.withColor(
                  AppTypography.body,
                  AuthColors.warning,
                ),
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Footer row with total (Cash Ledger style)
class _WagesTableFooter extends StatelessWidget {
  const _WagesTableFooter({
    required this.totalAmount,
    required this.formatCurrency,
  });

  final double totalAmount;
  final String Function(double) formatCurrency;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AuthColors.primary.withOpacity(0.15),
            AuthColors.primary.withOpacity(0.05),
          ],
        ),
        border: Border(
          top: BorderSide(
            color: AuthColors.primary.withOpacity(0.5),
            width: 2,
          ),
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  const Icon(
                    Icons.calculate,
                    size: 18,
                    color: AuthColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Total',
                    style: AppTypography.withColor(
                      AppTypography.withWeight(
                        AppTypography.bodyLarge,
                        FontWeight.w700,
                      ),
                      AuthColors.textMain,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 70),
            SizedBox(
              width: 90,
              child: Text(
                formatCurrency(totalAmount),
                style: AppTypography.withColor(
                  AppTypography.withWeight(
                    AppTypography.bodyLarge,
                    FontWeight.w700,
                  ),
                  AuthColors.warning,
                ),
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingXS),
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
        padding: EdgeInsets.all(AppSpacing.paddingXXXL * 1.25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.paddingXXL),
            Text(
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
        padding: const EdgeInsets.all(AppSpacing.paddingXXXL * 1.25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AuthColors.error.withValues(alpha: 0.7)),
            const SizedBox(height: AppSpacing.paddingLG),
            const Text(
              'Failed to load employee wages',
              style: TextStyle(color: AuthColors.textMain, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.paddingSM),
            Text(
              message,
              style: const TextStyle(color: AuthColors.textSub, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.paddingXXL),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AuthColors.primary,
                foregroundColor: AuthColors.textMain,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingXXL, vertical: AppSpacing.paddingMD),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMD)),
              ),
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingMD, vertical: AppSpacing.paddingMD),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
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
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingSM),
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

