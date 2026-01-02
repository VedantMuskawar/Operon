import 'package:core_datasources/core_datasources.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LinkTripsDialog extends StatefulWidget {
  final String transactionId;
  final String vehicleNumber;
  final String voucherNumber;
  final VoidCallback? onTripsLinked;

  const LinkTripsDialog({
    super.key,
    required this.transactionId,
    required this.vehicleNumber,
    required this.voucherNumber,
    this.onTripsLinked,
  });

  @override
  State<LinkTripsDialog> createState() => _LinkTripsDialogState();
}

class _LinkTripsDialogState extends State<LinkTripsDialog> {
  List<Map<String, dynamic>> _availableTrips = [];
  Set<String> _selectedDmIds = {};
  bool _isLoading = true;
  bool _isLinking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAvailableTrips();
  }

  Future<void> _loadAvailableTrips() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final orgState = context.read<OrganizationContextCubit>().state;
      final organization = orgState.organization;
      
      if (organization == null) {
        setState(() {
          _error = 'No organization selected';
          _isLoading = false;
        });
        return;
      }

      final repository = DeliveryMemoRepository();
      final trips = await repository.getReturnedDMsForVehicle(
        organizationId: organization.id,
        vehicleNumber: widget.vehicleNumber,
      );

      setState(() {
        _availableTrips = trips;
        _isLoading = false;
      });
    } catch (e) {
      String errorMessage = 'Failed to load trips: $e';
      
      // Check if it's an index error and provide helpful message
      final errorStr = e.toString();
      if (errorStr.contains('index') || errorStr.contains('failed-precondition')) {
        errorMessage = 'A database index is required for this query. '
            'Please contact your administrator to create the required index, '
            'or try again later.';
      }
      
      setState(() {
        _error = errorMessage;
        _isLoading = false;
      });
    }
  }

  double _getDistanceKm(Map<String, dynamic> trip) {
    final deliveryZone = trip['deliveryZone'] as Map<String, dynamic>?;
    if (deliveryZone == null) return 0.0;
    final roundtripKm = deliveryZone['roundtrip_km'];
    if (roundtripKm is num) {
      return roundtripKm.toDouble();
    }
    return 0.0;
  }

  double _getTotalDistance() {
    double total = 0.0;
    for (final dmId in _selectedDmIds) {
      final trip = _availableTrips.firstWhere((t) => t['dmId'] == dmId);
      total += _getDistanceKm(trip);
    }
    return total;
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    DateTime dateTime;
    if (date is Timestamp) {
      dateTime = date.toDate();
    } else if (date is Map && date['_seconds'] != null) {
      dateTime = DateTime.fromMillisecondsSinceEpoch(
        (date['_seconds'] as int) * 1000,
      );
    } else {
      return 'N/A';
    }
    
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = months[dateTime.month - 1];
    final year = dateTime.year;
    return '$day $month $year';
  }

  Future<void> _linkTrips() async {
    if (_selectedDmIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one trip')),
      );
      return;
    }

    setState(() => _isLinking = true);

    try {
      final orgState = context.read<OrganizationContextCubit>().state;
      final organization = orgState.organization;
      
      if (organization == null) {
        throw Exception('No organization selected');
      }

      final repository = DeliveryMemoRepository();
      
      // Update all selected DMs with fuelVoucherId
      await repository.updateMultipleDMsWithFuelVoucher(
        dmIds: _selectedDmIds.toList(),
        fuelVoucherId: widget.transactionId,
      );

      // Build trip details for transaction metadata
      final tripDetails = _selectedDmIds.map((dmId) {
        final trip = _availableTrips.firstWhere((t) => t['dmId'] == dmId);
        final deliveryZone = trip['deliveryZone'] as Map<String, dynamic>? ?? {};
        
        return {
          'dmId': dmId,
          'tripId': trip['tripId'] as String? ?? '',
          'scheduleTripId': trip['scheduleTripId'] as String? ?? '',
          'vehicleNumber': trip['vehicleNumber'] as String? ?? widget.vehicleNumber,
          'scheduledDate': trip['scheduledDate'],
          'distanceKm': _getDistanceKm(trip),
          'clientName': trip['clientName'] as String? ?? 'Unknown',
          'deliveryZone': {
            'city': deliveryZone['city_name'] as String? ?? deliveryZone['city'] as String? ?? '',
            'region': deliveryZone['region'] as String? ?? '',
          },
        };
      }).toList();

      // Update transaction metadata with linked trips
      await FirebaseFirestore.instance
          .collection('TRANSACTIONS')
          .doc(widget.transactionId)
          .update({
            'metadata.linkedTrips': tripDetails,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trips linked successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
        widget.onTripsLinked?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to link trips: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLinking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF11111B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6F4BFF).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.link,
                      color: Color(0xFF6F4BFF),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Link Trips to Voucher',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Voucher: ${widget.voucherNumber}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Vehicle: ${widget.vehicleNumber}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _error!,
                                  style: const TextStyle(color: Colors.red),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadAvailableTrips,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _availableTrips.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.directions_car_outlined,
                                      size: 64,
                                      color: Colors.white.withValues(alpha: 0.3),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No trips found',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No returned trips found for this vehicle in the past 3 days',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.4),
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              itemCount: _availableTrips.length,
                              itemBuilder: (context, index) {
                                final trip = _availableTrips[index];
                                final dmId = trip['dmId'] as String;
                                final isSelected = _selectedDmIds.contains(dmId);
                                final hasFuelVoucher = trip['fuelVoucherId'] != null;
                                final clientName = trip['clientName'] as String? ?? 'Unknown';
                                final deliveryZone = trip['deliveryZone'] as Map<String, dynamic>? ?? {};
                                final city = deliveryZone['city_name'] as String? ?? deliveryZone['city'] as String? ?? '';
                                final region = deliveryZone['region'] as String? ?? '';
                                final distance = _getDistanceKm(trip);
                                final scheduledDate = trip['scheduledDate'];

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF6F4BFF).withValues(alpha: 0.2)
                                        : hasFuelVoucher
                                            ? Colors.orange.withValues(alpha: 0.1)
                                            : const Color(0xFF13131E),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF6F4BFF)
                                          : hasFuelVoucher
                                              ? Colors.orange.withValues(alpha: 0.5)
                                              : Colors.white.withValues(alpha: 0.1),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: CheckboxListTile(
                                    value: isSelected,
                                    onChanged: hasFuelVoucher
                                        ? null // Disable selection if already has fuel voucher
                                        : (value) {
                                            setState(() {
                                              if (value == true) {
                                                _selectedDmIds.add(dmId);
                                              } else {
                                                _selectedDmIds.remove(dmId);
                                              }
                                            });
                                          },
                                    activeColor: const Color(0xFF6F4BFF),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            clientName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        if (hasFuelVoucher)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                                            ),
                                            child: const Text(
                                              'Linked',
                                              style: TextStyle(
                                                color: Colors.orange,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.calendar_today, size: 12, color: Colors.white.withValues(alpha: 0.6)),
                                            const SizedBox(width: 4),
                                            Text(
                                              _formatDate(scheduledDate),
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.6),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.location_on, size: 12, color: Colors.white.withValues(alpha: 0.6)),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                '$city${region.isNotEmpty ? ', $region' : ''}',
                                                style: TextStyle(
                                                  color: Colors.white.withValues(alpha: 0.6),
                                                  fontSize: 12,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (distance > 0) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.straighten, size: 12, color: Colors.white.withValues(alpha: 0.6)),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${distance.toStringAsFixed(1)} KM',
                                                style: TextStyle(
                                                  color: Colors.white.withValues(alpha: 0.6),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
            
            // Summary and Actions
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B2C),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedDmIds.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_selectedDmIds.length} trip${_selectedDmIds.length > 1 ? 's' : ''} selected',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Total Distance: ${_getTotalDistance().toStringAsFixed(1)} KM',
                          style: const TextStyle(
                            color: Color(0xFF6F4BFF),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isLinking ? null : () => Navigator.of(context).pop(),
                        child: Text(
                          'Skip',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_selectedDmIds.isEmpty)
                        TextButton(
                          onPressed: _isLinking ? null : () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF6F4BFF),
                          ),
                          child: const Text('Continue Without Linking'),
                        )
                      else
                        ElevatedButton(
                          onPressed: _isLinking ? null : _linkTrips,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6F4BFF),
                            foregroundColor: Colors.white,
                          ),
                          child: _isLinking
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text('Link ${_selectedDmIds.length} Trip${_selectedDmIds.length > 1 ? 's' : ''}'),
                        ),
                    ],
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

