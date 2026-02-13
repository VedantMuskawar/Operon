import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/data/repositories/pending_orders_repository.dart';
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/views/orders/pending_order_detail_page.dart';
import 'package:dash_mobile/presentation/widgets/schedule_trip_modal.dart';
import 'package:dash_mobile/shared/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderTile extends StatefulWidget {
  const OrderTile({
    super.key,
    required this.order,
    required this.onTripsUpdated,
    required this.onDeleted,
  });

  final Map<String, dynamic> order;
  final VoidCallback onTripsUpdated;
  final VoidCallback onDeleted;

  @override
  State<OrderTile> createState() => _OrderTileState();
}

class _OrderTileState extends State<OrderTile> {
  bool _isDeleting = false;

  // Cached computed values
  int? _cachedTotalTrips;
  int? _cachedTotalScheduledTrips;
  int? _cachedEstimatedTrips;
  String? _cachedProductName;
  int? _cachedFixedQuantityPerTrip;
  String? _cachedClientName;
  String? _cachedZoneText;
  dynamic _cachedCreatedAt;
  String? _cachedFormattedCreatedAt;
  Color? _cachedPriorityColor;
  List<BoxShadow>? _cachedPriorityShadows;
  dynamic _cachedEstimatedDeliveryDate;

  @override
  void initState() {
    super.initState();
    _computeCachedValues();
  }

  @override
  void didUpdateWidget(OrderTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recompute if order changed
    if (oldWidget.order != widget.order) {
      _computeCachedValues();
    }
  }

  void _computeCachedValues() {
    final items = widget.order['items'] as List<dynamic>? ?? [];
    final firstItem =
        items.isNotEmpty ? items.first as Map<String, dynamic> : null;
    final autoSchedule = widget.order['autoSchedule'] as Map<String, dynamic>?;
    final edd = widget.order['edd'] as Map<String, dynamic>?;

    // Calculate total trips: prefer item-level sum (source of truth)
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
    final totalScheduledTrips = totalTrips > 0 && itemLevelScheduled > 0
        ? itemLevelScheduled
        : (widget.order['totalScheduledTrips'] as int? ?? 0);
    final estimatedTrips =
        (totalTrips - totalScheduledTrips).clamp(0, totalTrips);

    final productName = firstItem?['productName'] as String? ?? 'N/A';
    final fixedQuantityPerTrip =
        firstItem?['fixedQuantityPerTrip'] as int? ?? 0;
    final clientName = widget.order['clientName'] as String? ?? 'N/A';
    final deliveryZone = widget.order['deliveryZone'] as Map<String, dynamic>?;
    final zoneText = deliveryZone != null
        ? '${deliveryZone['region'] ?? ''}, ${deliveryZone['city_name'] ?? deliveryZone['city'] ?? ''}'
        : 'N/A';
    final createdAt = widget.order['createdAt'];
    final estimatedDeliveryDate = edd?['estimatedCompletionDate'] ??
        autoSchedule?['estimatedDeliveryDate'];

    // Cache formatted date string
    _cachedFormattedCreatedAt = _formatDate(createdAt);

    // Compute priority-related values
    final priority = widget.order['priority'] as String? ?? 'normal';
    final isHighPriority = priority == 'high' || priority == 'priority';
    final priorityColor = isHighPriority
        ? AuthColors.secondary
        : AuthColors.textMainWithOpacity(0.15);
    final priorityShadows = isHighPriority
        ? [
            BoxShadow(
              color: AuthColors.secondary.withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 0),
            ),
            BoxShadow(
              color: AuthColors.secondary.withValues(alpha: 0.2),
              blurRadius: 6,
              spreadRadius: -2,
              offset: const Offset(0, 2),
            ),
          ]
        : <BoxShadow>[];

