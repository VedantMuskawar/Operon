import 'package:flutter/material.dart';

import '../../../../core/models/order.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../vehicle/models/vehicle.dart';
import '../../repositories/scheduled_order_repository.dart';

class ScheduleOrderDialog extends StatefulWidget {
  const ScheduleOrderDialog({
    super.key,
    required this.organizationId,
    required this.order,
    required this.userId,
    required this.repository,
  });

  final String organizationId;
  final Order order;
  final String userId;
  final ScheduledOrderRepository repository;

  @override
  State<ScheduleOrderDialog> createState() => _ScheduleOrderDialogState();
}

class _ScheduleOrderDialogState extends State<ScheduleOrderDialog> {
  final TextEditingController _notesController = TextEditingController();

  bool _loadingVehicles = true;
  bool _loadingSlots = false;
  bool _submitting = false;
  String? _errorMessage;

  List<Vehicle> _vehicles = const [];
  Vehicle? _selectedVehicle;
  DateTime? _selectedDate;
  List<int> _availableSlots = const [];
  int? _selectedSlot;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _loadingVehicles = true;
      _errorMessage = null;
    });

    try {
      final vehicles = await widget.repository.fetchEligibleVehicles(
        organizationId: widget.organizationId,
        requiredQuantity: widget.order.totalQuantity,
      );

      setState(() {
        _vehicles = vehicles;
        _loadingVehicles = false;
        if (_vehicles.isEmpty) {
          _errorMessage =
              'No eligible vehicles available for the required quantity.';
        }
      });
    } catch (error) {
      setState(() {
        _loadingVehicles = false;
        _errorMessage = 'Failed to load vehicles: $error';
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initialDate = _selectedDate ?? now;

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(now) ? now : initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );

    if (selected != null) {
      setState(() {
        _selectedDate = DateTime(selected.year, selected.month, selected.day);
        _selectedSlot = null;
      });
      await _loadSlotsIfReady();
    }
  }

  Future<void> _loadSlotsIfReady() async {
    if (_selectedVehicle == null || _selectedDate == null) return;

    setState(() {
      _loadingSlots = true;
      _errorMessage = null;
      _availableSlots = const [];
      _selectedSlot = null;
    });

    try {
      final slots = await widget.repository.fetchAvailableSlots(
        organizationId: widget.organizationId,
        vehicle: _selectedVehicle!,
        scheduledDate: _selectedDate!,
      );

      setState(() {
        _availableSlots = slots;
        _loadingSlots = false;
        if (_availableSlots.isEmpty) {
          _errorMessage = 'No slots available for the selected date.';
        }
      });
    } catch (error) {
      setState(() {
        _loadingSlots = false;
        _errorMessage = 'Failed to load slots: $error';
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedVehicle == null ||
        _selectedDate == null ||
        _selectedSlot == null) {
      setState(() {
        _errorMessage = 'Please select date, vehicle, and slot.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await widget.repository.createSchedule(
        order: widget.order,
        vehicle: _selectedVehicle!,
        scheduledDate: _selectedDate!,
        slotIndex: _selectedSlot!,
        userId: widget.userId,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ScheduleConflictException {
      setState(() {
        _errorMessage =
            'Selected slot has just been booked. Please choose another slot.';
        _submitting = false;
      });
      await _loadSlotsIfReady();
    } on RemainingTripsExhaustedException {
      setState(() {
        _errorMessage = 'All trips have already been scheduled for this order.';
        _submitting = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Failed to schedule order: $error';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isCompact = media.size.width < 600;

    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 16 : 40,
        vertical: isCompact ? 24 : 24,
      ),
      titlePadding: EdgeInsets.only(
        top: 20,
        left: isCompact ? 20 : 24,
        right: isCompact ? 20 : 24,
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 20 : 24,
        vertical: 16,
      ),
      actionsPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 16,
        vertical: 12,
      ),
      title: const Text('Schedule Order'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isCompact ? double.infinity : 480,
        ),
        child: _buildContent(),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _canSubmit ? _submit : null,
          child: _submitting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Confirm'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_loadingVehicles) {
      return const SizedBox(
        height: 160,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final isCompactContent = width < 360;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage != null) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
          _buildSummarySection(isCompact: isCompactContent),
          const SizedBox(height: 16),
          _buildDatePicker(),
          const SizedBox(height: 12),
          _buildVehicleDropdown(),
          const SizedBox(height: 12),
          _buildSlotSelector(),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection({bool isCompact = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildSummaryItems(),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildSummaryItems(),
                  ),
                ),
                const SizedBox(width: 12),
                _buildQuantityBadge(),
              ],
            ),
    );
  }

  List<Widget> _buildSummaryItems() {
    return [
      Text(
        widget.order.orderId,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 4),
      Text(
        'Total quantity: ${widget.order.totalQuantity}',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      Text(
        'Remaining trips: ${widget.order.remainingTrips}',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 4),
      Text(
        widget.order.gstApplicable
            ? 'GST: Applicable (${widget.order.gstRate.toStringAsFixed(2)}%)'
            : 'GST: Not applicable',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: widget.order.gstApplicable
                  ? AppTheme.successColor
                  : AppTheme.textSecondaryColor,
              fontWeight: widget.order.gstApplicable
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
      ),
    ];
  }

  Widget _buildQuantityBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.local_shipping_outlined,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.order.remainingTrips} trips left',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _loadingSlots || _submitting ? null : _pickDate,
            icon: const Icon(Icons.calendar_today),
            label: Text(
              _selectedDate != null
                  ? _formatDate(_selectedDate!)
                  : 'Select date',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleDropdown() {
    return DropdownButtonFormField<Vehicle>(
      value: _selectedVehicle,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        labelText: 'Vehicle',
      ),
      items: _vehicles
          .map(
            (vehicle) => DropdownMenuItem<Vehicle>(
              value: vehicle,
              child: Text(
                '${vehicle.vehicleNo} (${vehicle.vehicleQuantity})',
              ),
            ),
          )
          .toList(),
      onChanged: _loadingSlots || _submitting
          ? null
          : (vehicle) async {
              setState(() {
                _selectedVehicle = vehicle;
              });
              await _loadSlotsIfReady();
            },
    );
  }

  Widget _buildSlotSelector() {
    if (_selectedVehicle == null || _selectedDate == null) {
      return const Text(
        'Select date and vehicle to view available slots.',
      );
    }

    if (_loadingSlots) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_availableSlots.isEmpty) {
      return const Text('No slots available for the selected configuration.');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _availableSlots
          .map(
            (slot) => ChoiceChip(
              label: Text('Trip ${slot + 1}'),
              selected: _selectedSlot == slot,
              onSelected: _submitting
                  ? null
                  : (selected) {
                      setState(() {
                        _selectedSlot = selected ? slot : null;
                      });
                    },
            ),
          )
          .toList(),
    );
  }

  bool get _canSubmit =>
      !_submitting &&
      _selectedVehicle != null &&
      _selectedDate != null &&
      _selectedSlot != null;

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}



