import 'package:flutter/material.dart';
import 'dart:math';
import '../../models/vehicle.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/custom_dropdown.dart';
import '../../../../core/theme/app_theme.dart';

class VehicleFormDialog extends StatefulWidget {
  final Vehicle? vehicle;
  final Function(Vehicle) onSubmit;
  final Function() onCancel;

  const VehicleFormDialog({
    super.key,
    this.vehicle,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<VehicleFormDialog> createState() => _VehicleFormDialogState();
}

class _VehicleFormDialogState extends State<VehicleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _vehicleIdController;
  late TextEditingController _vehicleNoController;
  late TextEditingController _capacityController;
  late Map<String, TextEditingController> _weeklyCapacityControllers;

  bool _autoGenerateId = true;
  String _selectedType = '';
  String _selectedMeterType = '';
  String _selectedStatus = VehicleStatus.active;

  Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    
    _vehicleIdController = TextEditingController();
    _vehicleNoController = TextEditingController();
    _capacityController = TextEditingController();
    
    _weeklyCapacityControllers = {
      'Thu': TextEditingController(),
      'Fri': TextEditingController(),
      'Sat': TextEditingController(),
      'Sun': TextEditingController(),
      'Mon': TextEditingController(),
      'Tue': TextEditingController(),
      'Wed': TextEditingController(),
    };

    if (widget.vehicle != null) {
      // Editing existing vehicle
      _autoGenerateId = false;
      _vehicleIdController.text = widget.vehicle!.vehicleID;
      _vehicleNoController.text = widget.vehicle!.vehicleNo;
      _selectedType = widget.vehicle!.type;
      _selectedMeterType = widget.vehicle!.meterType;
      _selectedStatus = widget.vehicle!.status;
      _capacityController.text = widget.vehicle!.vehicleQuantity.toString();
      
      widget.vehicle!.weeklyCapacity.forEach((day, value) {
        if (_weeklyCapacityControllers.containsKey(day)) {
          _weeklyCapacityControllers[day]!.text = value.toString();
        }
      });
    } else {
      // New vehicle - generate ID if auto-generate is enabled
      if (_autoGenerateId) {
        _vehicleIdController.text = _generateVehicleId();
      }
    }
  }

