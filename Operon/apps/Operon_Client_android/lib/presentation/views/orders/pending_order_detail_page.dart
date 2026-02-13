import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/data/repositories/pending_orders_repository.dart';
import 'package:dash_mobile/data/repositories/scheduled_trips_repository.dart';
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/presentation/widgets/schedule_trip_modal.dart';
import 'package:dash_mobile/presentation/widgets/modern_tile.dart';
import 'package:dash_mobile/presentation/widgets/quick_action_menu.dart';
import 'package:dash_mobile/presentation/widgets/edit_order_dialog.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:dash_mobile/shared/constants/app_typography.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

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
  int _selectedTabIndex = 0;
  List<Map<String, dynamic>> _scheduledTrips = [];
  bool _isLoadingTrips = true;
  bool _isDeleting = false;
  StreamSubscription<Map<String, dynamic>?>? _orderSubscription;
  Map<String, dynamic>? _currentOrder;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _loadScheduledTrips();
    _subscribeToOrder();
  }

  void _subscribeToOrder() {
    final orderId = widget.order['id'] as String?;
    if (orderId == null) return;

    final repository = context.read<PendingOrdersRepository>();
    _orderSubscription = repository.watchOrder(orderId).listen(
      (order) {
        if (order != null && mounted) {
          setState(() {
            _currentOrder = order;
          });
          // Reload trips when order updates (in case trips were scheduled)
          _loadScheduledTrips();
        }
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error receiving order updates: $error'),
              backgroundColor: AuthColors.error,
            ),
          );
        }
      },
    );
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
            backgroundColor: AuthColors.error,
            action: SnackBarAction(
              label: 'Retry',
              textColor: AuthColors.textMain,
              onPressed: () => _loadScheduledTrips(),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
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

  String _formatCurrency(double? amount) {
    if (amount == null) return '₹0';
    return '₹${amount.toStringAsFixed(2)}';
  }

  Color _getPriorityColor() {
    final priority = _currentOrder?['priority'] as String? ?? 'normal';
    return priority == 'high' || priority == 'priority'
        ? AuthColors.secondary
        : AuthColors.textDisabled;
  }

  Future<void> _deleteOrder() async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AuthColors.surface,
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
            color: AuthColors.textSub,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.buttonSmall.copyWith(
                color: AuthColors.textSub,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: AppTypography.buttonSmall.copyWith(
                color: AuthColors.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) {
      return;
    }

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
                color: AuthColors.textMain,
              ),
            ),
            backgroundColor: AuthColors.success,
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
                color: AuthColors.textMain,
              ),
            ),
            backgroundColor: AuthColors.error,
            action: SnackBarAction(
              label: 'Retry',
              textColor: AuthColors.textMain,
              onPressed: () => _deleteOrder(),
            ),
          ),
        );
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _callClient() async {
    final phone = _currentOrder?['clientPhone'] as String?;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Phone number not available',
            style: AppTypography.bodySmall.copyWith(
              color: AuthColors.textMain,
            ),
          ),
          backgroundColor: AuthColors.warning,
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
                  color: AuthColors.textMain,
                ),
              ),
              backgroundColor: AuthColors.error,
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
                color: AuthColors.textMain,
              ),
            ),
            backgroundColor: AuthColors.error,
          ),
        );
      }
    }
  }

  Future<void> _openEditDialog() async {
    final orderId = _currentOrder?['id'] as String?;
    if (orderId == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditOrderDialog(
        order: _currentOrder ?? widget.order,
        onSave: ({
          String? priority,
          double? advanceAmount,
          String? advancePaymentAccountId,
        }) async {
          final repository = context.read<PendingOrdersRepository>();
          await repository.updateOrder(
            orderId: orderId,
            priority: priority,
            advanceAmount: advanceAmount,
            advancePaymentAccountId: advancePaymentAccountId,
          );
        },
      ),
    );

    if (result == true) {
      // Order will be updated via stream
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _openScheduleModal() async {
    final clientId = _currentOrder?['clientId'] as String?;
    final clientName = _currentOrder?['clientName'] as String? ?? 'N/A';

    if (clientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Client information not available',
            style: AppTypography.bodySmall.copyWith(
              color: AuthColors.textMain,
            ),
          ),
          backgroundColor: AuthColors.warning,
        ),
      );
      return;
    }

    try {
      final clientService = ClientService();
      final orgId =
          context.read<OrganizationContextCubit>().state.organization?.id;
      final client = await clientService.findClientByPhone(
        _currentOrder?['clientPhone'] as String? ?? '',
        organizationId: orgId,
      );

      if (!mounted) {
        return;
      }

      if (client == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Client not found',
              style: AppTypography.bodySmall.copyWith(
                color: AuthColors.textMain,
              ),
            ),
            backgroundColor: AuthColors.warning,
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
          order: _currentOrder ?? widget.order,
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
                color: AuthColors.textMain,
              ),
            ),
            backgroundColor: AuthColors.error,
          ),
        );
      }
    }
  }

  Map<String, dynamic> _getOrderData() {
    return _currentOrder ?? widget.order;
  }

  int _calculateTotalTrips() {
    final order = _getOrderData();
    final items = order['items'] as List<dynamic>? ?? [];
    final autoSchedule = order['autoSchedule'] as Map<String, dynamic>?;
    // Prefer item-level sum (source of truth); fallback to totalTripsRequired only when sum is 0
    int totalTrips = 0;
    for (final item in items) {
      final itemMap = item as Map<String, dynamic>;
      final itemEstimatedTrips = (itemMap['estimatedTrips'] as int? ?? 0);
      final itemScheduledTrips = (itemMap['scheduledTrips'] as int? ?? 0);
      totalTrips += (itemEstimatedTrips + itemScheduledTrips);
    }
    if (totalTrips == 0 && items.isNotEmpty) {
      final firstItem = items.first as Map<String, dynamic>;
      final firstItemEstimated = firstItem['estimatedTrips'] as int? ?? 0;
      final firstItemScheduled = firstItem['scheduledTrips'] as int? ?? 0;
      totalTrips = firstItemEstimated + firstItemScheduled;
      if (totalTrips == 0) {
        totalTrips = (order['tripIds'] as List<dynamic>?)?.length ?? 0;
      }
    }
    if (totalTrips == 0 && autoSchedule?['totalTripsRequired'] != null) {
      totalTrips = (autoSchedule!['totalTripsRequired'] as num).toInt();
    }
    return totalTrips;
  }

  int _calculateTotalScheduledTrips() {
    final order = _getOrderData();
    final items = order['items'] as List<dynamic>? ?? [];
    int itemLevelScheduled = 0;
    for (final item in items) {
      final itemMap = item as Map<String, dynamic>;
      itemLevelScheduled += (itemMap['scheduledTrips'] as int? ?? 0);
    }
    return itemLevelScheduled > 0
        ? itemLevelScheduled
        : (order['totalScheduledTrips'] as int? ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final order = _getOrderData();
    final items = order['items'] as List<dynamic>? ?? [];
    final totalTrips = _calculateTotalTrips();
    final totalScheduledTrips = _calculateTotalScheduledTrips();
    final estimatedTrips =
        (totalTrips - totalScheduledTrips).clamp(0, totalTrips);
    final priorityColor = _getPriorityColor();
    final priority = order['priority'] as String? ?? 'normal';
    final pricing = order['pricing'] as Map<String, dynamic>?;

    // Calculate order age
    final createdAt = order['createdAt'];
    int orderAgeDays = 0;
    if (createdAt != null) {
      try {
        DateTime createdDate;
        if (createdAt is DateTime) {
          createdDate = createdAt;
        } else {
          createdDate = (createdAt as Timestamp).toDate();
        }
        orderAgeDays = DateTime.now().difference(createdDate).inDays;
      } catch (e) {
        // Ignore
      }
    }

    return Scaffold(
      backgroundColor: AuthColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Enhanced Header
                _OrderHeader(
                  order: order,
                  priority: priority,
                  priorityColor: priorityColor,
                  totalTrips: totalTrips,
                  totalScheduledTrips: totalScheduledTrips,
                  orderAgeDays: orderAgeDays,
                ),

                // Spacing between header and tab bar
                const SizedBox(height: AppSpacing.paddingLG),

                // Tab Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.paddingLG),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.paddingXS / 2),
                    decoration: BoxDecoration(
                      color: AuthColors.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                      border: Border.all(
                        color: AuthColors.textSub.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TabButton(
                            label: 'Items',
                            isSelected: _selectedTabIndex == 0,
                            onTap: () => setState(() => _selectedTabIndex = 0),
                          ),
                        ),
                        Expanded(
                          child: _TabButton(
                            label: 'Trips',
                            isSelected: _selectedTabIndex == 1,
                            onTap: () => setState(() => _selectedTabIndex = 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.paddingMD),

                // Tab Content
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadScheduledTrips,
                    color: AuthColors.primary,
                    child: IndexedStack(
                      index: _selectedTabIndex,
                      children: [
                        _ItemsTab(
                          items: items,
                          pricing: pricing,
                          formatCurrency: _formatCurrency,
                          onCallCustomer: _callClient,
                          order: order,
                          formatDateTime: _formatDateTime,
                        ),
                        _TripsTab(
                          trips: _scheduledTrips,
                          isLoading: _isLoadingTrips,
                          formatDate: _formatDate,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // FAB Menu - positioned at bottom right with safe padding
            QuickActionMenu(
              right: QuickActionMenu.standardRight,
              bottom:
                  MediaQuery.of(context).padding.bottom + AppSpacing.paddingLG,
              actions: [
                QuickActionItem(
                  icon: Icons.schedule_outlined,
                  label: 'Schedule Trip',
                  onTap: estimatedTrips > 0
                      ? _openScheduleModal
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('All trips are scheduled'),
                              backgroundColor: AuthColors.warning,
                            ),
                          );
                        },
                ),
                QuickActionItem(
                  icon: Icons.edit_outlined,
                  label: 'Edit Order',
                  onTap: _openEditDialog,
                ),
                QuickActionItem(
                  icon: Icons.phone_outlined,
                  label: 'Call Client',
                  onTap: _callClient,
                ),
                QuickActionItem(
                  icon: Icons.share_outlined,
                  label: 'Share Order',
                  onTap: () {
                    // TODO: Implement share functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Share functionality coming soon'),
                        backgroundColor: AuthColors.info,
                      ),
                    );
                  },
                ),
                QuickActionItem(
                  icon: Icons.delete_outline,
                  label: 'Delete Order',
                  onTap: _isDeleting ? () {} : _deleteOrder,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Enhanced Header Widget
class _OrderHeader extends StatelessWidget {
  const _OrderHeader({
    required this.order,
    required this.priority,
    required this.priorityColor,
    required this.totalTrips,
    required this.totalScheduledTrips,
    required this.orderAgeDays,
  });

  final Map<String, dynamic> order;
  final String priority;
  final Color priorityColor;
  final int totalTrips;
  final int totalScheduledTrips;
  final int orderAgeDays;

  @override
  Widget build(BuildContext context) {
    final clientName = order['clientName'] as String? ?? 'N/A';
    final progress = totalTrips > 0 ? (totalScheduledTrips / totalTrips) : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.paddingLG,
        AppSpacing.paddingMD,
        AppSpacing.paddingLG,
        AppSpacing.paddingMD,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AuthColors.surface,
            AuthColors.surface.withValues(alpha: 0.95),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: AuthColors.textSub.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.arrow_back,
                  color: AuthColors.textSub,
                  size: AppSpacing.iconMD,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: AppSpacing.paddingSM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: AppTypography.h3,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.paddingSM),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.paddingMD,
                  vertical: AppSpacing.paddingSM,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      priorityColor.withValues(alpha: 0.25),
                      priorityColor.withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                  border: Border.all(
                    color: priorityColor.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
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
          const SizedBox(height: AppSpacing.paddingLG),
          // Progress Indicator
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
                          'Trip Progress',
                          style: AppTypography.bodySmall.copyWith(
                            color: AuthColors.textSub,
                          ),
                        ),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}%',
                          style: AppTypography.labelSmall.copyWith(
                            color: progress == 1.0
                                ? AuthColors.success
                                : AuthColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.paddingXS),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: AuthColors.surface,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusXS),
                        ),
                        child: Stack(
                          children: [
                            if (totalTrips > 0)
                              FractionallySizedBox(
                                widthFactor: progress,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: progress == 1.0
                                          ? [
                                              AuthColors.success,
                                              AuthColors.success
                                                  .withValues(alpha: 0.8),
                                            ]
                                          : [
                                              AuthColors.primary,
                                              AuthColors.primary
                                                  .withValues(alpha: 0.8),
                                            ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.paddingXS),
                    Text(
                      '$totalScheduledTrips of $totalTrips scheduled',
                      style: AppTypography.captionSmall.copyWith(
                        color: AuthColors.textDisabled,
                      ),
                    ),
                  ],
                ),
              ),
              if (orderAgeDays > 0) ...[
                const SizedBox(width: AppSpacing.paddingMD),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.paddingSM,
                    vertical: AppSpacing.paddingXS,
                  ),
                  decoration: BoxDecoration(
                    color: orderAgeDays > 7
                        ? AuthColors.error.withValues(alpha: 0.1)
                        : AuthColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
                    border: Border.all(
                      color: orderAgeDays > 7
                          ? AuthColors.error.withValues(alpha: 0.3)
                          : AuthColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: orderAgeDays > 7
                            ? AuthColors.error
                            : AuthColors.warning,
                      ),
                      const SizedBox(width: AppSpacing.paddingXS / 2),
                      Text(
                        '$orderAgeDays days',
                        style: AppTypography.captionSmall.copyWith(
                          color: orderAgeDays > 7
                              ? AuthColors.error
                              : AuthColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// Tab Button Widget
class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.paddingSM,
          horizontal: AppSpacing.paddingXS,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AuthColors.primary : AuthColors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(
            color: isSelected ? AuthColors.textMain : AuthColors.textSub,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// Items Tab
class _ItemsTab extends StatelessWidget {
  const _ItemsTab({
    required this.items,
    required this.pricing,
    required this.formatCurrency,
    required this.onCallCustomer,
    required this.order,
    required this.formatDateTime,
  });

  final List<dynamic> items;
  final Map<String, dynamic>? pricing;
  final String Function(double?) formatCurrency;
  final VoidCallback onCallCustomer;
  final Map<String, dynamic> order;
  final String Function(dynamic) formatDateTime;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: AuthColors.textDisabled,
            ),
            const SizedBox(height: AppSpacing.paddingMD),
            Text(
              'No items in this order',
              style: AppTypography.body.copyWith(
                color: AuthColors.textSub,
              ),
            ),
          ],
        ),
      );
    }

    double totalSubtotal = 0.0;
    double totalGst = 0.0;
    double grandTotal = 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.paddingLG,
        AppSpacing.paddingMD,
        AppSpacing.paddingLG,
        AppSpacing.paddingXL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Call Customer Button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                onCallCustomer();
              },
              icon: const Icon(Icons.phone_outlined, size: 20),
              label: const Text('Call Customer'),
              style: FilledButton.styleFrom(
                backgroundColor: AuthColors.primary,
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.paddingMD,
                  horizontal: AppSpacing.paddingLG,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.paddingLG),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value as Map<String, dynamic>;
            final productName = item['productName'] as String? ?? 'N/A';
            final quantity = item['quantity'] as int? ?? 0;
            final unitPrice = (item['unitPrice'] as num?)?.toDouble() ?? 0.0;
            final subtotal = (item['subtotal'] as num?)?.toDouble() ??
                (quantity * unitPrice);
            final gstAmount = (item['gstAmount'] as num?)?.toDouble() ?? 0.0;
            final gstPercent = (item['gstPercent'] as num?)?.toDouble() ?? 0.0;
            final itemTotal = subtotal + gstAmount;
            final estimatedTrips = item['estimatedTrips'] as int? ?? 0;
            final scheduledTrips = item['scheduledTrips'] as int? ?? 0;
            final remainingTrips = estimatedTrips - scheduledTrips;
            final fixedQuantityPerTrip =
                item['fixedQuantityPerTrip'] as int? ?? 0;

            totalSubtotal += subtotal;
            totalGst += gstAmount;
            grandTotal += itemTotal;

            return Padding(
              padding: EdgeInsets.only(
                bottom: index < items.length - 1 ? AppSpacing.paddingMD : 0,
              ),
              child: _ItemCard(
                productName: productName,
                quantity: quantity,
                unitPrice: unitPrice,
                subtotal: subtotal,
                gstAmount: gstAmount,
                gstPercent: gstPercent,
                itemTotal: itemTotal,
                estimatedTrips: estimatedTrips,
                scheduledTrips: scheduledTrips,
                remainingTrips: remainingTrips,
                fixedQuantityPerTrip: fixedQuantityPerTrip,
                formatCurrency: formatCurrency,
              ),
            );
          }),

          // Pricing Summary
          const SizedBox(height: AppSpacing.paddingLG),
          _InfoCard(
            title: 'Order Summary',
            children: [
              _InfoRow(
                label: 'Subtotal',
                value: formatCurrency(totalSubtotal),
              ),
              if (totalGst > 0)
                _InfoRow(
                  label: 'GST',
                  value: formatCurrency(totalGst),
                ),
              const Divider(height: AppSpacing.paddingMD),
              _InfoRow(
                label: 'Grand Total',
                value: formatCurrency(grandTotal),
                valueColor: AuthColors.primary,
                valueStyle: AppTypography.h4.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          // Created Date
          const SizedBox(height: AppSpacing.paddingLG),
          _InfoCard(
            title: 'Order Information',
            children: [
              _InfoRow(
                label: 'Created',
                value: formatDateTime(order['createdAt']),
              ),
            ],
          ),
          SizedBox(
              height:
                  MediaQuery.of(context).padding.bottom + AppSpacing.paddingXL),
        ],
      ),
    );
  }
}

