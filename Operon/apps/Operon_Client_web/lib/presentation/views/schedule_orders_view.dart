import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/repositories/scheduled_trips_repository.dart';
import 'package:dash_web/data/repositories/vehicles_repository.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/widgets/scheduled_trip_tile.dart';
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
  List<Map<String, dynamic>> _allTripsForDate = [];
  List<Map<String, dynamic>> _scheduledTrips = [];
  bool _isLoadingTrips = true;
  String? _currentOrgId;
  List<Vehicle> _vehicles = [];
  String? _selectedVehicleId;
  String? _vehiclesOrgId;
  int _totalTrips = 0;
  double _totalValue = 0.0;
  int _totalQuantity = 0;
  int _totalVehicles = 0;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCenter();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orgContext = context.read<OrganizationContextCubit>().state;
    if (orgContext.organization != null && _currentOrgId == null) {
      _loadVehicles();
      _subscribeToTrips();
    }
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
        _vehiclesOrgId = null;
      });
      return;
    }

    if (_vehiclesOrgId == organization.id && _vehicles.isNotEmpty) {
      return;
    }

    _vehiclesOrgId = organization.id;

    try {
      final vehiclesRepo = context.read<VehiclesRepository>();
      final allVehicles = await vehiclesRepo.fetchVehicles(organization.id);
      if (!mounted) return;
      final activeVehicles = allVehicles.where((v) => v.isActive).toList();

      setState(() {
        _vehicles = activeVehicles;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _vehicles = [];
        });
      }
    }
  }

  void _subscribeToTrips() {
    final orgContext = context.read<OrganizationContextCubit>().state;
    final organization = orgContext.organization;

    if (organization == null) {
      setState(() {
        _isLoadingTrips = false;
        _scheduledTrips = [];
      });
      return;
    }

    final orgId = organization.id;
    if (_currentOrgId == orgId && _tripsSubscription != null) {
      return;
    }

    _currentOrgId = orgId;
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
          final filteredTrips = _applyFilters(trips);
          final summary = _buildSummary(filteredTrips);
          setState(() {
            _allTripsForDate = trips;
            _scheduledTrips = filteredTrips;
            _isLoadingTrips = false;
            _totalTrips = summary.totalTrips;
            _totalValue = summary.totalValue;
            _totalQuantity = summary.totalQuantity;
            _totalVehicles = summary.totalVehicles;
          });
        }
      },
      onError: (error) {
        debugPrint('ScheduleOrdersView: Error loading trips: $error');
        if (mounted) {
          setState(() {
            _isLoadingTrips = false;
            _scheduledTrips = [];
          });
          DashSnackbar.show(
            context,
            message: 'Error loading scheduled trips: $error',
            isError: true,
          );
        }
      },
    );
  }

  void _onDateChanged(DateTime newDate) {
    setState(() {
      _selectedDate = newDate;
      _isLoadingTrips = true;
      _currentOrgId = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCenter();
    });
    _subscribeToTrips();
  }

  void _onVehicleFilterChanged(String? vehicleId) {
    setState(() {
      _selectedVehicleId = vehicleId;
      _scheduledTrips = _applyFilters(_allTripsForDate);
      final summary = _buildSummary(_scheduledTrips);
      _totalTrips = summary.totalTrips;
      _totalValue = summary.totalValue;
      _totalQuantity = summary.totalQuantity;
      _totalVehicles = summary.totalVehicles;
    });
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> trips) {
    var filtered = trips;
    if (_selectedVehicleId != null) {
      filtered = filtered.where((trip) {
        final vehicleId = trip['vehicleId'] as String?;
        return vehicleId == _selectedVehicleId;
      }).toList();
    }

    return filtered;
  }

  _TripSummary _buildSummary(List<Map<String, dynamic>> trips) {
    double totalValue = 0.0;
    int totalQuantity = 0;
    final vehicleIds = <String>{};

    for (final trip in trips) {
      final tripPricing = trip['tripPricing'] as Map<String, dynamic>?;
      if (tripPricing != null) {
        final tripTotal = (tripPricing['total'] as num?)?.toDouble() ?? 0.0;
        totalValue += tripTotal;
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
          totalValue += subtotal + gstAmount;
          totalQuantity += fixedQuantity;
        }
      }

      final vehicleId = trip['vehicleId'] as String?;
      if (vehicleId != null) {
        vehicleIds.add(vehicleId);
      }
    }

    return _TripSummary(
      totalTrips: trips.length,
      totalValue: totalValue,
      totalQuantity: totalQuantity,
      totalVehicles: vehicleIds.length,
    );
  }

  int _getTotalTrips() => _totalTrips;

  double _getTotalValue() => _totalValue;

  int _getTotalQuantity() => _totalQuantity;

  int _getTotalVehicles() => _totalVehicles;

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

  List<Vehicle> _getFilteredVehicles() {
    if (_scheduledTrips.isEmpty) {
      return [];
    }
    final vehicleIds = _scheduledTrips
        .map((trip) => trip['vehicleId'] as String?)
        .where((id) => id != null)
        .toSet()
        .toList();
    return _vehicles
        .where((vehicle) => vehicleIds.contains(vehicle.id))
        .toList();
  }

  void _scrollToCenter() {
    if (!_scrollController.hasClients || !mounted) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && _scrollController.hasClients) {
          _scrollToCenter();
        }
      });
      return;
    }

    const itemWidth = 70.0;
    final selectedIndex = _getDateIndex(_selectedDate);
    final screenWidth = MediaQuery.of(context).size.width;
    const padding = 12.0;

    final scrollPosition = (selectedIndex * itemWidth) -
        (screenWidth / 2) +
        (itemWidth / 2) +
        padding;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final clampedPosition = scrollPosition.clamp(0.0, maxScroll);

    if ((_scrollController.offset - clampedPosition).abs() > 2.0) {
      _scrollController.animateTo(
        clampedPosition,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else if ((_scrollController.offset - clampedPosition).abs() > 0.1) {
      _scrollController.jumpTo(clampedPosition);
    }
  }

  int _getDateIndex(DateTime date) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final selectedDate = DateTime(date.year, date.month, date.day);
    return selectedDate.difference(todayDate).inDays + 4;
  }

  List<DateTime> _getDateRange() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final dates = <DateTime>[];
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dateRange = _getDateRange();
    final datePickerWidth = dateRange.length * 76; // 70 width + 6 margin
    final availableWidth = screenWidth * 0.8;
    final horizontalPadding = datePickerWidth < availableWidth
        ? (availableWidth - datePickerWidth) / 2
        : 12.0;

    return BlocListener<OrganizationContextCubit, OrganizationContextState>(
      listener: (context, state) {
        if (state.organization != null) {
          _currentOrgId = null;
          _loadVehicles();
          _subscribeToTrips();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Date Picker - Centered on page
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                height: 90,
                width: screenWidth * 0.8,
                child: ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  itemCount: dateRange.length,
                  itemBuilder: (context, index) {
                    final date = dateRange[index];
                    final isSelected = date.year == _selectedDate.year &&
                        date.month == _selectedDate.month &&
                        date.day == _selectedDate.day;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDate = date;
                        });
                        _onDateChanged(date);
                        _scrollToCenter();
                      },
                      child: Container(
                        width: 70,
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AuthColors.primary
                              : AuthColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AuthColors.primary
                                : AuthColors.textMain.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _getMonthAbbr(date),
                              style: TextStyle(
                                color: isSelected
                                    ? AuthColors.textMain
                                    : AuthColors.textSub,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              date.day.toString(),
                              style: const TextStyle(
                                color: AuthColors.textMain,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getDayAbbr(date),
                              style: TextStyle(
                                color: isSelected
                                    ? AuthColors.textMain
                                    : AuthColors.textSub,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
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
          ),

          const SizedBox(height: 12),

          // Summary Statistics - Compact
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AuthColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AuthColors.textMain.withValues(alpha: 0.1),
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
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _CompactSummaryItem(
                        value: _getTotalTrips().toString(),
                        color: AuthColors.primary,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: AuthColors.textMain.withValues(alpha: 0.1),
                    ),
                    Expanded(
                      flex: 2,
                      child: _CompactSummaryItem(
                        value: _formatCurrency(_getTotalValue()),
                        color: AuthColors.success,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: AuthColors.textMain.withValues(alpha: 0.1),
                    ),
                    Expanded(
                      flex: 1,
                      child: _CompactSummaryItem(
                        value: _formatNumber(_getTotalQuantity()),
                        color: AuthColors.warning,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: AuthColors.textMain.withValues(alpha: 0.1),
                    ),
                    Expanded(
                      flex: 1,
                      child: _CompactSummaryItem(
                        value: _getTotalVehicles().toString(),
                        color: AuthColors.info,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Vehicle Filter - Horizontal Scrollable Buttons
          SizedBox(
            height: 40,
            child: Builder(
              builder: (context) {
                final filteredVehicles = _getFilteredVehicles();
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filteredVehicles.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _VehicleFilterButton(
                          label: 'All',
                          isSelected: _selectedVehicleId == null,
                          onTap: () => _onVehicleFilterChanged(null),
                        ),
                      );
                    } else {
                      final vehicle = filteredVehicles[index - 1];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _VehicleFilterButton(
                          label: vehicle.vehicleNumber,
                          isSelected: _selectedVehicleId == vehicle.id,
                          onTap: () => _onVehicleFilterChanged(vehicle.id),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Scheduled Trips Grid (with expandable location tracking)
          if (_isLoadingTrips)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(
                  color: AuthColors.primary,
                ),
              ),
            )
          else if (_scheduledTrips.isEmpty)
            EmptyState(
              icon: Icons.schedule_outlined,
              title: 'No Scheduled Trips',
              message:
                  'No trips scheduled for ${_getDayAbbr(_selectedDate)}, ${_selectedDate.day} ${_getMonthAbbr(_selectedDate)}. Try selecting a different date.',
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const crossAxisCount = 5;
                  const crossAxisSpacing = 20.0;
                  const mainAxisSpacing = 20.0;
                  final contentWidth = constraints.maxWidth;
                  final tileWidth =
                      (contentWidth - crossAxisSpacing * (crossAxisCount - 1)) /
                          crossAxisCount;
                  final rowCount =
                      (_scheduledTrips.length / crossAxisCount).ceil();

                  return AnimationLimiter(
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: rowCount,
                      itemBuilder: (context, rowIndex) {
                        final start = rowIndex * crossAxisCount;
                        final end = (start + crossAxisCount)
                            .clamp(0, _scheduledTrips.length);
                        final rowTrips = _scheduledTrips.sublist(start, end);

                        return Padding(
                          padding: EdgeInsets.only(
                            bottom:
                                rowIndex < rowCount - 1 ? mainAxisSpacing : 0,
                          ),
                          child: AnimationConfiguration.staggeredList(
                            position: rowIndex,
                            duration: const Duration(milliseconds: 200),
                            child: SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(
                                curve: Curves.easeOut,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: List.generate(
                                      crossAxisCount * 2 - 1, (i) {
                                    if (i.isOdd) {
                                      return const SizedBox(
                                          width: crossAxisSpacing);
                                    }
                                    final tileIndex = i ~/ 2;
                                    if (tileIndex >= rowTrips.length) {
                                      return SizedBox(width: tileWidth);
                                    }
                                    final trip = rowTrips[tileIndex];
                                    return SizedBox(
                                      width: tileWidth,
                                      child: Align(
                                        alignment: Alignment.topCenter,
                                        child: ScheduledTripTile(
                                          trip: trip,
                                          onTripsUpdated: () {
                                            _currentOrgId = null;
                                            _subscribeToTrips();
                                          },
                                          onTap: () {
                                            DashSnackbar.show(
                                              context,
                                              message:
                                                  'Trip detail view coming soon',
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _CompactSummaryItem extends StatelessWidget {
  const _CompactSummaryItem({
    required this.value,
    required this.color,
  });

  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: TextStyle(
        color: color,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AuthColors.primary : AuthColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AuthColors.primary
                : AuthColors.textMain.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AuthColors.textMain : AuthColors.textSub,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TripSummary {
  const _TripSummary({
    required this.totalTrips,
    required this.totalValue,
    required this.totalQuantity,
    required this.totalVehicles,
  });

  final int totalTrips;
  final double totalValue;
  final int totalQuantity;
  final int totalVehicles;
}
