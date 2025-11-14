import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/models/order.dart' show PaymentType;
import '../../../../core/models/scheduled_order.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/storage_utils.dart';
import '../../../vehicle/models/vehicle.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/scheduled_order_repository.dart';
import '../pages/dm_template_print_page.dart';

class ScheduledOrdersDashboard extends StatefulWidget {
  const ScheduledOrdersDashboard({
    super.key,
    required this.organizationId,
    required this.repository,
    required this.orderRepository,
    required this.userId,
    this.userRole = 0,
  });

  final String organizationId;
  final ScheduledOrderRepository repository;
  final OrderRepository orderRepository;
  final String userId;
  final int userRole;

  @override
  State<ScheduledOrdersDashboard> createState() =>
      _ScheduledOrdersDashboardState();
}

class _ScheduledOrdersDashboardState extends State<ScheduledOrdersDashboard> {
  static const MethodChannel _tripTrackingChannel =
      MethodChannel('com.example.operon/trip_tracking');
  late DateTime _selectedDate;
  bool _isLoading = true;
  String? _selectedVehicleId;
  List<ScheduledOrder> _schedules = const [];
  Map<String, Vehicle> _vehicleMap = const {};
  String? _error;
  final Set<String> _reschedulingScheduleIds = <String>{};
  final Set<String> _dmGenerationScheduleIds = <String>{};
  final Set<String> _dmCancellationScheduleIds = <String>{};
  final ImagePicker _imagePicker = ImagePicker();
  final Set<String> _dispatchingScheduleIds = <String>{};
  final Set<String> _deliveringScheduleIds = <String>{};
  final Set<String> _returningScheduleIds = <String>{};
  final Set<String> _revertingDispatchScheduleIds = <String>{};

