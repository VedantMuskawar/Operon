import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/presentation/blocs/products/products_cubit.dart';
import 'package:dash_mobile/presentation/widgets/page_workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ProductsCubit>();
    return BlocListener<ProductsCubit, ProductsState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message!)),
          );
        }
      },
      child: PageWorkspaceLayout(
        title: 'Products',
        currentIndex: 4,
        onBack: () => context.go('/home'),
        onNavTap: (value) => context.go('/home', extra: value),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xFF13131E),
                border: Border.all(color: Colors.white12),
              ),
              child: const Text(
                'Manage products, GST, and pricing for this organization.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 20),
            if (cubit.canCreate)
              SizedBox(
                width: double.infinity,
                child: DashButton(
                  label: 'Add Product',
                  onPressed: () => _openProductDialog(context),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0x22FFFFFF),
                ),
                child: const Text(
                  'You have read-only access to products.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            const SizedBox(height: 20),
            BlocBuilder<ProductsCubit, ProductsState>(
              builder: (context, state) {
                if (state.status == ViewStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.products.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Text(
                      cubit.canCreate
                          ? 'No products yet. Tap “Add Product”.'
                          : 'No products to display.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final product = state.products[index];
                    return _ProductTile(
                      product: product,
                      canEdit: cubit.canEdit,
                      canDelete: cubit.canDelete,
                      onEdit: () =>
                          _openProductDialog(context, product: product),
                      onDelete: () => cubit.deleteProduct(product.id),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openProductDialog(
    BuildContext context, {
    OrganizationProduct? product,
  }) async {
    final cubit = context.read<ProductsCubit>();
    await showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: cubit,
        child: _ProductDialog(product: product),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2A), Color(0xFF11111B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.inventory_2_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  product.hasGst
                      ? '₹${product.unitPrice.toStringAsFixed(2)} • GST ${product.gstPercent!.toStringAsFixed(1)}%'
                      : '₹${product.unitPrice.toStringAsFixed(2)} • No GST',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                if (product.fixedQuantityPerTripOptions != null &&
                    product.fixedQuantityPerTripOptions!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Fixed Qty/Trip: ${product.fixedQuantityPerTripOptions!.join(", ")}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Status: ${product.status.name}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          if (canEdit || canDelete)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (canEdit)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white54),
                    onPressed: onEdit,
                  ),
                if (canEdit && canDelete) const SizedBox(height: 8),
                if (canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: onDelete,
                  ),
              ],
            ),
        ],
      ),
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

    return AlertDialog(
      backgroundColor: const Color(0xFF11111B),
      title: Text(
        isEditing ? 'Edit Product' : 'Add Product',
        style: const TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
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
                style: const TextStyle(color: Colors.white),
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
                style: const TextStyle(color: Colors.white),
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
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Stock (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fixedQuantityController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
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
                dropdownColor: const Color(0xFF1B1B2C),
                style: const TextStyle(color: Colors.white),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
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
                  final double? gstPercent = gstText.isEmpty
                      ? null
                      : double.tryParse(gstText);

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
          child: Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFF1B1B2C),
      labelStyle: const TextStyle(color: Colors.white70),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}

