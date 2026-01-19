import 'dart:async';

import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/presentation/blocs/employee_wages/employee_wages_cubit.dart';
import 'package:dash_mobile/presentation/blocs/employee_wages/employee_wages_state.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/widgets/quick_nav_bar.dart';
import 'package:dash_mobile/presentation/widgets/quick_action_menu.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:dash_mobile/presentation/widgets/date_range_picker.dart';
import 'package:dash_mobile/presentation/views/employee_wages/credit_salary_dialog.dart';
import 'package:dash_mobile/presentation/views/employee_wages/record_bonus_dialog.dart';
import 'package:dash_mobile/presentation/views/employee_wages/employee_wages_analytics_page.dart';
import 'package:flutter/foundation.dart';
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
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text;
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

    // Apply date range filter
    if (_startDate != null || _endDate != null) {
      filtered = filtered.where((tx) {
        final txDate = tx.createdAt ?? DateTime(1970);
        final start = _startDate ?? DateTime(1970);
        final end = _endDate ?? DateTime.now();
        
        return txDate.isAfter(start.subtract(const Duration(days: 1))) &&
               txDate.isBefore(end.add(const Duration(days: 1)));
      }).toList();
    }

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

                              return SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Date Range Picker
                                    DateRangePicker(
                                      startDate: _startDate,
                                      endDate: _endDate,
                                      onStartDateChanged: (date) {
                                        setState(() => _startDate = date);
                                      },
                                      onEndDateChanged: (date) {
                                        setState(() => _endDate = date);
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    // Search Bar
                                    TextField(
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
                                        hintText: 'Search by employee, description...',
                                        hintStyle: const TextStyle(color: Colors.white38),
                                        filled: true,
                                        fillColor: const Color(0xFF1B1B2C),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    // Sort Dropdown
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1B1B2C),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<_WagesSortOption>(
                                          value: _sortOption,
                                          dropdownColor: AuthColors.surface,
                                          style: const TextStyle(color: AuthColors.textMain, fontSize: 14),
                                          isExpanded: true,
                                          items: const [
                                            DropdownMenuItem(
                                              value: _WagesSortOption.dateNewest,
                                              child: Text('Date (Newest)'),
                                            ),
                                            DropdownMenuItem(
                                              value: _WagesSortOption.dateOldest,
                                              child: Text('Date (Oldest)'),
                                            ),
                                            DropdownMenuItem(
                                              value: _WagesSortOption.amountHigh,
                                              child: Text('Amount (High to Low)'),
                                            ),
                                            DropdownMenuItem(
                                              value: _WagesSortOption.amountLow,
                                              child: Text('Amount (Low to High)'),
                                            ),
                                            DropdownMenuItem(
                                              value: _WagesSortOption.employeeAsc,
                                              child: Text('Employee (A-Z)'),
                                            ),
                                          ],
                                          onChanged: (value) {
                                            if (value != null) {
                                              setState(() => _sortOption = value);
                                            }
                                          },
                                          icon: const Icon(Icons.sort, color: AuthColors.textSub, size: 20),
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    // Results count
                                    Text(
                                      '${filtered.length} ${filtered.length == 1 ? 'transaction' : 'transactions'}',
                                      style: TextStyle(
                                        color: AuthColors.textMainWithOpacity(0.7),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    
                                    // Transactions Table
                                    if (filtered.isEmpty && _query.isNotEmpty)
                                      _EmptySearchState(query: _query)
                                    else if (filtered.isEmpty)
                                      const _EmptyTransactionsState()
                                    else
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: _WagesTransactionsTable(
                                          transactions: filtered,
                                          employeeNames: _employeeNames,
                                          formatCurrency: _formatCurrency,
                                          formatDate: _formatDate,
                                          onDelete: (transaction) => _showDeleteConfirmation(context, transaction),
                                        ),
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
              // Quick Action Menu - only show on transactions page
              if (_currentPage == 0)
                Builder(
                  builder: (context) {
                    final media = MediaQuery.of(context);
                    final bottomPadding = media.padding.bottom;
                    // Nav bar height (~80px) + safe area bottom + spacing (20px)
                    final bottomOffset = 80 + bottomPadding + 20;
                    return QuickActionMenu(
                      right: 40,
                      bottom: bottomOffset,
                      actions: [
                        QuickActionItem(
                          icon: Icons.payments,
                          label: 'Credit Salary',
                          onTap: _openCreditSalaryDialog,
                        ),
                        QuickActionItem(
                          icon: Icons.card_giftcard,
                          label: 'Record Bonus',
                          onTap: _openRecordBonusDialog,
                        ),
                      ],
                    );
                  },
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
                color: isActive ? AuthColors.legacyAccent : AuthColors.textDisabled,
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
            Text(
              'Loading employee wages...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
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
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.redAccent.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load employee wages',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6F4BFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTransactionsState extends StatelessWidget {
  const _EmptyTransactionsState();

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
                color: const Color(0xFF6F4BFF).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.payments_outlined,
                size: 40,
                color: Color(0xFF6F4BFF),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No wages transactions yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start by crediting salary to your employees',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
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
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'No results found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No transactions match "$query"',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WagesTransactionsTable extends StatelessWidget {
  const _WagesTransactionsTable({
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
  final void Function(Transaction) onDelete;

  String _getCategoryName(TransactionCategory category) {
    switch (category) {
      case TransactionCategory.salaryCredit:
        return 'Salary';
      case TransactionCategory.bonus:
        return 'Bonus';
      default:
        return category.name;
    }
  }

  Color _getCategoryColor(TransactionCategory category) {
    switch (category) {
      case TransactionCategory.salaryCredit:
        return const Color(0xFF6F4BFF);
      case TransactionCategory.bonus:
        return const Color(0xFF9C27B0);
      default:
        return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 100),
      constraints: const BoxConstraints(minWidth: 770),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1F1F33),
            Color(0xFF1A1A28),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(120), // Date
          1: FixedColumnWidth(150), // Employee
          2: FixedColumnWidth(100), // Category
          3: FixedColumnWidth(120), // Amount
          4: FixedColumnWidth(200), // Description
          5: FixedColumnWidth(80), // Actions
        },
        border: TableBorder(
          horizontalInside: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        children: [
          // Header Row
          TableRow(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            children: const [
              _TableHeaderCell('Date'),
              _TableHeaderCell('Employee'),
              _TableHeaderCell('Category'),
              _TableHeaderCell('Amount'),
              _TableHeaderCell('Description'),
              _TableHeaderCell('Actions'),
            ],
          ),
          // Data Rows
          ...transactions.asMap().entries.map((entry) {
            final index = entry.key;
            final transaction = entry.value;
            final date = transaction.createdAt ?? DateTime.now();
            final employeeName = employeeNames[transaction.employeeId ?? ''] ?? 'Loading...';
            final categoryName = _getCategoryName(transaction.category);
            final categoryColor = _getCategoryColor(transaction.category);
            final description = transaction.description ?? '-';
            final isLast = index == transactions.length - 1;

            return TableRow(
              decoration: BoxDecoration(
                color: index % 2 == 0
                    ? Colors.transparent
                    : Colors.white.withOpacity(0.02),
                borderRadius: isLast
                    ? const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      )
                    : null,
              ),
              children: [
                _TableDataCell(
                  formatDate(date),
                  alignment: Alignment.centerLeft,
                ),
                _TableDataCell(
                  employeeName != 'Loading...' ? employeeName : 'Unknown',
                  alignment: Alignment.centerLeft,
                ),
                _TableDataCell(
                  categoryName,
                  alignment: Alignment.center,
                  categoryColor: categoryColor,
                ),
                _TableDataCell(
                  formatCurrency(transaction.amount),
                  alignment: Alignment.centerRight,
                  isAmount: true,
                ),
                _TableDataCell(
                  description,
                  alignment: Alignment.centerLeft,
                ),
                _TableActionCell(
                  onDelete: () => onDelete(transaction),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _TableHeaderCell extends StatelessWidget {
  const _TableHeaderCell(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TableDataCell extends StatelessWidget {
  const _TableDataCell(
    this.text, {
    required this.alignment,
    this.isAmount = false,
    this.categoryColor,
  });

  final String text;
  final Alignment alignment;
  final bool isAmount;
  final Color? categoryColor;

  @override
  Widget build(BuildContext context) {
    Widget content = Text(
      text,
      style: TextStyle(
        color: isAmount
            ? const Color(0xFFFF9800)
            : categoryColor != null
                ? categoryColor!
                : Colors.white70,
        fontSize: 13,
        fontWeight: isAmount ? FontWeight.w700 : FontWeight.w500,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

    if (categoryColor != null) {
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: categoryColor!.withOpacity(0.2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: categoryColor!.withOpacity(0.5),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: categoryColor!,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Align(
        alignment: alignment,
        child: content,
      ),
    );
  }
}

class _TableActionCell extends StatelessWidget {
  const _TableActionCell({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Center(
        child: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
          onPressed: onDelete,
          tooltip: 'Delete',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ),
    );
  }
}

