import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/data/repositories/scheduled_trips_repository.dart';
import 'package:dash_mobile/data/repositories/vehicles_repository.dart';
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/views/home_sections/orders_section_shared.dart';
import 'package:dash_mobile/presentation/views/orders/schedule_trip_detail_page.dart';
import 'package:dash_mobile/presentation/widgets/schedule_trip_modal.dart';
import 'package:dash_mobile/presentation/widgets/scheduled_trip_tile.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:dash_mobile/shared/constants/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class ScheduleOrdersView extends StatefulWidget {
  const ScheduleOrdersView({super.key});

  @override
  State<ScheduleOrdersView> createState() => _ScheduleOrdersViewState();
}

class _ScheduleOrdersViewState extends State<ScheduleOrdersView> {
  late DateTime _selectedDate;
  late ScrollController _scrollController;
  StreamSubscription<List<Map<String, dynamic>>>? _tripsSubscription;

  /// All trips for the selected date (unfiltered). Used for local vehicle filtering.
  List<Map<String, dynamic>> _allTripsForDate = [];
  List<Map<String, dynamic>> _scheduledTrips = [];
  bool _isLoadingTrips = true;
  String? _currentOrgId;
  DateTime? _currentDate; // Only re-subscribe when org or date actually changes
  List<Vehicle> _vehicles = [];
  final Set<String> _selectedVehicleIds = {};