    _cachedTotalTrips = totalTrips;
    _cachedTotalScheduledTrips = totalScheduledTrips;
    _cachedEstimatedTrips = estimatedTrips;
    _cachedProductName = productName;
    _cachedFixedQuantityPerTrip = fixedQuantityPerTrip;
    _cachedClientName = clientName;
    _cachedZoneText = zoneText;
    _cachedCreatedAt = createdAt;
    _cachedPriorityColor = priorityColor;
    _cachedPriorityShadows = priorityShadows;
    _cachedEstimatedDeliveryDate = estimatedDeliveryDate;
  }

  bool _isHighPriority() {
    final priority = widget.order['priority'] as String? ?? 'normal';
    return priority == 'high' || priority == 'priority';
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

  String _formatETAText(DateTime etaDate, int daysDiff) {
    if (daysDiff < 0) {
      return 'Overdue';
    } else if (daysDiff == 0) {
      return 'Today';
    } else if (daysDiff == 1) {
      return 'Tomorrow';
    } else {
      return _formatDate(etaDate);
    }
  }

  IconData _getETAIcon(int daysDiff) {
    if (daysDiff < 0) {
      return Icons.error_outline;
    } else if (daysDiff == 0) {
      return Icons.today;
    } else if (daysDiff == 1) {
      return Icons.schedule;
    } else if (daysDiff <= 3) {
      return Icons.event;
    } else {
      return Icons.calendar_today;
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
      return AuthColors.info;
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
      final icon = _getETAIcon(daysDiff);

      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.paddingSM,
          vertical: AppSpacing.paddingXS,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.2),
              color.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
          border: Border.all(
            color: color.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: AppSpacing.iconXS,
              color: color,
            ),
            const SizedBox(width: AppSpacing.paddingXS / 2),
            Text(
              _formatETAText(etaDate, daysDiff),
              style: AppTypography.captionSmall.copyWith(
                color: color,
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
        backgroundColor: AuthColors.surface,
        title: const Text('Delete Order',
            style: TextStyle(color: AuthColors.textMain)),
        content: const Text(
          'Are you sure you want to delete this order?',
          style: TextStyle(color: AuthColors.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child:
                const Text('Delete', style: TextStyle(color: AuthColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      final repository = context.read<PendingOrdersRepository>();
      await repository.deleteOrder(widget.order['id'] as String);
      widget.onDeleted();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete order: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _callClient() async {
    final phone = widget.order['clientPhone'] as String?;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available')),
      );
      return;
    }

    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open phone app')),
        );
      }
    }
  }

  Future<void> _openScheduleModal() async {
    final clientId = widget.order['clientId'] as String?;
    final clientName = widget.order['clientName'] as String? ?? 'N/A';

    if (clientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client information not available')),
      );
      return;
    }

    // Fetch client phones
    try {
      final clientService = ClientService();
      final orgId =
          context.read<OrganizationContextCubit>().state.organization?.id;
      final client = await clientService.findClientByPhone(
        widget.order['clientPhone'] as String? ?? '',
        organizationId: orgId,
      );

      if (client == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Client not found')),
        );
        return;
      }

      // Get phone numbers from client
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
          onScheduled: widget.onTripsUpdated,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open schedule modal: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use cached values
    final totalTrips = _cachedTotalTrips ?? 0;
    final totalScheduledTrips = _cachedTotalScheduledTrips ?? 0;
    final estimatedTrips = _cachedEstimatedTrips ?? 0;
    final productName = _cachedProductName ?? 'N/A';
    final fixedQuantityPerTrip = _cachedFixedQuantityPerTrip ?? 0;
    final clientName = _cachedClientName ?? 'N/A';
    final zoneText = _cachedZoneText ?? 'N/A';
    final createdAt = _cachedCreatedAt;
    final priorityColor =
        _cachedPriorityColor ?? AuthColors.textMainWithOpacity(0.15);
    final priorityShadows = _cachedPriorityShadows ?? const [];
    final estimatedDeliveryDate = _cachedEstimatedDeliveryDate;

    return RepaintBoundary(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PendingOrderDetailPage(order: widget.order),
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.paddingMD),
          decoration: BoxDecoration(
            color: AuthColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(
              color: priorityColor,
              width: _isHighPriority() ? 2 : 1,
            ),
            boxShadow: [
              ...priorityShadows,
              BoxShadow(
                color: AuthColors.background.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header: Client name and Trip counter
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _OrderHeader(
                      clientName: clientName,
                      zoneText: zoneText,
                      estimatedDeliveryDate: estimatedDeliveryDate,
                      buildETALabel: _buildETALabel,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.paddingMD),
                  _TripCounterBadge(
                    scheduled: totalScheduledTrips,
                    total: totalTrips,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.paddingMD),
              // Product and quantity info
              _ProductInfo(
                productName: productName,
                fixedQuantityPerTrip: fixedQuantityPerTrip,
                formattedCreatedAt:
                    _cachedFormattedCreatedAt ?? _formatDate(createdAt),
              ),
              const SizedBox(height: AppSpacing.paddingMD),
              // Action buttons
              _ActionButtons(
                isDeleting: _isDeleting,
                onDelete: _deleteOrder,
                onCall: _callClient,
                onSchedule: estimatedTrips > 0 ? _openScheduleModal : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({
    required this.clientName,
    required this.zoneText,
    required this.estimatedDeliveryDate,
    required this.buildETALabel,
  });

  final String clientName;
  final String zoneText;
  final dynamic estimatedDeliveryDate;
  final Widget Function(dynamic) buildETALabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          clientName,
          style: AppTypography.h4.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AuthColors.textMain,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.paddingXS / 2),
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: AppSpacing.iconXS,
              color: AuthColors.textSub,
            ),
            const SizedBox(width: AppSpacing.paddingXS / 2),
            Expanded(
              child: Text(
                zoneText,
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 12,
                  color: AuthColors.textSub,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (estimatedDeliveryDate != null) ...[
          const SizedBox(height: AppSpacing.paddingXS),
          buildETALabel(estimatedDeliveryDate),
        ],
      ],
    );
  }
}

class _TripCounterBadge extends StatelessWidget {
  const _TripCounterBadge({
    required this.scheduled,
    required this.total,
  });

  final int scheduled;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? scheduled / total : 0.0;
    final isComplete = scheduled >= total;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.paddingMD,
        vertical: AppSpacing.paddingSM,
      ),
      decoration: BoxDecoration(
        gradient: isComplete
            ? LinearGradient(
                colors: [
                  AuthColors.success,
                  AuthColors.success.withValues(alpha: 0.8),
                ],
              )
            : LinearGradient(
                colors: [
                  AuthColors.primary.withValues(alpha: 0.2),
                  AuthColors.primary.withValues(alpha: 0.1),
                ],
              ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        border: Border.all(
          color: isComplete
              ? AuthColors.success
              : AuthColors.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isComplete ? AuthColors.success : AuthColors.primary)
                .withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.route,
                size: AppSpacing.iconSM,
                color: isComplete ? AuthColors.textMain : AuthColors.primary,
              ),
              const SizedBox(width: AppSpacing.paddingXS / 2),
              Text(
                '$scheduled/$total',
                style: AppTypography.labelSmall.copyWith(
                  color: isComplete ? AuthColors.textMain : AuthColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (!isComplete && total > 0) ...[
            const SizedBox(height: AppSpacing.paddingXS / 2),
            SizedBox(
              width: 50,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.paddingXS),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: AuthColors.textMainWithOpacity(0.08),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AuthColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProductInfo extends StatelessWidget {
  const _ProductInfo({
    required this.productName,
    required this.fixedQuantityPerTrip,
    required this.formattedCreatedAt,
  });

  final String productName;
  final int fixedQuantityPerTrip;
  final String formattedCreatedAt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.paddingSM,
            vertical: AppSpacing.paddingXS,
          ),
          decoration: BoxDecoration(
            color: AuthColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
            border: Border.all(
              color: AuthColors.textMainWithOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: AppSpacing.iconXS,
                color: AuthColors.textSub,
              ),
              const SizedBox(width: AppSpacing.paddingXS / 2),
              Text(
                productName,
                style: AppTypography.labelSmall.copyWith(
                  color: AuthColors.textMain,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.paddingSM),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.paddingSM,
            vertical: AppSpacing.paddingXS,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AuthColors.success.withValues(alpha: 0.2),
                AuthColors.success.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
            border: Border.all(
              color: AuthColors.success.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            'Qty: $fixedQuantityPerTrip',
            style: AppTypography.captionSmall.copyWith(
              color: AuthColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Spacer(),
        Text(
          formattedCreatedAt,
          style: AppTypography.captionSmall.copyWith(
            color: AuthColors.textDisabled,
          ),
        ),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.isDeleting,
    required this.onDelete,
    required this.onCall,
    required this.onSchedule,
  });

  final bool isDeleting;
  final VoidCallback onDelete;
  final VoidCallback onCall;
  final VoidCallback? onSchedule;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CompactActionButton(
            icon: Icons.delete_outline,
            label: 'Delete',
            color: AuthColors.error,
            onTap: isDeleting ? null : onDelete,
            isLoading: isDeleting,
          ),
        ),
        const SizedBox(width: AppSpacing.paddingSM),
        Expanded(
          child: _CompactActionButton(
            icon: Icons.phone_outlined,
            label: 'Call',
            color: AuthColors.success,
            onTap: onCall,
          ),
        ),
        const SizedBox(width: AppSpacing.paddingSM),
        Expanded(
          child: _CompactActionButton(
            icon: Icons.schedule_outlined,
            label: 'Schedule',
            color: AuthColors.info,
            onTap: onSchedule,
            isDisabled: onSchedule == null,
          ),
        ),
      ],
    );
  }
}

class _CompactActionButton extends StatelessWidget {
  const _CompactActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLoading = false,
    this.isDisabled = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = (isDisabled || onTap == null)
        ? AuthColors.textMainWithOpacity(0.08)
        : color;
    final textColor = (isDisabled || onTap == null)
        ? AuthColors.textDisabled
        : AuthColors.textMain;

    return Material(
      color: AuthColors.background.withValues(alpha: 0),
      child: InkWell(
        onTap: (isDisabled || isLoading) ? null : onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
        splashColor: effectiveColor.withValues(alpha: 0.2),
        highlightColor: effectiveColor.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.paddingSM,
            vertical: AppSpacing.paddingSM + 2,
          ),
          constraints: const BoxConstraints(
            minHeight: 44, // Minimum touch target
          ),
          decoration: BoxDecoration(
            gradient: (isDisabled || onTap == null)
                ? null
                : LinearGradient(
                    colors: [
                      effectiveColor,
                      effectiveColor.withValues(alpha: 0.9),
                    ],
                  ),
            color: (isDisabled || onTap == null) ? effectiveColor : null,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
            border: (isDisabled || onTap == null)
                ? Border.all(
                    color: AuthColors.textMainWithOpacity(0.1),
                    width: 1,
                  )
                : null,
            boxShadow: (isDisabled || onTap == null)
                ? null
                : [
                    BoxShadow(
                      color: effectiveColor.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
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
                      size: AppSpacing.iconSM,
                    ),
                    const SizedBox(width: AppSpacing.paddingXS / 2),
                    Flexible(
                      child: Text(
                        label,
                        style: AppTypography.captionSmall.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
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
