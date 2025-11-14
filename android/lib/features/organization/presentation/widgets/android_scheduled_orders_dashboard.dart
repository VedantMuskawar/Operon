import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/app_theme.dart';
import '../../models/order.dart';
import '../../models/scheduled_order.dart';
import '../../repositories/android_order_repository.dart';
import '../../repositories/android_scheduled_order_repository.dart';
import '../../../vehicle/models/vehicle.dart' as android_vehicle;
import '../pages/android_scheduled_order_detail_page.dart';
import '../pages/android_dm_preview_page.dart';

class AndroidScheduledOrdersDashboard extends StatefulWidget {
  const AndroidScheduledOrdersDashboard({
    super.key,
    required this.organizationId,
    required this.repository,
    required this.orderRepository,
    required this.userId,
  });

  final String organizationId;
  final AndroidScheduledOrderRepository repository;
  final AndroidOrderRepository orderRepository;
  final String userId;

  @override
  State<AndroidScheduledOrdersDashboard> createState() =>
      _AndroidScheduledOrdersDashboardState();
}

class _AndroidScheduledOrdersDashboardState
    extends State<AndroidScheduledOrdersDashboard> {
  late DateTime _selectedDate;
  bool _isLoading = true;
  String? _selectedVehicleId;
  List<ScheduledOrder> _schedules = const [];
  Map<String, android_vehicle.Vehicle> _vehicleMap = const {};
  String? _errorMessage;
  final Set<String> _reschedulingScheduleIds = <String>{};
  final Set<String> _dmGenerationScheduleIds = <String>{};
  final Set<String> _dmCancellationScheduleIds = <String>{};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadSchedules();
  }

  Future<void> _loadSchedules({bool resetSelection = true}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
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

      final vehicleMap = <String, android_vehicle.Vehicle>{};
      for (final vehicleId in vehicleIds) {
        try {
          final vehicle = await widget.repository.fetchVehicleById(
            organizationId: widget.organizationId,
            vehicleId: vehicleId,
          );
          if (vehicle != null) {
            vehicleMap[vehicleId] = vehicle;
          }
        } catch (_) {}
      }

      setState(() {
        _schedules = schedules;
        _vehicleMap = vehicleMap;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Failed to load schedules: $error';
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Reschedule trip?',
              style: TextStyle(color: AppTheme.textPrimaryColor),
            ),
            content: const Text(
              'We will remove the current schedule and move the trip back to pending orders. Do you want to continue?',
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
        'Schedule removed. Schedule again from the pending orders list.',
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
        'DM can be cancelled only when schedule status is scheduled.',
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

  Future<void> _openDmPrint(ScheduledOrder schedule) async {
    final android_vehicle.Vehicle? vehicle = _vehicleMap[schedule.vehicleId];

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AndroidDmPreviewPage(
          schedule: schedule,
          organizationId: widget.organizationId,
          vehicle: vehicle,
        ),
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
        const SizedBox(height: 16),
        _buildVehicleSelector(),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          _buildErrorBanner(_errorMessage!),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => _loadSchedules(resetSelection: false),
                  child: _buildScheduleList(),
                ),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    final dates = _dateRange;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderColor),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: dates.map((date) {
          final isSelected = _isSameDay(date, _selectedDate);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDate = DateTime(date.year, date.month, date.day);
                });
                _loadSchedules();
              },
              child: Container(
                width: 60,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? AppTheme.primaryGradient
                      : null,
                  color: isSelected
                      ? null
                      : AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(16),
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
                      DateFormat('MMM').format(date).toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('d').format(date),
                      style: const TextStyle(
                        color: AppTheme.textPrimaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEE').format(date).toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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
        ),
      ),
    );
  }

  Widget _buildVehicleSelector() {
    final vehicles = _vehicleMap.entries.toList()
      ..sort(
        (a, b) => a.value.vehicleNo
            .toLowerCase()
            .compareTo(b.value.vehicleNo.toLowerCase()),
      );

    if (vehicles.isEmpty && !_isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: const Text(
          'No vehicles scheduled',
          style: TextStyle(
            color: AppTheme.textSecondaryColor,
          ),
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              label: const Text('All Vehicles'),
              selected: _selectedVehicleId == null,
              onSelected: (_) {
                setState(() {
                  _selectedVehicleId = null;
                });
              },
            ),
            const SizedBox(width: 8),
            ...vehicles.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(entry.value.vehicleNo),
                  selected: _selectedVehicleId == entry.key,
                  onSelected: (_) {
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


  Widget _buildScheduleList() {
    final schedules = _filteredSchedules;

    if (schedules.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: 300,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 56,
                    color: AppTheme.textSecondaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No schedules on ${DateFormat('MMM d').format(_selectedDate)}',
                    style: const TextStyle(
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemBuilder: (context, index) {
        final schedule = schedules[index];
        final vehicle = _vehicleMap[schedule.vehicleId];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            final refresh = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (context) => AndroidScheduledOrderDetailPage(
                  schedule: schedule,
                  organizationId: widget.organizationId,
                  userId: widget.userId,
                  repository: widget.repository,
                  vehicle: vehicle,
                ),
              ),
            );

            if (refresh == true && mounted) {
              await _loadSchedules(resetSelection: false);
            }
          },
          child: _buildScheduleCard(schedule, vehicle, index),
        );
      },
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemCount: schedules.length,
    );
  }

  Widget _buildScheduleCard(
    ScheduledOrder schedule,
    android_vehicle.Vehicle? vehicle,
    int index,
  ) {
    final gradients = [
      [const Color(0xFF4F46E5), const Color(0xFF7C3AED)],
      [const Color(0xFFF97316), const Color(0xFFF59E0B)],
      [const Color(0xFF0EA5E9), const Color(0xFF22D3EE)],
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
    final isRescheduling = _reschedulingScheduleIds.contains(schedule.id);
    final paymentDisplay = _paymentDisplayName(schedule.paymentType);
    final vehicleLabel = vehicle?.vehicleNo ?? schedule.vehicleId;
    final slotLabel = schedule.slotLabel;
    final clientNameOnly = (schedule.clientName?.trim().isNotEmpty ?? false)
        ? schedule.clientName!.trim()
        : 'Client';
    final canCancelDm = schedule.status == ScheduledOrderStatus.scheduled;
    final hasDm = schedule.dmNumber != null;
    final isGeneratingDm = _dmGenerationScheduleIds.contains(schedule.id);
    final isCancellingDm = _dmCancellationScheduleIds.contains(schedule.id);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(1),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicleLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        slotLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      paymentDisplay,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      clientNameOnly,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if ((schedule.clientPhone ?? '').trim().isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _callClient(schedule.clientPhone!.trim()),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.call),
                  label: const Text(
                    'Call Client',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (hasDm) const SizedBox(height: 16),
            _buildScheduleActions(
              schedule: schedule,
              hasDm: hasDm,
              canCancelDm: canCancelDm,
              isGeneratingDm: isGeneratingDm,
              isCancellingDm: isCancellingDm,
              isRescheduling: isRescheduling,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleActions({
    required ScheduledOrder schedule,
    required bool hasDm,
    required bool canCancelDm,
    required bool isGeneratingDm,
    required bool isCancellingDm,
    required bool isRescheduling,
  }) {
    const spacing = SizedBox(width: 12);
    final status = schedule.status;

    Widget loader(Color color) => SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        );

    if (hasDm) {
      final dmLabel = _formatDmLabel(schedule);
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isCancellingDm ? null : () => _openDmPrint(schedule),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.print_outlined),
              label: Text(
                dmLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          spacing,
          Expanded(
            child: OutlinedButton.icon(
              onPressed: (!canCancelDm || isCancellingDm)
                  ? null
                  : () => _handleCancelDm(schedule),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(
                  color: canCancelDm
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.white24,
                ),
                foregroundColor: Colors.white,
              ),
              icon: isCancellingDm
                  ? loader(Colors.white)
                  : Icon(
                      canCancelDm
                          ? Icons.cancel_outlined
                          : status == ScheduledOrderStatus.delivered
                              ? Icons.inventory_2_outlined
                              : status == ScheduledOrderStatus.returned
                                  ? Icons.check_circle_outline
                                  : Icons.local_shipping_outlined,
                    ),
              label: isCancellingDm
                  ? const SizedBox.shrink()
                  : Text(
                      canCancelDm
                          ? 'Cancel DM'
                          : status == ScheduledOrderStatus.delivered
                              ? 'Delivered'
                              : status == ScheduledOrderStatus.returned
                                  ? 'Returned'
                                  : 'Dispatched',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed:
                isGeneratingDm ? null : () => _handleGenerateDm(schedule),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: isGeneratingDm
                ? loader(AppTheme.primaryColor)
                : const Icon(Icons.description_outlined),
            label: isGeneratingDm
                ? const SizedBox.shrink()
                : const Text(
                    'Generate DM',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        spacing,
        Expanded(
          child: OutlinedButton.icon(
            onPressed:
                isRescheduling ? null : () => _handleReschedule(schedule),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.7),
              ),
              foregroundColor: Colors.white,
            ),
            icon: isRescheduling
                ? loader(Colors.white)
                : const Icon(Icons.refresh),
            label: isRescheduling
                ? const SizedBox.shrink()
                : const Text(
                    'Reschedule',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.errorColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor),
          const SizedBox(width: 12),
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

  String _formatDmLabel(ScheduledOrder schedule) {
    final number = schedule.dmNumber;
    if (number == null) {
      return '—';
    }
    return 'DM-$number';
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

  Future<void> _callClient(String phoneNumber) async {
    final normalized = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (normalized.isEmpty) {
      _showSnackbar(
        'Client phone number unavailable',
        backgroundColor: AppTheme.errorColor,
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: normalized);
    final launched = await launchUrl(uri);
    if (!launched) {
      _showSnackbar(
        'Unable to open dialer',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

}