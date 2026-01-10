import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_mobile/presentation/blocs/expense_sub_categories/expense_sub_categories_cubit.dart';
import 'package:dash_mobile/presentation/blocs/expense_sub_categories/expense_sub_categories_state.dart';
import 'package:dash_mobile/presentation/widgets/expense_sub_category_form_dialog.dart';
import 'package:dash_mobile/presentation/widgets/quick_nav_bar.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ExpenseSubCategoriesPage extends StatefulWidget {
  const ExpenseSubCategoriesPage({super.key});

  @override
  State<ExpenseSubCategoriesPage> createState() =>
      _ExpenseSubCategoriesPageState();
}

class _ExpenseSubCategoriesPageState extends State<ExpenseSubCategoriesPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    context.read<ExpenseSubCategoriesCubit>().search(_searchController.text);
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<ExpenseSubCategoriesCubit>().search('');
  }

  Future<void> _openSubCategoryDialog(
    ExpenseSubCategory? subCategory,
  ) async {
    final cubit = context.read<ExpenseSubCategoriesCubit>();
    final maxOrder = cubit.state.subCategories.isEmpty
        ? 0
        : cubit.state.subCategories.map((sc) => sc.order).reduce((a, b) => a > b ? a : b) + 1;

    final result = await showDialog<ExpenseSubCategory>(
      context: context,
      builder: (context) => ExpenseSubCategoryFormDialog(
        subCategory: subCategory,
        maxOrder: maxOrder,
      ),
    );

    if (result != null && mounted) {
      if (subCategory == null) {
        // Create new
        final newCategory = result.copyWith(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          organizationId: cubit.organizationId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await cubit.createSubCategory(newCategory);
      } else {
        // Update existing
        final updatedCategory = result.copyWith(
          updatedAt: DateTime.now(),
        );
        await cubit.updateSubCategory(updatedCategory);
      }
    }
  }

  Future<void> _deleteSubCategory(ExpenseSubCategory subCategory) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        title: const Text(
          'Delete Sub-Category',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${subCategory.name}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<ExpenseSubCategoriesCubit>().deleteSubCategory(subCategory.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExpenseSubCategoriesCubit, ExpenseSubCategoriesState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message!)),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        appBar: const ModernPageHeader(
          title: 'Expense Sub-Categories',
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            _buildSearchBar(),
            const SizedBox(height: 16),
            // Sub-Categories List
            BlocBuilder<ExpenseSubCategoriesCubit,
                ExpenseSubCategoriesState>(
              builder: (context, state) {
                if (state.status == ViewStatus.loading &&
                    state.subCategories.isEmpty) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final subCategories = state.filteredSubCategories;

                if (subCategories.isEmpty) {
                  return _EmptyState(
                    onAdd: () => _openSubCategoryDialog(null),
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...subCategories.asMap().entries.map((entry) {
                      final index = entry.key;
                      final subCategory = entry.value;
                      return Column(
                        children: [
                          _SubCategoryTile(
                            subCategory: subCategory,
                            onEdit: () => _openSubCategoryDialog(subCategory),
                            onDelete: () => _deleteSubCategory(subCategory),
                          ),
                          if (index < subCategories.length - 1)
                            const SizedBox(height: 12),
                        ],
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          ],
                ),
                      ),
                    ),
            QuickNavBar(
              currentIndex: 0,
              onTap: (value) => context.go('/home', extra: value),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return BlocBuilder<ExpenseSubCategoriesCubit, ExpenseSubCategoriesState>(
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
            hintText: 'Search sub-categories',
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
}

class _SubCategoryTile extends StatelessWidget {
  const _SubCategoryTile({
    required this.subCategory,
    required this.onEdit,
    required this.onDelete,
  });

  final ExpenseSubCategory subCategory;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Color _getColor() {
    try {
      return Color(int.parse(subCategory.colorHex.substring(1), radix: 16) + 0xFF000000);
    } catch (e) {
      return const Color(0xFF6F4BFF);
    }
  }

  String _getIcon() {
    final iconMap = {
      'home': '🏠',
      'wifi': '📡',
      'car': '🚗',
      'shopping': '🛒',
      'food': '🍔',
      'phone': '📱',
      'laptop': '💻',
      'tools': '🔧',
      'money': '💰',
      'receipt': '🧾',
      'building': '🏢',
      'gas': '⛽',
    };
    return iconMap[subCategory.icon] ?? '📁';
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final icon = _getIcon();

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
          // Icon/Color indicator
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                icon,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subCategory.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (!subCategory.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Inactive',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                if (subCategory.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subCategory.description!,
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
                      Icons.receipt_long,
                      size: 12,
                      color: Colors.white.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${subCategory.transactionCount} transactions',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.account_balance_wallet,
                      size: 12,
                      color: Colors.white.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatCurrency(subCategory.totalAmount),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Actions
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white54),
            color: const Color(0xFF1B1B2C),
            onSelected: (value) {
              if (value == 'edit') {
                onEdit();
              } else if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.white70, size: 18),
                    SizedBox(width: 8),
                    Text('Edit', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

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
                Icons.category_outlined,
                size: 32,
                color: Color(0xFF6F4BFF),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No sub-categories yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start by adding your first expense sub-category',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add Sub-Category'),
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

