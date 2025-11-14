import 'package:flutter/material.dart';

import '../../../vehicle/models/vehicle.dart';
import '../../models/order.dart';
import '../../repositories/android_scheduled_order_repository.dart';
import '../../../../core/app_theme.dart';

class AndroidScheduleOrderDialog extends StatefulWidget {
  const AndroidScheduleOrderDialog({
    super.key,
    required this.organizationId,
    required this.order,
    required this.userId,
    required this.scheduledOrderRepository,
  });

  final String organizationId;
  final Order order;
  final String userId;
  final AndroidScheduledOrderRepository scheduledOrderRepository;

  @override
  State<AndroidScheduleOrderDialog> createState() =>
      _AndroidScheduleOrderDialogState();
}

class _AndroidScheduleOrderDialogState extends State<AndroidScheduleOrderDialog> {
  final TextEditingController _notesController = TextEditingController();

  bool _loadingVehicles = true;
  bool _loadingSlots = false;
  bool _submitting = false;
  String? _error;

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
      _error = null;
    });

    try {
      final vehicles = await widget.scheduledOrderRepository.fetchEligibleVehicles(
        organizationId: widget.organizationId,
        requiredQuantity: widget.order.totalQuantity,
      );

      if (vehicles.isEmpty) {
        setState(() {
          _vehicles = const [];
          _loadingVehicles = false;
          _error = 'No eligible vehicles available.';
        });
        return;
      }

      setState(() {
        _vehicles = vehicles;
        _loadingVehicles = false;
      });
    } catch (error) {
      setState(() {
        _loadingVehicles = false;
        _error = 'Failed to load vehicles: $error';
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );

    if (selected != null) {
      setState(() {
        _selectedDate = DateTime(selected.year, selected.month, selected.day);
        _selectedSlot = null;
        _availableSlots = const [];
      });
      await _loadSlotsIfReady();
    }
  }

  Future<void> _loadSlotsIfReady() async {
    if (_selectedVehicle == null || _selectedDate == null) return;

    setState(() {
      _loadingSlots = true;
      _error = null;
      _selectedSlot = null;
      _availableSlots = const [];
    });

    try {
      final slots = await widget.scheduledOrderRepository.fetchAvailableSlots(
        organizationId: widget.organizationId,
        vehicle: _selectedVehicle!,
        scheduledDate: _selectedDate!,
      );

      setState(() {
        _availableSlots = slots;
        _loadingSlots = false;
        if (_availableSlots.isEmpty) {
          _error = 'No slots available for selected date.';
        }
      });
    } catch (error) {
      setState(() {
        _loadingSlots = false;
        _error = 'Failed to load slots: $error';
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedVehicle == null ||
        _selectedDate == null ||
        _selectedSlot == null) {
      setState(() {
        _error = 'Please select date, vehicle, and slot.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.scheduledOrderRepository.createSchedule(
        order: widget.order,
        vehicle: _selectedVehicle!,
        scheduledDate: _selectedDate!,
        slotIndex: _selectedSlot!,
        userId: widget.userId,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ScheduleConflictException {
      setState(() {
        _error =
            'Selected slot has already been booked. Please choose another slot.';
        _submitting = false;
      });
      await _loadSlotsIfReady();
    } on RemainingTripsExhaustedException {
      setState(() {
        _error = 'All trips have already been scheduled for this order.';
        _submitting = false;
      });
    } catch (error) {
      setState(() {
        _error = 'Failed to schedule order: $error';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isCompact = media.size.width < 420;
    final maxWidth = isCompact ? media.size.width - 32 : 480.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 16 : 40,
        vertical: isCompact ? 24 : 40,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.borderSecondaryColor.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 20 : 24,
                  vertical: 20,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Schedule Order',
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close, color: AppTheme.textSecondaryColor),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFF1F2937)),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 20 : 24,
                    vertical: 20,
                  ),
                  child: _buildContent(isCompact: isCompact),
                ),
              ),
              const Divider(height: 1, color: Color(0xFF1F2937)),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 16 : 24,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _submitting ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _canSubmit ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(110, 44),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Confirm'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent({required bool isCompact}) {
    if (_loadingVehicles) {
      return const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360 || isCompact;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.errorColor),
                ),
              ),
            ],
            _buildSummary(isCompact: compact),
            const SizedBox(height: 16),
            _buildDateSelector(),
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
        );
      },
    );
  }

  Widget _buildSummary({required bool isCompact}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
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
                _buildTripsBadge(),
              ],
            ),
    );
  }

  List<Widget> _buildSummaryItems() {
    return [
      Text(
        widget.order.orderId,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimaryColor,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Total quantity: ${widget.order.totalQuantity}',
        style: const TextStyle(color: AppTheme.textSecondaryColor),
      ),
      Text(
        'Remaining trips: ${widget.order.remainingTrips}',
        style: const TextStyle(color: AppTheme.textSecondaryColor),
      ),
    ];
  }

  Widget _buildTripsBadge() {
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

  Widget _buildDateSelector() {
    return OutlinedButton.icon(
      onPressed: _loadingSlots || _submitting ? null : _pickDate,
      icon: const Icon(Icons.calendar_today_rounded),
      label: Text(
        _selectedDate != null
            ? _formatDate(_selectedDate!)
            : 'Select scheduling date',
      ),
    );
  }

  Widget _buildVehicleDropdown() {
    return DropdownButtonFormField<Vehicle>(
      value: _selectedVehicle,
      decoration: const InputDecoration(
        labelText: 'Vehicle',
        border: OutlineInputBorder(),
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
        style: TextStyle(color: AppTheme.textSecondaryColor),
      );
    }

    if (_loadingSlots) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_availableSlots.isEmpty) {
      return const Text(
        'No slots available for the selected configuration.',
        style: TextStyle(color: AppTheme.textSecondaryColor),
      );
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

