import 'package:flutter/material.dart';
import 'dart:math';
import '../../models/address.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/custom_dropdown.dart';
import '../../../../core/theme/app_theme.dart';

class AddressFormDialog extends StatefulWidget {
  final Address? address;
  final Function(Address) onSubmit;
  final Function() onCancel;

  const AddressFormDialog({
    super.key,
    this.address,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<AddressFormDialog> createState() => _AddressFormDialogState();
}

class _AddressFormDialogState extends State<AddressFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _addressIdController;
  late TextEditingController _addressNameController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _pincodeController;

  bool _autoGenerateId = true;
  String _selectedRegion = '';
  String _selectedStatus = AddressStatus.active;

  Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    
    _addressIdController = TextEditingController();
    _addressNameController = TextEditingController();
    _addressController = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _pincodeController = TextEditingController();

    if (widget.address != null) {
      // Editing existing address
      _autoGenerateId = false;
      _addressIdController.text = widget.address!.addressId;
      _addressNameController.text = widget.address!.addressName;
      _addressController.text = widget.address!.address;
      _selectedRegion = widget.address!.region;
      _cityController.text = widget.address!.city ?? '';
      _stateController.text = widget.address!.state ?? '';
      _pincodeController.text = widget.address!.pincode ?? '';
      _selectedStatus = widget.address!.status;
    } else {
      // New address - generate ID if auto-generate is enabled
      if (_autoGenerateId) {
        _addressIdController.text = _generateAddressId();
      }
    }
  }

  @override
  void dispose() {
    _addressIdController.dispose();
    _addressNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  String _generateAddressId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return 'ADDR${String.fromCharCodes(
      Iterable.generate(8, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    )}';
  }

  void _onAutoGenerateChanged(bool value) {
    setState(() {
      _autoGenerateId = value;
      if (value) {
        _addressIdController.text = _generateAddressId();
      } else {
        _addressIdController.text = '';
      }
    });
  }

  void _regenerateId() {
    if (_autoGenerateId) {
      setState(() {
        _addressIdController.text = _generateAddressId();
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

    if (_addressIdController.text.trim().isEmpty) {
      _errors['addressId'] = 'Address ID is required';
      isValid = false;
    }

    if (_addressNameController.text.trim().isEmpty) {
      _errors['addressName'] = 'Address name is required';
      isValid = false;
    }

    if (_addressController.text.trim().isEmpty) {
      _errors['address'] = 'Address is required';
      isValid = false;
    }

    if (_selectedRegion.isEmpty) {
      _errors['region'] = 'Region is required';
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

    final address = Address(
      id: widget.address?.id,
      addressId: _addressIdController.text.trim(),
      addressName: _addressNameController.text.trim(),
      address: _addressController.text.trim(),
      region: _selectedRegion,
      city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
      state: _stateController.text.trim().isEmpty ? null : _stateController.text.trim(),
      pincode: _pincodeController.text.trim().isEmpty ? null : _pincodeController.text.trim(),
      status: _selectedStatus,
      createdAt: widget.address?.createdAt ?? now,
      updatedAt: now,
      createdBy: widget.address?.createdBy,
      updatedBy: null,
    );

    widget.onSubmit(address);
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
                      const Text('📍', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Text(
                        widget.address == null ? 'Add Address' : 'Edit Address',
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('📋 Basic Information'),
                          const SizedBox(height: 16),
                          
                          _buildAddressIdField(),
                          const SizedBox(height: 16),
                          
                          CustomTextField(
                            controller: _addressNameController,
                            labelText: 'Address Name *',
                            hintText: 'e.g., Main Warehouse',
                            errorText: _errors['addressName'],
                            onChanged: (_) => _clearError('addressName'),
                          ),
                          const SizedBox(height: 16),
                          
                          CustomTextField(
                            controller: _addressController,
                            labelText: 'Full Address *',
                            hintText: 'Enter complete address',
                            maxLines: 3,
                            errorText: _errors['address'],
                            onChanged: (_) => _clearError('address'),
                          ),
                          const SizedBox(height: 16),
                          
                          CustomDropdown<String>(
                            value: _selectedRegion.isEmpty ? null : _selectedRegion,
                            labelText: 'Region *',
                            hintText: 'Select Region',
                            errorText: _errors['region'],
                            items: AddressRegion.all.map((region) {
                              return DropdownMenuItem(
                                value: region,
                                child: Text(region),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedRegion = value ?? '';
                                _clearError('region');
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          Row(
                            children: [
                              Expanded(
                                child: CustomTextField(
                                  controller: _cityController,
                                  labelText: 'City',
                                  hintText: 'Enter city',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: CustomTextField(
                                  controller: _stateController,
                                  labelText: 'State',
                                  hintText: 'Enter state',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          Row(
                            children: [
                              Expanded(
                                child: CustomTextField(
                                  controller: _pincodeController,
                                  labelText: 'Pincode',
                                  hintText: 'Enter pincode',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: CustomDropdown<String>(
                                  value: _selectedStatus,
                                  labelText: 'Status *',
                                  items: AddressStatus.all.map((status) {
                                    return DropdownMenuItem(
                                      value: status,
                                      child: Text(status),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedStatus = value ?? AddressStatus.active;
                                    });
                                  },
                                ),
                              ),
                            ],
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
                          widget.address == null ? 'Add Address' : 'Update Address',
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

  Widget _buildAddressIdField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: _autoGenerateId,
              onChanged: widget.address == null
                  ? (value) => _onAutoGenerateChanged(value ?? true)
                  : null,
            ),
            const Text(
              'Auto-generate Address ID',
              style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _addressIdController,
                labelText: 'Address ID *',
                hintText: _autoGenerateId
                    ? 'Auto-generated ID'
                    : 'e.g., ADDR001',
                errorText: _errors['addressId'],
                enabled: !_autoGenerateId || widget.address != null,
                onChanged: (_) => _clearError('addressId'),
              ),
            ),
            if (_autoGenerateId && widget.address == null) ...[
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

