import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_mobile/presentation/blocs/expense_sub_categories/expense_sub_categories_cubit.dart';
import 'package:dash_mobile/presentation/blocs/expense_sub_categories/expense_sub_categories_state.dart';
import 'package:dash_mobile/presentation/widgets/expense_sub_category_form_dialog.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:dash_mobile/shared/constants/app_typography.dart';
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
        : cubit.state.subCategories
                .map((sc) => sc.order)
                .reduce((a, b) => a > b ? a : b) +
            1;

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
        backgroundColor: AuthColors.background,
        title: const Text(
          'Delete Sub-Category',
          style: TextStyle(color: AuthColors.textMain),
        ),
        content: Text(
          'Are you sure you want to delete "${subCategory.name}"?',
          style: const TextStyle(color: AuthColors.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AuthColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context
          .read<ExpenseSubCategoriesCubit>()
          .deleteSubCategory(subCategory.id);
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
        backgroundColor: AuthColors.background,
        appBar: const ModernPageHeader(
          title: 'Expense Sub-Categories',
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.paddingLG),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search Bar
                      _buildSearchBar(),
                      const SizedBox(height: AppSpacing.paddingLG),
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
                                    _SubCategoryDataListItem(
                                      subCategory: subCategory,
                                      onEdit: () =>
                                          _openSubCategoryDialog(subCategory),
                                      onDelete: () =>
                                          _deleteSubCategory(subCategory),
                                    ),
                                    if (index < subCategories.length - 1)
                                      const SizedBox(
                                          height: AppSpacing.paddingMD),
                                  ],
                                );
                              }),
                            ],
                          );
                        },
                      ),
                    ],
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
                currentIndex: -1,
                onItemTapped: (index) {
                  context.go('/home', extra: index);
                },
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
          style: const TextStyle(color: AuthColors.textMain),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search, color: AuthColors.textSub),
            suffixIcon: state.searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, color: AuthColors.textSub),
                    onPressed: _clearSearch,
                  )
                : null,
            hintText: 'Search sub-categories',
            hintStyle: const TextStyle(color: AuthColors.textDisabled),
            filled: true,
            fillColor: AuthColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
              borderSide: BorderSide.none,
            ),
          ),
        );
      },
    );
  }
}

class _SubCategoryDataListItem extends StatelessWidget {
  const _SubCategoryDataListItem({
    required this.subCategory,
    required this.onEdit,
    required this.onDelete,
  });

  final ExpenseSubCategory subCategory;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Color _getColor() {
    try {
      return Color(
          int.parse(subCategory.colorHex.substring(1), radix: 16) + 0xFF000000);
    } catch (e) {
      return AuthColors.primary;
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

  String _formatSubtitle() {
    final parts = <String>[];
    if (subCategory.transactionCount > 0) {
      parts.add('${subCategory.transactionCount} transactions');
    }
    if (subCategory.totalAmount > 0) {
      parts.add(_formatCurrency(subCategory.totalAmount));
    }
    if (!subCategory.isActive) {
      parts.add('Inactive');
    }
    return parts.isEmpty ? 'No transactions' : parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final icon = _getIcon();

    return Container(
      decoration: BoxDecoration(
        color: AuthColors.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
      ),
      child: DataList(
        title: subCategory.name,
        subtitle: _formatSubtitle(),
        leading: DataListAvatar(
          initial: icon,
          radius: 28,
          statusRingColor:
              subCategory.isActive ? color : AuthColors.textDisabled,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DataListStatusDot(
              color: subCategory.isActive
                  ? AuthColors.success
                  : AuthColors.textDisabled,
              size: 8,
            ),
            const SizedBox(width: AppSpacing.paddingMD),
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                color: AuthColors.textSub,
                size: 20,
              ),
              onPressed: onEdit,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: AppSpacing.paddingSM),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: AuthColors.error,
                size: 20,
              ),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        onTap: onEdit,
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
        padding: const EdgeInsets.all(AppSpacing.paddingXXXL * 1.25),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AuthColors.backgroundAlt.withOpacity(0.6),
              AuthColors.surface.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXXL),
          border: Border.all(
            color: AuthColors.textMainWithOpacity(0.1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AuthColors.secondary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.category_outlined,
                size: 32,
                color: AuthColors.secondary,
              ),
            ),
            const SizedBox(height: AppSpacing.paddingXL),
            const Text(
              'No sub-categories yet',
              style: TextStyle(
                color: AuthColors.textMain,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.paddingSM),
            Text(
              'Start by adding your first expense sub-category',
              style: AppTypography.withColor(
                  AppTypography.body, AuthColors.textSub),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.paddingXXL),
            DashButton(
              label: 'Add Sub-Category',
              icon: Icons.add,
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}
