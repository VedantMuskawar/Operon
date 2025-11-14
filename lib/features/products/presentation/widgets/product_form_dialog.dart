import 'package:flutter/material.dart';
import 'dart:math';
import '../../models/product.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/custom_dropdown.dart';
import '../../../../core/theme/app_theme.dart';

class ProductFormDialog extends StatefulWidget {
  final Product? product;
  final Function(Product) onSubmit;
  final Function() onCancel;

  const ProductFormDialog({
    super.key,
    this.product,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _productIdController;
  late TextEditingController _productNameController;
  late TextEditingController _descriptionController;
  late TextEditingController _unitPriceController;
  late TextEditingController _gstRateController;

  bool _autoGenerateId = true;
  String _selectedStatus = ProductStatus.active;

  Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    
    _productIdController = TextEditingController();
    _productNameController = TextEditingController();
    _descriptionController = TextEditingController();
    _unitPriceController = TextEditingController();
    _gstRateController = TextEditingController();

    if (widget.product != null) {
      // Editing existing product
      _autoGenerateId = false;
      _productIdController.text = widget.product!.productId;
      _productNameController.text = widget.product!.productName;
      _descriptionController.text = widget.product!.description ?? '';
      _unitPriceController.text = widget.product!.unitPrice.toString();
      _gstRateController.text = widget.product!.gstRate.toString();
      _selectedStatus = widget.product!.status;
    } else {
      // New product - generate ID if auto-generate is enabled
      if (_autoGenerateId) {
        _productIdController.text = _generateProductId();
      }
      _gstRateController.text = '0';
    }
  }

  @override
  void dispose() {
    _productIdController.dispose();
    _productNameController.dispose();
    _descriptionController.dispose();
    _unitPriceController.dispose();
    _gstRateController.dispose();
    super.dispose();
  }

  String _generateProductId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return 'PRD${String.fromCharCodes(
      Iterable.generate(8, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    )}';
  }

  void _onAutoGenerateChanged(bool value) {
    setState(() {
      _autoGenerateId = value;
      if (value) {
        _productIdController.text = _generateProductId();
      } else {
        _productIdController.text = '';
      }
    });
  }

  void _regenerateId() {
    if (_autoGenerateId) {
      setState(() {
        _productIdController.text = _generateProductId();
      });
    }
  }

  void _clearError(String field) {
    if (_errors.containsKey(field)) {
      setState(() {
        _errors.remove(field);
      });
    }
  }

  bool _validateForm() {
    _errors.clear();
    bool isValid = true;

    if (_productIdController.text.trim().isEmpty) {
      _errors['productId'] = 'Product ID is required';
      isValid = false;
    }

    if (_productNameController.text.trim().isEmpty) {
      _errors['productName'] = 'Product name is required';
      isValid = false;
    }

    final unitPrice = double.tryParse(_unitPriceController.text);
    if (unitPrice == null || unitPrice <= 0) {
      _errors['unitPrice'] = 'Unit price must be greater than 0';
      isValid = false;
    }

    final gstRateValue = double.tryParse(_gstRateController.text);
    if (gstRateValue == null || gstRateValue < 0) {
      _errors['gstRate'] = 'GST rate must be 0 or a positive number';
      isValid = false;
    }

    setState(() {});
    return isValid;
  }

  void _handleSubmit() {
    if (!_validateForm()) {
      return;
    }

    final now = DateTime.now();

    final product = Product(
      id: widget.product?.id,
      productId: _productIdController.text.trim(),
      productName: _productNameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty 
          ? null 
          : _descriptionController.text.trim(),
      unitPrice: double.parse(_unitPriceController.text),
      gstRate: double.parse(_gstRateController.text),
      status: _selectedStatus,
      createdAt: widget.product?.createdAt ?? now,
      updatedAt: now,
      createdBy: widget.product?.createdBy,
      updatedBy: null,
    );

    widget.onSubmit(product);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1F1F1F),
              Color(0xFF2A2A2A),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 60,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Color(0x33FFFFFF),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('📦', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Text(
                        widget.product == null ? 'Add Product' : 'Edit Product',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00C3FF),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        color: const Color(0xFFFF4444),
                        onPressed: widget.onCancel,
                      ),
                    ],
                  ),
                ),
                
                // Form
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Basic Information Section
                          _buildSectionTitle('📋 Basic Information'),
                          const SizedBox(height: 16),
                          
                          // Product ID
                          _buildProductIdField(),
                          const SizedBox(height: 16),
                          
                          // Product Name and Status
                          Row(
                            children: [
                              Expanded(
                                child: CustomTextField(
                                  controller: _productNameController,
                                  labelText: 'Product Name *',
                                  hintText: 'e.g., Cement Bag',
                                  errorText: _errors['productName'],
                                  onChanged: (_) => _clearError('productName'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: CustomDropdown<String>(
                                  value: _selectedStatus,
                                  labelText: 'Status *',
                                  items: ProductStatus.all.map((status) {
                                    return DropdownMenuItem(
                                      value: status,
                                      child: Text(status),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedStatus = value ?? ProductStatus.active;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Description
                          CustomTextField(
                            controller: _descriptionController,
                            labelText: 'Description',
                            hintText: 'Enter product description (optional)',
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          
                          // Pricing
                          Row(
                            children: [
                              Expanded(
                                child: CustomTextField(
                                  controller: _unitPriceController,
                                  labelText: 'Base Unit Price *',
                                  hintText: '0.00',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  variant: CustomTextFieldVariant.number,
                                  errorText: _errors['unitPrice'],
                                  onChanged: (_) => _clearError('unitPrice'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: CustomTextField(
                                  controller: _gstRateController,
                                  labelText: 'GST Rate (%)',
                                  hintText: 'e.g., 18',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  variant: CustomTextFieldVariant.number,
                                  errorText: _errors['gstRate'],
                                  onChanged: (_) => _clearError('gstRate'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Actions
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Color(0x33FFFFFF),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: widget.onCancel,
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A84FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          widget.product == null ? 'Add Product' : 'Update Product',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF00C3FF),
          ),
        ),
      ],
    );
  }

  Widget _buildProductIdField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: _autoGenerateId,
              onChanged: widget.product == null
                  ? (value) => _onAutoGenerateChanged(value ?? true)
                  : null,
            ),
            const Text(
              'Auto-generate Product ID',
              style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _productIdController,
                labelText: 'Product ID *',
                hintText: _autoGenerateId
                    ? 'Auto-generated ID'
                    : 'e.g., PRD001',
                errorText: _errors['productId'],
                enabled: !_autoGenerateId || widget.product != null,
                onChanged: (_) => _clearError('productId'),
              ),
            ),
            if (_autoGenerateId && widget.product == null) ...[
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _regenerateId,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('🔄 Regenerate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C3FF),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

