import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/order.dart';
import '../../../../core/theme/app_theme.dart';
import '../../bloc/pending_orders_bloc.dart';
import '../../bloc/pending_orders_event.dart';
import '../../bloc/pending_orders_state.dart';
import '../../repositories/scheduled_order_repository.dart';
import 'schedule_order_dialog.dart';

class PendingOrdersView extends StatefulWidget {
  const PendingOrdersView({
    super.key,
    required this.organizationId,
    required this.userId,
    required this.scheduledOrderRepository,
  });

  final String organizationId;
  final String userId;
  final ScheduledOrderRepository scheduledOrderRepository;

  @override
  State<PendingOrdersView> createState() => _PendingOrdersViewState();
}

class _PendingOrdersViewState extends State<PendingOrdersView> {
  @override
  void initState() {
    super.initState();
    _loadPendingOrders(forceRefresh: true);
  }

  @override
  void didUpdateWidget(covariant PendingOrdersView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organizationId != widget.organizationId &&
        widget.organizationId.isNotEmpty) {
      _loadPendingOrders(forceRefresh: true);
    }
  }

  void _loadPendingOrders({bool forceRefresh = false}) {
    if (widget.organizationId.isEmpty) return;

    context.read<PendingOrdersBloc>().add(
          PendingOrdersRequested(
            organizationId: widget.organizationId,
            forceRefresh: forceRefresh,
          ),
        );
  }

  Future<void> _refreshPendingOrders() {
    final bloc = context.read<PendingOrdersBloc>();
    final completer = Completer<void>();

    late StreamSubscription subscription;
    subscription = bloc.stream.listen((state) {
      if (!state.isRefreshing) {
        if (!completer.isCompleted) {
          completer.complete();
        }
        subscription.cancel();
      }
    });

    bloc.add(const PendingOrdersRefreshed());

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        subscription.cancel();
        return;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PendingOrdersBloc, PendingOrdersState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          context
              .read<PendingOrdersBloc>()
              .add(const PendingOrdersMessageCleared());
        } else if (state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.successMessage!),
              backgroundColor: AppTheme.successColor,
            ),
          );
          context
              .read<PendingOrdersBloc>()
              .add(const PendingOrdersMessageCleared());
        }
      },
      builder: (context, state) {
        switch (state.status) {
          case PendingOrdersStatus.initial:
          case PendingOrdersStatus.loading:
            return _buildLoadingState();
          case PendingOrdersStatus.failure:
            return _buildErrorState(state);
          case PendingOrdersStatus.empty:
            return _buildEmptyState(state);
          case PendingOrdersStatus.success:
            return _buildOrdersList(state);
        }
      },
    );
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildErrorState(PendingOrdersState state) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(
            color: AppTheme.errorColor.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 40,
              color: AppTheme.errorColor.withValues(alpha: 0.9),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              'We couldn\'t load pending orders.',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              state.errorMessage ??
                  'An unknown error occurred. Please try again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            ElevatedButton.icon(
              onPressed: () => _loadPendingOrders(forceRefresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(PendingOrdersState state) {
    return RefreshIndicator(
      onRefresh: _refreshPendingOrders,
      color: AppTheme.primaryColor,
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingLg,
          vertical: AppTheme.spacingXl,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingXl),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              border: Border.all(
                color: AppTheme.borderSecondaryColor.withValues(alpha: 0.4),
              ),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.receipt_long,
                  size: 48,
                  color: AppTheme.textSecondaryColor.withValues(alpha: 0.8),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                Text(
                  'No Pending Orders',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  'All caught up! New orders will appear here as they come in.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(PendingOrdersState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount = 1;
        if (width >= 1400) {
          crossAxisCount = 4;
        } else if (width >= 1024) {
          crossAxisCount = 3;
        } else if (width >= 720) {
          crossAxisCount = 2;
        }

        return RefreshIndicator(
          onRefresh: _refreshPendingOrders,
          color: AppTheme.primaryColor,
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(
              AppTheme.spacingLg,
              AppTheme.spacingLg,
              AppTheme.spacingLg,
              AppTheme.spacingMd,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: AppTheme.spacingLg,
              crossAxisSpacing: AppTheme.spacingLg,
              childAspectRatio: 1.05,
            ),
            itemCount: state.orders.length,
            itemBuilder: (context, index) {
              final order = state.orders[index];
              return _buildOrderCard(order, state);
            },
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(Order order, PendingOrdersState state) {
    final processing = state.processingOrderIds.contains(order.id);
    final orderAgeColor = _orderAgeColor(order.createdAt);
    final clientDisplay = (order.clientName?.trim().isNotEmpty ?? false)
        ? order.clientName!.trim()
        : '—';
    final regionAddress = _formatLocation(order.region, order.city);
    final totalQuantity =
        order.items.fold<int>(0, (sum, item) => sum + item.quantity);
    final orderPlacedOn = _formatOrderPlaced(order.createdAt);

    TextStyle? labelStyle(BuildContext context) => Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(
          color: AppTheme.textSecondaryColor,
          fontWeight: FontWeight.w500,
        );
    TextStyle? valueStyle(BuildContext context) => Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(
          color: AppTheme.textPrimaryColor,
          fontWeight: FontWeight.w600,
        );

    Widget infoPair(
      String label,
      String value, {
      TextAlign valueAlign = TextAlign.start,
      int maxLines = 1,
    }) {
      return Column(
        crossAxisAlignment: valueAlign == TextAlign.end
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: labelStyle(context)),
          const SizedBox(height: 4),
          Text(
            value,
            style: valueStyle(context),
            textAlign: valueAlign,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    final card = Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(
          color: orderAgeColor.withValues(alpha: 0.6),
          width: 1.2,
        ),
        boxShadow: [
          ...AppTheme.cardShadow,
          BoxShadow(
            color: orderAgeColor.withValues(alpha: 0.16),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    orderPlacedOn,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                _buildRemainingTripsBadge(order.remainingTrips),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Divider(
              color: AppTheme.borderSecondaryColor.withValues(alpha: 0.25),
              height: 1,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            infoPair('Client Name', clientDisplay, maxLines: 1),
            const SizedBox(height: AppTheme.spacingSm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: infoPair(
                    'Region, Address',
                    regionAddress,
                    maxLines: 2,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSm),
                infoPair(
                  'Quantity',
                  '$totalQuantity',
                  valueAlign: TextAlign.end,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSm),
            infoPair('Order placed', orderPlacedOn, maxLines: 2),
            const SizedBox(height: AppTheme.spacingSm),
            Divider(
              color: AppTheme.borderSecondaryColor.withValues(alpha: 0.25),
              height: 1,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        processing ? null : () => _openScheduleDialog(order),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacingXs,
                      ),
                    ),
                    child: const Text(
                      'Schedule',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingXs),
                Expanded(
                  child: OutlinedButton(
                    onPressed: processing ? null : () => _confirmDelete(order),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacingXs,
                      ),
                      side: BorderSide(
                        color: AppTheme.errorColor.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppTheme.errorColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return AspectRatio(
      aspectRatio: 1.05,
      child: Stack(
        children: [
          card,
          if (processing)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRemainingTripsBadge(int remainingTrips) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        '$remainingTrips',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  Color _orderAgeColor(DateTime createdAt) {
    final daysSince = DateTime.now().difference(createdAt).inDays;
    if (daysSince <= 1) {
      return AppTheme.successColor;
    } else if (daysSince <= 3) {
      return AppTheme.warningColor;
    } else {
      return AppTheme.errorColor.withValues(alpha: 0.85);
    }
  }

  String _formatLocation(String region, String city) {
    final parts = [region, city].where((part) => part.trim().isNotEmpty);
    if (parts.isEmpty) return 'Location pending';
    return parts.join(', ');
  }

  String _formatOrderPlaced(DateTime date) {
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
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$day $month $year, $hour12:$minute $period';
  }

  Future<void> _openScheduleDialog(Order order) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ScheduleOrderDialog(
        organizationId: widget.organizationId,
        order: order,
        userId: widget.userId,
        repository: widget.scheduledOrderRepository,
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order scheduled successfully'),
        ),
      );
      context
          .read<PendingOrdersBloc>()
          .add(const PendingOrdersRefreshed());
    }
  }

  Future<void> _confirmDelete(Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          ),
          title: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(AppTheme.spacingSm),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.errorColor,
                ),
              ),
              const SizedBox(width: AppTheme.spacingSm),
              const Expanded(
                child: Text('Delete order?'),
              ),
            ],
          ),
          content: const Text(
            'This action cannot be undone. Are you sure you want to delete this order?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      context.read<PendingOrdersBloc>().add(
            PendingOrderDeleteRequested(order: order),
          );
    }
  }
}

