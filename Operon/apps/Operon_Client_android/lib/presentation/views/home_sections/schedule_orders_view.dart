import 'dart:async';

import 'package:dash_mobile/data/repositories/scheduled_trips_repository.dart';
import 'package:dash_mobile/data/repositories/vehicles_repository.dart';
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/domain/entities/vehicle.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/views/orders/schedule_trip_detail_page.dart';
import 'package:dash_mobile/presentation/widgets/schedule_trip_modal.dart';
import 'package:dash_mobile/presentation/widgets/scheduled_trip_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ScheduleOrdersView extends StatefulWidget {
  const ScheduleOrdersView({super.key});

  @override
  State<ScheduleOrdersView> createState() => _ScheduleOrdersViewState();
}

class _ScheduleOrdersViewState extends State<ScheduleOrdersView> {
  late DateTime _selectedDate;
  late ScrollController _scrollController;
  StreamSubscription<List<Map<String, dynamic>>>? _tripsSubscription;
  List<Map<String, dynamic>> _scheduledTrips = [];
  bool _isLoadingTrips = true;
  String? _currentOrgId;
  List<Vehicle> _vehicles = [];
  String? _selectedVehicleId;

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
        });
      }
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
          setState(() {
            // Check if selected vehicle still has trips, if not reset selection
            if (_selectedVehicleId != null) {
              final hasTripsForVehicle = trips.any((trip) {
                final vehicleId = trip['vehicleId'] as String?;
                return vehicleId == _selectedVehicleId;
              });
              if (!hasTripsForVehicle) {
                _selectedVehicleId = null;
              }
            }

            // Filter by vehicle if selected
            var filteredTrips = trips;
            if (_selectedVehicleId != null) {
              filteredTrips = trips.where((trip) {
                final vehicleId = trip['vehicleId'] as String?;
                return vehicleId == _selectedVehicleId;
              }).toList();
            }
            _scheduledTrips = filteredTrips;
            _isLoadingTrips = false;
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
      _currentOrgId = null; // Force resubscription
    });
    // Scroll to center after state update
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCenter();
    });
    _subscribeToTrips();
  }

  void _onVehicleFilterChanged(String? vehicleId) {
    setState(() {
      _selectedVehicleId = vehicleId;
    });
    // Re-filter existing trips
    _subscribeToTrips();
  }

  Future<void> _onReschedule(Map<String, dynamic> trip) async {
    // Show confirmation dialog with reason field
    final reasonController = TextEditingController();
    final confirmed = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF11111B),
            title: const Text(
              'Reschedule Trip',
              style: TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This will delete the current scheduled trip and allow you to reschedule it.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Reason for rescheduling *',
                      labelStyle: const TextStyle(color: Colors.white60),
                      hintText: 'Enter reason...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.orange),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1A1A2E),
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
                child: const Text(
                  'Reschedule',
                  style: TextStyle(color: Colors.orange),
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
      
      // Delete the trip - Cloud Functions will automatically update PENDING_ORDERS:
      // - Decrements totalScheduledTrips
      // - Increments estimatedTrips
      // - Removes trip from scheduledTrips array
      await scheduledTripsRepo.deleteScheduledTrip(tripId);

      // Get order data from trip
      final orderId = trip['orderId'] as String?;
      final clientId = trip['clientId'] as String?;
      final clientName = trip['clientName'] as String? ?? 'N/A';
      final customerNumber = trip['customerNumber'] as String? ?? trip['clientPhone'] as String?;

      if (orderId == null || clientId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order or client information not available')),
        );
        return;
      }

      // Fetch client phones
      final clientService = ClientService();
      List<Map<String, dynamic>> clientPhones = [];
      
      if (customerNumber != null && customerNumber.isNotEmpty) {
        try {
          final client = await clientService.findClientByPhone(customerNumber);
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
            // Refresh trips list
            _currentOrgId = null;
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
    return selectedDate.difference(todayDate).inDays + 4; // Offset by 4 to center today
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
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return months[date.month - 1];
  }

  String _getDayAbbr(DateTime date) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[date.weekday - 1];
  }

  // Calculate summary statistics from scheduled trips
  int _getTotalTrips() {
    return _scheduledTrips.length;
  }

  double _getTotalValue() {
    double total = 0.0;
    for (final trip in _scheduledTrips) {
      // Use tripPricing if available (calculated based on fixedQuantityPerTrip with GST)
      final tripPricing = trip['tripPricing'] as Map<String, dynamic>?;
      if (tripPricing != null) {
        final tripTotal = (tripPricing['total'] as num?)?.toDouble() ?? 0.0;
        total += tripTotal;
      } else {
        // Fallback: calculate from items if tripPricing is not available
        final items = trip['items'] as List<dynamic>? ?? [];
        for (final item in items) {
          final itemMap = item as Map<String, dynamic>? ?? {};
          final unitPrice = (itemMap['unitPrice'] as num?)?.toDouble() ?? 0.0;
          final fixedQuantity = (itemMap['fixedQuantityPerTrip'] as int?) ?? 0;
          final gstPercent = (itemMap['gstPercent'] as num?)?.toDouble();
          
          final subtotal = unitPrice * fixedQuantity;
          final gstAmount = gstPercent != null ? subtotal * (gstPercent / 100) : 0.0;
          total += subtotal + gstAmount;
        }
      }
    }
    return total;
  }

  int _getTotalQuantity() {
    int total = 0;
    for (final trip in _scheduledTrips) {
      final items = trip['items'] as List<dynamic>? ?? [];
      for (final item in items) {
        final itemMap = item as Map<String, dynamic>? ?? {};
        final fixedQuantity = (itemMap['fixedQuantityPerTrip'] as int?) ?? 0;
        total += fixedQuantity;
      }
    }
    return total;
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

  // Get vehicles that have scheduled trips for the selected date
  List<Vehicle> _getFilteredVehicles() {
    if (_scheduledTrips.isEmpty) {
      return [];
    }

    // Extract unique vehicle IDs from scheduled trips
    final vehicleIds = _scheduledTrips
        .map((trip) => trip['vehicleId'] as String?)
        .where((id) => id != null)
        .toSet()
        .toList();

    // Filter vehicles to only include those with trips
    return _vehicles.where((vehicle) => vehicleIds.contains(vehicle.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final dates = _getDateRange();
    
    return BlocListener<OrganizationContextCubit, OrganizationContextState>(
      listener: (context, state) {
        if (state.organization != null) {
          _currentOrgId = null;
          _loadVehicles();
          _subscribeToTrips();
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        // Summary Cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF131324),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
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
                    child: _SummaryItem(
                      value: '${_getTotalTrips()}',
                      color: const Color(0xFF6F4BFF),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: Colors.white.withOpacity(0.1),
                  ),
                  Expanded(
                    flex: 2,
                    child: _SummaryItem(
                      value: _formatCurrency(_getTotalValue()),
                      color: const Color(0xFF4CAF50),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: Colors.white.withOpacity(0.1),
                  ),
                  Expanded(
                    flex: 1,
                    child: _SummaryItem(
                      value: _formatNumber(_getTotalQuantity()),
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Horizontal Date Picker
        SizedBox(
          height: 80,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: dates.length,
            itemBuilder: (context, index) {
              final date = dates[index];
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
                  width: 64,
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF6F4BFF)
                        : const Color(0xFF13131E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF6F4BFF)
                          : Colors.white.withOpacity(0.1),
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
                              ? Colors.white
                              : Colors.white60,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        date.day.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _getDayAbbr(date),
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Colors.white60,
                          fontSize: 9,
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
        const SizedBox(height: 12),
        // Vehicle Filter - Horizontal Scrollable Buttons
        SizedBox(
          height: 40,
          child: Builder(
            builder: (context) {
              final filteredVehicles = _getFilteredVehicles();
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: filteredVehicles.length + 1, // +1 for "All" option
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // "All Vehicles" option
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _VehicleFilterButton(
                        label: 'All',
                        isSelected: _selectedVehicleId == null,
                        onTap: () => _onVehicleFilterChanged(null),
                      ),
                    );
                  } else {
                    // Vehicle options
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
        const SizedBox(height: 12),
        // Scheduled Trips List
        if (_isLoadingTrips)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_scheduledTrips.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No scheduled trips for this date',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: _scheduledTrips.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ScheduledTripTile(
                  trip: _scheduledTrips[index],
                  onReschedule: () => _onReschedule(_scheduledTrips[index]),
                  onOpenDetails: () async {
                    final trip = _scheduledTrips[index];
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ScheduleTripDetailPage(trip: trip),
                      ),
                    );
                    if (result == true) {
                      // Refresh trips after detail actions
                      _subscribeToTrips();
                    }
                  },
                ),
              );
            },
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
          color: isSelected
              ? const Color(0xFF6F4BFF)
              : const Color(0xFF13131E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6F4BFF)
                : Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