// Item Card Widget
class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.gstAmount,
    required this.gstPercent,
    required this.itemTotal,
    required this.estimatedTrips,
    required this.scheduledTrips,
    required this.remainingTrips,
    required this.fixedQuantityPerTrip,
    required this.formatCurrency,
  });

  final String productName;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final double gstAmount;
  final double gstPercent;
  final double itemTotal;
  final int estimatedTrips;
  final int scheduledTrips;
  final int remainingTrips;
  final int fixedQuantityPerTrip;
  final String Function(double?) formatCurrency;

  @override
  Widget build(BuildContext context) {
    return ModernTile(
      padding: const EdgeInsets.all(AppSpacing.paddingMD),
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AuthColors.primary.withValues(alpha: 0.2),
                      AuthColors.primary.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: AuthColors.primary,
                  size: AppSpacing.iconMD,
                ),
              ),
              const SizedBox(width: AppSpacing.paddingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.paddingXS / 2),
                    Text(
                      'Qty: $quantity',
                      style: AppTypography.bodySmall.copyWith(
                        color: AuthColors.textSub,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatCurrency(itemTotal),
                style: AppTypography.h4.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.paddingMD),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.paddingMD),

          // Pricing Details
          _InfoRow(
            label: 'Unit Price',
            value: formatCurrency(unitPrice),
          ),
          _InfoRow(
            label: 'Subtotal',
            value: formatCurrency(subtotal),
          ),
          if (gstAmount > 0 || gstPercent > 0)
            _InfoRow(
              label:
                  'GST ${gstPercent > 0 ? '(${gstPercent.toStringAsFixed(1)}%)' : ''}',
              value: formatCurrency(gstAmount),
            ),

          const SizedBox(height: AppSpacing.paddingMD),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.paddingMD),

          // Trip Information
          Row(
            children: [
              Expanded(
                child: _TripInfoChip(
                  icon: Icons.route_outlined,
                  label: 'Total',
                  value: estimatedTrips.toString(),
                  color: AuthColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.paddingSM),
              Expanded(
                child: _TripInfoChip(
                  icon: Icons.check_circle_outline,
                  label: 'Scheduled',
                  value: scheduledTrips.toString(),
                  color: AuthColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.paddingSM),
              Expanded(
                child: _TripInfoChip(
                  icon: Icons.pending_outlined,
                  label: 'Remaining',
                  value: remainingTrips.toString(),
                  color: AuthColors.warning,
                ),
              ),
            ],
          ),
          if (fixedQuantityPerTrip > 0) ...[
            const SizedBox(height: AppSpacing.paddingSM),
            _InfoRow(
              label: 'Qty per Trip',
              value: fixedQuantityPerTrip.toString(),
            ),
          ],
        ],
      ),
    );
  }
}

