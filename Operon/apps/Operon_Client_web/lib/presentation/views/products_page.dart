import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_web/presentation/blocs/products/products_cubit.dart';
import 'package:dash_web/presentation/widgets/page_workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';

class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ProductsCubit>();
    return BlocListener<ProductsCubit, ProductsState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          DashSnackbar.show(context, message: state.message!, isError: true);
        }
      },
      child: PageWorkspaceLayout(
        title: 'Products',
        currentIndex: 4,
        onBack: () => context.go('/home'),
        onNavTap: (value) => context.go('/home?section=$value'),
        child: ProductsPageContent(canCreate: cubit.canCreate),
      ),
    );
  }
}

// Content widget for sidebar use
class ProductsPageContent extends StatelessWidget {
  const ProductsPageContent({required this.canCreate, super.key});

  final bool canCreate;

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ProductsCubit>();
    // Background comes from PageWorkspaceLayout's Container (AuthColors.background)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canCreate)
          SizedBox(
            width: double.infinity,
            child: DashButton(
              label: 'Add Product',
              icon: Icons.add,
              onPressed: () => _openProductDialog(context),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AuthColors.textMain.withOpacity(0.1),
            ),
            child: const Text(
              'You have read-only access to products.',
              style: TextStyle(color: AuthColors.textSub),
            ),
          ),
        const SizedBox(height: 20),
        BlocBuilder<ProductsCubit, ProductsState>(
          builder: (context, state) {
            if (state.status == ViewStatus.loading) {
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
            if (state.products.isEmpty) {
              return EmptyState(
                icon: Icons.inventory_2_outlined,
                title: canCreate
                    ? 'No products yet'
                    : 'No products to display',
                message: canCreate
                    ? 'Tap "Add Product" to create your first product'
                    : null,
              );
            }
            return AnimationLimiter(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.products.length,
                itemBuilder: (context, index) {
                  final product = state.products[index];
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 200),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        curve: Curves.easeOut,
                        child: _ProductDataListItem(
                          product: product,
                          canEdit: cubit.canEdit,
                          canDelete: cubit.canDelete,
                          onEdit: () =>
                              _openProductDialog(context, product: product),
                          onDelete: () => cubit.deleteProduct(product.id),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _openProductDialog(
    BuildContext context, {
    OrganizationProduct? product,
  }) async {
    final cubit = context.read<ProductsCubit>();
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Product Dialog',
      barrierColor: AuthColors.background.withValues(alpha: 0.8),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return BlocProvider.value(
          value: cubit,
          child: _ProductDialog(product: product),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class _ProductDataListItem extends StatelessWidget {
  const _ProductDataListItem({
    required this.product,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  final OrganizationProduct product;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Get status ring color based on stock level
  Color _getStatusRingColor() {
    if (product.status == ProductStatus.archived) {
      return AuthColors.textDisabled;
    }
    if (product.stock > 10) {
      // In Stock - Green
      return AuthColors.success;
    } else if (product.stock > 0) {
      // Low Stock - Orange (keep orange for visibility)
      return const Color(0xFFFF9800);
    } else {
      // Out of Stock - Grey
      return AuthColors.textDisabled;
    }
  }

  /// Get status dot color based on product status
  Color? _getStatusDotColor() {
    if (product.status == ProductStatus.active) {
      return AuthColors.primary; // Use primary color instead of Instagram blue
    }
    return AuthColors.textDisabled; // Paused or archived
  }

  /// Format subtitle with price and stock info
  String _formatSubtitle() {
    final priceText = '₹${product.unitPrice.toStringAsFixed(2)}';
    final stockText = product.stock > 0
        ? '${product.stock} in stock'
        : 'Out of stock';
    return '$priceText • $stockText';
  }

  @override
  Widget build(BuildContext context) {
    return DataList(
      title: product.name,
      subtitle: _formatSubtitle(),
      leading: DataListAvatar(
        initial: product.name.isNotEmpty ? product.name[0] : '?',
        radius: 28,
        statusRingColor: _getStatusRingColor(),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DataListStatusDot(
            color: _getStatusDotColor(),
            size: 8,
          ),
          const SizedBox(width: 12),
          if (canEdit)
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
          if (canEdit && canDelete) const SizedBox(width: 8),
          if (canDelete)
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
      onTap: canEdit ? onEdit : null,
    );
  }

}


class _ProductDialog extends StatefulWidget {
  const _ProductDialog({this.product});

  final OrganizationProduct? product;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _gstController;
  late final TextEditingController _stockController;
  late final TextEditingController _fixedQuantityController;
  ProductStatus _status = ProductStatus.active;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _priceController = TextEditingController(
      text: product != null ? product.unitPrice.toStringAsFixed(2) : '',
    );
    _gstController = TextEditingController(
      text: product != null && product.gstPercent != null
          ? product.gstPercent!.toStringAsFixed(1)
          : '',
    );
    _stockController = TextEditingController(
      text: product != null ? product.stock.toString() : '',
    );
    _fixedQuantityController = TextEditingController(
      text: product != null && product.fixedQuantityPerTripOptions != null
          ? product.fixedQuantityPerTripOptions!.join(', ')
          : '',
    );
    _status = product?.status ?? ProductStatus.active;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _gstController.dispose();
    _stockController.dispose();
    _fixedQuantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;
    final cubit = context.read<ProductsCubit>();
    final canCreate = cubit.canCreate;
    final canEdit = cubit.canEdit;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.9).clamp(400.0, 600.0);

    return AlertDialog(
      backgroundColor: AuthColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: AuthColors.textMain.withOpacity(0.1),
          width: 1,
        ),
      ),
      title: Text(
        isEditing ? 'Edit Product' : 'Add Product',
        style: const TextStyle(color: AuthColors.textMain),
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: AuthColors.textMain),
                  decoration: _inputDecoration('Product name'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Enter product name'
                          : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AuthColors.textMain),
                  decoration: _inputDecoration('Unit price'),
                  validator: (value) {
                    final parsed = double.tryParse(value ?? '');
                    if (parsed == null || parsed < 0) {
                      return 'Enter a valid price';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _gstController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AuthColors.textMain),
                  decoration: _inputDecoration('GST (%) - Optional'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null; // GST is optional
                    }
                    final parsed = double.tryParse(value);
                    if (parsed == null || parsed < 0 || parsed > 100) {
                      return 'Enter value between 0 and 100';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _stockController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AuthColors.textMain),
                  decoration: _inputDecoration('Stock (optional)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _fixedQuantityController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AuthColors.textMain),
                  decoration: _inputDecoration(
                    'Fixed Quantity Per Trip (comma-separated, e.g., 1000, 1500, 2000) - Optional',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null; // Optional field
                    }
                    final parts = value.split(',');
                    for (final part in parts) {
                      final trimmed = part.trim();
                      if (trimmed.isEmpty) continue;
                      final parsed = int.tryParse(trimmed);
                      if (parsed == null || parsed <= 0) {
                        return 'Enter valid numbers separated by commas';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ProductStatus>(
                  initialValue: _status,
                  dropdownColor: AuthColors.surface,
                  style: const TextStyle(color: AuthColors.textMain),
                  decoration: _inputDecoration('Status'),
                  onChanged: (value) {
                    if (value != null) setState(() => _status = value);
                  },
                  items: const [
                    DropdownMenuItem(
                      value: ProductStatus.active,
                      child: Text('Active'),
                    ),
                    DropdownMenuItem(
                      value: ProductStatus.paused,
                      child: Text('Paused'),
                    ),
                    DropdownMenuItem(
                      value: ProductStatus.archived,
                      child: Text('Archived'),
                    ),
                  ],
                ),
              ],
            ),
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
          onPressed: (isEditing ? canEdit : canCreate)
              ? () {
                  if (!(_formKey.currentState?.validate() ?? false)) return;
                  final cubit = context.read<ProductsCubit>();
                  // Parse fixed quantity options
                  List<int>? fixedQuantityOptions;
                  final fixedQuantityText = _fixedQuantityController.text.trim();
                  if (fixedQuantityText.isNotEmpty) {
                    final parts = fixedQuantityText.split(',');
                    fixedQuantityOptions = parts
                        .map((p) => p.trim())
                        .where((p) => p.isNotEmpty)
                        .map((p) => int.tryParse(p))
                        .whereType<int>()
                        .where((v) => v > 0)
                        .toList();
                    if (fixedQuantityOptions.isEmpty) {
                      fixedQuantityOptions = null;
                    }
                  }

                  // Parse GST (optional)
                  final gstText = _gstController.text.trim();
                  final double? gstPercent =
                      gstText.isEmpty ? null : double.tryParse(gstText);

                  final product = OrganizationProduct(
                    id: widget.product?.id ??
                        DateTime.now().millisecondsSinceEpoch.toString(),
                    name: _nameController.text.trim(),
                    unitPrice:
                        double.tryParse(_priceController.text.trim()) ?? 0,
                    gstPercent: gstPercent,
                    stock: int.tryParse(_stockController.text.trim()) ?? 0,
                    status: _status,
                    fixedQuantityPerTripOptions: fixedQuantityOptions,
                  );
                  if (widget.product == null) {
                    cubit.createProduct(product);
                  } else {
                    cubit.updateProduct(product);
                  }
                  Navigator.of(context).pop();
                }
              : null,
          variant: DashButtonVariant.text,
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AuthColors.surface,
      labelStyle: const TextStyle(color: AuthColors.textSub),
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
