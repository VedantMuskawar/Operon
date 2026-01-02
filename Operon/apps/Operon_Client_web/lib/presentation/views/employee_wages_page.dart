import 'dart:async';

import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_web/presentation/blocs/employee_wages/employee_wages_cubit.dart';
import 'package:dash_web/presentation/blocs/employee_wages/employee_wages_state.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:dash_web/presentation/views/employee_wages/credit_salary_dialog.dart';
import 'package:dash_web/presentation/views/employee_wages/record_bonus_dialog.dart';
import 'package:flutter/foundation.dart';
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

  // Pagination state
  int _currentPage = 0;
  int _itemsPerPage = 10;

  String? _currentOrgId;
  List<Transaction> _previousTransactions = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    
    if (organization != null && _currentOrgId != organization.id) {
      _currentOrgId = organization.id;
      _previousTransactions = [];
      _employeeNames.clear();
    }
  }

  Future<void> _fetchEmployeeNames(List<Transaction> transactions) async {
    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    if (organization == null) return;

    try {
      // Get employee IDs that we don't have names for yet
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

    // Apply search filter
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
          final aName = (_employeeNames[a.employeeId ?? ''] ?? '').toLowerCase();
          final bName = (_employeeNames[b.employeeId ?? ''] ?? '').toLowerCase();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete transaction: $e'),
            backgroundColor: Colors.red,
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
        backgroundColor: const Color(0xFF11111B),
        title: const Text(
          'Delete Transaction',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete this transaction?\n\n'
          'Employee: $employeeName\n'
          'Type: $categoryName\n'
          'Amount: ${_formatCurrency(transaction.amount)}',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _deleteTransaction(transaction.id);
              Navigator.of(dialogContext).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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
            return _LoadingState();
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
          
          // Fetch employee names when transactions change
          if (transactions.length != _previousTransactions.length ||
              !_areTransactionListsEqual(transactions, _previousTransactions)) {
            _previousTransactions = List.from(transactions);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fetchEmployeeNames(transactions);
            });
          }
          final filtered = _applyFiltersAndSort(transactions);
          final totalAmount = transactions.fold<double>(0.0, (sum, tx) => sum + tx.amount);
          final salaryCount = transactions.where((tx) => tx.category == TransactionCategory.salaryCredit).length;
          final bonusCount = transactions.where((tx) => tx.category == TransactionCategory.bonus).length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Statistics Dashboard
              _WagesStatsHeader(
                totalTransactions: transactions.length,
                totalAmount: totalAmount,
                salaryCount: salaryCount,
                bonusCount: bonusCount,
              ),
              const SizedBox(height: 32),

              // Top Action Bar with Filters
              Row(
                children: [
                  // Search Bar
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1B2C).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: TextField(
                        onChanged: (v) => setState(() {
                          _query = v;
                          _currentPage = 0;
                        }),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search by employee, description...',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          prefixIcon: const Icon(Icons.search, color: Colors.white54),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.white54),
                                  onPressed: () => setState(() => _query = ''),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Sort Options
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1B2C).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sort, size: 16, color: Colors.white.withValues(alpha: 0.7)),
                        const SizedBox(width: 6),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<_WagesSortOption>(
                            value: _sortOption,
                            dropdownColor: const Color(0xFF1B1B2C),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            items: const [
                              DropdownMenuItem(
                                value: _WagesSortOption.dateNewest,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.calendar_today, size: 16, color: Colors.white70),
                                    SizedBox(width: 8),
                                    Text('Date (Newest)'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: _WagesSortOption.dateOldest,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.calendar_today, size: 16, color: Colors.white70),
                                    SizedBox(width: 8),
                                    Text('Date (Oldest)'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: _WagesSortOption.amountHigh,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.trending_down, size: 16, color: Colors.white70),
                                    SizedBox(width: 8),
                                    Text('Amount (High to Low)'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: _WagesSortOption.amountLow,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.trending_up, size: 16, color: Colors.white70),
                                    SizedBox(width: 8),
                                    Text('Amount (Low to High)'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: _WagesSortOption.employeeAsc,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.person, size: 16, color: Colors.white70),
                                    SizedBox(width: 8),
                                    Text('Employee (A-Z)'),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _sortOption = value;
                                  _currentPage = 0;
                                });
                              }
                            },
                            icon: Icon(Icons.arrow_drop_down, color: Colors.white.withValues(alpha: 0.7), size: 20),
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Results count
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1B2C).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      '${filtered.length} ${filtered.length == 1 ? 'transaction' : 'transactions'}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Credit Salary Button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.payments, size: 20),
                    label: const Text('Credit Salary'),
                    onPressed: () {
                      final cubit = context.read<EmployeeWagesCubit>();
                      showDialog(
                        context: context,
                        builder: (dialogContext) => BlocProvider.value(
                          value: cubit,
                          child: CreditSalaryDialog(
                            onSalaryCredited: () {
                              // Streams will auto-update
                            },
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6F4BFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Record Bonus Button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.card_giftcard, size: 20),
                    label: const Text('Record Bonus'),
                    onPressed: () {
                      final cubit = context.read<EmployeeWagesCubit>();
                      showDialog(
                        context: context,
                        builder: (dialogContext) => BlocProvider.value(
                          value: cubit,
                          child: RecordBonusDialog(
                            onBonusRecorded: () {
                              // Streams will auto-update
                            },
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9C27B0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Transactions Table
              if (filtered.isEmpty && _query.isNotEmpty)
                _EmptySearchState(query: _query)
              else if (filtered.isEmpty)
                Builder(
                  builder: (context) => _EmptyTransactionsState(
                    onCreditSalary: () {
                      final cubit = context.read<EmployeeWagesCubit>();
                      showDialog(
                        context: context,
                        builder: (dialogContext) => BlocProvider.value(
                          value: cubit,
                          child: CreditSalaryDialog(
                            onSalaryCredited: () {},
                          ),
                        ),
                      );
                    },
                  ),
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Table
                    _WagesTransactionTable(
                      transactions: _getPaginatedData(filtered),
                      formatCurrency: _formatCurrency,
                      formatDate: _formatDate,
                      employeeNames: _employeeNames,
                      onDelete: (transaction) => _showDeleteConfirmation(context, transaction),
                    ),
                    const SizedBox(height: 16),
                    // Pagination Controls
                    _PaginationControls(
                      currentPage: _currentPage,
                      totalPages: _getTotalPages(filtered.length),
                      totalItems: filtered.length,
                      itemsPerPage: _itemsPerPage,
                      onPageChanged: (page) {
                        setState(() {
                          _currentPage = page;
                        });
                      },
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _WagesStatsHeader extends StatelessWidget {
  const _WagesStatsHeader({
    required this.totalTransactions,
    required this.totalAmount,
    required this.salaryCount,
    required this.bonusCount,
  });

  final int totalTransactions;
  final double totalAmount;
  final int salaryCount;
  final int bonusCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1200;
        return isWide
            ? Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.receipt_long,
                      label: 'Total Transactions',
                      value: totalTransactions.toString(),
                      color: const Color(0xFF6F4BFF),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Total Amount',
                      value: '₹${totalAmount.toStringAsFixed(0).replaceAllMapped(
                        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                        (Match m) => '${m[1]},',
                      )}',
                      color: const Color(0xFFFF9800),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.payments,
                      label: 'Salary Credits',
                      value: salaryCount.toString(),
                      color: const Color(0xFF5AD8A4),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.card_giftcard,
                      label: 'Bonuses',
                      value: bonusCount.toString(),
                      color: const Color(0xFF2196F3),
                    ),
                  ),
                ],
              )
            : Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _StatCard(
                    icon: Icons.receipt_long,
                    label: 'Total Transactions',
                    value: totalTransactions.toString(),
                    color: const Color(0xFF6F4BFF),
                  ),
                  _StatCard(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Total Amount',
                    value: '₹${totalAmount.toStringAsFixed(0).replaceAllMapped(
                      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                      (Match m) => '${m[1]},',
                    )}',
                    color: const Color(0xFFFF9800),
                  ),
                  _StatCard(
                    icon: Icons.payments,
                    label: 'Salary Credits',
                    value: salaryCount.toString(),
                    color: const Color(0xFF5AD8A4),
                  ),
                  _StatCard(
                    icon: Icons.card_giftcard,
                    label: 'Bonuses',
                    value: bonusCount.toString(),
                    color: const Color(0xFF2196F3),
                  ),
                ],
              );
      },
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1F1F33),
            Color(0xFF1A1A28),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
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
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
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

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Loading employee wages...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
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
          color: const Color(0xFF1B1B2C).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.redAccent.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.redAccent.withValues(alpha: 0.7),
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
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
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
  const _EmptyTransactionsState({required this.onCreditSalary});

  final VoidCallback onCreditSalary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1B1B2C).withValues(alpha: 0.6),
              const Color(0xFF161622).withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF6F4BFF).withValues(alpha: 0.15),
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
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start by crediting salary to your employees',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.payments, size: 20),
              label: const Text('Credit Salary'),
              onPressed: onCreditSalary,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6F4BFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
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
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
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
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WagesTransactionTable extends StatelessWidget {
  const _WagesTransactionTable({
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
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1F1F33),
            Color(0xFF1A1A28),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            Colors.black.withValues(alpha: 0.3),
          ),
          dataRowColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return Colors.white.withValues(alpha: 0.05);
            }
            return Colors.transparent;
          }),
          headingTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          dataTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
          columns: const [
            DataColumn(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.white70),
                  SizedBox(width: 8),
                  Text('Date'),
                ],
              ),
            ),
            DataColumn(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person, size: 16, color: Colors.white70),
                  SizedBox(width: 8),
                  Text('Employee'),
                ],
              ),
            ),
            DataColumn(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.category, size: 16, color: Colors.white70),
                  SizedBox(width: 8),
                  Text('Type'),
                ],
              ),
            ),
            DataColumn(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.currency_rupee, size: 16, color: Colors.white70),
                  SizedBox(width: 8),
                  Text('Amount'),
                ],
              ),
              numeric: true,
            ),
            DataColumn(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.description, size: 16, color: Colors.white70),
                  SizedBox(width: 8),
                  Text('Description'),
                ],
              ),
            ),
            DataColumn(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.more_vert, size: 16, color: Colors.white70),
                  SizedBox(width: 8),
                  Text('Actions'),
                ],
              ),
            ),
          ],
          rows: transactions.map((tx) {
            final date = tx.createdAt ?? DateTime.now();
            final employeeName = employeeNames[tx.employeeId ?? ''] ?? 'Unknown Employee';
            final categoryName = tx.category == TransactionCategory.salaryCredit
                ? 'Salary'
                : tx.category == TransactionCategory.bonus
                    ? 'Bonus'
                    : tx.category.name;

            return DataRow(
              cells: [
                DataCell(Text(formatDate(date))),
                DataCell(
                  Text(
                    employeeName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: tx.category == TransactionCategory.salaryCredit
                          ? const Color(0xFF6F4BFF).withValues(alpha: 0.2)
                          : const Color(0xFF9C27B0).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      categoryName,
                      style: TextStyle(
                        color: tx.category == TransactionCategory.salaryCredit
                            ? const Color(0xFF6F4BFF)
                            : const Color(0xFF9C27B0),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    formatCurrency(tx.amount),
                    style: const TextStyle(
                      color: Color(0xFFFF9800),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    tx.description ?? '-',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.redAccent.withValues(alpha: 0.8),
                    onPressed: () => onDelete(tx),
                    tooltip: 'Delete transaction',
                  ),
                ),
              ],
            );
          }).toList(),
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
    final startItem = (currentPage * itemsPerPage) + 1;
    final endItem = ((currentPage + 1) * itemsPerPage).clamp(0, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B2C).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Items info
          Text(
            'Showing $startItem-$endItem of $totalItems',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          // Pagination buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // First page
              IconButton(
                icon: const Icon(Icons.first_page, size: 20),
                color: currentPage == 0
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.7),
                onPressed: currentPage == 0
                    ? null
                    : () => onPageChanged(0),
                tooltip: 'First page',
              ),
              // Previous page
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 24),
                color: currentPage == 0
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.7),
                onPressed: currentPage == 0
                    ? null
                    : () => onPageChanged(currentPage - 1),
                tooltip: 'Previous page',
              ),
              // Page numbers
              ...List.generate(
                totalPages.clamp(0, 7), // Show max 7 page numbers
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
                      color: isCurrentPage
                          ? const Color(0xFF6F4BFF)
                          : Colors.transparent,
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
                              color: isCurrentPage
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.7),
                              fontSize: 14,
                              fontWeight: isCurrentPage
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Next page
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 24),
                color: currentPage >= totalPages - 1
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.7),
                onPressed: currentPage >= totalPages - 1
                    ? null
                    : () => onPageChanged(currentPage + 1),
                tooltip: 'Next page',
              ),
              // Last page
              IconButton(
                icon: const Icon(Icons.last_page, size: 20),
                color: currentPage >= totalPages - 1
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.7),
                onPressed: currentPage >= totalPages - 1
                    ? null
                    : () => onPageChanged(totalPages - 1),
                tooltip: 'Last page',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

