import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/data/repositories/clients_repository.dart';
import 'package:dash_mobile/data/repositories/pending_orders_repository.dart';
import 'package:dash_mobile/data/services/client_service.dart';
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
      backgroundColor: AuthColors.background.withValues(alpha: 0),
      builder: (context) => _CustomerTypeDialog(),
    );
  }

  @override
  State<PendingOrdersView> createState() => _PendingOrdersViewState();
}

class _PendingOrdersViewState extends State<PendingOrdersView> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  bool _isEddRunning = false;
  StreamSubscription<List<Map<String, dynamic>>>? _ordersSubscription;
  String? _currentOrgId;
  final Set<int> _selectedFixedQuantityFilters = {}; // empty means "All"
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Cached — recomputed only when _orders or _selectedFixedQuantityFilter change
  List<Map<String, dynamic>> _cachedFilteredOrders = [];
  List<int> _cachedUniqueQuantities = [];
  int _cachedFilteredOrdersCount = 0;
  int _cachedFilteredTripsCount = 0;

  // Cache trip counts per order to avoid recalculating on every stream update
  final Map<String, int> _orderTripCounts = {};
  Set<String> _cachedOrderIds = {};

  @override
  void initState() {
    super.initState();
    _subscribeToOrders();
    _searchController.addListener(_handleSearchChanged);
  }

  void _updateCachedValues() {
    _cachedFilteredOrders = _computeFilteredOrders();
    _cachedUniqueQuantities = _computeUniqueQuantities();
    _cachedFilteredOrdersCount = _cachedFilteredOrders.length;
    _cachedFilteredTripsCount =
        _calculateTotalTrips(_cachedFilteredOrders);
  }

  void _handleSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (query == _searchQuery) return;
    setState(() {
      _searchQuery = query;
      _updateCachedValues();
    });
  }

  bool _matchesSearch(Map<String, dynamic> order) {
    if (_searchQuery.isEmpty) return true;
    final clientName = (order['clientName'] as String? ?? '').toLowerCase();
    final clientPhone = (order['clientPhone'] as String? ?? '').toLowerCase();
    final orderNumber = (order['orderNumber'] as String? ?? '').toLowerCase();
    final orderId = (order['id'] as String? ?? '').toLowerCase();
    return clientName.contains(_searchQuery) ||
        clientPhone.contains(_searchQuery) ||
        orderNumber.contains(_searchQuery) ||
        orderId.contains(_searchQuery);
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
      if (!mounted) {
        return;
      }
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
    if (_selectedFixedQuantityFilters.isEmpty) {
      return _orders.where(_matchesSearch).toList();
    }
    return _orders.where((order) {
      if (!_matchesSearch(order)) return false;
      final items = order['items'] as List<dynamic>? ?? [];
      if (items.isEmpty) return false;
      final firstItem = items.first as Map<String, dynamic>;
      final fixedQuantity = firstItem['fixedQuantityPerTrip'] as int?;
      return fixedQuantity != null &&
          _selectedFixedQuantityFilters.contains(fixedQuantity);
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
        if (mounted) {
          setState(() {
            _orders = orders;
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
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
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
                                value: _cachedFilteredOrdersCount.toString(),
                                icon: Icons.shopping_cart_outlined,
                                accentColor: AuthColors.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.paddingLG),
                            Expanded(
                              child: _StatTile(
                                title: 'Trips',
                                value: _cachedFilteredTripsCount.toString(),
                                icon: Icons.route_outlined,
                                accentColor: AuthColors.secondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.paddingMD),
                        SizedBox(
                          height: 44,
                          child: FilledButton.icon(
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
                            style: FilledButton.styleFrom(
                              backgroundColor: AuthColors.primary,
                              foregroundColor: AuthColors.textMain,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.paddingMD),
                        TextField(
                          controller: _searchController,
                          style: const TextStyle(
                            color: AuthColors.textMain,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search orders by client, phone, or order #',
                            hintStyle: const TextStyle(
                              color: AuthColors.textDisabled,
                              fontSize: 13,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: AuthColors.textSub,
                              size: 20,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                    },
                                    icon: const Icon(
                                      Icons.clear,
                                      color: AuthColors.textSub,
                                      size: 18,
                                    ),
                                  )
                                : null,
                            filled: true,
                            fillColor: AuthColors.backgroundAlt,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.paddingLG,
                              vertical: AppSpacing.paddingLG,
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusLG),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusLG),
                              borderSide: const BorderSide(
                                color: AuthColors.primary,
                                width: 2,
                              ),
                            ),
                          ),
                          textInputAction: TextInputAction.search,
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
                        selectedValues: _selectedFixedQuantityFilters,
                        onFilterChanged: (values) {
                          setState(() {
                            _selectedFixedQuantityFilters
                              ..clear()
                              ..addAll(values);
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
    required this.selectedValues,
    required this.onFilterChanged,
  });

  final List<int> uniqueQuantities;
  final Set<int> selectedValues;
  final ValueChanged<Set<int>> onFilterChanged;

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
            isSelected: selectedValues.isEmpty,
            onTap: () => onFilterChanged(<int>{}),
          ),
          const SizedBox(width: AppSpacing.paddingSM),
          ...uniqueQuantities.map((quantity) => Padding(
                padding: const EdgeInsets.only(right: AppSpacing.paddingSM),
                child: _FilterChip(
                  label: quantity.toString(),
                  isSelected: selectedValues.contains(quantity),
                  onTap: () {
                    final updated = Set<int>.from(selectedValues);
                    if (updated.contains(quantity)) {
                      updated.remove(quantity);
                    } else {
                      updated.add(quantity);
                    }
                    onFilterChanged(updated);
                  },
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
      color: AuthColors.background.withValues(alpha: 0),
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
                final rootNavigator = Navigator.of(context, rootNavigator: true);
                Navigator.of(context).pop();
                final result = await rootNavigator.push<ClientRecord>(
                  MaterialPageRoute(
                    builder: (_) => const ContactPage(),
                    fullscreenDialog: true,
                  ),
                );
                if (result != null) {
                  rootNavigator.push(
                    MaterialPageRoute(
                      builder: (_) => CreateOrderPage(client: result),
                      fullscreenDialog: true,
                    ),
                  );
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
                final org =
                    context.read<OrganizationContextCubit>().state.organization;
                if (org == null) {
                  return;
                }
                final clientsRepository = context.read<ClientsRepository>();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BlocProvider(
                      create: (_) => ClientsCubit(
                        repository: clientsRepository,
                        orgId: org.id,
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
                color: AuthColors.legacyAccent.withValues(alpha: 0.2),
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
