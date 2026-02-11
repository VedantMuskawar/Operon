import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/data/repositories/clients_repository.dart';
import 'package:dash_mobile/data/repositories/pending_orders_repository.dart';
import 'package:dash_mobile/presentation/blocs/clients/clients_cubit.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/views/clients_page/contact_page.dart';
import 'package:dash_mobile/presentation/views/home_sections/orders_section_shared.dart';
import 'package:dash_mobile/presentation/views/orders/create_order_page.dart';
import 'package:dash_mobile/presentation/views/orders/select_customer_page.dart';
import 'package:dash_mobile/presentation/widgets/order_tile.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:dash_mobile/shared/constants/app_typography.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PendingOrdersView extends StatefulWidget {
  const PendingOrdersView({super.key});

  static void showCustomerTypeDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AuthColors.background.withOpacity(0),
      builder: (context) => _CustomerTypeDialog(),
    );
  }

  @override
  State<PendingOrdersView> createState() => _PendingOrdersViewState();
}

class _PendingOrdersViewState extends State<PendingOrdersView> {
  int _pendingOrdersCount = 0;
  int _totalPendingTrips = 0;
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  bool _isEddRunning = false;
  StreamSubscription<List<Map<String, dynamic>>>? _ordersSubscription;
  String? _currentOrgId;
  int? _selectedFixedQuantityFilter; // null means "All"

  // Cached — recomputed only when _orders or _selectedFixedQuantityFilter change
  List<Map<String, dynamic>> _cachedFilteredOrders = [];
  List<int> _cachedUniqueQuantities = [];

  // Cache trip counts per order to avoid recalculating on every stream update
  final Map<String, int> _orderTripCounts = {};
  Set<String> _cachedOrderIds = {};

  @override
  void initState() {
    super.initState();
    _subscribeToOrders();
  }

  void _updateCachedValues() {
    _cachedFilteredOrders = _computeFilteredOrders();
    _cachedUniqueQuantities = _computeUniqueQuantities();
  }

  /// Calculate remaining trips for a single order (pending trips to schedule)
  /// Do NOT use totalTripsRequired — that's total; we need remaining only
  int _calculateOrderTrips(Map<String, dynamic> order) {
    final items = order['items'] as List<dynamic>? ?? [];
    final firstItem =
        items.isNotEmpty ? items.first as Map<String, dynamic> : null;
    int remainingTrips = 0;
    for (final item in items) {
      final itemMap = item as Map<String, dynamic>;
      remainingTrips += (itemMap['estimatedTrips'] as int? ?? 0);
    }
    if (remainingTrips == 0 && firstItem != null) {
      remainingTrips = firstItem['estimatedTrips'] as int? ??
          (order['tripIds'] as List<dynamic>?)?.length ??
          0;
    }
    return remainingTrips;
  }