// Trip Info Chip
class _TripInfoChip extends StatelessWidget {
  const _TripInfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.paddingSM),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: AppSpacing.paddingXS / 2),
          Text(
            value,
            style: AppTypography.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: AppTypography.captionSmall.copyWith(
              color: AuthColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}

// Trips Tab
class _TripsTab extends StatelessWidget {
  const _TripsTab({
    required this.trips,
    required this.isLoading,
    required this.formatDate,
  });

  final List<Map<String, dynamic>> trips;
  final bool isLoading;
  final String Function(dynamic) formatDate;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AuthColors.primary,
        ),
      );
    }

    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.route_outlined,
              size: 64,
              color: AuthColors.textDisabled,
            ),
            const SizedBox(height: AppSpacing.paddingMD),
            Text(
              'No scheduled trips yet',
              style: AppTypography.body.copyWith(
                color: AuthColors.textSub,
              ),
            ),
            const SizedBox(height: AppSpacing.paddingXS),
            Text(
              'Schedule trips using the FAB menu',
              style: AppTypography.bodySmall.copyWith(
                color: AuthColors.textDisabled,
              ),
            ),
          ],
        ),
      );
    }

    // Sort trips by scheduled date
    final sortedTrips = List<Map<String, dynamic>>.from(trips);
    sortedTrips.sort((a, b) {
      final dateA = a['scheduledDate'];
      final dateB = b['scheduledDate'];
      if (dateA == null || dateB == null) return 0;

      DateTime dateTimeA, dateTimeB;
      try {
        dateTimeA = dateA is DateTime ? dateA : (dateA as Timestamp).toDate();
        dateTimeB = dateB is DateTime ? dateB : (dateB as Timestamp).toDate();
        return dateTimeA.compareTo(dateTimeB);
      } catch (e) {
        return 0;
      }
    });

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.paddingLG,
        AppSpacing.paddingMD,
        AppSpacing.paddingLG,
        AppSpacing.paddingXL,
      ),
      itemCount: sortedTrips.length,
      itemBuilder: (context, index) {
        final trip = sortedTrips[index];
        return Padding(
          padding: EdgeInsets.only(
            bottom: index < sortedTrips.length - 1 ? AppSpacing.paddingMD : 0,
          ),
          child: _ScheduledTripItem(
            trip: trip,
            formatDate: formatDate,
            isFirst: index == 0,
            isLast: index == sortedTrips.length - 1,
          ),
        );
      },
    );
  }
}