  // Cached values — recomputed only when _scheduledTrips or _vehicles change
  int _cachedTotalTrips = 0;
  double _cachedTotalValue = 0.0;
  int _cachedTotalQuantity = 0;
  List<Vehicle> _cachedFilteredVehicles = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _scrollController = ScrollController();
    // Add listener to scroll to center when controller is ready
    _scrollController.addListener(() {});
    // Scroll to center after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCenter();
    });
    _loadVehicles();
    _subscribeToTrips();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tripsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    final orgContext = context.read<OrganizationContextCubit>().state;
    final organization = orgContext.organization;

    if (organization == null) {
      setState(() {
        _vehicles = [];
        _updateCachedValues();
      });
      return;
    }

    try {
      final vehiclesRepo = context.read<VehiclesRepository>();
      final allVehicles = await vehiclesRepo.fetchVehicles(organization.id);
      final activeVehicles = allVehicles.where((v) => v.isActive).toList();
      if (mounted) {
        setState(() {
          _vehicles = activeVehicles;
          _updateCachedValues();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _vehicles = [];
          _updateCachedValues();
        });
      }
    }
  }

  void _updateCachedValues() {
    _cachedTotalTrips = _scheduledTrips.length;
    _cachedTotalValue = _computeTotalValue(_scheduledTrips);
    _cachedTotalQuantity = _computeTotalQuantity(_scheduledTrips);
    _cachedFilteredVehicles = _computeFilteredVehicles();
  }

  void _subscribeToTrips() {
    final orgContext = context.read<OrganizationContextCubit>().state;
    final organization = orgContext.organization;

    if (organization == null) {
      setState(() {
        _isLoadingTrips = false;
        _allTripsForDate = [];
        _scheduledTrips = [];
        _updateCachedValues();
      });
      return;
    }

    final orgId = organization.id;
    final selectedDateOnly =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final sameOrg = _currentOrgId == orgId;
    final sameDate = _currentDate != null &&
        _currentDate!.year == _selectedDate.year &&
        _currentDate!.month == _selectedDate.month &&
        _currentDate!.day == _selectedDate.day;
    if (sameOrg && sameDate && _tripsSubscription != null) {
      return;
    }

    _currentOrgId = orgId;
    _currentDate = selectedDateOnly;
    final repository = context.read<ScheduledTripsRepository>();

    _tripsSubscription?.cancel();
    _tripsSubscription = repository
        .watchScheduledTripsForDate(
      organizationId: orgId,
      scheduledDate: _selectedDate,
    )
        .listen(
      (trips) {
        if (mounted) {
          setState(() {
            _allTripsForDate = trips;
            _scheduledTrips = _applyFilters(_allTripsForDate);
            _isLoadingTrips = false;
            _updateCachedValues();
          });
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() => _isLoadingTrips = false);
        }
      },
    );
  }

  void _onDateChanged(DateTime newDate) {
    setState(() {
      _selectedDate = newDate;
      _isLoadingTrips = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCenter();
    });
    _subscribeToTrips();
  }

  void _onVehicleFilterChanged(String? vehicleId) {
    setState(() {
      if (vehicleId == null) {
        _selectedVehicleIds.clear();
      } else if (_selectedVehicleIds.contains(vehicleId)) {
        _selectedVehicleIds.remove(vehicleId);
      } else {
        _selectedVehicleIds.add(vehicleId);
      }
      _scheduledTrips = _applyFilters(_allTripsForDate);
      _updateCachedValues();
    });
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> trips) {
    var filtered = trips;
    if (_selectedVehicleIds.isNotEmpty) {
      filtered = filtered
          .where((trip) {
            final vehicleId = trip['vehicleId'] as String?;
            return vehicleId != null && _selectedVehicleIds.contains(vehicleId);
          })
          .toList();
    }

    return filtered;
  }

  Future<void> _onReschedule(Map<String, dynamic> trip) async {
    // Show confirmation dialog with reason field
    final reasonController = TextEditingController();
    final confirmed = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AuthColors.surface,
            title: Text(
              'Reschedule Trip',
              style: AppTypography.withColor(
                  AppTypography.h3, AuthColors.textMain),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This will delete the current scheduled trip and allow you to reschedule it.',
                    style: AppTypography.withColor(
                        AppTypography.body, AuthColors.textSub),
                  ),
                  const SizedBox(height: AppSpacing.paddingLG),
                  TextField(
                    controller: reasonController,
                    style: AppTypography.withColor(
                        AppTypography.body, AuthColors.textMain),
                    decoration: InputDecoration(
                      labelText: 'Reason for rescheduling *',
                      labelStyle: AppTypography.withColor(
                          AppTypography.label, AuthColors.textSub),
                      hintText: 'Enter reason...',
                      hintStyle:
                          TextStyle(color: AuthColors.textMainWithOpacity(0.3)),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: AuthColors.textMainWithOpacity(0.3)),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSM),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: AuthColors.warning),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSM),
                      ),
                      filled: true,
                      fillColor: AuthColors.surface,
                    ),
                    maxLines: 3,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: reasonController.text.trim().isEmpty
                    ? null
                    : () => Navigator.of(context).pop({
                          'confirmed': true,
                          'reason': reasonController.text.trim(),
                        }),
                child: Text(
                  'Reschedule',
                  style: AppTypography.withColor(
                      AppTypography.buttonSmall, AuthColors.warning),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == null || confirmed['confirmed'] != true) {
      reasonController.dispose();
      return;
    }

    if (!mounted) {
      reasonController.dispose();
      return;
    }

    final rescheduleReason = confirmed['reason'] as String? ?? '';

    try {
      // Delete the existing scheduled trip
      final tripId = trip['id'] as String?;
      if (tripId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip ID not found')),
        );
        return;
      }

      final scheduledTripsRepo = context.read<ScheduledTripsRepository>();

      // Update trip with reschedule reason before deleting
      // This allows Cloud Functions to access it if needed for audit/logging
      await scheduledTripsRepo.updateTripRescheduleReason(
        tripId: tripId,
        reason: rescheduleReason,
      );

      if (!mounted) {
        return;
      }

      // Delete the trip - Cloud Functions will automatically update PENDING_ORDERS:
      // - Decrements totalScheduledTrips
      // - Increments estimatedTrips
      // - Removes trip from scheduledTrips array
      await scheduledTripsRepo.deleteScheduledTrip(tripId);

      if (!mounted) {
        return;
      }

      // Get order data from trip
      final orderId = trip['orderId'] as String?;
      final clientId = trip['clientId'] as String?;
      final clientName = trip['clientName'] as String? ?? 'N/A';
      final customerNumber =
          trip['customerNumber'] as String? ?? trip['clientPhone'] as String?;

      if (orderId == null || clientId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Order or client information not available')),
        );
        return;
      }

      // Fetch client phones
      final clientService = ClientService();
      List<Map<String, dynamic>> clientPhones = [];

      if (customerNumber != null && customerNumber.isNotEmpty) {
        try {
          final orgId = context
              .read<OrganizationContextCubit>()
              .state
              .organization
              ?.id;
          final client = await clientService.findClientByPhone(
            customerNumber,
            organizationId: orgId,
          );
          if (client != null) {
            clientPhones = client.phones;
            if (clientPhones.isEmpty && client.primaryPhone != null) {
              clientPhones.add({
                'number': client.primaryPhone,
                'normalized': client.primaryPhone,
              });
            }
          }
        } catch (e) {
          // If client lookup fails, use the customer number from trip
          clientPhones = [
            {
              'number': customerNumber,
              'normalized': customerNumber,
            }
          ];
        }
      }

      // Reconstruct order object from trip data
      final orderData = <String, dynamic>{
        'id': orderId,
        'clientId': clientId,
        'clientName': clientName,
        'clientPhone': customerNumber,
        'items': trip['items'] as List<dynamic>? ?? [],
        'deliveryZone': trip['deliveryZone'] as Map<String, dynamic>? ?? {},
        'pricing': trip['pricing'] as Map<String, dynamic>? ?? {},
        'priority': trip['priority'] as String? ?? 'normal',
      };

      if (!mounted) return;

      // Open schedule modal
      await showDialog(
        context: context,
        builder: (context) => ScheduleTripModal(
          order: orderData,
          clientId: clientId,
          clientName: clientName,
          clientPhones: clientPhones,
          onScheduled: () {
            _currentOrgId = null;
            _currentDate = null;
            _subscribeToTrips();
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reschedule trip: $e')),
        );
      }
    }
  }

  void _scrollToCenter() {
    if (!_scrollController.hasClients || !mounted) {
      // Retry after a short delay if controller is not ready
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && _scrollController.hasClients) {
          _scrollToCenter();
        }
      });
      return;
    }

    const itemWidth = 70.0; // Width of each date card (64 + 6 margin)
    final selectedIndex = _getDateIndex(_selectedDate);
    final screenWidth = MediaQuery.of(context).size.width;
    const padding = 12.0; // Horizontal padding of ListView

    // Calculate the position to center the selected item
    // Position of selected item - half screen width + half item width
    // Account for padding on the left
    final scrollPosition = (selectedIndex * itemWidth) -
        (screenWidth / 2) +
        (itemWidth / 2) +
        padding;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final clampedPosition = scrollPosition.clamp(0.0, maxScroll);

    // Only animate if the position is significantly different
    if ((_scrollController.offset - clampedPosition).abs() > 2.0) {
      _scrollController.animateTo(
        clampedPosition,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else if ((_scrollController.offset - clampedPosition).abs() > 0.1) {
      // Use jumpTo for small adjustments to avoid animation delay
      _scrollController.jumpTo(clampedPosition);
    }
  }

  int _getDateIndex(DateTime date) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final selectedDate = DateTime(date.year, date.month, date.day);
    return selectedDate.difference(todayDate).inDays +
        4; // Offset by 4 to center today
  }

  List<DateTime> _getDateRange() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final dates = <DateTime>[];

    // 4 days back, today, 4 days forward = 9 days total
    for (int i = -4; i <= 4; i++) {
      dates.add(todayDate.add(Duration(days: i)));
    }

    return dates;
  }

  String _getMonthAbbr(DateTime date) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ];
    return months[date.month - 1];
  }

  String _getDayAbbr(DateTime date) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[date.weekday - 1];
  }

  static double _computeTotalValue(List<Map<String, dynamic>> trips) {
    double total = 0.0;
    for (final trip in trips) {
      final tripPricing = trip['tripPricing'] as Map<String, dynamic>?;
      if (tripPricing != null) {
        total += (tripPricing['total'] as num?)?.toDouble() ?? 0.0;
      } else {
        final items = trip['items'] as List<dynamic>? ?? [];
        for (final item in items) {
          final itemMap = item as Map<String, dynamic>? ?? {};
          final unitPrice = (itemMap['unitPrice'] as num?)?.toDouble() ?? 0.0;
          final fixedQuantity = (itemMap['fixedQuantityPerTrip'] as int?) ?? 0;
          final gstPercent = (itemMap['gstPercent'] as num?)?.toDouble();
          final subtotal = unitPrice * fixedQuantity;
          final gstAmount =
              gstPercent != null ? subtotal * (gstPercent / 100) : 0.0;
          total += subtotal + gstAmount;
        }
      }
    }
    return total;
  }

  static int _computeTotalQuantity(List<Map<String, dynamic>> trips) {
    int total = 0;
    for (final trip in trips) {
      final items = trip['items'] as List<dynamic>? ?? [];
      for (final item in items) {
        final itemMap = item as Map<String, dynamic>? ?? {};
        total += (itemMap['fixedQuantityPerTrip'] as int?) ?? 0;
      }
    }
    return total;
  }

  List<Vehicle> _computeFilteredVehicles() {
    if (_allTripsForDate.isEmpty) return [];
    final vehicleIds = _allTripsForDate
        .map((trip) => trip['vehicleId'] as String?)
        .where((id) => id != null)
        .toSet()
        .toList();
    return _vehicles.where((v) => vehicleIds.contains(v.id)).toList();
  }

  String _formatCurrency(double value) {
    if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(1)}L';
    } else if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return '₹${value.toStringAsFixed(0)}';
    }
  }

  String _formatNumber(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return value.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dates = _getDateRange();

    return BlocListener<OrganizationContextCubit, OrganizationContextState>(
      listener: (context, state) {
        if (state.organization != null) {
          _currentOrgId = null;
          _currentDate = null;
          _loadVehicles();
          _subscribeToTrips();
        }
      },
      child: CustomScrollView(
        slivers: [
          // Summary — primary (burgundy) for main, secondary (gold) for high-priority
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.paddingSM),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.paddingMD),
                decoration: BoxDecoration(
                  color: AuthColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                  border: Border.all(
                    color: AuthColors.textMainWithOpacity(0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AuthColors.background.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.paddingMD),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: _SummaryItem(
                          value: '$_cachedTotalTrips',
                          color: AuthColors.primary,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        margin: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.paddingSM),
                        color: AuthColors.textMainWithOpacity(0.1),
                      ),
                      Expanded(
                        flex: 2,
                        child: _SummaryItem(
                          value: _formatCurrency(_cachedTotalValue),
                          color: AuthColors.secondary,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        margin: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.paddingSM),
                        color: AuthColors.textMainWithOpacity(0.1),
                      ),
                      Expanded(
                        flex: 1,
                        child: _SummaryItem(
                          value: _formatNumber(_cachedTotalQuantity),
                          color: AuthColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.paddingMD)),
          // Date picker
          SliverToBoxAdapter(
            child: SizedBox(
              height: 80,
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.paddingMD),
                itemCount: dates.length,
                itemBuilder: (context, index) {
                  final date = dates[index];
                  final isSelected = date.year == _selectedDate.year &&
                      date.month == _selectedDate.month &&
                      date.day == _selectedDate.day;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedDate = date);
                      _onDateChanged(date);
                      _scrollToCenter();
                    },
                    child: Container(
                      width: 64,
                      margin: const EdgeInsets.only(right: AppSpacing.gapSM),
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.paddingSM,
                          horizontal: AppSpacing.gapSM),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AuthColors.primary
                            : AuthColors.surface,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMD),
                        border: Border.all(
                          color: isSelected
                              ? AuthColors.primary
                              : AuthColors.textMainWithOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getMonthAbbr(date),
                            style: AppTypography.withColor(
                              AppTypography.withWeight(
                                  AppTypography.withSize(
                                      AppTypography.captionSmall, 9),
                                  FontWeight.w500),
                              isSelected
                                  ? AuthColors.textMain
                                  : AuthColors.textSub,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.paddingXS),
                          Text(
                            date.day.toString(),
                            style: AppTypography.withColor(
                              AppTypography.withWeight(
                                  AppTypography.h4, FontWeight.w700),
                              AuthColors.textMain,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.paddingXS),
                          Text(
                            _getDayAbbr(date),
                            style: AppTypography.withColor(
                              AppTypography.withWeight(
                                  AppTypography.withSize(
                                      AppTypography.captionSmall, 9),
                                  FontWeight.w500),
                              isSelected
                                  ? AuthColors.textMain
                                  : AuthColors.textSub,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.paddingMD)),
          // Vehicle filter
          SliverToBoxAdapter(
            child: SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.paddingMD),
                itemCount: _cachedFilteredVehicles.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding:
                          const EdgeInsets.only(right: AppSpacing.paddingSM),
                      child: _VehicleFilterButton(
                        label: 'All',
                        isSelected: _selectedVehicleIds.isEmpty,
                        onTap: () => _onVehicleFilterChanged(null),
                      ),
                    );
                  }
                  final vehicle = _cachedFilteredVehicles[index - 1];
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.paddingSM),
                    child: _VehicleFilterButton(
                      label: vehicle.vehicleNumber,
                      isSelected: _selectedVehicleIds.contains(vehicle.id),
                      onTap: () => _onVehicleFilterChanged(vehicle.id),
                    ),
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.paddingMD)),
          if (_isLoadingTrips)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: OrdersSectionLoadingState(),
            )
          else if (_scheduledTrips.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.paddingXL),
                child: OrdersSectionEmptyState(
                  title: 'No scheduled trips',
                  message: 'No scheduled trips for this date',
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final trip = _scheduledTrips[index];
                  final tile = Padding(
                    padding: const EdgeInsets.only(
                        bottom: AppSpacing.paddingMD,
                        left: AppSpacing.paddingLG,
                        right: AppSpacing.paddingLG),
                    child: ScheduledTripTile(
                      trip: trip,
                      onReschedule: () => _onReschedule(trip),
                      onOpenDetails: () async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ScheduleTripDetailPage(trip: trip),
                          ),
                        );
                        if (result == true) _subscribeToTrips();
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
                childCount: _scheduledTrips.length,
                addRepaintBoundaries: true,
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.value,
    required this.color,
  });

  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: AppTypography.withColor(
        AppTypography.withWeight(AppTypography.h4, FontWeight.w700)
            .copyWith(letterSpacing: 0.5),
        color,
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _VehicleFilterButton extends StatelessWidget {
  const _VehicleFilterButton({
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
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.paddingMD, vertical: AppSpacing.paddingSM),
        decoration: BoxDecoration(
          color: isSelected ? AuthColors.primary : AuthColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
          border: Border.all(
            color: isSelected
                ? AuthColors.primary
                : AuthColors.textMainWithOpacity(0.1),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.withColor(
            isSelected
                ? AppTypography.withWeight(
                    AppTypography.labelSmall, FontWeight.w600)
                : AppTypography.withWeight(
                    AppTypography.labelSmall, FontWeight.w500),
            isSelected ? AuthColors.textMain : AuthColors.textSub,
          ),
        ),
      ),
    );
  }
}