  Future<void> _runEddForAllOrders() async {
    if (_isEddRunning) return;

    final orgContext = context.read<OrganizationContextCubit>().state;
    final organization = orgContext.organization;
    if (organization == null) {
      DashSnackbar.show(context,
          message: 'Organization not selected', isError: true);
      return;
    }

    setState(() {
      _isEddRunning = true;
    });

    try {
      final repository = context.read<PendingOrdersRepository>();
      final result =
          await repository.calculateEddForAllPendingOrders(organization.id);
      final updatedOrders = result['updatedOrders'] ?? 0;
      DashSnackbar.show(context,
          message: 'EDD calculated for $updatedOrders order(s)');
    } catch (e) {
      DashSnackbar.show(context,
          message: 'Failed to calculate EDD: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isEddRunning = false;
        });
      }
    }
  }

  /// Calculate total trips count, using cached values when possible
  int _calculateTotalTrips(List<Map<String, dynamic>> orders) {
    int totalTrips = 0;
    final newOrderIds = orders
        .map((o) => o['id'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    // Check if orders list actually changed by comparing IDs using Set (O(n) instead of O(n²))
    final ordersChanged = newOrderIds.length != _cachedOrderIds.length ||
        !newOrderIds.every((id) => _cachedOrderIds.contains(id));

    if (ordersChanged) {
      // Recalculate trip counts for all orders
      _orderTripCounts.clear();
      for (final order in orders) {
        final orderId = order['id'] as String? ?? '';
        if (orderId.isNotEmpty) {
          _orderTripCounts[orderId] = _calculateOrderTrips(order);
        }
      }
      _cachedOrderIds = newOrderIds;
    }

    // Sum up cached trip counts
    for (final orderId in newOrderIds) {
      totalTrips += _orderTripCounts[orderId] ?? 0;
    }

    return totalTrips;
  }

  List<Map<String, dynamic>> _computeFilteredOrders() {
    if (_selectedFixedQuantityFilter == null) {
      return _orders; // Return reference, no need to copy
    }
    return _orders.where((order) {
      final items = order['items'] as List<dynamic>? ?? [];
      if (items.isEmpty) return false;
      final firstItem = items.first as Map<String, dynamic>;
      return (firstItem['fixedQuantityPerTrip'] as int?) ==
          _selectedFixedQuantityFilter;
    }).toList();
  }

  List<int> _computeUniqueQuantities() {
    final Set<int> unique = {};
    for (final order in _orders) {
      final items = order['items'] as List<dynamic>? ?? [];
      if (items.isNotEmpty) {
        final q = (items.first as Map<String, dynamic>)['fixedQuantityPerTrip']
            as int?;
        if (q != null && q > 0) unique.add(q);
      }
    }
    final list = unique.toList()..sort();
    return list;
  }

  Future<void> _subscribeToOrders() async {
    final orgContext = context.read<OrganizationContextCubit>().state;
    final organization = orgContext.organization;

    if (organization == null) {
      await _ordersSubscription?.cancel();
      _ordersSubscription = null;
      _currentOrgId = null;
      _cachedOrderIds.clear();
      _orderTripCounts.clear();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _orders = [];
          _pendingOrdersCount = 0;
          _totalPendingTrips = 0;
          _updateCachedValues();
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
        // Use cached calculation method that only recalculates when orders change
        final tripsCount = _calculateTotalTrips(orders);

        if (mounted) {
          setState(() {
            _orders = orders;
            _pendingOrdersCount = orders.length;
            _totalPendingTrips = tripsCount;
            _isLoading = false;
            _updateCachedValues();
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

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const horizontalPadding = 20.0;
    return BlocListener<OrganizationContextCubit, OrganizationContextState>(
      listener: (context, state) {
        if (state.organization != null) {
          _currentOrgId = null;
          _subscribeToOrders();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: _isLoading
            ? const OrdersSectionSkeletonLoading()
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _StatTile(
                                title: 'Orders',
                                value: _pendingOrdersCount.toString(),
                                icon: Icons.shopping_cart_outlined,
                                accentColor: AuthColors.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.paddingLG),
                            Expanded(
                              child: _StatTile(
                                title: 'Trips',
                                value: _totalPendingTrips.toString(),
                                icon: Icons.route_outlined,
                                accentColor: AuthColors.secondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.paddingMD),
                        SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: (_isEddRunning || _orders.isEmpty)
                                ? null
                                : _runEddForAllOrders,
                            icon: _isEddRunning
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.schedule_outlined),
                            label: Text(_isEddRunning
                                ? 'Calculating EDD...'
                                : 'Estimated Dates'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AuthColors.primary,
                              foregroundColor: AuthColors.textMain,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_orders.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.paddingXL)),
                    SliverToBoxAdapter(
                      child: _FixedQuantityFilter(
                        uniqueQuantities: _cachedUniqueQuantities,
                        selectedValue: _selectedFixedQuantityFilter,
                        onFilterChanged: (value) {
                          setState(() {
                            _selectedFixedQuantityFilter = value;
                            _updateCachedValues();
                          });
                        },
                      ),
                    ),
                    const SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.paddingMD)),
                  ],
                  if (_cachedFilteredOrders.isNotEmpty)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final order = _cachedFilteredOrders[index];
                          final tile = Padding(
                            padding: const EdgeInsets.only(
                                bottom: AppSpacing.paddingMD),
                            child: OrderTile(
                              key: ValueKey(order['id']),
                              order: order,
                              onTripsUpdated: () {
                                // Stream subscription already handles real-time updates
                                // No need to recreate subscription
                              },
                              onDeleted: () {
                                // Stream subscription already handles real-time updates
                                // No need to recreate subscription
                              },
                            ),
                          );
                          return RepaintBoundary(
                            child: AnimationConfiguration.staggeredList(
                              position: index,
                              duration: const Duration(milliseconds: 200),
                              child: SlideAnimation(
                                verticalOffset: 50.0,
                                child: FadeInAnimation(
                                  curve: Curves.easeOut,
                                  child: tile,
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: _cachedFilteredOrders.length,
                        addRepaintBoundaries: true,
                      ),
                    )
                  else if (!_isLoading && _orders.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: 32),
                        child: OrdersSectionEmptyState(
                          title: 'No Pending Orders',
                          message: 'All orders have been processed',
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _FixedQuantityFilter extends StatelessWidget {
  const _FixedQuantityFilter({
    required this.uniqueQuantities,
    required this.selectedValue,
    required this.onFilterChanged,
  });

  final List<int> uniqueQuantities;
  final int? selectedValue;
  final ValueChanged<int?> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    if (uniqueQuantities.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            isSelected: selectedValue == null,
            onTap: () => onFilterChanged(null),
          ),
          const SizedBox(width: AppSpacing.paddingSM),
          ...uniqueQuantities.map((quantity) => Padding(
                padding: const EdgeInsets.only(right: AppSpacing.paddingSM),
                child: _FilterChip(
                  label: quantity.toString(),
                  isSelected: selectedValue == quantity,
                  onTap: () => onFilterChanged(quantity),
                ),
              )),
        ],
      ),
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
      color: AuthColors.background.withOpacity(0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
        splashColor: AuthColors.primaryWithOpacity(0.2),
        highlightColor: AuthColors.primaryWithOpacity(0.1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.paddingLG, vertical: AppSpacing.paddingSM),
          decoration: BoxDecoration(
            color: isSelected ? AuthColors.primary : AuthColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
            border: Border.all(
              color: isSelected
                  ? AuthColors.primary
                  : AuthColors.textMainWithOpacity(0.15),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AuthColors.primaryWithOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: AppTypography.withColor(
              isSelected
                  ? AppTypography.withWeight(
                      AppTypography.bodySmall, FontWeight.w600)
                  : AppTypography.withWeight(
                      AppTypography.bodySmall, FontWeight.w500),
              isSelected ? AuthColors.textMain : AuthColors.textSub,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.paddingLG, vertical: AppSpacing.paddingLG),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accentColor, size: 24),
          const SizedBox(width: AppSpacing.paddingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.withColor(
                      AppTypography.labelSmall, AuthColors.textSub),
                ),
                const SizedBox(height: AppSpacing.paddingXS),
                Text(
                  value,
                  style: AppTypography.withColor(
                      AppTypography.h1, AuthColors.textMain),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerTypeDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.paddingLG),
              decoration: BoxDecoration(
                color: AuthColors.textDisabled,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select Customer Type',
                style: AppTypography.withColor(
                    AppTypography.h3, AuthColors.textMain),
              ),
            ),
            const SizedBox(height: AppSpacing.paddingXL),
            _CustomerTypeOption(
              icon: Icons.person_add_outlined,
              title: 'New Customer',
              subtitle: 'Create a new customer profile',
              onTap: () async {
                Navigator.of(context).pop();
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const ContactPage(),
                    fullscreenDialog: true,
                  ),
                );
                // If client was created successfully, fetch the most recent client and navigate to create order page
                if (result == true && context.mounted) {
                  final clientsRepository = context.read<ClientsRepository>();
                  try {
                    // Fetch the most recently created client
                    final recentClients =
                        await clientsRepository.fetchRecentClients(limit: 1);
                    final createdClient =
                        recentClients.isNotEmpty ? recentClients.first : null;

                    if (context.mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              CreateOrderPage(client: createdClient),
                          fullscreenDialog: true,
                        ),
                      );
                    }
                  } catch (error) {
                    // If fetching fails, still navigate but without client
                    if (context.mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CreateOrderPage(),
                          fullscreenDialog: true,
                        ),
                      );
                    }
                  }
                }
              },
            ),
            const SizedBox(height: AppSpacing.paddingMD),
            _CustomerTypeOption(
              icon: Icons.person_outline,
              title: 'Existing Customer',
              subtitle: 'Select from existing customers',
              onTap: () {
                Navigator.of(context).pop();
                final clientsRepository = context.read<ClientsRepository>();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BlocProvider(
                      create: (_) => ClientsCubit(
                        repository: clientsRepository,
                      )..subscribeToRecent(),
                      child: const SelectCustomerPage(),
                    ),
                    fullscreenDialog: true,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerTypeOption extends StatelessWidget {
  const _CustomerTypeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.paddingXL),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
          border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AuthColors.legacyAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              ),
              child: Icon(
                icon,
                color: AuthColors.legacyAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.paddingLG),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.withColor(
                        AppTypography.h4, AuthColors.textMain),
                  ),
                  const SizedBox(height: AppSpacing.paddingXS),
                  Text(
                    subtitle,
                    style: AppTypography.withColor(
                        AppTypography.bodySmall, AuthColors.textSub),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AuthColors.textSub,
            ),
          ],
        ),
      ),
    );
  }
}
