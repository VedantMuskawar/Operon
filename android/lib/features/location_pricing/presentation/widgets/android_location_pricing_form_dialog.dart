import 'package:flutter/material.dart';
import 'dart:math';
import '../../models/location_pricing.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/config/android_config.dart';

class AndroidLocationPricingFormDialog extends StatefulWidget {
  final LocationPricing? locationPricing;
  final Function(LocationPricing) onSubmit;

  const AndroidLocationPricingFormDialog({
    super.key,
    this.locationPricing,
    required this.onSubmit,
  });

  @override
  State<AndroidLocationPricingFormDialog> createState() => _AndroidLocationPricingFormDialogState();
}

class _AndroidLocationPricingFormDialogState extends State<AndroidLocationPricingFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _locationIdController;
  late TextEditingController _locationNameController;
  late TextEditingController _cityController;
  late TextEditingController _unitPriceController;

  String _selectedStatus = LocationStatus.active;

  @override
  void initState() {
    super.initState();
    _locationIdController = TextEditingController();
    _locationNameController = TextEditingController();
    _cityController = TextEditingController();
    _unitPriceController = TextEditingController();

    if (widget.locationPricing != null) {
      _locationIdController.text = widget.locationPricing!.locationId;
      _locationNameController.text = widget.locationPricing!.locationName;
      _cityController.text = widget.locationPricing!.city;
      _unitPriceController.text = widget.locationPricing!.unitPrice.toString();
      _selectedStatus = widget.locationPricing!.status;
    } else {
      _locationIdController.text = _generateLocationId();
      _unitPriceController.text = '0.00';
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
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(21, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final location = LocationPricing(
        id: widget.locationPricing?.id,
        locationId: _locationIdController.text.trim(),
        locationName: _locationNameController.text.trim(),
        city: _cityController.text.trim(),
        unitPrice: double.tryParse(_unitPriceController.text) ?? 0.0,
        status: _selectedStatus,
        createdAt: widget.locationPricing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: widget.locationPricing?.createdBy,
        updatedBy: widget.locationPricing?.updatedBy,
      );

      widget.onSubmit(location);
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
                      widget.locationPricing == null ? 'Add Location' : 'Edit Location',
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
                          controller: _locationIdController,
                          decoration: InputDecoration(
                            labelText: 'Location ID',
                            labelStyle: const TextStyle(color: AppTheme.textSecondaryColor),
                            enabled: widget.locationPricing == null,
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
                              return 'Location ID is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _locationNameController,
                          decoration: InputDecoration(
                            labelText: 'Location Name',
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
                              return 'Location name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _cityController,
                          decoration: InputDecoration(
                            labelText: 'City',
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
                              return 'City is required';
                            }
                            return null;
                          },
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
                          items: LocationStatus.all.map((status) {
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
                    widget.locationPricing == null ? 'Add Location' : 'Update Location',
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

