import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/presentation/blocs/expense_sub_categories/expense_sub_categories_cubit.dart';
import 'package:dash_web/presentation/blocs/expense_sub_categories/expense_sub_categories_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Content widget for sidebar use
class ExpenseSubCategoriesPageContent extends StatefulWidget {
  const ExpenseSubCategoriesPageContent({super.key});

  @override
  State<ExpenseSubCategoriesPageContent> createState() =>
      _ExpenseSubCategoriesPageContentState();
}

class _ExpenseSubCategoriesPageContentState
    extends State<ExpenseSubCategoriesPageContent> {
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
      builder: (context) => _ExpenseSubCategoryFormDialog(
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
        backgroundColor: AuthColors.surface,
        title: const Text(
          'Delete Sub-Category',
          style: TextStyle(color: AuthColors.textMain),
        ),
        content: Text(
          'Are you sure you want to delete "${subCategory.name}"?',
          style: const TextStyle(color: AuthColors.textSub),
        ),
        actions: [
          DashButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(false),
            variant: DashButtonVariant.text,
          ),
          DashButton(
            label: 'Delete',
            onPressed: () => Navigator.of(context).pop(true),
            variant: DashButtonVariant.text,
            isDestructive: true,
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
          DashSnackbar.show(context, message: state.message!, isError: true);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: AuthColors.surface,
              border: Border.all(color: AuthColors.textMain.withOpacity(0.1)),
            ),
            child: const Text(
              'Manage expense sub-categories for better expense tracking and organization.',
              style: TextStyle(color: AuthColors.textSub),
            ),
          ),
          const SizedBox(height: 20),
          // Search Bar
          _buildSearchBar(),
          const SizedBox(height: 20),
          // Add Button
          SizedBox(
            width: double.infinity,
            child: DashButton(
              label: 'Add Sub-Category',
              onPressed: () => _openSubCategoryDialog(null),
            ),
          ),
          const SizedBox(height: 20),
          // Sub-Categories List
          BlocBuilder<ExpenseSubCategoriesCubit, ExpenseSubCategoriesState>(
            builder: (context, state) {
              if (state.status == ViewStatus.loading &&
                  state.subCategories.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final subCategories = state.filteredSubCategories;

              if (subCategories.isEmpty) {
                return const EmptyState(
                  icon: Icons.category_outlined,
                  title: 'No sub-categories yet',
                  message: 'Start by adding your first expense sub-category',
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: subCategories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final subCategory = subCategories[index];
                  return _SubCategoryDataListItem(
                    subCategory: subCategory,
                    onEdit: () => _openSubCategoryDialog(subCategory),
                    onDelete: () => _deleteSubCategory(subCategory),
                  );
                },
              );
            },
          ),
        ],
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
            hintText: 'Search sub-categories',
            hintStyle: const TextStyle(color: AuthColors.textSub),
            prefixIcon: const Icon(Icons.search, color: AuthColors.textSub),
            suffixIcon: state.searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, color: AuthColors.textSub),
                    onPressed: _clearSearch,
                  )
                : null,
            filled: true,
            fillColor: AuthColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AuthColors.textMain.withOpacity(0.1),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AuthColors.textMain.withOpacity(0.1),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AuthColors.primary,
                width: 2,
              ),
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
      return Color(int.parse(subCategory.colorHex.substring(1), radix: 16) + 0xFF000000);
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

  String _formatSubtitle() {
    final parts = <String>[];
    if (subCategory.transactionCount > 0) {
      parts.add('${subCategory.transactionCount} transactions');
    }
    if (subCategory.totalAmount > 0) {
      parts.add('₹${subCategory.totalAmount.toStringAsFixed(0)}');
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

    return DataList(
      title: subCategory.name,
      subtitle: _formatSubtitle(),
      leading: DataListAvatar(
        initial: icon,
        radius: 28,
        statusRingColor: subCategory.isActive ? color : AuthColors.textDisabled,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DataListStatusDot(
            color: subCategory.isActive ? AuthColors.success : AuthColors.textDisabled,
            size: 8,
          ),
          const SizedBox(width: 12),
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
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: AuthColors.textSub,
              size: 20,
            ),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      onTap: onEdit,
    );
  }
}

class _ExpenseSubCategoryFormDialog extends StatefulWidget {
  const _ExpenseSubCategoryFormDialog({
    this.subCategory,
    required this.maxOrder,
  });

  final ExpenseSubCategory? subCategory;
  final int maxOrder;

