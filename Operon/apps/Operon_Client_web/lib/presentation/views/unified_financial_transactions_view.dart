import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/presentation/blocs/financial_transactions/unified_financial_transactions_cubit.dart';
import 'package:dash_web/presentation/blocs/financial_transactions/unified_financial_transactions_state.dart';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';

class UnifiedFinancialTransactionsView extends StatefulWidget {
  const UnifiedFinancialTransactionsView({super.key});

  @override
  State<UnifiedFinancialTransactionsView> createState() =>
      _UnifiedFinancialTransactionsViewState();
}

class _UnifiedFinancialTransactionsViewState
    extends State<UnifiedFinancialTransactionsView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    // Load data on init
    context.read<UnifiedFinancialTransactionsCubit>().load();
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    context
        .read<UnifiedFinancialTransactionsCubit>()
        .search(_searchController.text);
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<UnifiedFinancialTransactionsCubit>().search('');
  }

  String _formatDatePicker(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    return '$day $month $year';
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    final hour = date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour < 12 ? 'am' : 'pm';
    return '$day $month $year • ${hour == 0 ? 12 : hour}:$minute $period';
  }

  Future<void> _selectStartDate() async {
    final state = context.read<UnifiedFinancialTransactionsCubit>().state;
    final picked = await showDatePicker(
      context: context,
      initialDate: state.startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: state.endDate ?? DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AuthColors.legacyAccent,
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
      final startDate = DateTime(picked.year, picked.month, picked.day);
      final endDate = state.endDate ?? DateTime.now();
      context.read<UnifiedFinancialTransactionsCubit>().setDateRange(
            startDate.isAfter(endDate) ? startDate : startDate,
            endDate.isBefore(startDate) ? DateTime(picked.year, picked.month, picked.day, 23, 59, 59) : endDate,
          );
    }
  }

  Future<void> _selectEndDate() async {
    final state = context.read<UnifiedFinancialTransactionsCubit>().state;
    final picked = await showDatePicker(
      context: context,
      initialDate: state.endDate ?? DateTime.now(),
      firstDate: state.startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AuthColors.legacyAccent,
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
      context.read<UnifiedFinancialTransactionsCubit>().setDateRange(
            state.startDate,
            DateTime(picked.year, picked.month, picked.day, 23, 59, 59),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<UnifiedFinancialTransactionsCubit,
        UnifiedFinancialTransactionsState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message!),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: SectionWorkspaceLayout(
        panelTitle: 'Financial Transactions',
        currentIndex: -1,
        onNavTap: (index) => context.go('/home?section=$index'),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards
              _buildSummaryCards(),
              const SizedBox(height: 24),
              // Tab Selector
              _buildTabSelector(),
              const SizedBox(height: 24),
              // Filter Bar (Date Range + Search + View Toggle)
              _buildFilterBar(),
              const SizedBox(height: 24),
              // Transaction List/Grid
              _buildTransactionList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return BlocBuilder<UnifiedFinancialTransactionsCubit,
        UnifiedFinancialTransactionsState>(
      builder: (context, state) {
        return TransactionSummaryCards(
          income: state.totalIncome,
          payments: state.totalExpenses,
          purchases: state.totalPurchases,
          netBalance: state.netBalance,
          formatCurrency: _formatCurrency,
        );
      },
    );
  }

  Widget _buildTabSelector() {
    return BlocBuilder<UnifiedFinancialTransactionsCubit,
        UnifiedFinancialTransactionsState>(
      builder: (context, state) {
        return TransactionTypeSegmentedControl(
          selectedIndex: state.selectedTab.index,
          onSelectionChanged: (index) {
            context.read<UnifiedFinancialTransactionsCubit>().selectTab(
                  TransactionTabType.values[index],
                );
          },
        );
      },
    );
  }

  Widget _buildFilterBar() {
    return BlocBuilder<UnifiedFinancialTransactionsCubit,
        UnifiedFinancialTransactionsState>(
      builder: (context, state) {
        return Row(
          children: [
            // Date Range Pickers
            Container(
              constraints: const BoxConstraints(maxWidth: 200),
              child: InkWell(
                onTap: _selectStartDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AuthColors.surface.withOpacity(0.6),
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
                          const Text(
                            'Start',
                            style: TextStyle(color: AuthColors.textSub, fontSize: 10),
                          ),
                          Text(
                            state.startDate != null
                                ? _formatDatePicker(state.startDate!)
                                : 'Select',
                            style: const TextStyle(
                              color: AuthColors.textMain,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              constraints: const BoxConstraints(maxWidth: 200),
              child: InkWell(
                onTap: _selectEndDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AuthColors.surface.withOpacity(0.6),
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
                          const Text(
                            'End',
                            style: TextStyle(color: AuthColors.textSub, fontSize: 10),
                          ),
                          Text(
                            state.endDate != null
                                ? _formatDatePicker(state.endDate!)
                                : 'Select',
                            style: const TextStyle(
                              color: AuthColors.textMain,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Search Bar
            Expanded(
              child:               TextField(
                controller: _searchController,
                style: const TextStyle(color: AuthColors.textMain),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: AuthColors.textSub, size: 20),
                  suffixIcon: state.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, color: AuthColors.textSub, size: 20),
                          onPressed: _clearSearch,
                        )
                      : null,
                  hintText: 'Search transactions...',
                  hintStyle: const TextStyle(color: AuthColors.textSub),
                  filled: true,
                  fillColor: AuthColors.surface.withOpacity(0.6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // View Toggle
            Container(
              decoration: BoxDecoration(
                color: AuthColors.surface.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ViewToggleButton(
                    icon: Icons.grid_view,
                    isSelected: !state.isListView,
                    onTap: () => context.read<UnifiedFinancialTransactionsCubit>().toggleView(),
                    tooltip: 'Grid View',
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: AuthColors.textMainWithOpacity(0.1),
                  ),
                  _ViewToggleButton(
                    icon: Icons.list,
                    isSelected: state.isListView,
                    onTap: () => context.read<UnifiedFinancialTransactionsCubit>().toggleView(),
                    tooltip: 'List View',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Refresh Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AuthColors.surface.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
              ),
              child: TextButton.icon(
                onPressed: () => context.read<UnifiedFinancialTransactionsCubit>().refresh(),
                icon: const Icon(Icons.refresh, color: AuthColors.textSub, size: 16),
                label: const Text('Refresh', style: TextStyle(color: AuthColors.textSub, fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTransactionList() {
    return BlocBuilder<UnifiedFinancialTransactionsCubit,
        UnifiedFinancialTransactionsState>(
      builder: (context, state) {
        final isLoading = state.status == ViewStatus.loading;
        var transactions = state.currentTransactions;

        // Apply search filter
        if (state.searchQuery.isNotEmpty) {
          final query = state.searchQuery.toLowerCase();
          transactions = transactions.where((tx) {
            final description = tx.description?.toLowerCase() ?? '';
            final reference = tx.referenceNumber?.toLowerCase() ?? '';
            final amount = tx.amount.toString();
            return description.contains(query) ||
                reference.contains(query) ||
                amount.contains(query);
          }).toList();
        }

        if (isLoading && transactions.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (transactions.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: AuthColors.textDisabled,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No transactions found',
                    style: TextStyle(
                      color: AuthColors.textSub,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Group transactions by date
        final groupedTransactions = _groupTransactionsByDate(transactions);

        if (state.isListView) {
          return AnimationLimiter(
            child: Column(
              children: [
                for (final entry in groupedTransactions.entries) ...[
                  TransactionDateGroupHeader(date: entry.key),
                  const SizedBox(height: 8),
                  ...entry.value.asMap().entries.map((txEntry) {
                    final index = txEntry.key;
                    final transaction = txEntry.value;
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 200),
                      child: SlideAnimation(
                        verticalOffset: 50.0,
                        child: FadeInAnimation(
                          curve: Curves.easeOut,
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: index < entry.value.length - 1 ? 12 : 0,
                            ),
                            child: _buildTransactionTile(transaction, true),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          );
        } else {
          // Grid view
          return AnimationLimiter(
            child: Column(
              children: [
                for (final entry in groupedTransactions.entries) ...[
                  TransactionDateGroupHeader(date: entry.key),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: entry.value.length,
                    itemBuilder: (context, index) {
                      final transaction = entry.value[index];
                      return AnimationConfiguration.staggeredGrid(
                        position: index,
                        duration: const Duration(milliseconds: 200),
                        columnCount: 3,
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            curve: Curves.easeOut,
                            child: _buildTransactionTile(transaction, false),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildTransactionTile(Transaction transaction, bool isListView) {
    String title;
    String? subtitle;

    switch (transaction.category) {
      case TransactionCategory.clientPayment:
        title = transaction.metadata?['clientName'] ?? 'Client Payment';
        break;
      case TransactionCategory.vendorPurchase:
        title = transaction.metadata?['vendorName'] ?? 'Vendor Purchase';
        subtitle = transaction.referenceNumber;
        break;
      case TransactionCategory.vendorPayment:
        title = transaction.metadata?['vendorName'] ?? 'Vendor Payment';
        break;
      case TransactionCategory.salaryDebit:
        title = transaction.metadata?['employeeName'] ?? 'Salary Payment';
        break;
      case TransactionCategory.generalExpense:
        title = transaction.metadata?['subCategoryName'] ?? 'General Expense';
        subtitle = transaction.description;
        break;
      default:
        title = transaction.description ?? 'Transaction';
    }

    return TransactionListTile(
      transaction: transaction,
      title: title,
      subtitle: subtitle,
      formatCurrency: _formatCurrency,
      formatDate: _formatDate,
      isGridView: !isListView,
      onDelete: () => _showDeleteConfirmation(context, transaction),
    );
  }

  Map<DateTime, List<Transaction>> _groupTransactionsByDate(
    List<Transaction> transactions,
  ) {
    final Map<DateTime, List<Transaction>> grouped = {};

    for (final tx in transactions) {
      final date = tx.createdAt ?? DateTime.now();
      final dateOnly = DateTime(date.year, date.month, date.day);

      if (grouped.containsKey(dateOnly)) {
        grouped[dateOnly]!.add(tx);
      } else {
        grouped[dateOnly] = [tx];
      }
    }

    // Sort dates descending (most recent first)
    final sortedDates = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    // Sort transactions within each date group
    for (final date in sortedDates) {
      grouped[date]!.sort((a, b) {
        final aDate = a.createdAt ?? DateTime(1970);
        final bDate = b.createdAt ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });
    }

    return Map.fromEntries(
      sortedDates.map((date) => MapEntry(date, grouped[date]!)),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    Transaction transaction,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AuthColors.surface,
        title: const Text(
          'Delete Transaction',
          style: TextStyle(color: AuthColors.textMain),
        ),
        content: const Text(
          'Are you sure you want to delete this transaction?',
          style: TextStyle(color: AuthColors.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context
                  .read<UnifiedFinancialTransactionsCubit>()
                  .deleteTransaction(transaction.id);
              Navigator.of(dialogContext).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: AuthColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  const _ViewToggleButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected
                ? AuthColors.legacyAccent.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isSelected
                ? AuthColors.legacyAccent
                : AuthColors.textSub,
          ),
        ),
      ),
    );
  }
}
