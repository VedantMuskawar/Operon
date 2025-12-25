import 'package:dash_web/data/repositories/pending_orders_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PendingOrderTile extends StatefulWidget {
  const PendingOrderTile({
    super.key,
    required this.order,
    this.onTripsUpdated,
    this.onDeleted,
    this.onTap,
  });

  final Map<String, dynamic> order;
  final VoidCallback? onTripsUpdated;
  final VoidCallback? onDeleted;
  final VoidCallback? onTap;

  @override
  State<PendingOrderTile> createState() => _PendingOrderTileState();
}

class _PendingOrderTileState extends State<PendingOrderTile> {
  bool _isDeleting = false;

  Color _getPriorityBorderColor() {
    final priority = widget.order['priority'] as String? ?? 'normal';
    return priority == 'high' || priority == 'priority'
        ? const Color(0xFFD4AF37) // Gold
        : const Color(0xFFC0C0C0); // Silver
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      DateTime date;
      if (timestamp is DateTime) {
        date = timestamp;
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
      return Colors.red;
    } else if (daysDiff == 0 || daysDiff == 1) {
      return const Color(0xFF4CAF50);
    } else if (daysDiff <= 3) {
      return Colors.orange;
    } else {
      return Colors.amber;
    }
  }

  Widget _buildETALabel(dynamic timestamp) {
    if (timestamp == null) return const SizedBox.shrink();

    try {
      DateTime etaDate;
      if (timestamp is DateTime) {
        etaDate = timestamp;
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
        backgroundColor: const Color(0xFF11111B),
        title: const Text('Delete Order', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this order?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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

  Future<void> _openScheduleModal() async {
    // TODO: Implement schedule trip modal for web
    if (widget.onTripsUpdated != null) {
      widget.onTripsUpdated!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.order['items'] as List<dynamic>? ?? [];
    final firstItem = items.isNotEmpty ? items.first as Map<String, dynamic> : null;
    
    // Calculate trips
    int totalEstimatedTrips = 0;
    for (final item in items) {
      final itemMap = item as Map<String, dynamic>;
      totalEstimatedTrips += (itemMap['estimatedTrips'] as int? ?? 0);
    }
    if (totalEstimatedTrips == 0 && firstItem != null) {
      totalEstimatedTrips = firstItem['estimatedTrips'] as int? ?? 
          (widget.order['tripIds'] as List<dynamic>?)?.length ?? 0;
    }
    
    final totalScheduledTrips = widget.order['totalScheduledTrips'] as int? ?? 0;
    final estimatedTrips = totalEstimatedTrips - totalScheduledTrips;
    final totalTrips = totalScheduledTrips + (estimatedTrips > 0 ? estimatedTrips : 0);
    
    final productName = firstItem?['productName'] as String? ?? 'N/A';
    final fixedQuantityPerTrip = firstItem?['fixedQuantityPerTrip'] as int? ?? 0;
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
    final autoSchedule = widget.order['autoSchedule'] as Map<String, dynamic>?;
    final estimatedDeliveryDate = autoSchedule?['estimatedDeliveryDate'];
    
    // Pricing information
    final pricing = widget.order['pricing'] as Map<String, dynamic>?;
    final subtotal = (pricing?['subtotal'] as num?)?.toDouble() ?? 0.0;
    final totalGst = (pricing?['totalGst'] as num?)?.toDouble() ?? 0.0;
    final totalAmount = (pricing?['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final includeGst = widget.order['includeGstInTotal'] as bool? ?? true;
    
    // Progress calculation
    final progress = totalTrips > 0 ? totalScheduledTrips / totalTrips : 0.0;
    final progressPercent = (progress * 100).toInt();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF131324),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: priorityColor.withValues(alpha: 0.6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                // Header Row: Client Name, Priority, Trip Counter
                Row(
                  children: [
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
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (priority == 'high' || priority == 'priority') ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: priorityColor.withValues(alpha: 0.2),
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
                                color: Colors.white60,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  zoneText,
                                  style: const TextStyle(
                                    color: Colors.white60,
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
                                  color: Colors.white60,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    clientPhone,
                                    style: const TextStyle(
                                      color: Colors.white60,
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1B2C),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$totalScheduledTrips/$totalTrips',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Trips',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
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
                  color: Colors.white.withValues(alpha: 0.1),
                  height: 1,
                ),
                
                const SizedBox(height: 16),
                
                // Product Information Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1B2C).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 14,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            productName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'Qty/Trip: $fixedQuantityPerTrip',
                        style: const TextStyle(
                          color: Color(0xFF81C784),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (totalQuantity > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6F4BFF).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Total: $totalQuantity',
                          style: const TextStyle(
                            color: Color(0xFF6F4BFF),
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Progress',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '$progressPercent%',
                                  style: const TextStyle(
                                    color: Colors.white,
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
                                backgroundColor: Colors.white.withValues(alpha: 0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  totalScheduledTrips == totalTrips
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFF6F4BFF),
                                ),
                                minHeight: 8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _StatBadge(
                                  label: 'Scheduled',
                                  value: totalScheduledTrips.toString(),
                                  color: const Color(0xFF4CAF50),
                                ),
                                _StatBadge(
                                  label: 'Pending',
                                  value: estimatedTrips.toString(),
                                  color: Colors.orange,
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: includeGst
                            ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
                            : Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_outlined,
                            size: 12,
                            color: includeGst ? const Color(0xFF4CAF50) : Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'GST: ${includeGst ? 'Included' : 'Excluded'}',
                            style: TextStyle(
                              color: includeGst ? const Color(0xFF81C784) : Colors.orange,
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
                      color: const Color(0xFF0F0F1F),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
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
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${subtotal.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.white,
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
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₹${totalGst.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.white,
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
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${totalAmount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Color(0xFF6F4BFF),
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
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'ID: ${widget.order['id'] ?? 'N/A'}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
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
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(createdAt),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 10,
                      ),
                    ),
                    if (updatedAt != null && updatedAt != createdAt) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.update_outlined,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(updatedAt),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
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
                        color: Colors.red,
                        onTap: _isDeleting ? null : _deleteOrder,
                        isLoading: _isDeleting,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CompactActionButton(
                        icon: Icons.schedule_outlined,
                        label: 'Schedule',
                        color: Colors.blue,
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

class _CompactActionButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
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
    );
  }
}