  @override
  void dispose() {
    _vehicleIdController.dispose();
    _vehicleNoController.dispose();
    _capacityController.dispose();
    for (var controller in _weeklyCapacityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _generateVehicleId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(21, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  void _onAutoGenerateChanged(bool value) {
    setState(() {
      _autoGenerateId = value;
      if (value) {
        _vehicleIdController.text = _generateVehicleId();
      } else {
        _vehicleIdController.text = '';
      }
    });
  }

  void _regenerateId() {
    if (_autoGenerateId) {
      setState(() {
        _vehicleIdController.text = _generateVehicleId();
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

    if (_vehicleIdController.text.trim().isEmpty) {
      _errors['vehicleID'] = 'Vehicle ID is required';
      isValid = false;
    }

    if (_vehicleNoController.text.trim().isEmpty) {
      _errors['vehicleNo'] = 'Vehicle number is required';
      isValid = false;
    }

    if (_selectedType.isEmpty) {
      _errors['type'] = 'Vehicle type is required';
      isValid = false;
    }

    if (_selectedMeterType.isEmpty) {
      _errors['meterType'] = 'Meter type is required';
      isValid = false;
    }

    final capacity = int.tryParse(_capacityController.text);
    if (capacity == null || capacity <= 0) {
      _errors['vehicleQuantity'] = 'Vehicle capacity must be greater than 0';
      isValid = false;
    }

    // Check weekly capacity
    bool hasCapacity = false;
    for (var controller in _weeklyCapacityControllers.values) {
      final value = int.tryParse(controller.text) ?? 0;
      if (value > 0) {
        hasCapacity = true;
        break;
      }
    }

    if (!hasCapacity) {
      _errors['weeklyCapacity'] = 'At least one day must have capacity > 0';
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
    final weeklyCapacity = <String, int>{};
    
    for (var entry in _weeklyCapacityControllers.entries) {
      weeklyCapacity[entry.key] = int.tryParse(entry.value.text) ?? 0;
    }

    final vehicle = Vehicle(
      id: widget.vehicle?.id,
      vehicleID: _vehicleIdController.text.trim(),
      vehicleNo: _vehicleNoController.text.trim(),
      type: _selectedType,
      meterType: _selectedMeterType,
      vehicleQuantity: int.parse(_capacityController.text),
      status: _selectedStatus,
      weeklyCapacity: weeklyCapacity,
      createdAt: widget.vehicle?.createdAt ?? now,
      updatedAt: now,
      createdBy: widget.vehicle?.createdBy,
      updatedBy: null,
    );

    widget.onSubmit(vehicle);
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
                      const Text('🚜', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Text(
                        widget.vehicle == null ? 'Add New Vehicle' : 'Edit Vehicle',
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
                          
                          // Vehicle ID
                          _buildVehicleIdField(),
                          const SizedBox(height: 16),
                          
                          // Vehicle Number and Type
                          Row(
                            children: [
                              Expanded(
                                child: CustomTextField(
                                  controller: _vehicleNoController,
                                  labelText: 'Vehicle Number *',
                                  hintText: 'e.g., MH 34 AP 0148',
                                  errorText: _errors['vehicleNo'],
                                  onChanged: (_) => _clearError('vehicleNo'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: CustomDropdown<String>(
                                  value: _selectedType.isEmpty ? null : _selectedType,
                                  labelText: 'Vehicle Type *',
                                  hintText: 'Select Type',
                                  errorText: _errors['type'],
                                  items: VehicleType.all.map((type) {
                                    return DropdownMenuItem(
                                      value: type,
                                      child: Text(type),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedType = value ?? '';
                                      _clearError('type');
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Meter Type and Capacity
                          Row(
                            children: [
                              Expanded(
                                child: CustomDropdown<String>(
                                  value: _selectedMeterType.isEmpty ? null : _selectedMeterType,
                                  labelText: 'Meter Type *',
                                  hintText: 'Select Meter Type',
                                  errorText: _errors['meterType'],
                                  items: MeterType.all.map((type) {
                                    return DropdownMenuItem(
                                      value: type,
                                      child: Text(type),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedMeterType = value ?? '';
                                      _clearError('meterType');
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: CustomTextField(
                                  controller: _capacityController,
                                  labelText: 'Vehicle Capacity *',
                                  hintText: 'e.g., 2000',
                                  errorText: _errors['vehicleQuantity'],
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => _clearError('vehicleQuantity'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Status
                          SizedBox(
                            width: 200,
                            child: CustomDropdown<String>(
                              value: _selectedStatus,
                              labelText: 'Status',
                              items: VehicleStatus.all.map((status) {
                                return DropdownMenuItem(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedStatus = value ?? VehicleStatus.active;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          // Weekly Capacity Section
                          _buildSectionTitle('📅 Weekly Capacity (Thu → Wed)'),
                          const SizedBox(height: 16),
                          
                          _buildWeeklyCapacityGrid(),
                          
                          if (_errors.containsKey('weeklyCapacity')) ...[
                            const SizedBox(height: 8),
                            Text(
                              _errors['weeklyCapacity']!,
                              style: const TextStyle(
                                color: Color(0xFFFF4444),
                                fontSize: 12,
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 8),
                          const Text(
                            'Set the number of orders this vehicle can handle each day',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
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
                        child: Text(widget.vehicle == null ? 'Add Vehicle' : 'Update Vehicle'),
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

  Widget _buildVehicleIdField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: _autoGenerateId,
              onChanged: widget.vehicle == null
                  ? (value) => _onAutoGenerateChanged(value ?? true)
                  : null,
            ),
            const Text(
              'Auto-generate Vehicle ID',
              style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _vehicleIdController,
                labelText: 'Vehicle ID *',
                hintText: _autoGenerateId
                    ? 'Auto-generated ID'
                    : 'e.g., VEH001, MH34AP0147',
                errorText: _errors['vehicleID'],
                enabled: !_autoGenerateId || widget.vehicle != null,
                onChanged: (_) => _clearError('vehicleID'),
              ),
            ),
            if (_autoGenerateId && widget.vehicle == null) ...[
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

  Widget _buildWeeklyCapacityGrid() {
    final days = ['Thu', 'Fri', 'Sat', 'Sun', 'Mon', 'Tue', 'Wed'];
    
    return Row(
      children: days.map((day) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                Text(
                  day,
                  style: const TextStyle(
                    color: Color(0xFFCCCCCC),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: _weeklyCapacityControllers[day]!,
                  hintText: '0',
                  keyboardType: TextInputType.number,
                  size: CustomTextFieldSize.small,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

