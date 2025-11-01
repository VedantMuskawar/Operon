import 'package:flutter/material.dart';
import 'dart:math';
import '../../models/product.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/config/android_config.dart';

class AndroidProductFormDialog extends StatefulWidget {
  final Product? product;
  final Function(Product) onSubmit;

  const AndroidProductFormDialog({
    super.key,
    this.product,
    required this.onSubmit,
  });

  @override
  State<AndroidProductFormDialog> createState() => _AndroidProductFormDialogState();
}

class _AndroidProductFormDialogState extends State<AndroidProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _productIdController;
  late TextEditingController _productNameController;
  late TextEditingController _descriptionController;
  late TextEditingController _unitPriceController;

  String _selectedStatus = ProductStatus.active;

  @override
  void initState() {
    super.initState();
    _productIdController = TextEditingController();
    _productNameController = TextEditingController();
    _descriptionController = TextEditingController();
    _unitPriceController = TextEditingController();

    if (widget.product != null) {
      _productIdController.text = widget.product!.productId;
      _productNameController.text = widget.product!.productName;
      _descriptionController.text = widget.product!.description ?? '';
      _unitPriceController.text = widget.product!.unitPrice.toString();
      _selectedStatus = widget.product!.status;
    } else {
      _productIdController.text = _generateProductId();
      _unitPriceController.text = '0.00';
    }
  }

  @override
  void dispose() {
    _productIdController.dispose();
    _productNameController.dispose();
    _descriptionController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  String _generateProductId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(21, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final product = Product(
        id: widget.product?.id,
        productId: _productIdController.text.trim(),
        productName: _productNameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        unitPrice: double.tryParse(_unitPriceController.text) ?? 0.0,
        status: _selectedStatus,
        createdAt: widget.product?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: widget.product?.createdBy,
        updatedBy: widget.product?.updatedBy,
      );

      widget.onSubmit(product);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(AndroidConfig.defaultPadding),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondaryColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.product == null ? 'Add Product' : 'Edit Product',
                      style: const TextStyle(color: AppTheme.textPrimaryColor, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      color: AppTheme.textSecondaryColor,
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _productIdController,
                          decoration: InputDecoration(
                            labelText: 'Product ID',
                            labelStyle: const TextStyle(color: AppTheme.textSecondaryColor),
                            enabled: widget.product == null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppTheme.borderColor),
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppTheme.primaryColor),
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                          ),
                          style: const TextStyle(color: AppTheme.textPrimaryColor),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Product ID is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _productNameController,
                          decoration: InputDecoration(
                            labelText: 'Product Name',
                            labelStyle: const TextStyle(color: AppTheme.textSecondaryColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppTheme.borderColor),
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppTheme.primaryColor),
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                          ),
                          style: const TextStyle(color: AppTheme.textPrimaryColor),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Product name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: 'Description (Optional)',
                            labelStyle: const TextStyle(color: AppTheme.textSecondaryColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppTheme.borderColor),
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppTheme.primaryColor),
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                          ),
                          maxLines: 3,
                          style: const TextStyle(color: AppTheme.textPrimaryColor),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _unitPriceController,
                          decoration: InputDecoration(
                            labelText: 'Unit Price',
                            labelStyle: const TextStyle(color: AppTheme.textSecondaryColor),
                            prefixText: '₹ ',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppTheme.borderColor),
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppTheme.primaryColor),
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: AppTheme.textPrimaryColor),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Unit price is required';
                            }
                            if (double.tryParse(value) == null || double.parse(value) < 0) {
                              return 'Please enter a valid price';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedStatus,
                          decoration: InputDecoration(
                            labelText: 'Status',
                            labelStyle: const TextStyle(color: AppTheme.textSecondaryColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppTheme.borderColor),
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppTheme.primaryColor),
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                          ),
                          dropdownColor: AppTheme.surfaceColor,
                          style: const TextStyle(color: AppTheme.textPrimaryColor),
                          items: ProductStatus.all.map((status) {
                            return DropdownMenuItem(value: status, child: Text(status));
                          }).toList(),
                          onChanged: (value) => setState(() => _selectedStatus = value!),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    widget.product == null ? 'Add Product' : 'Update Product',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