  bool get _isRunningOnAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadSchedules();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadSchedules({bool resetSelection = true}) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _schedules = const [];
      _vehicleMap = const {};
      if (resetSelection) {
        _selectedVehicleId = null;
      }
    });

    try {
      final schedules = await widget.repository.fetchSchedulesByDate(
        organizationId: widget.organizationId,
        scheduledDate: _selectedDate,
      );

      final vehicleIds = schedules
          .map((schedule) => schedule.vehicleId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final vehicleMap = <String, Vehicle>{};
      for (final vehicleId in vehicleIds) {
        try {
          final vehicle = await widget.repository.fetchVehicleById(
            organizationId: widget.organizationId,
            vehicleId: vehicleId,
          );
          if (vehicle != null) {
            vehicleMap[vehicleId] = vehicle;
          }
        } catch (_) {
          // Ignore failures for individual vehicles; leave them unmapped.
        }
      }

      setState(() {
        _schedules = schedules;
        _vehicleMap = vehicleMap;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _error = 'Failed to load scheduled orders: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleReschedule(ScheduledOrder schedule) async {
    if (schedule.dmNumber != null) {
      _showSnackbar(
        'Cannot reschedule once a DM has been generated.',
        backgroundColor: AppTheme.warningColor,
      );
      return;
    }

    if (_reschedulingScheduleIds.contains(schedule.id)) {
      return;
    }

    final previousVehicle = _selectedVehicleId;

    setState(() {
      _reschedulingScheduleIds.add(schedule.id);
    });

    var shouldReload = false;

    try {
      await widget.repository.deleteScheduleAndRevert(schedule: schedule);

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: AppTheme.cardColor,
            title: const Text(
              'Reschedule trip?',
              style: TextStyle(color: AppTheme.textPrimaryColor),
            ),
            content: const Text(
              'This will remove the existing schedule and return the trip to the pending list. Proceed?',
              style: TextStyle(color: AppTheme.textSecondaryColor),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) {
        shouldReload = true;
        return;
      }

      _showSnackbar(
        'Schedule removed. You can schedule this order again from the pending list.',
        backgroundColor: AppTheme.warningColor,
      );
      shouldReload = true;
    } catch (error) {
      if (mounted) {
        _showSnackbar(
          'Failed to reschedule: $error',
          backgroundColor: AppTheme.errorColor,
        );
      }
      shouldReload = true;
    } finally {
      if (!mounted) {
        return;
      }

      if (shouldReload) {
        await _loadSchedules(resetSelection: false);
        if (!mounted) {
          return;
        }
        if (previousVehicle != null) {
          setState(() {
            _selectedVehicleId = previousVehicle;
          });
        }
      }

      setState(() {
        _reschedulingScheduleIds.remove(schedule.id);
      });
    }
  }

  Future<void> _handleGenerateDm(ScheduledOrder schedule) async {
    if (_dmGenerationScheduleIds.contains(schedule.id) ||
        schedule.dmNumber != null) {
      return;
    }

    setState(() {
      _dmGenerationScheduleIds.add(schedule.id);
    });

    try {
      final updatedSchedule = await widget.repository.generateDmNumber(
        organizationId: widget.organizationId,
        scheduleId: schedule.id,
        orderId: schedule.orderId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _schedules = _schedules
            .map(
              (current) =>
                  current.id == updatedSchedule.id ? updatedSchedule : current,
            )
            .toList();
      });

      _showSnackbar(
        'DM ${updatedSchedule.dmNumber} generated successfully.',
        backgroundColor: AppTheme.successColor,
      );
    } catch (error) {
      if (mounted) {
        _showSnackbar(
          'Failed to generate DM: $error',
          backgroundColor: AppTheme.errorColor,
        );
      }
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _dmGenerationScheduleIds.remove(schedule.id);
      });
    }
  }

  Future<void> _handleCancelDm(ScheduledOrder schedule) async {
    if (_dmCancellationScheduleIds.contains(schedule.id) ||
        schedule.dmNumber == null) {
      return;
    }

    if (schedule.status != ScheduledOrderStatus.scheduled) {
      _showSnackbar(
        'DM can only be cancelled while the schedule is in scheduled status.',
        backgroundColor: AppTheme.warningColor,
      );
      return;
    }

    setState(() {
      _dmCancellationScheduleIds.add(schedule.id);
    });

    try {
      final updatedSchedule = await widget.repository.cancelDmNumber(
        organizationId: widget.organizationId,
        scheduleId: schedule.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _schedules = _schedules
            .map(
              (current) =>
                  current.id == updatedSchedule.id ? updatedSchedule : current,
            )
            .toList();
      });

      _showSnackbar(
        'DM cancelled successfully.',
        backgroundColor: AppTheme.successColor,
      );
    } catch (error) {
      if (mounted) {
        _showSnackbar(
          'Failed to cancel DM: $error',
          backgroundColor: AppTheme.errorColor,
        );
      }
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _dmCancellationScheduleIds.remove(schedule.id);
      });
    }
  }

  Future<void> _handleDispatch(ScheduledOrder schedule) async {
    if (_dispatchingScheduleIds.contains(schedule.id)) {
      return;
    }

    if (_isRunningOnAndroid) {
      final permitted = await _ensureAndroidLocationPermission();
      if (!permitted) {
        return;
      }
    }

    final meterReading = await _promptForMeterReading(
      title: 'Enter initial meter reading',
      confirmLabel: 'Start Trip',
      initialValue: schedule.initialMeterReading,
    );

    if (meterReading == null) {
      return;
    }

    setState(() {
      _dispatchingScheduleIds.add(schedule.id);
    });

    try {
      await widget.repository.markAsDispatched(
        organizationId: widget.organizationId,
        schedule: schedule,
        userId: widget.userId,
        initialMeterReading: meterReading,
        initialMeterRecordedAt: DateTime.now(),
      );

      await _startTripTrackingOnAndroid(
        schedule.id,
        _vehicleLabelFor(schedule),
      );

      if (!mounted) {
        return;
      }

      await _loadSchedules(resetSelection: false);

      if (!mounted) {
        return;
      }

      _showSnackbar(
        'Trip dispatched and ready for tracking on mobile.',
        backgroundColor: AppTheme.successColor,
      );
    } catch (error) {
      if (mounted) {
        _showSnackbar(
          'Failed to dispatch trip: $error',
          backgroundColor: AppTheme.errorColor,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _dispatchingScheduleIds.remove(schedule.id);
        });
      } else {
        _dispatchingScheduleIds.remove(schedule.id);
      }
    }
  }

  Future<void> _handleRevertDispatch(ScheduledOrder schedule) async {
    if (_revertingDispatchScheduleIds.contains(schedule.id)) {
      return;
    }

    final shouldRevert = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardColor,
          title: const Text(
            'Revert dispatch?',
            style: TextStyle(color: AppTheme.textPrimaryColor),
          ),
          content: const Text(
            'This will switch the trip back to scheduled status and pause GPS tracking.',
            style: TextStyle(color: AppTheme.textSecondaryColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (shouldRevert != true) {
      return;
    }

    setState(() {
      _revertingDispatchScheduleIds.add(schedule.id);
    });

    try {
      await widget.repository.revertDispatch(
        schedule: schedule,
        userId: widget.userId,
      );

      await _stopTripTrackingOnAndroid(schedule.id);

      if (!mounted) {
        return;
      }

      await _loadSchedules(resetSelection: false);

      if (!mounted) {
        return;
      }

      _showSnackbar(
        'Dispatch reverted successfully.',
        backgroundColor: AppTheme.warningColor,
      );
    } catch (error) {
      if (mounted) {
        _showSnackbar(
          'Failed to revert dispatch: $error',
          backgroundColor: AppTheme.errorColor,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _revertingDispatchScheduleIds.remove(schedule.id);
        });
      } else {
        _revertingDispatchScheduleIds.remove(schedule.id);
      }
    }
  }

  Future<void> _handleMarkDelivered(ScheduledOrder schedule) async {
    if (_deliveringScheduleIds.contains(schedule.id)) {
      return;
    }

    final payload = await _pickDeliveryPhoto();
    if (payload == null) {
      return;
    }

    setState(() {
      _deliveringScheduleIds.add(schedule.id);
    });

    try {
      final originalName =
          payload.originalName?.isNotEmpty == true ? payload.originalName! : 'delivery.jpg';
      final fileName = StorageUtils.generateUniqueFileName(
        originalName,
        '${schedule.id}_delivery',
      );
      final storagePath = StorageUtils.getScheduleDeliveryProofPath(
        widget.organizationId,
        schedule.id,
        fileName,
      );

      final url = await StorageUtils.uploadFile(
        storagePath,
        payload.bytes,
        fileName: fileName,
      );

      await widget.repository.markTripDelivered(
        schedule: schedule,
        userId: widget.userId,
        deliveryPhotoUrl: url,
        recordedAt: DateTime.now(),
      );

      if (!mounted) {
        return;
      }

      await _loadSchedules(resetSelection: false);

      if (!mounted) {
        return;
      }

      _showSnackbar(
        'Delivery proof saved successfully.',
        backgroundColor: AppTheme.successColor,
      );
    } catch (error) {
      if (mounted) {
        _showSnackbar(
          'Failed to mark delivery: $error',
          backgroundColor: AppTheme.errorColor,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _deliveringScheduleIds.remove(schedule.id);
        });
      } else {
        _deliveringScheduleIds.remove(schedule.id);
      }
    }
  }

  Future<void> _handleMarkReturned(ScheduledOrder schedule) async {
    if (_returningScheduleIds.contains(schedule.id)) {
      return;
    }

    final meterReading = await _promptForMeterReading(
      title: 'Enter final meter reading',
      confirmLabel: 'Complete Trip',
      initialValue: schedule.finalMeterReading,
    );

    if (meterReading == null) {
      return;
    }

    setState(() {
      _returningScheduleIds.add(schedule.id);
    });

    try {
      await widget.repository.markTripReturned(
        schedule: schedule,
        userId: widget.userId,
        finalMeterReading: meterReading,
        recordedAt: DateTime.now(),
      );

      await _stopTripTrackingOnAndroid(schedule.id);

      if (!mounted) {
        return;
      }

      await _loadSchedules(resetSelection: false);

      if (!mounted) {
        return;
      }

      _showSnackbar(
        'Trip completed and tracking stopped.',
        backgroundColor: AppTheme.successColor,
      );
    } catch (error) {
      if (mounted) {
        _showSnackbar(
          'Failed to complete trip: $error',
          backgroundColor: AppTheme.errorColor,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _returningScheduleIds.remove(schedule.id);
        });
      } else {
        _returningScheduleIds.remove(schedule.id);
      }
    }
  }

  Future<double?> _promptForMeterReading({
    required String title,
    required String confirmLabel,
    double? initialValue,
  }) async {
    final controller = TextEditingController(
      text: initialValue != null ? initialValue.toString() : '',
    );
    String? errorText;

    final result = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              backgroundColor: AppTheme.cardColor,
              title: Text(
                title,
                style: const TextStyle(color: AppTheme.textPrimaryColor),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Meter reading (km)',
                      errorText: errorText,
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  const Text(
                    'Provide the odometer value at this stage of the trip.',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final input = controller.text.trim();
                    final parsed = double.tryParse(input);
                    if (parsed == null || parsed < 0) {
                      setLocalState(() => errorText = 'Enter a valid number');
                      return;
                    }
                    Navigator.of(context).pop(parsed);
                  },
                  child: Text(confirmLabel),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<_DeliveryPhotoPayload?> _pickDeliveryPhoto() async {
    try {
      XFile? file;
      try {
        file = await _imagePicker.pickImage(
          source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
          maxWidth: 1920,
          imageQuality: 85,
        );
      } on PlatformException {
        file = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          imageQuality: 85,
        );
      }

      if (file == null) {
        return null;
      }

      final bytes = await file.readAsBytes();
      final inferredName = file.name.isNotEmpty
          ? file.name
          : file.path.split('/').last;

      return _DeliveryPhotoPayload(
        bytes: bytes,
        originalName: inferredName,
      );
    } catch (error) {
      if (mounted) {
        _showSnackbar(
          'Failed to capture delivery photo: $error',
          backgroundColor: AppTheme.errorColor,
        );
      }
      return null;
    }
  }

  Future<bool> _ensureAndroidLocationPermission() async {
    if (!_isRunningOnAndroid) {
      return true;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackbar(
        'Enable device location services to start trip tracking.',
        backgroundColor: AppTheme.warningColor,
      );
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      _showSnackbar(
        'Location permission is required to track the trip.',
        backgroundColor: AppTheme.warningColor,
      );
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackbar(
        'Location permission permanently denied. Update app permissions in settings.',
        backgroundColor: AppTheme.warningColor,
      );
      return false;
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<void> _startTripTrackingOnAndroid(
    String scheduleId,
    String vehicleLabel,
  ) async {
    if (!_isRunningOnAndroid) {
      return;
    }

    try {
      await _tripTrackingChannel.invokeMethod<void>(
        'startTripTracking',
        {
          'scheduleId': scheduleId,
          'vehicleLabel': vehicleLabel,
        },
      );
    } on PlatformException catch (error) {
      _showSnackbar(
        'Unable to start trip tracking on device: ${error.message ?? error.code}',
        backgroundColor: AppTheme.warningColor,
      );
    } catch (error) {
      _showSnackbar(
        'Unable to start trip tracking on device: $error',
        backgroundColor: AppTheme.warningColor,
      );
    }
  }

  Future<void> _stopTripTrackingOnAndroid(String scheduleId) async {
    if (!_isRunningOnAndroid) {
      return;
    }

    try {
      await _tripTrackingChannel.invokeMethod<void>(
        'stopTripTracking',
        {
          'scheduleId': scheduleId,
        },
      );
    } on PlatformException catch (error) {
      _showSnackbar(
        'Unable to stop device tracking: ${error.message ?? error.code}',
        backgroundColor: AppTheme.warningColor,
      );
    } catch (error) {
      _showSnackbar(
        'Unable to stop device tracking: $error',
        backgroundColor: AppTheme.warningColor,
      );
    }
  }

  List<DateTime> get _dateRange {
    final start = _selectedDate.subtract(const Duration(days: 2));
    return List<DateTime>.generate(
      7,
      (index) => DateTime(
        start.year,
        start.month,
        start.day + index,
      ),
    );
  }

  List<ScheduledOrder> get _filteredSchedules {
    if (_selectedVehicleId == null) {
      return _schedules;
    }
    return _schedules
        .where((schedule) => schedule.vehicleId == _selectedVehicleId)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDateSelector(),
        const SizedBox(height: AppTheme.spacingLg),
        _buildVehicleSelector(),
        const SizedBox(height: AppTheme.spacingLg),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingLg),
            child: _buildErrorBanner(_error!),
          ),
        _buildMetricsRow(),
        const SizedBox(height: AppTheme.spacingLg),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildScheduleGrid(),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    final dates = _dateRange;

    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: dates.map((date) {
          final isSelected = _isSameDay(date, _selectedDate);
          return Padding(
            padding: const EdgeInsets.only(right: AppTheme.spacingSm),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDate = DateTime(date.year, date.month, date.day);
                });
                _loadSchedules();
              },
              child: Container(
                width: 72,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingSm,
                  vertical: AppTheme.spacingSm,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? AppTheme.primaryGradient
                      : null,
                  color: isSelected
                      ? null
                      : AppTheme.cardColor.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : AppTheme.borderColor,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _monthLabel(date).toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date.day.toString(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _weekdayLabel(date).toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildVehicleSelector() {
    final vehicles = _vehicleMap.entries.toList()
      ..sort(
        (a, b) =>
            a.value.vehicleNo.toLowerCase().compareTo(
                  b.value.vehicleNo.toLowerCase(),
                ),
      );

    if (vehicles.isEmpty) {
      return Wrap(
        spacing: AppTheme.spacingSm,
        runSpacing: AppTheme.spacingSm,
        children: [
          _buildVehicleChip(
            label: 'All Vehicles',
            isSelected: true,
            onTap: () {},
          ),
        ],
      );
    }

    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildVehicleChip(
              label: 'All Vehicles',
              isSelected: _selectedVehicleId == null,
              onTap: () {
                setState(() {
                  _selectedVehicleId = null;
                });
              },
            ),
            const SizedBox(width: AppTheme.spacingSm),
            ...vehicles.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(right: AppTheme.spacingSm),
                child: _buildVehicleChip(
                  label: entry.value.vehicleNo,
                  isSelected: _selectedVehicleId == entry.key,
                  onTap: () {
                    setState(() {
                      _selectedVehicleId = entry.key;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingLg,
          vertical: AppTheme.spacingSm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.15)
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : AppTheme.borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_shipping,
              size: 16,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(width: AppTheme.spacingSm),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsRow() {
    if (_isLoading) {
      return _buildLoadingMetricsRow();
    }

    final schedules = _filteredSchedules;
    final ordersCount = schedules.length;
    final totalQuantity = schedules.fold<int>(
      0,
      (sum, schedule) => sum + schedule.quantity,
    );
    final totalValue = schedules.fold<double>(
      0,
      (sum, schedule) => sum + schedule.totalAmount,
    );

    final tiles = [
      _buildMetricTileContent(
        icon: Icons.assignment,
        title: 'Orders',
        value: ordersCount.toString(),
      ),
      _buildMetricTileContent(
        icon: Icons.inventory_2,
        title: 'Quantity',
        value: _formatCompactNumber(totalQuantity),
      ),
      _buildMetricTileContent(
        icon: Icons.currency_rupee,
        title: 'Total Value',
        value: _formatCurrency(totalValue),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 620;

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                tiles[i],
                if (i < tiles.length - 1)
                  const SizedBox(height: AppTheme.spacingSm),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              Expanded(child: tiles[i]),
              if (i < tiles.length - 1)
                const SizedBox(width: AppTheme.spacingSm),
            ],
          ],
        );
      },
    );
  }

  Widget _buildMetricTileContent({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingLg,
        vertical: AppTheme.spacingMd,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingSm),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(
              icon,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: AppTheme.spacingLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTileLoading() {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
    );
  }

  Widget _buildLoadingMetricsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 620;
        final tiles = List.generate(3, (_) => _buildMetricTileLoading());

        if (isCompact) {
          return Column(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                tiles[i],
                if (i < tiles.length - 1)
                  const SizedBox(height: AppTheme.spacingSm),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              Expanded(child: tiles[i]),
              if (i < tiles.length - 1)
                const SizedBox(width: AppTheme.spacingSm),
            ],
          ],
        );
      },
    );
  }
  Widget _buildScheduleGrid() {
    final schedules = _filteredSchedules;

    if (schedules.isEmpty) {
      return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.event_busy,
                size: 56,
                color: AppTheme.textSecondaryColor,
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Text(
                'No schedules for ${_formattedFullDate(_selectedDate)}',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 16,
                ),
              ),
            ],
          ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 1;
        if (constraints.maxWidth >= 1400) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth >= 1100) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth >= 760) {
          crossAxisCount = 2;
        }

        return GridView.builder(
          padding: const EdgeInsets.only(
            bottom: AppTheme.spacingXl,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppTheme.spacingLg,
            mainAxisSpacing: AppTheme.spacingLg,
            childAspectRatio: 1.05,
          ),
          itemCount: schedules.length,
          itemBuilder: (context, index) {
            final schedule = schedules[index];
            final vehicle = _vehicleMap[schedule.vehicleId];
            return _buildScheduleCard(schedule, vehicle, index);
          },
        );
      },
    );
  }

  Widget _buildScheduleCard(
    ScheduledOrder schedule,
    Vehicle? vehicle,
    int index,
  ) {
    final List<List<Color>> gradients = [
      [const Color(0xFF4F46E5), const Color(0xFF7C3AED)],
      [const Color(0xFF0EA5E9), const Color(0xFF22D3EE)],
      [const Color(0xFFF97316), const Color(0xFFF59E0B)],
      [const Color(0xFF10B981), const Color(0xFF14B8A6)],
    ];

    final status = schedule.status;
    final List<Color> gradient;
    if (status == ScheduledOrderStatus.scheduled) {
      gradient = [
        AppTheme.errorColor.withValues(alpha: 0.9),
        AppTheme.errorColor,
      ];
    } else if (status == ScheduledOrderStatus.dispatched) {
      gradient = [
        AppTheme.warningColor.withValues(alpha: 0.9),
        AppTheme.warningColor,
      ];
    } else if (status == ScheduledOrderStatus.delivered) {
      gradient = [
        const Color(0xFF2563EB),
        const Color(0xFF38BDF8),
      ];
    } else if (status == ScheduledOrderStatus.returned) {
      gradient = [
        AppTheme.successColor.withValues(alpha: 0.9),
        AppTheme.successColor,
      ];
    } else {
      gradient = gradients[index % gradients.length];
    }

    final bool isGeneratingDm =
        _dmGenerationScheduleIds.contains(schedule.id);
    final bool isCancellingDm =
        _dmCancellationScheduleIds.contains(schedule.id);
    final bool isRescheduling =
        _reschedulingScheduleIds.contains(schedule.id);
    final bool isBusy = isGeneratingDm || isCancellingDm || isRescheduling;

    final clientSummary = _formatClientContact(schedule);
    final driverSummary = _formatDriverContact(schedule);
    final unitPriceDisplay = _formatUnitPrice(schedule.unitPrice);
    final paymentDisplay = _paymentDisplayName(schedule.paymentType);
    final canCancelDm = schedule.status == ScheduledOrderStatus.scheduled;
    final bool hasDm = schedule.dmNumber != null;

    final String primaryLabel = hasDm
        ? 'Print DM'
        : (isGeneratingDm ? 'Generating…' : 'Generate DM');
    final VoidCallback? primaryAction = hasDm
        ? () => _openDmPrint(schedule)
        : (isGeneratingDm ? null : () => _handleGenerateDm(schedule));

    String secondaryLabel;
    VoidCallback? secondaryAction;
    Color secondaryBorderColor;
    Color secondaryTextColor;

    if (!hasDm) {
      secondaryLabel = isRescheduling ? 'Rescheduling…' : 'Reschedule';
      secondaryAction =
          isRescheduling ? null : () => _handleReschedule(schedule);
      secondaryBorderColor = AppTheme.warningColor.withValues(alpha: 0.6);
      secondaryTextColor = AppTheme.warningColor;
    } else if (canCancelDm) {
      secondaryLabel = isCancellingDm ? 'Cancelling…' : 'Cancel DM';
      secondaryAction =
          isCancellingDm ? null : () => _handleCancelDm(schedule);
      secondaryBorderColor = AppTheme.errorColor.withValues(alpha: 0.7);
      secondaryTextColor = AppTheme.errorColor;
    } else if (status == ScheduledOrderStatus.delivered) {
      secondaryLabel = 'Delivered';
      secondaryAction = null;
      secondaryBorderColor = Colors.white38;
      secondaryTextColor = Colors.white70;
    } else if (status == ScheduledOrderStatus.returned) {
      secondaryLabel = 'Returned';
      secondaryAction = null;
      secondaryBorderColor = Colors.white38;
      secondaryTextColor = Colors.white70;
    } else {
      secondaryLabel = 'Dispatched';
      secondaryAction = null;
      secondaryBorderColor = Colors.white30;
      secondaryTextColor = Colors.white60;
    }

    final card = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(1),
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle?.vehicleNo ?? schedule.vehicleId,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        schedule.slotLabel,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Icon(Icons.schedule, color: Colors.white70, size: 18),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(schedule.scheduledAt),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: AppTheme.spacingXs),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final details = <Widget>[];

                    if (clientSummary != null) {
                      details.add(
                        _buildDetailRow(
                          icon: Icons.person_outline,
                          label: 'Client',
                          value: clientSummary,
                        ),
                      );
                    }
                    if (driverSummary != null) {
                      details.add(
                        _buildDetailRow(
                          icon: Icons.badge_outlined,
                          label: 'Driver',
                          value: driverSummary,
                        ),
                      );
                    }
                    details.add(
                      _buildDetailRow(
                        icon: Icons.place_outlined,
                        label: 'Region',
                        value: [
                          schedule.orderRegion,
                          schedule.orderCity,
                        ].where((part) => part.isNotEmpty).join(', '),
                      ),
                    );
                    details.add(
                      _buildDetailRow(
                        icon: Icons.category_outlined,
                        label: 'Products',
                        value: schedule.productNames.isEmpty
                            ? '—'
                            : schedule.productNames.join(', '),
                      ),
                    );
                    details.add(
                      _buildDetailRow(
                        icon: Icons.payments_outlined,
                        label: 'Payment',
                        value: paymentDisplay,
                      ),
                    );
                    details.add(
                      _buildDetailRow(
                        icon: Icons.inventory_2_outlined,
                        label: 'Quantity',
                        value: '${schedule.quantity}',
                      ),
                    );
                    if (unitPriceDisplay != null) {
                      details.add(
                        _buildDetailRow(
                          icon: Icons.price_change_outlined,
                          label: 'Unit Price',
                          value: unitPriceDisplay,
                        ),
                      );
                    }
                    details.add(
                      _buildDetailRow(
                        icon: Icons.currency_rupee,
                        label: 'Total',
                        value: _formatCurrency(schedule.totalAmount),
                      ),
                    );
                    if (schedule.gstApplicable) {
                      details.add(
                        _buildDetailRow(
                          icon: Icons.receipt_long_outlined,
                          label: 'GST',
                          value:
                              '${schedule.gstRate.toStringAsFixed(2)}% • ${_formatCurrency(schedule.gstAmount)}',
                        ),
                      );
                    }
                    if (schedule.dmNumber != null) {
                      details.add(
                        _buildDetailRow(
                          icon: Icons.description_outlined,
                          label: 'DM Number',
                          value: _formatDmLabel(schedule),
                          onTap: () => _openDmPrint(schedule),
                        ),
                      );
                    }
                    details.add(
                      _buildDetailRow(
                        icon: Icons.local_shipping_outlined,
                        label: 'Status',
                        value: _formatScheduleStatus(schedule.status),
                      ),
                    );
                    details.add(
                      _buildDetailRow(
                        icon: Icons.alt_route_rounded,
                        label: 'Trip Stage',
                        value: _formatTripStage(schedule.tripStage),
                      ),
                    );
                    if (schedule.initialMeterReading != null) {
                      details.add(
                        _buildDetailRow(
                          icon: Icons.speed_outlined,
                          label: 'Initial Meter',
                          value:
                              _formatMeterReading(schedule.initialMeterReading!),
                        ),
                      );
                    }
                    if (schedule.finalMeterReading != null) {
                      details.add(
                        _buildDetailRow(
                          icon: Icons.flag_outlined,
                          label: 'Final Meter',
                          value:
                              _formatMeterReading(schedule.finalMeterReading!),
                        ),
                      );
                    }
                    details.add(
                      _buildDetailRow(
                        icon: Icons.photo_camera_outlined,
                        label: 'Delivery Proof',
                        value: schedule.deliveryProofUrl == null
                            ? 'Pending'
                            : 'Uploaded',
                      ),
                    );

                    final isTwoColumn = constraints.maxWidth >= 360;
                    final spacing = AppTheme.spacingXs;

                    if (isTwoColumn) {
                      final itemWidth =
                          (constraints.maxWidth - spacing) / 2;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: details
                            .map(
                              (detail) => SizedBox(
                                width: itemWidth,
                                child: detail,
                              ),
                            )
                            .toList(),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final detail in details)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: detail == details.last
                                  ? 0
                                  : AppTheme.spacingXs,
                            ),
                            child: detail,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
            if (schedule.gstApplicable || hasDm)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacingXs),
                child: Wrap(
                  spacing: AppTheme.spacingXs,
                  runSpacing: AppTheme.spacingXs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (schedule.gstApplicable)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingSm,
                          vertical: AppTheme.spacingXs,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withValues(alpha: 0.18),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                          border: Border.all(
                            color:
                                AppTheme.successColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.receipt_long_outlined,
                              size: 14,
                              color: AppTheme.successColor,
                            ),
                            const SizedBox(width: AppTheme.spacingXs),
                            Text(
                              'GST ${schedule.gstRate.toStringAsFixed(2)}% • ${_formatCurrency(schedule.gstAmount)}',
                              style: const TextStyle(
                                color: AppTheme.successColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (hasDm)
                      InkWell(
                        onTap: () => _openDmPrint(schedule),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingSm,
                            vertical: AppTheme.spacingXs,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.description_outlined,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: AppTheme.spacingXs),
                              Text(
                                _formatDmLabel(schedule),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isBusy ? null : primaryAction,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacingXs,
                      ),
                    ),
                    child: Text(
                      primaryLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingXs),
                Expanded(
                  child: OutlinedButton(
                    onPressed: isBusy ? null : secondaryAction,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacingXs,
                      ),
                      side: BorderSide(color: secondaryBorderColor),
                      foregroundColor: secondaryTextColor,
                    ),
                    child: Text(
                      secondaryLabel,
                      style: TextStyle(
                        color: secondaryAction == null
                            ? secondaryTextColor.withValues(alpha: 0.6)
                            : secondaryTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingXs),
          ],
        ),
      ),
    );

    return Stack(
      children: [
        card,
        if (isBusy)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(AppTheme.radius2xl),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: AppTheme.spacingSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              onTap == null
                  ? Text(
                      value.isEmpty ? '—' : value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 2,
                        ),
                        child: Text(
                          value.isEmpty ? '—' : value,
                          style: const TextStyle(
                            color: Color(0xFF60A5FA),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.errorColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor),
          const SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _monthLabel(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[date.month - 1];
  }

  String _weekdayLabel(DateTime date) {
    const days = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    final index = date.weekday - 1;
    return days[index < 0 ? 0 : index];
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatCurrency(double value) {
    final isNegative = value < 0;
    final fixed = value.abs().toStringAsFixed(2);
    final parts = fixed.split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : '00';

    final buffer = StringBuffer();
    for (int i = 0; i < integerPart.length; i++) {
      buffer.write(integerPart[i]);
      final remaining = integerPart.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) {
        buffer.write(',');
      }
    }

    final sign = isNegative ? '-' : '';
    return '₹$sign${buffer.toString()}.$decimalPart';
  }

  String? _formatUnitPrice(double value) {
    if (value <= 0) {
      return null;
    }
    return '₹${value.toStringAsFixed(2)} / unit';
  }

  String _paymentDisplayName(String value) {
    final normalized = value.trim();
    switch (normalized) {
      case PaymentType.payOnDelivery:
        return 'Pay on Delivery';
      case PaymentType.payLater:
        return 'Pay Later';
      case PaymentType.advance:
        return 'Advance';
      default:
        return normalized.isEmpty ? 'Not specified' : normalized;
    }
  }

  String? _formatClientContact(ScheduledOrder schedule) {
    final name = schedule.clientName?.trim() ?? '';
    final phone = schedule.clientPhone?.trim() ?? '';
    if (name.isEmpty && phone.isEmpty) {
      return null;
    }
    if (name.isEmpty) {
      return phone;
    }
    if (phone.isEmpty) {
      return name;
    }
    return '$name · $phone';
  }

  String? _formatDriverContact(ScheduledOrder schedule) {
    final name = schedule.driverName?.trim() ?? '';
    final phone = schedule.driverPhone?.trim() ?? '';
    if (name.isEmpty && phone.isEmpty) {
      return null;
    }
    if (name.isEmpty) {
      return phone;
    }
    if (phone.isEmpty) {
      return name;
    }
    return '$name · $phone';
  }

  String _vehicleLabelFor(ScheduledOrder schedule) {
    final vehicle = _vehicleMap[schedule.vehicleId];
    if (vehicle != null && vehicle.vehicleNo.trim().isNotEmpty) {
      return vehicle.vehicleNo.trim();
    }
    final fallback = schedule.vehicleId.trim();
    if (fallback.isNotEmpty) {
      return fallback;
    }
    return schedule.slotLabel;
  }

  String _formatDmLabel(ScheduledOrder schedule) {
    final number = schedule.dmNumber;
    if (number == null) {
      return '—';
    }
    return 'DM-$number';
  }
  String _formatScheduleStatus(String status) {
    switch (status) {
      case ScheduledOrderStatus.scheduled:
        return 'Scheduled';
      case ScheduledOrderStatus.dispatched:
        return 'Dispatched';
      case ScheduledOrderStatus.delivered:
        return 'Delivered';
      case ScheduledOrderStatus.returned:
        return 'Returned';
      case ScheduledOrderStatus.rescheduled:
        return 'Rescheduled';
      case ScheduledOrderStatus.completed:
        return 'Completed';
      case ScheduledOrderStatus.cancelled:
        return 'Cancelled';
      default:
        if (status.isEmpty) {
          return 'Unknown';
        }
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  String _formatTripStage(String stage) {
    switch (stage) {
      case ScheduledOrderTripStage.dispatched:
        return 'Dispatched';
      case ScheduledOrderTripStage.delivered:
        return 'Delivered';
      case ScheduledOrderTripStage.returned:
        return 'Returned';
      case ScheduledOrderTripStage.pending:
      default:
        return 'Pending';
    }
  }

  String _formatMeterReading(double value) {
    return '${value.toStringAsFixed(1)} km';
  }

  Future<void> _openDmPrint(ScheduledOrder schedule) async {
    final vehicle = _vehicleMap[schedule.vehicleId];

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DmTemplatePrintPage(
          schedule: schedule,
          organizationId: widget.organizationId,
          vehicle: vehicle,
        ),
      ),
    );
  }

  void _showSnackbar(
    String message, {
    Color? backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  String _formatCompactNumber(int value) {
    final absValue = value.abs();
    if (absValue >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (absValue >= 1000) {
      final doubleValue = value / 1000;
      final formatted = absValue % 1000 == 0
          ? doubleValue.toStringAsFixed(0)
          : doubleValue.toStringAsFixed(1);
      return '${formatted}K';
    }
    return value.toString();
  }

  String _formattedFullDate(DateTime date) {
    return '${_monthLabel(date)} ${date.day}, ${date.year}';
  }
}

class _DeliveryPhotoPayload {
  const _DeliveryPhotoPayload({
    required this.bytes,
    required this.originalName,
  });

  final Uint8List bytes;
  final String originalName;
}

