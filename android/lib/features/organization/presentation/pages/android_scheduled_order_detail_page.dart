import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/services/storage_service.dart';
import '../../models/order.dart' show PaymentType;
import '../../models/scheduled_order.dart';
import '../../models/trip_location.dart';
import '../../repositories/android_scheduled_order_repository.dart';
import '../../../vehicle/models/vehicle.dart';

class AndroidScheduledOrderDetailPage extends StatefulWidget {
  const AndroidScheduledOrderDetailPage({
    super.key,
    required this.schedule,
    required this.organizationId,
    required this.userId,
    required this.repository,
    this.vehicle,
  });

  final ScheduledOrder schedule;
  final String organizationId;
  final String userId;
  final AndroidScheduledOrderRepository repository;
  final Vehicle? vehicle;

  @override
  State<AndroidScheduledOrderDetailPage> createState() =>
      _AndroidScheduledOrderDetailPageState();
}

class _AndroidScheduledOrderDetailPageState
    extends State<AndroidScheduledOrderDetailPage> {
  static const MethodChannel _tripTrackingChannel =
      MethodChannel('com.example.operon/trip_tracking');
  static const LatLng _defaultCameraTarget = LatLng(20.5937, 78.9629);

  late ScheduledOrder _schedule;
  Timer? _dispatchTimer;
  Duration _elapsedSinceDispatch = Duration.zero;
  bool _isDispatching = false;
  bool _shouldRefresh = false;
  bool _isDelivering = false;
  bool _isReturning = false;
  bool _isRevertingDispatch = false;
  final ImagePicker _imagePicker = ImagePicker();
  final StorageService _storageService = StorageService();
  final List<TripLocation> _tripLocations = [];
  StreamSubscription<List<TripLocation>>? _tripLocationsSubscription;
  GoogleMapController? _mapController;

  bool get _isTripActive =>
      _schedule.tripStage != ScheduledOrderTripStage.pending;

  bool get _canDispatch =>
      _schedule.tripStage == ScheduledOrderTripStage.pending &&
      _schedule.dmNumber != null &&
      !_isDispatching;

  bool get _canMarkDelivered =>
      _schedule.tripStage == ScheduledOrderTripStage.dispatched &&
      !_isDelivering;

  bool get _canMarkReturned =>
      _schedule.tripStage == ScheduledOrderTripStage.delivered &&
      !_isReturning;

  @override
  void initState() {
    super.initState();
    _schedule = widget.schedule;
    _startDispatchTimerIfNeeded();
    _subscribeToTripLocations();
  }

  @override
  void dispose() {
    _dispatchTimer?.cancel();
    _tripLocationsSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _startDispatchTimerIfNeeded() {
    _dispatchTimer?.cancel();
    if (_schedule.dispatchedAt != null) {
      _updateElapsed();
      _dispatchTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _updateElapsed(),
      );
    } else {
      _elapsedSinceDispatch = Duration.zero;
    }
  }

  void _updateElapsed() {
    if (!mounted || _schedule.dispatchedAt == null) return;
    setState(() {
      _elapsedSinceDispatch = DateTime.now().difference(
        _schedule.dispatchedAt!,
      );
    });
  }

  void _subscribeToTripLocations() {
    _tripLocationsSubscription?.cancel();
    _tripLocationsSubscription = widget.repository
        .watchTripLocations(_schedule.id)
        .listen((locations) {
      if (!mounted) {
        return;
      }
      if (_schedule.tripStage == ScheduledOrderTripStage.pending) {
        setState(() {
          _tripLocations.clear();
        });
        return;
      }
      setState(() {
        _tripLocations
          ..clear()
          ..addAll(locations);
      });
      if (locations.isNotEmpty && _mapController != null) {
        final latest = locations.first;
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(latest.latitude, latest.longitude),
            15,
          ),
        );
      }
    });
  }

  LatLng? get _latestLatLng {
    if (_tripLocations.isEmpty) {
      return null;
    }
    final latest = _tripLocations.first;
    return LatLng(latest.latitude, latest.longitude);
  }

  LatLng? get _startingLatLng {
    if (_tripLocations.isEmpty) {
      return null;
    }
    final oldest = _tripLocations.last;
    return LatLng(oldest.latitude, oldest.longitude);
  }

  List<LatLng> get _polylinePoints {
    if (_tripLocations.isEmpty) {
      return const [];
    }
    return _tripLocations
        .map((location) => LatLng(location.latitude, location.longitude))
        .toList()
        .reversed
        .toList();
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    final latest = _latestLatLng;
    if (latest != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('latest'),
          position: latest,
          infoWindow: const InfoWindow(title: 'Current position'),
        ),
      );
    }
    final start = _startingLatLng;
    if (start != null &&
        (latest == null ||
            start.latitude != latest.latitude ||
            start.longitude != latest.longitude)) {
      markers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: start,
          infoWindow: const InfoWindow(title: 'Trip start'),
        ),
      );
    }
    return markers;
  }

  Set<Polyline> _buildPolylines() {
    final points = _polylinePoints;
    if (points.length < 2) {
      return const <Polyline>{};
    }
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        width: 5,
        color: AppTheme.primaryColor,
      ),
    };
  }

  Future<void> _handleDispatch() async {
    if (!_canDispatch) {
      return;
    }

    final permitted = await _ensureLocationPermission();
    if (!permitted) {
      return;
    }

    final initialReading = await _promptForMeterReading(
      title: 'Enter initial meter reading',
      confirmLabel: 'Start Trip',
      initialValue: _schedule.initialMeterReading,
    );

    if (initialReading == null) {
      return;
    }

    setState(() {
      _isDispatching = true;
    });

    try {
      final updatedSchedule = await widget.repository.markAsDispatched(
        organizationId: widget.organizationId,
        schedule: _schedule,
        userId: widget.userId,
        initialMeterReading: initialReading,
        initialMeterRecordedAt: DateTime.now(),
      );

      await _startTripTrackingOnAndroid(
        updatedSchedule.id,
        _vehicleLabelFor(updatedSchedule),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _schedule = updatedSchedule;
        _isDispatching = false;
        _shouldRefresh = true;
      });
      _startDispatchTimerIfNeeded();
      _subscribeToTripLocations();

      _showSnackbar(
        'Trip dispatched. GPS tracking active.',
        backgroundColor: AppTheme.successColor,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isDispatching = false;
      });
      _showSnackbar(
        'Failed to dispatch: $error',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  Future<void> _handleRevertDispatch() async {
    if (_isRevertingDispatch) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Revert dispatch?',
            style: TextStyle(color: AppTheme.textPrimaryColor),
          ),
          content: const Text(
            'This will move the trip back to scheduled status and stop GPS tracking on the driver device.',
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

    if (confirm != true) {
      return;
    }

    setState(() {
      _isRevertingDispatch = true;
    });

    try {
      await _stopTripTrackingOnAndroid(_schedule.id);
      final updatedSchedule = await widget.repository.revertDispatch(
        schedule: _schedule,
        userId: widget.userId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _schedule = updatedSchedule;
        _isRevertingDispatch = false;
        _shouldRefresh = true;
        _tripLocations.clear();
      });
      _dispatchTimer?.cancel();
      _elapsedSinceDispatch = Duration.zero;

      _showSnackbar(
        'Dispatch reverted successfully.',
        backgroundColor: AppTheme.warningColor,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isRevertingDispatch = false;
      });
      _showSnackbar(
        'Failed to revert dispatch: $error',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  Future<void> _handleMarkDelivered() async {
    if (!_canMarkDelivered) {
      return;
    }

    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        imageQuality: 85,
      );

      if (file == null) {
        return;
      }

      setState(() {
        _isDelivering = true;
      });

      final Uint8List bytes = await file.readAsBytes();
      final fileName = _buildDeliveryFileName(file.name);
      final url = await _storageService.uploadScheduleDeliveryProof(
        organizationId: widget.organizationId,
        scheduleId: _schedule.id,
        bytes: bytes,
        fileName: fileName,
      );

      final updatedSchedule = await widget.repository.markTripDelivered(
        schedule: _schedule,
        userId: widget.userId,
        deliveryPhotoUrl: url,
        recordedAt: DateTime.now(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _schedule = updatedSchedule;
        _isDelivering = false;
        _shouldRefresh = true;
      });

      _showSnackbar(
        'Delivery proof saved.',
        backgroundColor: AppTheme.successColor,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isDelivering = false;
      });
      _showSnackbar(
        'Failed to mark delivered: $error',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  Future<void> _handleMarkReturned() async {
    if (!_canMarkReturned) {
      return;
    }

    final finalReading = await _promptForMeterReading(
      title: 'Enter final meter reading',
      confirmLabel: 'Complete Trip',
      initialValue: _schedule.finalMeterReading,
    );

    if (finalReading == null) {
      return;
    }

    setState(() {
      _isReturning = true;
    });

    try {
      final updatedSchedule = await widget.repository.markTripReturned(
        schedule: _schedule,
        userId: widget.userId,
        finalMeterReading: finalReading,
        recordedAt: DateTime.now(),
      );

      await _stopTripTrackingOnAndroid(_schedule.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _schedule = updatedSchedule;
        _isReturning = false;
        _shouldRefresh = true;
      });

      _dispatchTimer?.cancel();
      _elapsedSinceDispatch = Duration.zero;

      _showSnackbar(
        'Trip completed successfully.',
        backgroundColor: AppTheme.successColor,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isReturning = false;
      });
      _showSnackbar(
        'Failed to complete trip: $error',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  String _formatElapsed(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final schedule = _schedule;
    final paymentDisplay = _paymentDisplayName(schedule.paymentType);
    final vehicleLabel = _vehicleLabelFor(schedule);
    final slotLabel = schedule.slotLabel;
    final scheduledAtLabel =
        DateFormat('EEE, MMM d • hh:mm a').format(schedule.scheduledAt);
    final region = [
      schedule.orderRegion,
      schedule.orderCity,
    ].where((part) => part.trim().isNotEmpty).join(', ');
    final products = schedule.productNames.isEmpty
        ? '—'
        : schedule.productNames.join(', ');
    final clientName =
        schedule.clientName?.trim().isNotEmpty == true ? schedule.clientName!.trim() : 'Not specified';
    final unitPriceDisplay = _formatUnitPrice(schedule.unitPrice);
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    final subtotalDisplay =
        currencyFormatter.format(schedule.totalAmount - schedule.gstAmount);
    final gstDisplay = schedule.gstApplicable && schedule.gstAmount > 0
        ? currencyFormatter.format(schedule.gstAmount)
        : 'Not applied';
    final totalDisplay = currencyFormatter.format(schedule.totalAmount);
    final notes = schedule.notes?.trim();

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_shouldRefresh);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Schedule Details'),
          backgroundColor: AppTheme.surfaceColor,
        ),
        backgroundColor: AppTheme.backgroundColor,
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeaderCard(
              vehicleLabel: vehicleLabel,
              slotLabel: slotLabel,
              clientName: clientName,
              scheduledTime: scheduledAtLabel,
              paymentDisplay: paymentDisplay,
            ),
            const SizedBox(height: 16),
            if (schedule.dmNumber != null)
              _buildDispatchCard(currencyFormatter)
            else
              _buildPendingDmBanner(),
            const SizedBox(height: 16),
            _buildTripTrackingCard(),
            const SizedBox(height: 16),
            _buildDetailsSection(
              rows: [
                _InfoRow(label: 'Products', value: products),
                if (region.isNotEmpty)
                  _InfoRow(label: 'Region', value: region),
                _InfoRow(label: 'Quantity', value: '${schedule.quantity}'),
                if (unitPriceDisplay != null)
                  _InfoRow(label: 'Unit Price', value: unitPriceDisplay),
                _InfoRow(label: 'Subtotal', value: subtotalDisplay),
                _InfoRow(label: 'GST Amount', value: gstDisplay),
                _InfoRow(label: 'Total Amount', value: totalDisplay),
              ],
            ),
            const SizedBox(height: 16),
            if (notes?.isNotEmpty == true) ...[
              const SizedBox(height: 16),
              _buildNotesCard(notes!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard({
    required String vehicleLabel,
    required String slotLabel,
    required String clientName,
    required String scheduledTime,
    required String paymentDisplay,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicleLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      clientName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildChip(slotLabel),
                        const SizedBox(width: 8),
                        _buildChip(scheduledTime),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Icon(Icons.payments_outlined,
                      color: Colors.white70, size: 20),
                  const SizedBox(height: 6),
                  Text(
                    paymentDisplay,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection({
    required List<_InfoRow> rows,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
      ),
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTwoColumn = constraints.maxWidth >= 360;
          if (!isTwoColumn) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildInfoColumn(rows),
            );
          }

          final perColumn = (rows.length / 2).ceil();
          final List<List<_InfoRow>> columnChunks = [];
          for (var start = 0; start < rows.length; start += perColumn) {
            columnChunks.add(
              rows.sublist(
                start,
                math.min(start + perColumn, rows.length),
              ),
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < columnChunks.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == columnChunks.length - 1 ? 0 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildInfoColumn(columnChunks[i]),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildInfoColumn(List<_InfoRow> rows) {
    final widgets = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      widgets.add(_buildInfoRow(rows[i]));
      if (i != rows.length - 1) {
        widgets.add(const SizedBox(height: 12));
      }
    }
    return widgets;
  }

  Widget _buildInfoRow(_InfoRow row) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.label,
          style: const TextStyle(
            color: AppTheme.textSecondaryColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          row.value.isEmpty ? '—' : row.value,
          style: const TextStyle(
            color: AppTheme.textPrimaryColor,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesCard(String notes) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSecondaryColor),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notes',
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            notes,
            style: const TextStyle(
              color: AppTheme.textPrimaryColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDispatchCard(NumberFormat currencyFormatter) {
    final dispatchedAt = _schedule.dispatchedAt;
    final elapsedLabel =
        dispatchedAt != null ? _formatElapsed(_elapsedSinceDispatch) : null;
    final initialMeter = _schedule.initialMeterReading;
    final tripStageLabel = _formatTripStage(_schedule.tripStage);
    final hasDeliveryProof = _schedule.deliveryProofUrl != null;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSecondaryColor),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'DM-${_schedule.dmNumber}',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              if (_schedule.totalAmount > 0)
                Text(
                  currencyFormatter.format(_schedule.totalAmount),
                  style: const TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const Divider(height: 28),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dispatch',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_isTripActive && dispatchedAt != null)
                      Text(
                        'Dispatched ${DateFormat('MMM d • h:mm a').format(dispatchedAt)}',
                        style: const TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      const Text(
                        'Tap the switch to dispatch and start driver tracking.',
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _isDispatching
                  ? const SizedBox(
                      height: 36,
                      width: 36,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Switch(
                      value: _isTripActive,
                      onChanged: _canDispatch ? (_) => _handleDispatch() : null,
                      activeColor: AppTheme.primaryColor,
                    ),
            ],
          ),
          if (_isTripActive && elapsedLabel != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.timer_outlined,
                    size: 18, color: AppTheme.textSecondaryColor),
                const SizedBox(width: 8),
                Text(
                  'Elapsed: $elapsedLabel',
                  style: const TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          if (initialMeter != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.speed_outlined,
                    size: 18, color: AppTheme.textSecondaryColor),
                const SizedBox(width: 8),
                Text(
                  'Initial meter: ${_formatMeter(initialMeter)}',
                  style: const TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.flag_outlined,
                  size: 18, color: AppTheme.textSecondaryColor),
              const SizedBox(width: 8),
              Text(
                'Trip stage: $tripStageLabel',
                style: const TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (_schedule.finalMeterReading != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.speed,
                    size: 18, color: AppTheme.textSecondaryColor),
                const SizedBox(width: 8),
                Text(
                  'Final meter: ${_formatMeter(_schedule.finalMeterReading!)}',
                  style: const TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          if (hasDeliveryProof) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.photo_camera_outlined,
                    size: 18, color: AppTheme.textSecondaryColor),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _schedule.deliveryProofUrl == null
                      ? null
                      : () => _launchUrl(_schedule.deliveryProofUrl!),
                  child: const Text('View delivery proof'),
                ),
              ],
            ),
          ],
          if (_isTripActive &&
              _schedule.tripStage != ScheduledOrderTripStage.returned) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isRevertingDispatch ? null : _handleRevertDispatch,
                icon: _isRevertingDispatch
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.restart_alt),
                label: const Text('Revert Dispatch'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingDmBanner() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.warningColor.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            color: AppTheme.warningColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Generate a Delivery Memo before dispatching this trip.',
              style: const TextStyle(
                color: AppTheme.warningColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripTrackingCard() {
    final hasTripStarted =
        _schedule.tripStage != ScheduledOrderTripStage.pending;
    final latestLatLng = _latestLatLng;
    final polylinePoints = _polylinePoints;
    final markers = _buildMarkers();
    final polylines = _buildPolylines();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSecondaryColor),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Live Trip Tracking',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textPrimaryColor,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasTripStarted)
            const Text(
              'Dispatch the trip to start receiving GPS updates from the driver.',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontWeight: FontWeight.w600,
              ),
            )
          else if (_tripLocations.isEmpty)
            const Text(
              'Waiting for the driver device to send the first GPS update…',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            SizedBox(
              height: 240,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: latestLatLng ?? _defaultCameraTarget,
                    zoom: latestLatLng != null ? 15 : 5,
                  ),
                  markers: markers,
                  polylines: polylines,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: true,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                ),
              ),
            ),
          if (polylinePoints.length >= 2) ...[
            const SizedBox(height: 12),
            Text(
              'Locations received: ${_tripLocations.length}',
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (hasTripStarted &&
              _schedule.tripStage != ScheduledOrderTripStage.returned) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: _canMarkDelivered ? _handleMarkDelivered : null,
                  icon: _isDelivering
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: const Text('Mark Delivered'),
                ),
                ElevatedButton.icon(
                  onPressed: _canMarkReturned ? _handleMarkReturned : null,
                  icon: _isReturning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.flag),
                  label: const Text('Mark Return'),
                ),
              ],
            ),
          ],
          if (_schedule.tripStage == ScheduledOrderTripStage.returned)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Trip marked as returned and tracking has been stopped.',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _paymentDisplayName(String value) {
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

  static String? _formatUnitPrice(double value) {
    if (value <= 0) {
      return null;
    }
    return '₹${value.toStringAsFixed(2)} / unit';
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

  String _formatMeter(double value) {
    return '${value.toStringAsFixed(1)} km';
  }

  String _vehicleLabelFor(ScheduledOrder schedule) {
    final vehicle = widget.vehicle;
    if (vehicle != null && vehicle.vehicleNo.trim().isNotEmpty) {
      return vehicle.vehicleNo.trim();
    }
    final fallback = schedule.vehicleId.trim();
    if (fallback.isNotEmpty) {
      return fallback;
    }
    return schedule.slotLabel;
  }

  String _buildDeliveryFileName(String originalName) {
    final sanitized = originalName.trim();
    final extension = sanitized.contains('.')
        ? sanitized.split('.').last
        : 'jpg';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${_schedule.id}_$timestamp.$extension';
  }

  Future<bool> _ensureLocationPermission() async {
    final status = await Permission.location.status;
    if (status.isGranted) {
      return true;
    }

    final result = await Permission.location.request();
    if (result.isGranted) {
      return true;
    }

    if (result.isPermanentlyDenied) {
      await openAppSettings();
    }

    _showSnackbar(
      'Location permission is required to start trip tracking.',
      backgroundColor: AppTheme.warningColor,
    );
    return false;
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
                  const SizedBox(height: 8),
                  const Text(
                    'Provide the odometer value shown on the vehicle.',
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
                      setLocalState(
                        () => errorText = 'Enter a valid number',
                      );
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

  Future<void> _startTripTrackingOnAndroid(
    String scheduleId,
    String vehicleLabel,
  ) async {
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
        'Unable to start device tracking: ${error.message ?? error.code}',
        backgroundColor: AppTheme.warningColor,
      );
    } catch (error) {
      _showSnackbar(
        'Unable to start device tracking: $error',
        backgroundColor: AppTheme.warningColor,
      );
    }
  }

  Future<void> _stopTripTrackingOnAndroid(String scheduleId) async {
    try {
      await _tripTrackingChannel.invokeMethod<void>(
        'stopTripTracking',
        {
          'scheduleId': scheduleId,
        },
      );
    } catch (error) {
      // Best effort; do not block main flow
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showSnackbar(
        'Invalid URL: $url',
        backgroundColor: AppTheme.errorColor,
      );
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnackbar(
        'Unable to open link.',
        backgroundColor: AppTheme.errorColor,
      );
    }
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

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;
}

