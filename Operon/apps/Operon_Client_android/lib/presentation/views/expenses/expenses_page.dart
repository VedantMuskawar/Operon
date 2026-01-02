import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_mobile/presentation/blocs/expenses/expenses_cubit.dart';
import 'package:dash_mobile/presentation/blocs/expenses/expenses_state.dart';
import 'package:dash_mobile/presentation/views/expenses/record_expense_page.dart';
import 'package:dash_mobile/presentation/widgets/page_workspace_layout.dart';
import 'package:dash_mobile/presentation/widgets/quick_action_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController = TextEditingController()..addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    context.read<ExpensesCubit>().search(_searchController.text);
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<ExpensesCubit>().search('');
  }

  void _navigateToRecordExpense({ExpenseFormType? type}) {
    context.go('/record-expense', extra: type);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExpensesCubit, ExpensesState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message!)),
          );
        }
      },
      child: Stack(
        children: [
          PageWorkspaceLayout(
            title: 'Expenses',
            currentIndex: 0,
            onBack: () => context.go('/home'),
            onNavTap: (value) => context.go('/home', extra: value),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Summary Cards
            _buildSummaryCards(),
            const SizedBox(height: 16),
            // Tabs
            TabBar(
              controller: _tabController,
              onTap: (index) {
                final cubit = context.read<ExpensesCubit>();
                switch (index) {
                  case 0:
                    cubit.selectExpenseType(ExpenseType.vendorPayment);
                    break;
                  case 1:
                    cubit.selectExpenseType(ExpenseType.salaryDebit);
                    break;
                  case 2:
                    cubit.selectExpenseType(ExpenseType.generalExpense);
                    break;
                }
              },
              tabs: const [
                Tab(text: 'Vendor Payments'),
                Tab(text: 'Salary Payments'),
                Tab(text: 'General Expenses'),
              ],
              labelColor: const Color(0xFF6F4BFF),
              unselectedLabelColor: Colors.white54,
              indicatorColor: const Color(0xFF6F4BFF),
            ),
            const SizedBox(height: 16),
            // Search Bar
            _buildSearchBar(),
            const SizedBox(height: 16),
            // Expenses List
            Builder(
              builder: (context) {
                final media = MediaQuery.of(context);
                final screenHeight = media.size.height;
                // Calculate available height: screen - status bar - header - nav - padding - summary cards - tabs - search - spacing
                final statusBar = media.padding.top;
                const headerHeight = 72.0;
                const navArea = 80.0;
                const bottomPadding = 24.0;
                const summaryCardsHeight = 100.0;
                const tabsHeight = 48.0;
                const searchBarHeight = 56.0;
                const spacing = 48.0; // Total spacing between elements
                
                final availableHeight = screenHeight - 
                    statusBar - 
                    headerHeight - 
                    navArea - 
                    bottomPadding - 
                    summaryCardsHeight - 
                    tabsHeight - 
                    searchBarHeight - 
                    spacing;
                
                return SizedBox(
                  height: availableHeight > 0 ? availableHeight : 400,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildExpensesList(ExpenseType.vendorPayment),
                      _buildExpensesList(ExpenseType.salaryDebit),
                      _buildExpensesList(ExpenseType.generalExpense),
                    ],
                  ),
                );
              },
            ),
          ],
            ),
          ),
          // Quick Action Menu
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
                    icon: Icons.add,
                    label: 'Add Expense',
                    onTap: () => _navigateToRecordExpense(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return BlocBuilder<ExpensesCubit, ExpensesState>(
      builder: (context, state) {
        return Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'Vendor Payments',
                amount: state.totalVendorExpenses,
                color: const Color(0xFF6F4BFF),
                icon: Icons.store,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                title: 'Salary Payments',
                amount: state.totalEmployeeExpenses,
                color: const Color(0xFF5AD8A4),
                icon: Icons.person,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                title: 'General Expenses',
                amount: state.totalGeneralExpenses,
                color: const Color(0xFFFF9800),
                icon: Icons.receipt,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return BlocBuilder<ExpensesCubit, ExpensesState>(
      builder: (context, state) {
        return TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search, color: Colors.white54),
            suffixIcon: state.searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: _clearSearch,
                  )
                : null,
            hintText: 'Search expenses',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF1B1B2C),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpensesList(ExpenseType type) {
    return BlocBuilder<ExpensesCubit, ExpensesState>(
      builder: (context, state) {
        List<Transaction> expenses;
        switch (type) {
          case ExpenseType.vendorPayment:
            expenses = state.vendorExpenses;
            break;
          case ExpenseType.salaryDebit:
            expenses = state.employeeExpenses;
            break;
          case ExpenseType.generalExpense:
            expenses = state.generalExpenses;
            break;
        }

        // Apply search filter
        if (state.searchQuery.isNotEmpty) {
          final query = state.searchQuery.toLowerCase();
          expenses = expenses.where((tx) {
            return (tx.description?.toLowerCase().contains(query) ?? false) ||
                (tx.referenceNumber?.toLowerCase().contains(query) ?? false);
          }).toList();
        }

        if (state.status == ViewStatus.loading && expenses.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (expenses.isEmpty) {
          return _EmptyExpensesState(
            type: type,
            onAdd: () => _navigateToRecordExpense(
              type: type == ExpenseType.vendorPayment
                  ? ExpenseFormType.vendorPayment
                  : type == ExpenseType.salaryDebit
                      ? ExpenseFormType.salaryDebit
                      : ExpenseFormType.generalExpense,
            ),
          );
        }

        return ListView.separated(
          itemCount: expenses.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final expense = expenses[index];
            return _ExpenseTile(expense: expense, type: type);
          },
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
  });

  final String title;
  final double amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₹${amount.toStringAsFixed(0).replaceAllMapped(
              RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
              (Match m) => '${m[1]},',
            )}',
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({
    required this.expense,
    required this.type,
  });

  final Transaction expense;
  final ExpenseType type;

  String _getTitle() {
    switch (type) {
      case ExpenseType.vendorPayment:
        return expense.metadata?['vendorName'] ?? 'Vendor Payment';
      case ExpenseType.salaryDebit:
        return expense.metadata?['employeeName'] ?? 'Salary Payment';
      case ExpenseType.generalExpense:
        return expense.metadata?['subCategoryName'] ?? 'General Expense';
    }
  }

  IconData _getIcon() {
    switch (type) {
      case ExpenseType.vendorPayment:
        return Icons.store;
      case ExpenseType.salaryDebit:
        return Icons.person;
      case ExpenseType.generalExpense:
        return Icons.receipt;
    }
  }

  Color _getColor() {
    switch (type) {
      case ExpenseType.vendorPayment:
        return const Color(0xFF6F4BFF);
      case ExpenseType.salaryDebit:
        return const Color(0xFF5AD8A4);
      case ExpenseType.generalExpense:
        return const Color(0xFFFF9800);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1F1F33).withOpacity(0.6),
            const Color(0xFF1A1A28).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color,
                  color.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_getIcon(), color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTitle(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (expense.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    expense.description!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 12,
                      color: Colors.white.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      () {
                        final date = expense.createdAt ?? DateTime.now();
                        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                        final day = date.day.toString().padLeft(2, '0');
                        final month = months[date.month - 1];
                        final year = date.year;
                        return '$day $month $year';
                      }(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                      ),
                    ),
                    if (expense.referenceNumber != null) ...[
                      const SizedBox(width: 12),
                      Icon(
                        Icons.receipt,
                        size: 12,
                        color: Colors.white.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        expense.referenceNumber!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${expense.amount.toStringAsFixed(0).replaceAllMapped(
                  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                  (Match m) => '${m[1]},',
                )}',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (expense.paymentAccountType != null) ...[
                const SizedBox(height: 4),
                Text(
                  expense.paymentAccountType!.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyExpensesState extends StatelessWidget {
  const _EmptyExpensesState({
    required this.type,
    required this.onAdd,
  });

  final ExpenseType type;
  final VoidCallback onAdd;

  String _getTitle() {
    switch (type) {
      case ExpenseType.vendorPayment:
        return 'No vendor payments yet';
      case ExpenseType.salaryDebit:
        return 'No salary payments yet';
      case ExpenseType.generalExpense:
        return 'No general expenses yet';
    }
  }

  String _getMessage() {
    switch (type) {
      case ExpenseType.vendorPayment:
        return 'Start by recording your first vendor payment';
      case ExpenseType.salaryDebit:
        return 'Start by recording your first salary payment';
      case ExpenseType.generalExpense:
        return 'Start by recording your first general expense';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1B1B2C).withOpacity(0.6),
              const Color(0xFF161622).withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF6F4BFF).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 32,
                color: Color(0xFF6F4BFF),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _getTitle(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getMessage(),
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add Expense'),
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6F4BFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
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