// Enhanced Scheduled Trip Item
class _ScheduledTripItem extends StatelessWidget {
  const _ScheduledTripItem({
    required this.trip,
    required this.formatDate,
    this.isFirst = false,
    this.isLast = false,
  });

  final Map<String, dynamic> trip;
  final String Function(dynamic) formatDate;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheduledDate = trip['scheduledDate'];
    final scheduledDay = trip['scheduledDay'] as String? ?? '';
    final vehicleNumber = trip['vehicleNumber'] as String? ?? 'N/A';
    final driverName = trip['driverName'] as String?;
    final slot = trip['slot'] as int?;
    final status = trip['tripStatus'] as String? ?? 'scheduled';
    final isInProgress = status == 'in_progress';
    final isCompleted = status == 'delivered' || status == 'completed';

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (isCompleted) {
      statusColor = AuthColors.success;
      statusIcon = Icons.check_circle;
      statusText = 'Completed';
    } else if (isInProgress) {
      statusColor = AuthColors.warning;
      statusIcon = Icons.sync;
      statusText = 'In Progress';
    } else {
      statusColor = AuthColors.primary;
      statusIcon = Icons.schedule;
      statusText = 'Scheduled';
    }

    return ModernTile(
      padding: const EdgeInsets.all(AppSpacing.paddingMD),
      elevation: 0,
      child: Row(
        children: [
          // Timeline indicator
          Column(
            children: [
              if (!isFirst)
                Container(
                  width: 2,
                  height: 8,
                  color: AuthColors.textSub.withValues(alpha: 0.1),
                ),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AuthColors.surface,
                    width: 2,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AuthColors.textSub.withValues(alpha: 0.1),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.paddingMD),

          // Trip details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
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
                                color: AuthColors.textSub,
                              ),
                              const SizedBox(width: AppSpacing.paddingXS / 2),
                              Text(
                                vehicleNumber,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AuthColors.textSub,
                                ),
                              ),
                              if (driverName != null) ...[
                                const SizedBox(width: AppSpacing.paddingSM),
                                const Icon(
                                  Icons.person_outline,
                                  size: AppSpacing.iconXS,
                                  color: AuthColors.textSub,
                                ),
                                const SizedBox(width: AppSpacing.paddingXS / 2),
                                Text(
                                  driverName,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AuthColors.textSub,
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
                            statusColor.withValues(alpha: 0.25),
                            statusColor.withValues(alpha: 0.15),
                          ],
                        ),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusXS),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            statusIcon,
                            size: 14,
                            color: statusColor,
                          ),
                          const SizedBox(width: AppSpacing.paddingXS / 2),
                          Text(
                            statusText,
                            style: AppTypography.captionSmall.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (slot != null) ...[
                  const SizedBox(height: AppSpacing.paddingSM),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.paddingXS,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AuthColors.primary.withValues(alpha: 0.2),
                          AuthColors.primary.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusXS / 2),
                      border: Border.all(
                        color: AuthColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Slot $slot',
                      style: AppTypography.captionSmall.copyWith(
                        color: AuthColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Stat Card Widget
// Info Card Widget
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
        padding: const EdgeInsets.all(AppSpacing.paddingLG),
        elevation: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.h4.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.paddingLG),
            ...children,
          ],
        ),
      ),
    );
  }
}

// Info Row Widget
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueStyle,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final effectiveValueColor = valueColor ?? AuthColors.textSub;
    final effectiveValueStyle = valueStyle ??
        AppTypography.body.copyWith(
          color: effectiveValueColor,
          fontWeight: FontWeight.normal,
        );

    final content = Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AuthColors.textDisabled,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: effectiveValueStyle,
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingXS),
      child: content,
    );
  }
}

extension StringExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
