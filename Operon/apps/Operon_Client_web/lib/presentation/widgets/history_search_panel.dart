import 'package:core_ui/core_ui.dart';
import 'package:dash_web/presentation/widgets/glass_info_panel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// History search panel for fleet map history mode.
/// 
/// Provides two search modes:
/// 1. Search by Date + Vehicle No. + Slot
/// 2. Search by DM number
class HistorySearchPanel extends StatefulWidget {
  const HistorySearchPanel({
    super.key,
    required this.onSearchByTripId,
    required this.onSearchByDmNumber,
    this.vehicles = const [],
  });

  /// Callback when searching by Date/Vehicle/Slot.
  /// Parameters: (date, vehicleNumber, slot)
  final void Function(DateTime date, String vehicleNumber, int slot) onSearchByTripId;

  /// Callback when searching by DM number.
  final void Function(int dmNumber) onSearchByDmNumber;

  /// List of available vehicles for dropdown.
  final List<Map<String, dynamic>> vehicles;

  @override
  State<HistorySearchPanel> createState() => _HistorySearchPanelState();
}

class _HistorySearchPanelState extends State<HistorySearchPanel> {
  bool _searchByDmNumber = false;
  DateTime? _selectedDate;
  String? _selectedVehicleNumber;
  final TextEditingController _slotController = TextEditingController();
  final TextEditingController _dmNumberController = TextEditingController();

  @override
  void dispose() {
    _slotController.dispose();
    _dmNumberController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      helpText: 'Select date',
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _performSearch() {
    if (_searchByDmNumber) {
      final dmNumberText = _dmNumberController.text.trim();
      if (dmNumberText.isEmpty) {
        DashSnackbar.show(context, message: 'Please enter a DM number', isError: true);
        return;
      }
      final dmNumber = int.tryParse(dmNumberText);
      if (dmNumber == null) {
        DashSnackbar.show(context, message: 'Invalid DM number', isError: true);
        return;
      }
      widget.onSearchByDmNumber(dmNumber);
    } else {
      if (_selectedDate == null) {
        DashSnackbar.show(context, message: 'Please select a date', isError: true);
        return;
      }
      if (_selectedVehicleNumber == null || _selectedVehicleNumber!.isEmpty) {
        DashSnackbar.show(context, message: 'Please select a vehicle', isError: true);
        return;
      }
      final slotText = _slotController.text.trim();
      if (slotText.isEmpty) {
        DashSnackbar.show(context, message: 'Please enter a slot number', isError: true);
        return;
      }
      final slot = int.tryParse(slotText);
      if (slot == null) {
        DashSnackbar.show(context, message: 'Invalid slot number', isError: true);
        return;
      }
      widget.onSearchByTripId(_selectedDate!, _selectedVehicleNumber!, slot);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GlassPanel(
        padding: const EdgeInsets.all(16),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search mode toggle
          Row(
            children: [
              Expanded(
                child: _SearchModeButton(
                  label: 'By Trip ID',
                  isSelected: !_searchByDmNumber,
                  onTap: () {
                    setState(() {
                      _searchByDmNumber = false;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SearchModeButton(
                  label: 'By DM Number',
                  isSelected: _searchByDmNumber,
                  onTap: () {
                    setState(() {
                      _searchByDmNumber = true;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Search fields based on mode
          if (_searchByDmNumber)
            _buildDmNumberSearch()
          else
            _buildTripIdSearch(),
          const SizedBox(height: 16),
          // Search button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _performSearch,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AuthColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'Search',
                    style: TextStyle(
                      color: AuthColors.surface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildTripIdSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Date picker
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _selectDate,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AuthColors.textMainWithOpacity(0.2),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: AuthColors.textSub,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _selectedDate != null
                        ? DateFormat('MMM dd, yyyy').format(_selectedDate!)
                        : 'Select date',
                    style: TextStyle(
                      color: _selectedDate != null
                          ? AuthColors.textMain
                          : AuthColors.textSub,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Vehicle dropdown
        DropdownButtonFormField<String>(
          value: _selectedVehicleNumber,
          decoration: InputDecoration(
            labelText: 'Vehicle Number',
            labelStyle: const TextStyle(color: AuthColors.textSub),
            filled: true,
            fillColor: AuthColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: AuthColors.textMainWithOpacity(0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: AuthColors.textMainWithOpacity(0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AuthColors.primary,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
          ),
          style: const TextStyle(color: AuthColors.textMain),
          dropdownColor: AuthColors.surface,
          items: widget.vehicles.map((vehicle) {
            final vehicleNumber = vehicle['vehicleNumber'] as String? ?? '';
            return DropdownMenuItem<String>(
              value: vehicleNumber,
              child: Text(
                vehicleNumber,
                style: const TextStyle(color: AuthColors.textMain),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedVehicleNumber = value;
            });
          },
        ),
        const SizedBox(height: 12),
        // Slot input
        TextField(
          controller: _slotController,
          style: const TextStyle(color: AuthColors.textMain),
          decoration: InputDecoration(
            labelText: 'Slot',
            labelStyle: const TextStyle(color: AuthColors.textSub),
            filled: true,
            fillColor: AuthColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: AuthColors.textMainWithOpacity(0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: AuthColors.textMainWithOpacity(0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AuthColors.primary,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
          ),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildDmNumberSearch() {
    return TextField(
      controller: _dmNumberController,
      style: const TextStyle(color: AuthColors.textMain),
      decoration: InputDecoration(
        labelText: 'DM Number',
        labelStyle: const TextStyle(color: AuthColors.textSub),
        filled: true,
        fillColor: AuthColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AuthColors.textMainWithOpacity(0.2),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AuthColors.textMainWithOpacity(0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AuthColors.primary,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
      keyboardType: TextInputType.number,
    );
  }
}

class _SearchModeButton extends StatelessWidget {
  const _SearchModeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AuthColors.primary
                : AuthColors.surface.withOpacity(0.8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AuthColors.primary
                  : AuthColors.textMainWithOpacity(0.2),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? AuthColors.surface : AuthColors.textMain,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
