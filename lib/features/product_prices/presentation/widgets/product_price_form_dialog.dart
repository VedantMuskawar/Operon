import 'package:flutter/material.dart';
import '../../models/product_price.dart';
import '../../../products/models/product.dart';
import '../../../products/repositories/product_repository.dart';
import '../../../addresses/models/address.dart';
import '../../../addresses/repositories/address_repository.dart';
import '../../../../contexts/organization_context.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/custom_dropdown.dart';
import '../../../../core/theme/app_theme.dart';

class ProductPriceFormDialog extends StatefulWidget {
  final String organizationId;
  final ProductPrice? price;
  final Function(ProductPrice) onSubmit;
  final Function() onCancel;

  const ProductPriceFormDialog({
    super.key,
    required this.organizationId,
    this.price,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<ProductPriceFormDialog> createState() => _ProductPriceFormDialogState();
}

class _ProductPriceFormDialogState extends State<ProductPriceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _unitPriceController;
  
  List<Product> _products = [];
  List<Address> _addresses = [];
  String _selectedProductId = '';
  String _selectedAddressId = '';
  
  Map<String, String> _errors = {};
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _unitPriceController = TextEditingController();
    _loadProductAndAddressData();
    
    if (widget.price != null) {
      _selectedProductId = widget.price!.productId;
      _selectedAddressId = widget.price!.addressId;
      _unitPriceController.text = widget.price!.unitPrice.toString();
    }
  }

  @override
  void dispose() {
    _unitPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadProductAndAddressData() async {
    try {
      final productRepo = ProductRepository();
      final addressRepo = AddressRepository();
      
      final products = await productRepo.getProducts(widget.organizationId);
      final addresses = await addressRepo.getAddresses(widget.organizationId);
      
      setState(() {
        _products = products.where((p) => p.status == 'Active').toList();
        _addresses = addresses.where((a) => a.status == 'Active').toList();
        _isLoadingData = false;
      });
    } catch (e) {
      setState(() => _isLoadingData = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load products/addresses: $e')),
        );
      }
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

    if (_selectedProductId.isEmpty) {
      _errors['productId'] = 'Product is required';
      isValid = false;
    }

    if (_selectedAddressId.isEmpty) {
      _errors['addressId'] = 'Address is required';
      isValid = false;
    }

    final unitPrice = double.tryParse(_unitPriceController.text);
    if (unitPrice == null || unitPrice <= 0) {
      _errors['unitPrice'] = 'Unit price must be greater than 0';
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

    final price = ProductPrice(
      id: widget.price?.id,
      productId: _selectedProductId,
      addressId: _selectedAddressId,
      unitPrice: double.parse(_unitPriceController.text),
      effectiveFrom: null,
      effectiveTo: null,
      createdAt: widget.price?.createdAt ?? now,
      updatedAt: now,
      createdBy: widget.price?.createdBy,
      updatedBy: null,
    );

    widget.onSubmit(price);
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
                      const Text('💰', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Text(
                        widget.price == null ? 'Add Product Price' : 'Edit Product Price',
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
                
                Flexible(
                  child: _isLoadingData
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(
                              color: Color(0xFF00C3FF),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle('📋 Price Information'),
                                const SizedBox(height: 16),
                                
                                CustomDropdown<String>(
                                  value: _selectedProductId.isEmpty ? null : _selectedProductId,
                                  labelText: 'Product *',
                                  hintText: 'Select Product',
                                  errorText: _errors['productId'],
                                  items: _products.map((product) {
                                    return DropdownMenuItem(
                                      value: product.productId,
                                      child: Text(product.productName),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedProductId = value ?? '';
                                      _clearError('productId');
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                
                                CustomDropdown<String>(
                                  value: _selectedAddressId.isEmpty ? null : _selectedAddressId,
                                  labelText: 'Address *',
                                  hintText: 'Select Address',
                                  errorText: _errors['addressId'],
                                  items: _addresses.map((address) {
                                    return DropdownMenuItem(
                                      value: address.addressId,
                                      child: Text(address.addressName),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedAddressId = value ?? '';
                                      _clearError('addressId');
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                
                                CustomTextField(
                                  controller: _unitPriceController,
                                  labelText: 'Unit Price *',
                                  hintText: '0.00',
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  variant: CustomTextFieldVariant.number,
                                  errorText: _errors['unitPrice'],
                                  onChanged: (_) => _clearError('unitPrice'),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
                
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
                          widget.price == null ? 'Add Price' : 'Update Price',
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
}

