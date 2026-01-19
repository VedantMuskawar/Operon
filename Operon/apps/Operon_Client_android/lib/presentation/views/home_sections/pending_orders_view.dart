import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/data/repositories/clients_repository.dart';
import 'package:dash_mobile/data/repositories/pending_orders_repository.dart';
import 'package:dash_mobile/presentation/blocs/clients/clients_cubit.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/views/clients_page/contact_page.dart';
import 'package:dash_mobile/presentation/views/orders/create_order_page.dart';
import 'package:dash_mobile/presentation/views/orders/select_customer_page.dart';
import 'package:dash_mobile/presentation/widgets/order_tile.dart';
import 'package:dash_mobile/presentation/widgets/modern_tile.dart';
import 'package:dash_mobile/shared/constants/constants.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PendingOrdersView extends StatefulWidget {
  const PendingOrdersView({super.key});

  static void showCustomerTypeDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
          final totalScheduledTrips = (order['totalScheduledTrips'] as num?)?.toInt() ?? 0;
          final estimatedTrips = (order['estimatedTrips'] as num?)?.toInt() ??
              ((order['tripIds'] as List<dynamic>?)?.length ?? 0);
          return total + (totalScheduledTrips > 0 ? totalScheduledTrips : estimatedTrips);
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
          ? const _SkeletonLoader()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stat Tiles
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        title: 'Orders',
                        value: _pendingOrdersCount.toString(),
                        icon: Icons.shopping_cart_outlined,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.paddingLG),
                    Expanded(
                      child: _StatTile(
                        title: 'Trips',
                        value: _totalPendingTrips.toString(),
                        icon: Icons.route_outlined,
                        backgroundColor: AppColors.success.withOpacity(0.15),
                        iconColor: AppColors.success,
                      ),
                    ),
                  ],
                ),
                // Filters
                if (_orders.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _FixedQuantityFilter(
                    orders: _orders,
                    selectedValue: _selectedFixedQuantityFilter,
                    onFilterChanged: (value) {
                      setState(() {
                        _selectedFixedQuantityFilter = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                // Order Tiles
                if (_getFilteredOrders().isNotEmpty) ...[
                  _OrderList(
                    orders: _getFilteredOrders(),
                    onTripsUpdated: () => _subscribeToOrders(),
                    onDeleted: () => _subscribeToOrders(),
                  ),
                ] else if (!_isLoading && _orders.isEmpty) ...[
                  const SizedBox(height: AppSpacing.paddingXXL),
                  const _EmptyState(),
                ],
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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // "All" filter chip
          _FilterChip(
            label: 'All',
            isSelected: selectedValue == null,
            onTap: () => onFilterChanged(null),
          ),
          const SizedBox(width: AppSpacing.paddingSM),
          // Quantity filter chips
          ...sortedQuantities.map((quantity) => Padding(
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
        splashColor: AppColors.primary.withOpacity(0.2),
        highlightColor: AppColors.primary.withOpacity(0.1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.paddingLG,
            vertical: AppSpacing.paddingSM,
          ),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      AppColors.success,
                      AppColors.success.withOpacity(0.8),
                    ],
                  )
                : null,
            color: isSelected ? null : AppColors.cardBackgroundElevated,
            borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
            border: Border.all(
              color: isSelected
                  ? AppColors.success
                  : AppColors.borderMedium,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.success.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: AppTypography.labelSmall.copyWith(
              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
            child: Text(label),
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
    this.backgroundColor,
    this.iconColor,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color? backgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final isSuccess = backgroundColor == AppColors.success.withOpacity(0.15);
    final effectiveIconColor = iconColor ?? (isSuccess ? AppColors.success : AppColors.primary);

    return ModernTile(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.paddingLG,
        vertical: AppSpacing.paddingMD,
      ),
      borderColor: isSuccess
          ? AppColors.success.withOpacity(0.2)
          : AppColors.borderDefault,
      elevation: 0,
      child: Row(
        children: [
          Icon(
            icon,
            color: effectiveIconColor,
            size: AppSpacing.iconMD,
          ),
          const SizedBox(width: AppSpacing.paddingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.paddingXS / 2),
                Text(
                  value,
                  style: AppTypography.h1.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
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

class _SkeletonLoader extends StatelessWidget {
  const _SkeletonLoader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Stat tiles skeleton
        Row(
          children: [
            Expanded(child: _SkeletonTile()),
            const SizedBox(width: AppSpacing.paddingLG),
            Expanded(child: _SkeletonTile()),
          ],
        ),
        const SizedBox(height: AppSpacing.paddingXXL),
        // Order tiles skeleton
        ...List.generate(3, (index) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.paddingMD),
              child: _SkeletonOrderTile(),
            )),
      ],
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ModernTile(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.paddingLG,
        vertical: AppSpacing.paddingMD,
      ),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackgroundElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
              ),
            ),
            const SizedBox(width: AppSpacing.paddingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 80,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.inputBackground,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.paddingXS),
                  Container(
                    width: 40,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.inputBackground,
                      borderRadius: BorderRadius.circular(4),
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

class _SkeletonOrderTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.paddingMD),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.inputBackground,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.paddingXS),
                    Container(
                      width: 150,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.inputBackground,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 50,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.paddingMD),
          Row(
            children: List.generate(3, (index) => Expanded(
                  child: Container(
                    margin: EdgeInsets.only(
                      right: index < 2 ? AppSpacing.paddingSM : 0,
                    ),
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.inputBackground,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                )),
          ),
        ],
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({
    required this.orders,
    required this.onTripsUpdated,
    required this.onDeleted,
  });

  final List<Map<String, dynamic>> orders;
  final VoidCallback onTripsUpdated;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    // Use ListView.builder for better performance with large lists
    if (orders.length > 5) {
      return AnimationLimiter(
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: orders.length,
          separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.paddingMD),
          itemBuilder: (context, index) => AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 200),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                curve: Curves.easeOut,
                child: RepaintBoundary(
                  child: OrderTile(
                    key: ValueKey(orders[index]['id']),
                    order: orders[index],
                    onTripsUpdated: onTripsUpdated,
                    onDeleted: onDeleted,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // For small lists, use Column for simplicity
    return AnimationLimiter(
      child: Column(
        children: [
          for (int i = 0; i < orders.length; i++)
            AnimationConfiguration.staggeredList(
              position: i,
              duration: const Duration(milliseconds: 200),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  curve: Curves.easeOut,
                  child: Column(
                    children: [
                      if (i > 0) const SizedBox(height: AppSpacing.paddingMD),
                      RepaintBoundary(
                        key: ValueKey(orders[i]['id']),
                        child: OrderTile(
                          order: orders[i],
                          onTripsUpdated: onTripsUpdated,
                          onDeleted: onDeleted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.9 + (0.1 * value),
            child: child,
          ),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.paddingXXL),
            decoration: const BoxDecoration(
              color: AppColors.cardBackgroundElevated,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inbox_outlined,
              size: 64,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.paddingXL),
          Text(
            'No Pending Orders',
            style: AppTypography.h3.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.paddingSM),
          Text(
            'All orders have been processed',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
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
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AuthColors.textDisabled,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select Customer Type',
                style: TextStyle(
                  color: AuthColors.textMain,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 20),
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
                    final recentClients = await clientsRepository.fetchRecentClients(limit: 1);
                    final createdClient = recentClients.isNotEmpty ? recentClients.first : null;
                    
                    if (context.mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CreateOrderPage(client: createdClient),
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
            const SizedBox(height: 12),
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AuthColors.legacyAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AuthColors.legacyAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AuthColors.textMain,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AuthColors.textSub,
                      fontSize: 13,
                    ),
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



