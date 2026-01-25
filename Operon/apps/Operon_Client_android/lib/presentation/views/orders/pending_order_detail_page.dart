import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/data/repositories/pending_orders_repository.dart';
import 'package:dash_mobile/data/repositories/scheduled_trips_repository.dart';
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/presentation/widgets/schedule_trip_modal.dart';
import 'package:dash_mobile/presentation/widgets/modern_tile.dart';
import 'package:dash_mobile/shared/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class PendingOrderDetailPage extends StatefulWidget {
  const PendingOrderDetailPage({
    super.key,
    required this.order,
  });

  final Map<String, dynamic> order;

  @override
  State<PendingOrderDetailPage> createState() => _PendingOrderDetailPageState();
}

class _PendingOrderDetailPageState extends State<PendingOrderDetailPage> {
  List<Map<String, dynamic>> _scheduledTrips = [];
  bool _isLoadingTrips = true;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadScheduledTrips();
  }

  Future<void> _loadScheduledTrips() async {
    final orderId = widget.order['id'] as String?;
    if (orderId == null) {
      setState(() => _isLoadingTrips = false);
      return;
    }

    setState(() => _isLoadingTrips = true);
    try {
      final repository = context.read<ScheduledTripsRepository>();
      final trips = await repository.getScheduledTripsForOrder(orderId);
      if (mounted) {
        setState(() {
          _scheduledTrips = trips;
          _isLoadingTrips = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTrips = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load scheduled trips: $e'),
            backgroundColor: AppColors.error,
            action: SnackBarAction(
              label: 'Retry',
              textColor: AppColors.textPrimary,
              onPressed: () => _loadScheduledTrips(),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      DateTime date;
      if (timestamp is DateTime) {
        date = timestamp;
      } else {
        date = (timestamp as Timestamp).toDate();
      }
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().substring(2)}';
    } catch (e) {
      return 'N/A';
    }
  }

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      DateTime date;
      if (timestamp is DateTime) {
        date = timestamp;
      } else {
        date = (timestamp as Timestamp).toDate();
      }
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().substring(2)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  Color _getPriorityColor() {
    final priority = widget.order['priority'] as String? ?? 'normal';
    return priority == 'high' || priority == 'priority'
        ? AuthColors.secondary
        : AuthColors.textDisabled;
  }

  Future<void> _deleteOrder() async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.dialogRadius),
        ),
        title: const Text(
          'Delete Order',
          style: AppTypography.h3,
        ),
        content: Text(
          'Are you sure you want to delete this order? This action cannot be undone.',
          style: AppTypography.body.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.buttonSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: AppTypography.buttonSmall.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      final repository = context.read<PendingOrdersRepository>();
      await repository.deleteOrder(widget.order['id'] as String);
      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order deleted successfully',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete order: $e',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            backgroundColor: AppColors.error,
            action: SnackBarAction(
              label: 'Retry',
              textColor: AppColors.textPrimary,
              onPressed: () => _deleteOrder(),
            ),
          ),
        );
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _callClient() async {
    final phone = widget.order['clientPhone'] as String?;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Phone number not available',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    try {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not open phone app',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error calling client: $e',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _openScheduleModal() async {
    final clientId = widget.order['clientId'] as String?;
    final clientName = widget.order['clientName'] as String? ?? 'N/A';
    
    if (clientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Client information not available',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    try {
      final clientService = ClientService();
      final client = await clientService.findClientByPhone(
        widget.order['clientPhone'] as String? ?? '',
      );
      
      if (client == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Client not found',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }

      final phones = client.phones;
      if (phones.isEmpty && client.primaryPhone != null) {
        phones.add({
          'number': client.primaryPhone,
          'normalized': client.primaryPhone,
        });
      }

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) => ScheduleTripModal(
          order: widget.order,
          clientId: clientId,
          clientName: clientName,
          clientPhones: phones,
          onScheduled: () {
            _loadScheduledTrips();
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to open schedule modal: $e',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.order['items'] as List<dynamic>? ?? [];
    final firstItem = items.isNotEmpty ? items.first as Map<String, dynamic> : null;
    final autoSchedule = widget.order['autoSchedule'] as Map<String, dynamic>?;
    
    // Calculate total trips (original total = estimated + scheduled for each item)
    // This ensures the denominator stays constant (e.g., 4) even as trips are scheduled
    int totalTrips = 0;
    if (autoSchedule?['totalTripsRequired'] != null) {
      totalTrips = (autoSchedule!['totalTripsRequired'] as num).toInt();
    } else {
      // Sum (estimatedTrips + scheduledTrips) for each item to get original total
      for (final item in items) {
        final itemMap = item as Map<String, dynamic>;
        final itemEstimatedTrips = (itemMap['estimatedTrips'] as int? ?? 0);
        final itemScheduledTrips = (itemMap['scheduledTrips'] as int? ?? 0);
        totalTrips += (itemEstimatedTrips + itemScheduledTrips);
      }
      if (totalTrips == 0 && firstItem != null) {
        final firstItemEstimated = firstItem['estimatedTrips'] as int? ?? 0;
        final firstItemScheduled = firstItem['scheduledTrips'] as int? ?? 0;
        totalTrips = firstItemEstimated + firstItemScheduled;
        if (totalTrips == 0) {
          totalTrips = (widget.order['tripIds'] as List<dynamic>?)?.length ?? 0;
        }
      }
    }
    
    final totalScheduledTrips = widget.order['totalScheduledTrips'] as int? ?? 0;
    // Calculate remaining estimated trips for display
    final estimatedTrips = totalTrips - totalScheduledTrips;
    
    final productName = firstItem?['productName'] as String? ?? 'N/A';
    final fixedQuantityPerTrip = firstItem?['fixedQuantityPerTrip'] as int? ?? 0;
    final clientName = widget.order['clientName'] as String? ?? 'N/A';
    final clientPhone = widget.order['clientPhone'] as String? ?? 'N/A';
    final deliveryZone = widget.order['deliveryZone'] as Map<String, dynamic>?;
    final zoneText = deliveryZone != null
        ? '${deliveryZone['region'] ?? ''}, ${deliveryZone['city_name'] ?? deliveryZone['city'] ?? ''}'
        : 'N/A';
    final priorityColor = _getPriorityColor();
    final priority = widget.order['priority'] as String? ?? 'normal';
    final createdAt = widget.order['createdAt'];
    final updatedAt = widget.order['updatedAt'];
    final estimatedDeliveryDate = autoSchedule?['estimatedDeliveryDate'];
    
    // Check if GST is included by checking pricing.totalGst or items with GST
    final pricing = widget.order['pricing'] as Map<String, dynamic>?;
    final totalGst = (pricing?['totalGst'] as num?)?.toDouble() ?? 0.0;
    final hasTotalGst = totalGst > 0;
    final hasItemGst = items.any((item) {
      final itemMap = item as Map<String, dynamic>;
      final itemGstAmount = (itemMap['gstAmount'] as num?)?.toDouble() ?? 0.0;
      final itemGstPercent = (itemMap['gstPercent'] as num?)?.toDouble() ?? 0.0;
      return itemGstAmount > 0 || itemGstPercent > 0;
    });
    final isGstIncluded = hasTotalGst || hasItemGst;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.paddingLG,
                vertical: AppSpacing.paddingMD,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                      size: AppSpacing.iconMD,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.paddingSM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Order Details',
                          style: AppTypography.h3,
                        ),
                        const SizedBox(height: AppSpacing.paddingXS / 2),
                        Text(
                          'ID: ${widget.order['id'] ?? 'N/A'}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.paddingSM,
                      vertical: AppSpacing.paddingXS,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          priorityColor.withOpacity(0.25),
                          priorityColor.withOpacity(0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
                      border: Border.all(
                        color: priorityColor.withOpacity(0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: priorityColor.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      priority.toUpperCase(),
                      style: AppTypography.captionSmall.copyWith(
                        color: priorityColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadScheduledTrips,
                color: AppColors.primary,
                  child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingLG),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    const SizedBox(height: AppSpacing.paddingSM),
                    // Client Info Card
                    _InfoCard(
                      title: 'Client Information',
                      children: [
                        _InfoRow(label: 'Name', value: clientName),
                        _InfoRow(
                          label: 'Phone',
                          value: clientPhone,
                          isTappable: true,
                          onTap: _callClient,
                        ),
                        _InfoRow(label: 'Zone', value: zoneText),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.paddingMD),
                    // Order Summary Card
                    _InfoCard(
                      title: 'Order Summary',
                      children: [
                        _InfoRow(label: 'Product', value: productName),
                        _InfoRow(label: 'Qty/Trip', value: fixedQuantityPerTrip.toString()),
                        _InfoRow(
                          label: 'GST Included',
                          value: isGstIncluded ? 'Yes' : 'No',
                          valueColor: isGstIncluded ? AppColors.success : AppColors.textSecondary,
                        ),
                        if (estimatedDeliveryDate != null)
                          _InfoRow(
                            label: 'Est. Delivery',
                            value: _formatDate(estimatedDeliveryDate),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.paddingMD),
                    // Trip Progress Card
                    _InfoCard(
                      title: 'Trip Progress',
                      children: [
                        const SizedBox(height: AppSpacing.paddingSM),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.inputBackground,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
                            ),
                            child: Stack(
                              children: [
                                if (totalTrips > 0)
                                  FractionallySizedBox(
                                    widthFactor: totalScheduledTrips / totalTrips,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: totalScheduledTrips == totalTrips
                                              ? [
                                                  AppColors.success,
                                                  AppColors.success.withOpacity(0.8),
                                                ]
                                              : [
                                                  AppColors.primary,
                                                  AppColors.primary.withOpacity(0.8),
                                                ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.paddingMD),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$totalScheduledTrips of $totalTrips scheduled',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '${totalTrips > 0 ? ((totalScheduledTrips / totalTrips) * 100).toStringAsFixed(0) : 0}%',
                              style: AppTypography.labelSmall.copyWith(
                                color: totalScheduledTrips == totalTrips
                                    ? AppColors.success
                                    : AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.paddingMD),
                    // Scheduled Trips Card
                    if (_isLoadingTrips)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.paddingXXL),
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    else if (_scheduledTrips.isEmpty)
                      _InfoCard(
                        title: 'Scheduled Trips',
                        children: [
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.paddingXXL),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.route_outlined,
                                    size: 48,
                                    color: AppColors.textTertiary,
                                  ),
                                  const SizedBox(height: AppSpacing.paddingMD),
                                  Text(
                                    'No scheduled trips yet',
                                    style: AppTypography.body.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _InfoCard(
                        title: 'Scheduled Trips (${_scheduledTrips.length})',
                        children: [
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _scheduledTrips.length,
                            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.paddingMD),
                            itemBuilder: (context, index) {
                              final trip = _scheduledTrips[index];
                              return RepaintBoundary(
                                key: ValueKey(trip['id']),
                                child: _ScheduledTripItem(
                                  trip: trip,
                                  formatDate: _formatDate,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.paddingMD),
                    ],
                    // Order Details Card
                    _InfoCard(
                      title: 'Order Details',
                      children: [
                        _InfoRow(label: 'Created', value: _formatDateTime(createdAt)),
                        if (updatedAt != null)
                          _InfoRow(label: 'Updated', value: _formatDateTime(updatedAt)),
                      ],
                    ),
                    const SizedBox(height: 80), // Space for bottom buttons
                    ],
                  ),
                ),
              ),
            ),
            // Bottom Action Buttons
            Container(
              padding: const EdgeInsets.all(AppSpacing.paddingLG),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                border: Border(
                  top: BorderSide(color: AppColors.borderDefault),
                ),
                boxShadow: AppShadows.card,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.delete_outline,
                      label: 'Delete',
                      color: AppColors.error,
                      onTap: _isDeleting ? null : _deleteOrder,
                      isLoading: _isDeleting,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.paddingSM),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.phone_outlined,
                      label: 'Call',
                      color: AppColors.success,
                      onTap: _callClient,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.paddingSM),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.schedule_outlined,
                      label: 'Schedule',
                      color: AppColors.info,
                      onTap: estimatedTrips > 0 ? _openScheduleModal : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduledTripItem extends StatelessWidget {
  const _ScheduledTripItem({
    required this.trip,
    required this.formatDate,
  });

  final Map<String, dynamic> trip;
  final String Function(dynamic) formatDate;

  @override
  Widget build(BuildContext context) {
    final scheduledDate = trip['scheduledDate'];
    final scheduledDay = trip['scheduledDay'] as String? ?? '';
    final vehicleNumber = trip['vehicleNumber'] as String? ?? 'N/A';
    final slot = trip['slot'] as int?;
    final status = trip['tripStatus'] as String? ?? 'scheduled';
    final isInProgress = status == 'in_progress';

    return ModernTile(
      padding: const EdgeInsets.all(AppSpacing.paddingMD),
      elevation: 0,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.3),
                  AppColors.primary.withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.schedule,
              color: AppColors.primary,
              size: AppSpacing.iconSM,
            ),
          ),
          const SizedBox(width: AppSpacing.paddingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${scheduledDay.capitalizeFirst()} - ${formatDate(scheduledDate)}',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.paddingXS / 2),
                Row(
                  children: [
                    const Icon(
                      Icons.directions_car,
                      size: AppSpacing.iconXS,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.paddingXS / 2),
                    Text(
                      vehicleNumber,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (slot != null) ...[
                      const SizedBox(width: AppSpacing.paddingSM),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.paddingXS,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.2),
                              AppColors.primary.withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusXS / 2),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          'Slot $slot',
                          style: AppTypography.captionSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.paddingSM,
              vertical: AppSpacing.paddingXS,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (isInProgress ? AppColors.warning : AppColors.success).withOpacity(0.25),
                  (isInProgress ? AppColors.warning : AppColors.success).withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
              border: Border.all(
                color: (isInProgress ? AppColors.warning : AppColors.success).withOpacity(0.4),
              ),
            ),
            child: Text(
              isInProgress ? 'In Progress' : 'Scheduled',
              style: AppTypography.captionSmall.copyWith(
                color: isInProgress ? AppColors.warning : AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ModernTile(
        padding: const EdgeInsets.all(AppSpacing.paddingMD),
        elevation: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.h4.copyWith(
                fontSize: 15,
              ),
            ),
            const SizedBox(height: AppSpacing.paddingMD),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.isTappable = false,
    this.onTap,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool isTappable;
  final VoidCallback? onTap;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final effectiveValueColor = valueColor ??
        (isTappable ? AppColors.primary : AppColors.textSecondary);

    final content = Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.body.copyWith(
              color: effectiveValueColor,
              fontWeight: isTappable ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        if (isTappable)
          const Icon(
            Icons.phone,
            color: AppColors.primary,
            size: AppSpacing.iconSM,
          ),
      ],
    );

    if (isTappable && onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap!();
          },
          borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingXS),
            child: content,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingXS),
      child: content,
    );
  }
}


class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    final effectiveColor = isDisabled ? AppColors.inputBackground : color;
    final textColor = isDisabled ? AppColors.textTertiary : AppColors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: (isLoading || isDisabled)
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        splashColor: effectiveColor.withOpacity(0.2),
        highlightColor: effectiveColor.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.paddingMD,
            horizontal: AppSpacing.paddingSM,
          ),
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            gradient: isDisabled
                ? null
                : LinearGradient(
                    colors: [
                      effectiveColor,
                      effectiveColor.withOpacity(0.9),
                    ],
                  ),
            color: isDisabled ? effectiveColor : null,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
            border: isDisabled
                ? Border.all(
                    color: AppColors.borderDefault,
                    width: 1,
                  )
                : null,
            boxShadow: isDisabled
                ? null
                : [
                    BoxShadow(
                      color: effectiveColor.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(textColor),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      color: textColor,
                      size: AppSpacing.iconMD,
                    ),
                    const SizedBox(width: AppSpacing.paddingSM),
                    Flexible(
                      child: Text(
                        label,
                        style: AppTypography.buttonSmall.copyWith(
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

