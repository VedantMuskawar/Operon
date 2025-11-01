import 'package:flutter/material.dart';
import 'dart:math';
import '../../models/location_pricing.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/custom_dropdown.dart';

class LocationPricingFormDialog extends StatefulWidget {
  final LocationPricing? locationPricing;
  final Function(LocationPricing) onSubmit;
  final Function() onCancel;

  const LocationPricingFormDialog({
    super.key,
    this.locationPricing,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<LocationPricingFormDialog> createState() => _LocationPricingFormDialogState();
}

class _LocationPricingFormDialogState extends State<LocationPricingFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _locationIdController;
  late TextEditingController _locationNameController;
  late TextEditingController _cityController;
  late TextEditingController _unitPriceController;

  bool _autoGenerateId = true;
  String _selectedStatus = LocationStatus.active;

  Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    
    _locationIdController = TextEditingController();
    _locationNameController = TextEditingController();
    _cityController = TextEditingController();
    _unitPriceController = TextEditingController();

    if (widget.locationPricing != null) {
      // Editing existing location pricing
      _autoGenerateId = false;
      _locationIdController.text = widget.locationPricing!.locationId;
      _locationNameController.text = widget.locationPricing!.locationName;
      _cityController.text = widget.locationPricing!.city;
      _unitPriceController.text = widget.locationPricing!.unitPrice.toStringAsFixed(2);
      _selectedStatus = widget.locationPricing!.status;
    } else {
      // New location - generate ID if auto-generate is enabled
      if (_autoGenerateId) {
        _locationIdController.text = _generateLocationId();
      }
    }
  }

  @override
  void dispose() {
    _locationIdController.dispose();
    _locationNameController.dispose();
    _cityController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  String _generateLocationId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return 'LOC${String.fromCharCodes(
      Iterable.generate(8, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    )}';
  }

  void _onAutoGenerateChanged(bool value) {
    setState(() {
      _autoGenerateId = value;
      if (value) {
        _locationIdController.text = _generateLocationId();
      } else {
        _locationIdController.text = '';
      }
    });
  }

  void _regenerateId() {
    if (_autoGenerateId) {
      setState(() {
        _locationIdController.text = _generateLocationId();
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

    if (_locationIdController.text.trim().isEmpty) {
      _errors['locationId'] = 'Location ID is required';
      isValid = false;
    }

    if (_locationNameController.text.trim().isEmpty) {
      _errors['locationName'] = 'Location name is required';
      isValid = false;
    }

    if (_cityController.text.trim().isEmpty) {
      _errors['city'] = 'City is required';
      isValid = false;
    }

    if (_unitPriceController.text.trim().isEmpty) {
      _errors['unitPrice'] = 'Unit price is required';
      isValid = false;
    } else {
      final price = double.tryParse(_unitPriceController.text.trim());
      if (price == null || price < 0) {
        _errors['unitPrice'] = 'Please enter a valid unit price';
        isValid = false;
      }
    }

    setState(() {});
    return isValid;
  }

  void _handleSubmit() {
    if (!_validateForm()) {
      return;
    }

    final now = DateTime.now();
    final unitPrice = double.parse(_unitPriceController.text.trim());

    final locationPricing = LocationPricing(
      id: widget.locationPricing?.id,
      locationId: _locationIdController.text.trim(),
      locationName: _locationNameController.text.trim(),
      city: _cityController.text.trim(),
      unitPrice: unitPrice,
      status: _selectedStatus,
      createdAt: widget.locationPricing?.createdAt ?? now,
      updatedAt: now,
      createdBy: widget.locationPricing?.createdBy,
      updatedBy: null,
    );

    widget.onSubmit(locationPricing);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 600),
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
                        widget.locationPricing == null ? 'Add Location Pricing' : 'Edit Location Pricing',
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
                          _buildSectionTitle('📋 Location Information'),
                          const SizedBox(height: 16),
                          
                          _buildLocationIdField(),
                          const SizedBox(height: 16),
                          
                          CustomTextField(
                            controller: _locationNameController,
                            labelText: 'Location Name *',
                            hintText: 'e.g., Main Warehouse',
                            errorText: _errors['locationName'],
                            onChanged: (_) => _clearError('locationName'),
                          ),
                          const SizedBox(height: 16),
                          
                          CustomTextField(
                            controller: _cityController,
                            labelText: 'City *',
                            hintText: 'e.g., Mumbai',
                            errorText: _errors['city'],
                            onChanged: (_) => _clearError('city'),
                          ),
                          const SizedBox(height: 16),
                          
                          CustomTextField(
                            controller: _unitPriceController,
                            labelText: 'Unit Price (₹) *',
                            hintText: 'e.g., 100.00',
                            keyboardType: TextInputType.number,
                            errorText: _errors['unitPrice'],
                            onChanged: (_) => _clearError('unitPrice'),
                          ),
                          const SizedBox(height: 16),
                          
                          CustomDropdown<String>(
                            value: _selectedStatus,
                            labelText: 'Status *',
                            items: LocationStatus.all.map((status) {
                              return DropdownMenuItem(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedStatus = value ?? LocationStatus.active;
                              });
                            },
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
                          widget.locationPricing == null ? 'Add Location' : 'Update Location',
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

  Widget _buildLocationIdField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: _autoGenerateId,
              onChanged: widget.locationPricing == null
                  ? (value) => _onAutoGenerateChanged(value ?? true)
                  : null,
            ),
            const Text(
              'Auto-generate Location ID',
              style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _locationIdController,
                labelText: 'Location ID *',
                hintText: _autoGenerateId
                    ? 'Auto-generated ID'
                    : 'e.g., LOC001',
                errorText: _errors['locationId'],
                enabled: !_autoGenerateId || widget.locationPricing != null,
                onChanged: (_) => _clearError('locationId'),
              ),
            ),
            if (_autoGenerateId && widget.locationPricing == null) ...[
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

