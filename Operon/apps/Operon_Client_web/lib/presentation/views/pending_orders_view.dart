import 'dart:async';

import 'package:dash_web/data/repositories/pending_orders_repository.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/widgets/pending_order_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class PendingOrdersView extends StatefulWidget {
  const PendingOrdersView({super.key});

  @override
  State<PendingOrdersView> createState() => _PendingOrdersViewState();
}

class _PendingOrdersViewState extends State<PendingOrdersView> {
  int _pendingOrdersCount = 0;
  int _totalPendingTrips = 0;
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  StreamSubscription<List<Map<String, dynamic>>>? _ordersSubscription;
  String? _currentOrgId;
  int? _selectedFixedQuantityFilter; // null means "All"

  @override
  void initState() {
    super.initState();
    _subscribeToOrders();
  }

  Future<void> _subscribeToOrders() async {
    final orgContext = context.read<OrganizationContextCubit>().state;
    final organization = orgContext.organization;

    if (organization == null) {
      await _ordersSubscription?.cancel();
      _ordersSubscription = null;
      _currentOrgId = null;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _orders = [];
          _pendingOrdersCount = 0;
          _totalPendingTrips = 0;
        });
      }
      return;
    }

    final orgId = organization.id;
    if (_currentOrgId == orgId && _ordersSubscription != null) {
      // Already subscribed
      return;
    }

    _currentOrgId = orgId;

    final repository = context.read<PendingOrdersRepository>();
    await _ordersSubscription?.cancel();
    _ordersSubscription = repository.watchPendingOrders(orgId).listen(
      (orders) {
        final tripsCount = orders.fold<int>(0, (total, order) {
          final items = order['items'] as List<dynamic>? ?? [];
          final firstItem = items.isNotEmpty ? items.first as Map<String, dynamic>? : null;
          final autoSchedule = order['autoSchedule'] as Map<String, dynamic>?;
          
          // Calculate total estimated trips using same logic as tile
          // Priority: 1. autoSchedule.totalTripsRequired, 2. Sum of item estimatedTrips, 3. Fallback
          int totalEstimatedTrips = 0;
          if (autoSchedule?['totalTripsRequired'] != null) {
            totalEstimatedTrips = (autoSchedule!['totalTripsRequired'] as num).toInt();
          } else {
            // Fallback: Sum estimated trips from all items
            for (final item in items) {
              final itemMap = item as Map<String, dynamic>;
              totalEstimatedTrips += (itemMap['estimatedTrips'] as int? ?? 0);
            }
            if (totalEstimatedTrips == 0 && firstItem != null) {
              totalEstimatedTrips = firstItem['estimatedTrips'] as int? ?? 
                  (order['tripIds'] as List<dynamic>?)?.length ?? 0;
            }
          }
          
          return total + totalEstimatedTrips;
        });

        if (mounted) {
          setState(() {
            _orders = orders;
            _pendingOrdersCount = orders.length;
            _totalPendingTrips = tripsCount;
            _isLoading = false;
          });
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      },
    );
  }

  List<Map<String, dynamic>> _getFilteredOrders() {
    if (_selectedFixedQuantityFilter == null) {
      return _orders;
    }

    return _orders.where((order) {
      final items = order['items'] as List<dynamic>? ?? [];
      if (items.isEmpty) return false;
      final firstItem = items.first as Map<String, dynamic>;
      final fixedQuantityPerTrip = firstItem['fixedQuantityPerTrip'] as int?;
      return fixedQuantityPerTrip == _selectedFixedQuantityFilter;
    }).toList();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrganizationContextCubit, OrganizationContextState>(
      listener: (context, state) {
        if (state.organization != null) {
          _currentOrgId = null;
          _subscribeToOrders();
        }
      },
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6F4BFF),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stat Tiles
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        title: 'Pending Orders',
                        value: _pendingOrdersCount.toString(),
                        icon: Icons.pending_actions_outlined,
                        color: const Color(0xFFFF9800),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatTile(
                        title: 'Pending Trips',
                        value: _totalPendingTrips.toString(),
                        icon: Icons.local_shipping_outlined,
                        color: const Color(0xFF4CAF50),
                      ),
                    ),
                  ],
                ),
                // Filters
                if (_orders.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _FixedQuantityFilter(
                    orders: _orders,
                    selectedValue: _selectedFixedQuantityFilter,
                    onFilterChanged: (value) {
                      setState(() {
                        _selectedFixedQuantityFilter = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                ],
                // Order Tiles - Grid Layout
                if (_getFilteredOrders().isNotEmpty) ...[
                  AnimationLimiter(
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        childAspectRatio: 0.85, // Taller tiles to accommodate more content
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                      ),
                      itemCount: _getFilteredOrders().length,
                      itemBuilder: (context, index) {
                        return AnimationConfiguration.staggeredGrid(
                          position: index,
                          duration: const Duration(milliseconds: 200),
                          columnCount: 5,
                          child: SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(
                              curve: Curves.easeOut,
                              child: PendingOrderTile(
                                order: _getFilteredOrders()[index],
                                onTripsUpdated: () => _subscribeToOrders(),
                                onDeleted: () => _subscribeToOrders(),
                                onTap: () {
                                  // TODO: Navigate to order detail page
                          // context.push('/pending-orders/${order['id']}');
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ] else if (!_isLoading && _orders.isEmpty) ...[
                  const SizedBox(height: 48),
                  const _EmptyStateCard(
                    icon: Icons.pending_actions_outlined,
                    title: 'No Pending Orders',
                    description: 'All orders have been processed or there are no orders yet.',
                    color: Color(0xFFFF9800),
                  ),
                ],
              ],
            ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FixedQuantityFilter extends StatelessWidget {
  const _FixedQuantityFilter({
    required this.orders,
    required this.selectedValue,
    required this.onFilterChanged,
  });

  final List<Map<String, dynamic>> orders;
  final int? selectedValue;
  final ValueChanged<int?> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    // Extract unique fixedQuantityPerTrip values from orders
    final Set<int> uniqueQuantities = {};
    for (final order in orders) {
      final items = order['items'] as List<dynamic>? ?? [];
      if (items.isNotEmpty) {
        final firstItem = items.first as Map<String, dynamic>;
        final fixedQuantityPerTrip = firstItem['fixedQuantityPerTrip'] as int?;
        if (fixedQuantityPerTrip != null && fixedQuantityPerTrip > 0) {
          uniqueQuantities.add(fixedQuantityPerTrip);
        }
      }
    }

    final sortedQuantities = uniqueQuantities.toList()..sort();

    if (sortedQuantities.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filter by Quantity',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // "All" filter chip
              _FilterChip(
                label: 'All',
                isSelected: selectedValue == null,
                onTap: () => onFilterChanged(null),
              ),
              const SizedBox(width: 8),
              // Quantity filter chips
              ...sortedQuantities.map((quantity) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: quantity.toString(),
                      isSelected: selectedValue == quantity,
                      onTap: () => onFilterChanged(quantity),
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF6F4BFF)
                : const Color(0xFF1B1B2C),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF6F4BFF)
                  : Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(48),
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: const Color(0xFF131324),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: color,
                size: 32,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