  @override
  State<_ExpenseSubCategoryFormDialog> createState() =>
      _ExpenseSubCategoryFormDialogState();
}

class _ExpenseSubCategoryFormDialogState
    extends State<_ExpenseSubCategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _orderController;
  String _selectedColor = '#6F4BFF';
  String? _selectedIcon;
  bool _isActive = true;

  final List<String> _colorOptions = [
    '#6F4BFF',
    '#5AD8A4',
    '#FF9800',
    '#2196F3',
    '#E91E63',
    '#9C27B0',
    '#00BCD4',
    '#4CAF50',
    '#FF5722',
    '#795548',
  ];

  final List<Map<String, String>> _iconOptions = [
    {'name': 'home', 'icon': '🏠'},
    {'name': 'wifi', 'icon': '📡'},
    {'name': 'car', 'icon': '🚗'},
    {'name': 'shopping', 'icon': '🛒'},
    {'name': 'food', 'icon': '🍔'},
    {'name': 'phone', 'icon': '📱'},
    {'name': 'laptop', 'icon': '💻'},
    {'name': 'tools', 'icon': '🔧'},
    {'name': 'money', 'icon': '💰'},
    {'name': 'receipt', 'icon': '🧾'},
    {'name': 'building', 'icon': '🏢'},
    {'name': 'gas', 'icon': '⛽'},
  ];

  @override
  void initState() {
    super.initState();
    final subCategory = widget.subCategory;
    _nameController = TextEditingController(text: subCategory?.name ?? '');
    _descriptionController =
        TextEditingController(text: subCategory?.description ?? '');
    _orderController = TextEditingController(
        text: subCategory?.order.toString() ?? widget.maxOrder.toString());
    _selectedColor = subCategory?.colorHex ?? '#6F4BFF';
    _selectedIcon = subCategory?.icon;
    _isActive = subCategory?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.subCategory != null;

    return AlertDialog(
      backgroundColor: AuthColors.surface,
      title: Text(
        isEditing ? 'Edit Sub-Category' : 'Add Sub-Category',
        style: const TextStyle(color: AuthColors.textMain),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: AuthColors.textMain),
                decoration: _inputDecoration('Name *'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Enter name'
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                style: const TextStyle(color: AuthColors.textMain),
                decoration: _inputDecoration('Description (Optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _orderController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AuthColors.textMain),
                decoration: _inputDecoration('Order'),
                validator: (value) {
                  final parsed = int.tryParse(value ?? '');
                  if (parsed == null || parsed < 0) {
                    return 'Enter a valid order';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Color',
                style: TextStyle(
                  color: AuthColors.textMain,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _colorOptions.map((color) {
                  final isSelected = _selectedColor == color;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(int.parse(color.substring(1), radix: 16) + 0xFF000000),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AuthColors.primary : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text(
                'Icon',
                style: TextStyle(
                  color: AuthColors.textMain,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _iconOptions.map((iconOption) {
                  final isSelected = _selectedIcon == iconOption['name'];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = iconOption['name']),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AuthColors.primary.withOpacity(0.2)
                            : AuthColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AuthColors.primary
                              : AuthColors.textMain.withOpacity(0.1),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          iconOption['icon']!,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text(
                  'Active',
                  style: TextStyle(color: AuthColors.textMain),
                ),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
                activeThumbColor: AuthColors.primary,
              ),
            ],
          ),
        ),
      ),
      actions: [
        DashButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
          variant: DashButtonVariant.text,
        ),
        DashButton(
          label: isEditing ? 'Save' : 'Create',
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            final subCategory = ExpenseSubCategory(
              id: widget.subCategory?.id ?? '',
              name: _nameController.text.trim(),
              description: _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
              colorHex: _selectedColor,
              icon: _selectedIcon ?? 'home',
              order: int.tryParse(_orderController.text.trim()) ?? widget.maxOrder,
              isActive: _isActive,
              organizationId: widget.subCategory?.organizationId ?? '',
              transactionCount: widget.subCategory?.transactionCount ?? 0,
              totalAmount: widget.subCategory?.totalAmount ?? 0.0,
              createdAt: widget.subCategory?.createdAt ?? DateTime.now(),
              updatedAt: DateTime.now(),
            );
            Navigator.of(context).pop(subCategory);
          },
          variant: DashButtonVariant.text,
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AuthColors.textSub),
      filled: true,
      fillColor: AuthColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AuthColors.textMain.withOpacity(0.1),
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AuthColors.textMain.withOpacity(0.1),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AuthColors.primary,
          width: 2,
        ),
      ),
    );
  }
}
