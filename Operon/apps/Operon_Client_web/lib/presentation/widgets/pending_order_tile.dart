import 'package:core_ui/core_ui.dart'
    show AuthColors, DashButton, DashButtonVariant, DashSnackbar;
import 'package:dash_web/data/repositories/clients_repository.dart';
import 'package:dash_web/data/repositories/pending_orders_repository.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/widgets/schedule_trip_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PendingOrderTile extends StatefulWidget {
  const PendingOrderTile({
    super.key,
    required this.order,
    this.onTripsUpdated,
    this.onDeleted,
    this.onTap,
    this.isSelected = false,
    this.onSelectionToggle,
  });

  final Map<String, dynamic> order;
  final VoidCallback? onTripsUpdated;
  final VoidCallback? onDeleted;
  final VoidCallback? onTap;
  final bool isSelected;
  final VoidCallback? onSelectionToggle;

  @override
  State<PendingOrderTile> createState() => _PendingOrderTileState();
}

class _PendingOrderTileState extends State<PendingOrderTile> {
  bool _isDeleting = false;
  bool _isHovered = false;

  Color _getPriorityBorderColor() {
    final priority = widget.order['priority'] as String? ?? 'normal';
    return priority == 'high' || priority == 'priority'
        ? AuthColors.secondary // Gold
        : AuthColors.textSub; // Silver
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      DateTime date;
      if (timestamp is DateTime) {
        date = timestamp;
      } else if (timestamp is String) {
        final parsed = DateTime.tryParse(timestamp);
        if (parsed == null) return 'N/A';
        date = parsed;
      } else {
        date = (timestamp as dynamic).toDate();
      }
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().substring(2)}';
    } catch (e) {
      return 'N/A';
    }
  }

  String _formatETAText(DateTime etaDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final etaDay = DateTime(etaDate.year, etaDate.month, etaDate.day);
    final daysDiff = etaDay.difference(today).inDays;

    if (daysDiff == 0) {
      return 'Today';
    } else if (daysDiff == 1) {
      return 'Tomorrow';
    } else if (daysDiff < 0) {
      return 'Overdue';
    } else {
      return _formatDate(etaDate);
    }
  }

  Color _getETAColor(int daysDiff) {
    if (daysDiff < 0) {
      return AuthColors.error;
    } else if (daysDiff == 0 || daysDiff == 1) {
      return AuthColors.success;
    } else if (daysDiff <= 3) {
      return AuthColors.warning;
    } else {
      return AuthColors.warning;
    }
  }

  Widget _buildETALabel(dynamic timestamp) {
    if (timestamp == null) return const SizedBox.shrink();

    try {
      DateTime etaDate;
      if (timestamp is DateTime) {
        etaDate = timestamp;
      } else if (timestamp is String) {
        final parsed = DateTime.tryParse(timestamp);
        if (parsed == null) return const SizedBox.shrink();
        etaDate = parsed;
      } else {
        etaDate = (timestamp as dynamic).toDate();
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final etaDay = DateTime(etaDate.year, etaDate.month, etaDate.day);
      final daysDiff = etaDay.difference(today).inDays;

      final color = _getETAColor(daysDiff);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule_outlined,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              _formatETAText(etaDate),
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Future<void> _deleteOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AuthColors.background,
        title: const Text('Delete Order',
            style: TextStyle(color: AuthColors.textMain)),
        content: const Text(
          'Are you sure you want to delete this order?',
          style: TextStyle(color: AuthColors.textSub),
        ),
        actions: [
          DashButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(false),
            variant: DashButtonVariant.text,
          ),
          DashButton(
            label: 'Delete',
            onPressed: () => Navigator.of(context).pop(true),
            variant: DashButtonVariant.text,
            isDestructive: true,
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      final repository = context.read<PendingOrdersRepository>();
      await repository.deleteOrder(widget.order['id'] as String);
      widget.onDeleted?.call();
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(context,
            message: 'Failed to delete order: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _openScheduleModal() async {
    final clientId = widget.order['clientId'] as String?;
    final clientName = widget.order['clientName'] as String? ?? 'N/A';

    if (clientId == null) {
      DashSnackbar.show(context,
          message: 'Client information not available', isError: true);
      return;
    }

    try {
      final orgId =
          context.read<OrganizationContextCubit>().state.organization?.id;
      if (orgId == null || orgId.isEmpty) {
        DashSnackbar.show(context,
            message: 'Organization not selected', isError: true);
        return;
      }
      final clientsRepo = context.read<ClientsRepository>();
      final client = await clientsRepo.findClientByPhone(
        orgId,
        widget.order['clientPhone'] as String? ?? '',
      );

      if (client == null) {
        DashSnackbar.show(context, message: 'Client not found', isError: true);
        return;
      }

      final phones = client.phones;
      List<Map<String, dynamic>> clientPhones = [];
      if (phones.isNotEmpty) {
        clientPhones = phones;
      } else if (client.primaryPhone != null) {
        clientPhones.add({
          'e164': client.primaryPhone,
          'number': client.primaryPhone,
        });
      }

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierColor: AuthColors.background.withOpacity(0.7),
        builder: (context) => ScheduleTripModal(
          order: widget.order,
          clientId: clientId,
          clientName: clientName,
          clientPhones: clientPhones,
          onScheduled: () {
            if (widget.onTripsUpdated != null) {
              widget.onTripsUpdated!();
            }
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(context,
            message: 'Failed to open schedule modal: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.order['items'] as List<dynamic>? ?? [];
    final firstItem =
        items.isNotEmpty ? items.first as Map<String, dynamic> : null;
    final autoSchedule = widget.order['autoSchedule'] as Map<String, dynamic>?;
    final edd = widget.order['edd'] as Map<String, dynamic>?;

    // Calculate total trips (original total = estimated + scheduled for each item)
    // Prefer item-level sum (source of truth); fallback to totalTripsRequired only when sum is 0
    int totalTrips = 0;
    int itemLevelScheduled = 0;
    for (final item in items) {
      final itemMap = item as Map<String, dynamic>;
      final itemEstimatedTrips = (itemMap['estimatedTrips'] as int? ?? 0);
      final itemScheduledTrips = (itemMap['scheduledTrips'] as int? ?? 0);
      totalTrips += (itemEstimatedTrips + itemScheduledTrips);
      itemLevelScheduled += itemScheduledTrips;
    }
    if (totalTrips == 0 && firstItem != null) {
      final firstItemEstimated = firstItem['estimatedTrips'] as int? ?? 0;
      final firstItemScheduled = firstItem['scheduledTrips'] as int? ?? 0;
      totalTrips = firstItemEstimated + firstItemScheduled;
      itemLevelScheduled = firstItemScheduled;
      if (totalTrips == 0) {
        totalTrips = (widget.order['tripIds'] as List<dynamic>?)?.length ?? 0;
      }
    }
    if (totalTrips == 0 && autoSchedule?['totalTripsRequired'] != null) {
      totalTrips = (autoSchedule!['totalTripsRequired'] as num).toInt();
    }
    // Use item-level scheduled when available; order totalScheduledTrips can get out of sync
    final totalScheduledTrips = totalTrips > 0 && itemLevelScheduled > 0
        ? itemLevelScheduled
        : (widget.order['totalScheduledTrips'] as int? ?? 0);
    // Remaining = total - scheduled (clamp to avoid negative from data inconsistency)
    final estimatedTrips =
        (totalTrips - totalScheduledTrips).clamp(0, totalTrips);

    final productName = firstItem?['productName'] as String? ?? 'N/A';
    final fixedQuantityPerTrip =
        firstItem?['fixedQuantityPerTrip'] as int? ?? 0;
    final totalQuantity = estimatedTrips * fixedQuantityPerTrip;

    final clientName = widget.order['clientName'] as String? ?? 'N/A';
    final clientPhone = widget.order['clientPhone'] as String? ?? '';
    final deliveryZone = widget.order['deliveryZone'] as Map<String, dynamic>?;
    final zoneText = deliveryZone != null
        ? '${deliveryZone['region'] ?? ''}, ${deliveryZone['city_name'] ?? deliveryZone['city'] ?? ''}'
        : 'N/A';
    final createdAt = widget.order['createdAt'];
    final updatedAt = widget.order['updatedAt'];
    final priorityColor = _getPriorityBorderColor();
    final priority = widget.order['priority'] as String? ?? 'normal';
    final estimatedDeliveryDate = edd?['estimatedCompletionDate'] ??
        autoSchedule?['estimatedDeliveryDate'];

    // Pricing information
    final pricing = widget.order['pricing'] as Map<String, dynamic>?;
    final subtotal = (pricing?['subtotal'] as num?)?.toDouble() ?? 0.0;
    final totalGstValue = (pricing?['totalGst'] as num?)?.toDouble();
    final totalGst = totalGstValue ?? 0.0;
    final totalAmount = (pricing?['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final includeGstFlag = widget.order['includeGstInTotal'];
    final includeGst = includeGstFlag is bool
        ? includeGstFlag
        : (totalGstValue != null && totalGstValue > 0);

    // Progress calculation
    final progress = totalTrips > 0 ? totalScheduledTrips / totalTrips : 0.0;
    final progressPercent = (progress * 100).toInt();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Material(
        color: Colors.transparent,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? AuthColors.primary.withValues(alpha: 0.1)
                    : AuthColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.isSelected
                      ? AuthColors.primary
                      : priorityColor.withValues(alpha: 0.6),
                  width: widget.isSelected ? 2.5 : 2,
                ),
                boxShadow: [
                  if (_isHovered || widget.isSelected)
                    BoxShadow(
                      color: (widget.isSelected
                              ? AuthColors.primary
                              : priorityColor)
                          .withOpacity(0.3),
                      blurRadius: _isHovered ? 16 : 12,
                      spreadRadius: _isHovered ? 2 : 0,
                      offset: Offset(0, _isHovered ? 6 : 4),
                    )
                  else
                    BoxShadow(
                      color: AuthColors.background.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Row: Selection Checkbox, Client Name, Priority, Trip Counter
                  Row(
                    children: [
                      // Selection Checkbox
                      if (widget.onSelectionToggle != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: widget.onSelectionToggle,
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: widget.isSelected
                                      ? AuthColors.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: widget.isSelected
                                        ? AuthColors.primary
                                        : AuthColors.textMainWithOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: widget.isSelected
                                    ? const Icon(
                                        Icons.check,
                                        size: 16,
                                        color: AuthColors.textMain,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    clientName,
                                    style: const TextStyle(
                                      color: AuthColors.textMain,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (priority == 'high' ||
                                    priority == 'priority') ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color:
                                          priorityColor.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: priorityColor,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      'PRIORITY',
                                      style: TextStyle(
                                        color: priorityColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: AuthColors.textSub,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    zoneText,
                                    style: const TextStyle(
                                      color: AuthColors.textSub,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (clientPhone.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.phone_outlined,
                                    size: 14,
                                    color: AuthColors.textSub,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      clientPhone,
                                      style: const TextStyle(
                                        color: AuthColors.textSub,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Trip Counter Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AuthColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AuthColors.textMain.withValues(alpha: 0.15),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$totalScheduledTrips/$totalTrips',
                              style: const TextStyle(
                                color: AuthColors.textMain,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Trips',
                              style: TextStyle(
                                color:
                                    AuthColors.textMain.withValues(alpha: 0.6),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Divider
                  Divider(
                    color: AuthColors.textMain.withValues(alpha: 0.1),
                    height: 1,
                  ),

                  const SizedBox(height: 16),

                  // Product Information Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AuthColors.surface.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.inventory_2_outlined,
                              size: 14,
                              color: AuthColors.textSub,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              productName,
                              style: const TextStyle(
                                color: AuthColors.textMain,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: AuthColors.success.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AuthColors.success.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          'Qty/Trip: $fixedQuantityPerTrip',
                          style: const TextStyle(
                            color: AuthColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (totalQuantity > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: AuthColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Total: $totalQuantity',
                            style: const TextStyle(
                              color: AuthColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Progress Bar Section
                  if (totalTrips > 0) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Progress',
                                    style: TextStyle(
                                      color: AuthColors.textMain
                                          .withValues(alpha: 0.7),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '$progressPercent%',
                                    style: const TextStyle(
                                      color: AuthColors.textMain,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: AuthColors.textMain
                                      .withValues(alpha: 0.1),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    totalScheduledTrips == totalTrips
                                        ? AuthColors.success
                                        : AuthColors.primary,
                                  ),
                                  minHeight: 8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _StatBadge(
                                    label: 'Scheduled',
                                    value: totalScheduledTrips.toString(),
                                    color: AuthColors.success,
                                  ),
                                  _StatBadge(
                                    label: 'Pending',
                                    value: estimatedTrips.toString(),
                                    color: AuthColors.warning,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ETA and GST Row
                  Row(
                    children: [
                      if (estimatedDeliveryDate != null) ...[
                        Expanded(child: _buildETALabel(estimatedDeliveryDate)),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: includeGst
                              ? AuthColors.success.withValues(alpha: 0.15)
                              : AuthColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.receipt_outlined,
                              size: 12,
                              color: includeGst
                                  ? AuthColors.success
                                  : AuthColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'GST: ${includeGst ? 'Included' : 'Excluded'}',
                              style: TextStyle(
                                color: includeGst
                                    ? AuthColors.success
                                    : AuthColors.warning,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Pricing Information (if available)
                  if (totalAmount > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AuthColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AuthColors.textMain.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Subtotal',
                                style: TextStyle(
                                  color: AuthColors.textMain
                                      .withValues(alpha: 0.6),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₹${subtotal.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: AuthColors.textMain,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (totalGst > 0) ...[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'GST',
                                  style: TextStyle(
                                    color: AuthColors.textMain
                                        .withValues(alpha: 0.6),
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '₹${totalGst.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: AuthColors.textMain,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Total',
                                style: TextStyle(
                                  color: AuthColors.textMain
                                      .withValues(alpha: 0.6),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₹${totalAmount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: AuthColors.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Metadata Row: Order ID, Created Date
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.tag_outlined,
                              size: 12,
                              color: AuthColors.textMain.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'ID: ${widget.order['id'] ?? 'N/A'}',
                                style: TextStyle(
                                  color: AuthColors.textMain
                                      .withValues(alpha: 0.5),
                                  fontSize: 10,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 12,
                        color: AuthColors.textMain.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(createdAt),
                        style: TextStyle(
                          color: AuthColors.textMain.withValues(alpha: 0.5),
                          fontSize: 10,
                        ),
                      ),
                      if (updatedAt != null && updatedAt != createdAt) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.update_outlined,
                          size: 12,
                          color: AuthColors.textMain.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(updatedAt),
                          style: TextStyle(
                            color: AuthColors.textMain.withValues(alpha: 0.5),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _CompactActionButton(
                          icon: Icons.delete_outline,
                          label: 'Delete',
                          color: AuthColors.error,
                          onTap: _isDeleting ? null : _deleteOrder,
                          isLoading: _isDeleting,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _CompactActionButton(
                          icon: Icons.schedule_outlined,
                          label: 'Schedule',
                          color: AuthColors.info,
                          onTap: estimatedTrips > 0 ? _openScheduleModal : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactActionButton extends StatefulWidget {
  const _CompactActionButton({
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
  State<_CompactActionButton> createState() => _CompactActionButtonState();
}

class _CompactActionButtonState extends State<_CompactActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: widget.onTap == null
                  ? widget.color.withValues(alpha: 0.5)
                  : widget.color,
              borderRadius: BorderRadius.circular(8),
              boxShadow: _isHovered && widget.onTap != null
                  ? [
                      BoxShadow(
                        color: widget.color.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: widget.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AuthColors.textSub,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.icon,
                        color: widget.onTap == null
                            ? AuthColors.textSub
                            : AuthColors.textMain,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          widget.label,
                          style: TextStyle(
                            color: widget.onTap == null
                                ? AuthColors.textSub
                                : AuthColors.textMain,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
