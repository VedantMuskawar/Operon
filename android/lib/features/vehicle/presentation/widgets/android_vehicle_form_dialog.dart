import 'package:flutter/material.dart';
import 'dart:math';
import '../../models/vehicle.dart';
import '../../../../core/app_theme.dart';

class AndroidVehicleFormDialog extends StatefulWidget {
  final Vehicle? vehicle;
  final Function(Vehicle) onSubmit;

  const AndroidVehicleFormDialog({
    super.key,
    this.vehicle,
    required this.onSubmit,
  });

  @override
  State<AndroidVehicleFormDialog> createState() => _AndroidVehicleFormDialogState();
}

class _AndroidVehicleFormDialogState extends State<AndroidVehicleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _vehicleIdController;
  late TextEditingController _vehicleNoController;
  late TextEditingController _quantityController;

  bool _autoGenerateId = true;
  String? _selectedType;
  String? _selectedMeterType;
  String _selectedStatus = VehicleStatus.active;

  @override
  void initState() {
    super.initState();
    _vehicleIdController = TextEditingController();
    _vehicleNoController = TextEditingController();
    _quantityController = TextEditingController(text: '1');

    if (widget.vehicle != null) {
      _autoGenerateId = false;
      _vehicleIdController.text = widget.vehicle!.vehicleID;
      _vehicleNoController.text = widget.vehicle!.vehicleNo;
      _selectedType = widget.vehicle!.type;
      _selectedMeterType = widget.vehicle!.meterType;
      _selectedStatus = widget.vehicle!.status;
      _quantityController.text = widget.vehicle!.vehicleQuantity.toString();
    } else {
      if (_autoGenerateId) {
        _vehicleIdController.text = _generateVehicleId();
      }
    }
  }

  @override
  void dispose() {
    _vehicleIdController.dispose();
    _vehicleNoController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  String _generateVehicleId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(21, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (_selectedType == null || _selectedMeterType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select vehicle type and meter type')),
        );
        return;
      }

      final weeklyCapacity = <String, int>{
        'Thu': 0,
        'Fri': 0,
        'Sat': 0,
        'Sun': 0,
        'Mon': 0,
        'Tue': 0,
        'Wed': 0,
      };

      final vehicle = Vehicle(
        id: widget.vehicle?.id,
        vehicleID: _vehicleIdController.text.trim(),
        vehicleNo: _vehicleNoController.text.trim(),
        type: _selectedType!,
        meterType: _selectedMeterType!,
        vehicleQuantity: int.tryParse(_quantityController.text) ?? 1,
        status: _selectedStatus,
        weeklyCapacity: weeklyCapacity,
        createdAt: widget.vehicle?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: widget.vehicle?.createdBy,
        updatedBy: widget.vehicle?.updatedBy,
      );

      widget.onSubmit(vehicle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.vehicle != null;
    
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Edit Vehicle' : 'Add Vehicle',
                      style: const TextStyle(
                        color: AppTheme.textPrimaryColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 24),
                      onPressed: () => Navigator.pop(context),
                      color: AppTheme.textPrimaryColor,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              
              // Form Content
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Auto-generate ID checkbox (only for new vehicles)
                        if (!isEditing) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _autoGenerateId,
                                  onChanged: (value) {
                                    setState(() {
                                      _autoGenerateId = value ?? true;
                                      if (_autoGenerateId) {
                                        _vehicleIdController.text = _generateVehicleId();
                                      } else {
                                        _vehicleIdController.clear();
                                      }
                                    });
                                  },
                                  activeColor: AppTheme.primaryColor,
                                ),
                                const Text(
                                  'Auto-generate Vehicle ID',
                                  style: TextStyle(
                                    color: AppTheme.textSecondaryColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        
                        // Vehicle ID Field
                        _buildField(
                          label: 'Vehicle ID',
                          controller: _vehicleIdController,
                          enabled: !_autoGenerateId && !isEditing,
                          readOnly: isEditing || _autoGenerateId,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Vehicle ID is required';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Vehicle Number Field
                        _buildField(
                          label: 'Vehicle Number',
                          controller: _vehicleNoController,
                          enabled: !isEditing,
                          readOnly: isEditing,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Vehicle number is required';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Vehicle Type Dropdown
                        _buildDropdownField(
                          label: 'Vehicle Type',
                          value: _selectedType,
                          items: VehicleType.all,
                          onChanged: (value) {
                            setState(() {
                              _selectedType = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select vehicle type';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Meter Type Dropdown
                        _buildDropdownField(
                          label: 'Meter Type',
                          value: _selectedMeterType,
                          items: MeterType.all,
                          onChanged: (value) {
                            setState(() {
                              _selectedMeterType = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select meter type';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Quantity Field
                        _buildField(
                          label: 'Quantity',
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          readOnly: isEditing,
                          enabled: !isEditing,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Quantity is required';
                            }
                            if (int.tryParse(value) == null || int.parse(value) < 1) {
                              return 'Quantity must be at least 1';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Status Dropdown
                        _buildDropdownField(
                          label: 'Status',
                          value: _selectedStatus,
                          items: VehicleStatus.all,
                          onChanged: (value) {
                            setState(() {
                              _selectedStatus = value!;
                            });
                          },
                        ),
                        
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Action Button
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  border: Border(
                    top: BorderSide(
                      color: AppTheme.borderColor.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        isEditing ? 'Update Vehicle' : 'Add Vehicle',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    bool enabled = true,
    bool readOnly = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textSecondaryColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          readOnly: readOnly,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(
            color: readOnly 
                ? AppTheme.textSecondaryColor 
                : AppTheme.textPrimaryColor,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: readOnly 
                ? AppTheme.backgroundColor 
                : AppTheme.cardColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.borderColor,
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.borderColor,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.primaryColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.errorColor,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.errorColor,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textSecondaryColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          validator: validator,
          style: const TextStyle(
            color: AppTheme.textPrimaryColor,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.cardColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.borderColor,
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.borderColor,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.primaryColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.errorColor,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.errorColor,
                width: 2,
              ),
            ),
          ),
          dropdownColor: AppTheme.cardColor,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: AppTheme.textPrimaryColor,
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: const TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontSize: 16,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
