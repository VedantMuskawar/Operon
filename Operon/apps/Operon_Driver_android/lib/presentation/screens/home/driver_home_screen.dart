import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart' hide LatLng;
import 'package:core_ui/core_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:operon_auth_flow/operon_auth_flow.dart';
import 'package:operon_driver_android/core/services/location_service.dart';
import 'package:operon_driver_android/core/services/storage_service.dart';
import 'package:operon_driver_android/core/utils/message_utils.dart';
import 'package:operon_driver_android/core/utils/permission_utils.dart';
import 'package:operon_driver_android/core/utils/trip_status_utils.dart';
import 'package:operon_driver_android/presentation/blocs/trip/trip_bloc.dart';
import 'package:operon_driver_android/presentation/widgets/trip_execution_sheet.dart';
import 'package:operon_driver_android/presentation/widgets/driver_map.dart';
import 'package:operon_driver_android/presentation/widgets/hud_overlay.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  bool _isRequestingPermissions = true;
  bool _permissionsGranted = false;

  Map<String, dynamic>? _selectedTrip;
  int? _deliveryPointIndex;
  List<LatLng>? _historicalPath;
  int? _historicalDeliveryIndex;
  int _currentPathLength = 0;

  // HUD data
  Duration? _eta;
  double? _distance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestPermissions());
  }

  @override
  void dispose() {
    super.dispose();
  }


  Future<void> _requestPermissions() async {
    setState(() => _isRequestingPermissions = true);
    final ok = await PermissionUtils.requestDriverPermissions(context);
    if (!mounted) return;
    setState(() {
      _permissionsGranted = ok;
      _isRequestingPermissions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    final user = authState.userProfile;

    final locationService = context.read<LocationService>();
    final scheduledTripsRepo = context.read<ScheduledTripsRepository>();

    // Determine if we should show path based on trip status
    final tripStatus = _selectedTrip != null ? getTripStatus(_selectedTrip!) : null;
    final showPath = tripStatus == 'dispatched' ||
        tripStatus == 'delivered' ||
        tripStatus == 'returned';
    final isReturned = tripStatus == 'returned';

    // For returned trips, fetch history if not already loaded
    if (isReturned && _historicalPath == null && _selectedTrip != null) {
      final tripId = _selectedTrip!['id']?.toString();
      if (tripId != null && tripId.isNotEmpty) {
        _ensureHistoryLoaded(tripId, tripStatus);
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DriverMap(
              locationService: locationService,
              myLocationEnabled: _permissionsGranted,
              myLocationButtonEnabled: _permissionsGranted,
              showPath: showPath,
              deliveryPointIndex: isReturned
                  ? _historicalDeliveryIndex
                  : _deliveryPointIndex,
              historicalPath: isReturned ? _historicalPath : null,
              tripId: _selectedTrip?['id']?.toString(),
              onPathLengthChanged: (length) {
                _currentPathLength = length;
              },
            ),
          ),
          // HUD Overlay - Always render StreamBuilder to avoid disposal issues
          // StreamBuilder must always be in tree to properly manage subscription lifecycle
          // Use stable stream reference to avoid subscription lifecycle issues
          StreamBuilder<DriverLocation>(
            key: const ValueKey('location_stream'),
            stream: locationService.currentLocationStream, // Always use same stream reference
            builder: (context, snapshot) {
              // Early return if widget is disposed - check before any context usage
              if (!mounted || !context.mounted) {
                return const SizedBox.shrink();
              }
              
              // Don't show if permissions not granted
              if (!_permissionsGranted) {
                return const SizedBox.shrink();
              }
              
              // Read trip status directly from state, not from closure
              final currentTripStatus = _selectedTrip != null ? getTripStatus(_selectedTrip!) : null;
              
              // Only show HUD when trip is dispatched
              if (currentTripStatus != 'dispatched') {
                return const SizedBox.shrink();
              }
              
              // Handle errors gracefully
              if (snapshot.hasError) {
                debugPrint('[DriverHomeScreen] Location stream error: ${snapshot.error}');
                return const SizedBox.shrink();
              }
              
              // Double-check mounted before accessing data
              if (!mounted || !context.mounted) {
                return const SizedBox.shrink();
              }
              
              final location = snapshot.data;
              final speed = location?.speed;
              // Convert m/s to km/h
              final speedKmh = speed != null ? speed * 3.6 : null;

              // Final mounted check before building widget
              if (!mounted || !context.mounted) {
                return const SizedBox.shrink();
              }

              return HudOverlay(
                speed: speedKmh,
                eta: _eta,
                distance: _distance,
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Align(
                alignment: Alignment.topCenter,
                child: _TopStatusBar(
                  isRequestingPermissions: _isRequestingPermissions,
                  permissionsGranted: _permissionsGranted,
                  onTapGrant: _requestPermissions,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: BlocBuilder<TripBloc, TripState>(
                  buildWhen: (previous, current) {
                    // Only rebuild if relevant state changes
                    final shouldRebuild = previous.isTracking != current.isTracking ||
                        previous.activeTrip?.id != current.activeTrip?.id ||
                        previous.status != current.status;
                    return shouldRebuild;
                  },
                  builder: (context, tripState) {
                    // Guard against using context after disposal
                    if (!mounted || !context.mounted) {
                      return const SizedBox.shrink();
                    }
                    return _ControlPanel(
                      tripState: tripState,
                      organization: organization,
                      user: user,
                      scheduledTripsRepo: scheduledTripsRepo,
                      selectedTrip: _selectedTrip,
                      onSelectTrip: (t) {
                        if (!mounted) return;
                        setState(() {
                          final oldTripId = _selectedTrip?['id']?.toString();
                          final newTripId = t['id']?.toString();
                          _selectedTrip = t;
                          // Reset state when trip changes
                          if (oldTripId != newTripId) {
                            _deliveryPointIndex = null;
                            _historicalPath = null;
                            _historicalDeliveryIndex = null;
                            _currentPathLength = 0;
                          }
                        });
                        // Load history if returned trip is selected
                        if (!mounted) return;
                        final tripStatus = getTripStatus(t);
                        if (tripStatus == 'returned') {
                          final tripId = t['id']?.toString();
                          if (tripId != null && tripId.isNotEmpty) {
                            _ensureHistoryLoaded(tripId, tripStatus);
                          }
                        }
                      },
                      permissionsGranted: _permissionsGranted,
                      onDispatch: () => _handleDispatch(context),
                      onDelivery: () => _handleDelivery(context),
                      onReturn: () => _handleReturn(context),
                      locationService: locationService,
                      organizationId: organization != null ? organization.id.toString() : null,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Load historical path for returned trips (read-only, no writes during active trips)
  /// This reads from Firestore history collection which may contain legacy data
  /// New trips use polyline compression (saved on EndTrip) instead of history collection
  Future<void> _ensureHistoryLoaded(String tripId, String? status) async {
    if (status != 'returned' || _historicalPath != null) {
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('SCHEDULE_TRIPS')
          .doc(tripId)
          .collection('history')
          .orderBy('createdAt', descending: false)
          .get();

      final allLocations = <DriverLocation>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final locations = data['locations'] as List<dynamic>?;
        if (locations != null) {
          for (final locJson in locations) {
            try {
              final loc = DriverLocation.fromJson(
                Map<String, dynamic>.from(locJson),
              );
              allLocations.add(loc);
            } catch (_) {
              // Skip invalid location entries
            }
          }
        }
      }

      // Sort by timestamp to ensure chronological order
      allLocations.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Convert to LatLng list
      final path = allLocations.map((l) => LatLng(l.lat, l.lng)).toList();

      // Find delivery point index (location with status='delivered' or closest to deliveredAt)
      int? deliveryIndex;
      final selectedTrip = _selectedTrip;
      if (selectedTrip != null) {
        final deliveredAt = selectedTrip['deliveredAt'];
        if (deliveredAt != null) {
          final deliveredTimestamp = deliveredAt is Timestamp
              ? deliveredAt.millisecondsSinceEpoch
              : (deliveredAt as DateTime).millisecondsSinceEpoch;

          // Find first location after deliveredAt timestamp
          for (int i = 0; i < allLocations.length; i++) {
            if (allLocations[i].timestamp >= deliveredTimestamp) {
              deliveryIndex = i;
              break;
            }
          }
        } else {
          // Fallback: find location with status='delivered'
          for (int i = 0; i < allLocations.length; i++) {
            if (allLocations[i].status == 'delivered') {
              deliveryIndex = i;
              break;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _historicalPath = path;
          _historicalDeliveryIndex = deliveryIndex;
        });
      }
    } catch (e) {
      debugPrint('[DriverHomeScreen] Failed to load trip history: $e');
    }
  }

  // _askForReading method removed - functionality integrated into TripExecutionSheet

  Future<void> _handleDispatch(BuildContext context) async {
    if (_isRequestingPermissions) return;
    if (!_permissionsGranted) {
      showErrorSnackBar(context, 'Please grant permissions first.');
      return;
    }

    final selected = _selectedTrip;
    if (selected == null) {
      showErrorSnackBar(context, 'Select a trip to dispatch.');
      return;
    }

    final tripId = selected['id']?.toString();
    if (tripId == null || tripId.isEmpty) {
      showErrorSnackBar(context, 'Trip ID not found.');
      return;
    }

    // DEPRECATED: Use TripExecutionSheet instead
    // This method is kept for backward compatibility but should not be called
    // Reading input is now handled by TripExecutionSheet
    return;

    // Dead code below - kept for reference only
    // ignore: dead_code
    final reading = 0.0; // Dummy variable for deprecated code
    final scheduledTripsRepo = context.read<ScheduledTripsRepository>();

    try {
      // Get client ID first
      final clientId = selected['clientId']?.toString();
      if (clientId == null || clientId.isEmpty) {
        if (mounted) {
          showErrorSnackBar(context, 'Client ID not found in selected trip.');
        }
        return;
      }

      // Update scheduled trip status with initial reading
      // Note: TripBloc will also update status to dispatched, but we need to set initialReading here
      await scheduledTripsRepo.updateTripStatus(
        tripId: tripId,
        tripStatus: 'dispatched',
        initialReading: reading,
        deliveredByRole: 'driver',
        source: 'driver',
      );

      // Wait a frame to ensure Firestore stream updates are processed
      await Future.delayed(const Duration(milliseconds: 100));

      // Reset path state for new tracking session
      if (mounted) {
        setState(() {
          _deliveryPointIndex = null;
          _currentPathLength = 0;
        });
      }

      // Start location tracking via TripBloc
      // TripBloc will handle the status update atomically and start tracking
      context.read<TripBloc>().add(StartTrip(tripId: tripId, clientId: clientId));

      if (mounted) {
        showSuccessSnackBar(context, 'Trip dispatched. Tracking started.');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to dispatch trip: $e');
      }
    }
  }

  Future<void> _handleDelivery(BuildContext context) async {
    if (_isRequestingPermissions) return;
    if (!_permissionsGranted) {
      showErrorSnackBar(context, 'Please grant permissions first.');
      return;
    }

    final selected = _selectedTrip;
    if (selected == null) {
      showErrorSnackBar(context, 'Select a trip to mark as delivered.');
      return;
    }

    final tripId = selected['id']?.toString();
    if (tripId == null || tripId.isEmpty) {
      showErrorSnackBar(context, 'Trip ID not found.');
      return;
    }

    // DEPRECATED: Use TripExecutionSheet instead
    // This method is kept for backward compatibility but should not be called
    // Photo picker is now handled by TripExecutionSheet
    return;

    // Dead code below - kept for reference only
    // ignore: dead_code
    final photoFile = File(''); // Dummy variable for deprecated code
    final authState = context.read<AuthBloc>().state;
    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    final user = authState.userProfile;

    if (organization == null || user == null) {
      if (mounted) {
        showErrorSnackBar(context, 'Organization or user not found.');
      }
      return;
    }

    final orderId = selected['orderId']?.toString() ?? '';

    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading photo...')),
      );

      // Upload photo
      final storageService = StorageService();
      final photoUrl = await storageService.uploadDeliveryPhoto(
        imageFile: photoFile,
        // ignore: unnecessary_null_check (deprecated code, organization checked above)
        organizationId: organization.id.toString(),
        orderId: orderId,
        tripId: tripId,
      );

      // Update trip status
      final scheduledTripsRepo = context.read<ScheduledTripsRepository>();
      await scheduledTripsRepo.updateTripStatus(
        tripId: tripId,
        tripStatus: 'delivered',
        deliveryPhotoUrl: photoUrl,
        deliveredBy: user.id,
        deliveredByRole: 'driver',
        source: 'driver',
      );

      // Mark delivery point in current path (for live tracking)
      // Capture the current path length at the moment delivery is pressed
      // This will be used to split the polyline (orange before, blue after)
      if (mounted) {
        setState(() {
          // Use current path length - this represents the point where delivery happened
          // DriverMap will use this to render two polylines
          // If path length is 0, delivery happened before any movement, so we'll
          // show all future points in blue (deliveryIndex will be set on next location update)
          _deliveryPointIndex = _currentPathLength;
        });
      }

      if (mounted) {
        showSuccessSnackBar(context, 'Trip marked as delivered.');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to mark as delivered: $e');
      }
    }
  }

  Future<void> _handleReturn(BuildContext context) async {
    if (_isRequestingPermissions) return;
    if (!_permissionsGranted) {
      showErrorSnackBar(context, 'Please grant permissions first.');
      return;
    }

    final selected = _selectedTrip;
    if (selected == null) {
      showErrorSnackBar(context, 'Select a trip to mark as returned.');
      return;
    }

    final tripId = selected['id']?.toString();
    if (tripId == null || tripId.isEmpty) {
      showErrorSnackBar(context, 'Trip ID not found.');
      return;
    }

    // DEPRECATED: Use TripExecutionSheet instead
    // This method is kept for backward compatibility but should not be called
    // Reading input is now handled by TripExecutionSheet
    return;

    // Dead code below - kept for reference only
    // ignore: dead_code
    final reading = 0.0; // Dummy variable for deprecated code
    final authState = context.read<AuthBloc>().state;
    final user = authState.userProfile;
    if (user == null) {
      if (mounted) {
        showErrorSnackBar(context, 'User not found.');
      }
      return;
    }

    final initialReading = (selected['initialReading'] as num?)?.toDouble();
    final distance =
        (initialReading != null && reading >= initialReading)
            ? (reading - initialReading)
            : null;

    // Get computed distance from LocationService (GPS-based, incremental calculation)
    final locationService = context.read<LocationService>();
    final computedDistance = locationService.totalDistance;

    final scheduledTripsRepo = context.read<ScheduledTripsRepository>();

    try {
      // Update scheduled trip status
      await scheduledTripsRepo.updateTripStatus(
        tripId: tripId,
        tripStatus: 'returned',
        finalReading: reading,
        distanceTravelled: distance,
        computedTravelledDistance: computedDistance,
        returnedBy: user.id,
        returnedByRole: 'driver',
        source: 'driver',
      );

      // Wait a frame to ensure Firestore stream updates are processed
      await Future.delayed(const Duration(milliseconds: 100));

      // Stop location tracking
      if (mounted) {
        context.read<TripBloc>().add(const EndTrip());
        showSuccessSnackBar(context, 'Trip marked as returned.');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to mark as returned: $e');
      }
    }
  }
}

class _TopStatusBar extends StatelessWidget {
  const _TopStatusBar({
    required this.isRequestingPermissions,
    required this.permissionsGranted,
    required this.onTapGrant,
  });

  final bool isRequestingPermissions;
  final bool permissionsGranted;
  final VoidCallback onTapGrant;

  @override
  Widget build(BuildContext context) {
    final bg = AuthColors.surface.withValues(alpha: 0.92);
    final border = AuthColors.textMainWithOpacity(0.1);

    final text = isRequestingPermissions
        ? 'Requesting permissions…'
        : (permissionsGranted ? 'READY' : 'PERMISSIONS NEEDED');

    final textColor = permissionsGranted ? AuthColors.success : AuthColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              color: isRequestingPermissions ? AuthColors.textSub : textColor,
              fontFamily: 'SF Pro Display',
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
          if (!isRequestingPermissions && !permissionsGranted) ...[
            const SizedBox(width: 10),
            FilledButton(
              onPressed: onTapGrant,
              style: FilledButton.styleFrom(
                backgroundColor: AuthColors.legacyAccent,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text(
                'Grant',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.tripState,
    required this.organization,
    required this.user,
    required this.scheduledTripsRepo,
    required this.selectedTrip,
    required this.onSelectTrip,
    required this.permissionsGranted,
    required this.onDispatch,
    required this.onDelivery,
    required this.onReturn,
    required this.locationService,
    required this.organizationId,
  });

  final TripState tripState;
  final dynamic organization;
  final dynamic user;
  final ScheduledTripsRepository scheduledTripsRepo;
  final Map<String, dynamic>? selectedTrip;
  final ValueChanged<Map<String, dynamic>> onSelectTrip;
  final bool permissionsGranted;
  final VoidCallback onDispatch;
  final VoidCallback onDelivery;
  final VoidCallback onReturn;
  final LocationService locationService;
  final String? organizationId;

  @override
  Widget build(BuildContext context) {
    final bg = AuthColors.surface.withValues(alpha: 0.96);
    final border = AuthColors.textMainWithOpacity(0.12);

    final isLoading = tripState.status == ViewStatus.loading;
    final isActive = tripState.isTracking;

    // Determine button based on trip status
    final tripStatus = selectedTrip != null ? getTripStatus(selectedTrip!) : null;
    final canDispatch = (tripStatus == 'scheduled' || tripStatus == 'pending');
    final canDeliver = tripStatus == 'dispatched';
    final canReturn = tripStatus == 'delivered';
    final isReturned = tripStatus == 'returned';
    
    // Check if DM is required for dispatch
    final dmNumber = selectedTrip?['dmNumber'] as int?;
    final hasDM = dmNumber != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AuthColors.background.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Trip Tracking',
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 15,
                    fontFamily: 'SF Pro Display',
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _TrackingPill(isActive: isActive),
            ],
          ),
          const SizedBox(height: 10),
          _TripPicker(
            organization: organization,
            user: user,
            scheduledTripsRepo: scheduledTripsRepo,
            selectedTrip: selectedTrip,
            onSelectTrip: onSelectTrip,
          ),
          const SizedBox(height: 10),
          if (tripState.message != null && tripState.message!.trim().isNotEmpty) ...[
            Text(
              tripState.message!,
              style: const TextStyle(
                color: AuthColors.warning,
                fontSize: 12,
                fontFamily: 'SF Pro Display',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(6), child: CircularProgressIndicator()))
          else if (isReturned)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AuthColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AuthColors.success.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Text(
                'Trip completed. Viewing trip history.',
                style: TextStyle(
                  color: AuthColors.success,
                  fontSize: 12,
                  fontFamily: 'SF Pro Display',
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else if (selectedTrip != null && (canDispatch || canDeliver || canReturn)) ...[
            if (!hasDM && canDispatch)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AuthColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AuthColors.warning.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'DM must be generated before dispatch.',
                  style: TextStyle(
                    color: AuthColors.warning,
                    fontSize: 12,
                    fontFamily: 'SF Pro Display',
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else if (permissionsGranted)
              TripExecutionSheet(
                trip: selectedTrip!,
                organizationId: organizationId,
                onDispatch: (reading) async {
                  final tripId = selectedTrip!['id']?.toString();
                  final clientId = selectedTrip!['clientId']?.toString() ?? '';
                  if (tripId == null) return;

                  final scheduledTripsRepo = context.read<ScheduledTripsRepository>();
                  await scheduledTripsRepo.updateTripStatus(
                    tripId: tripId,
                    tripStatus: 'dispatched',
                    initialReading: reading,
                    source: 'driver',
                  );

                  await Future.delayed(const Duration(milliseconds: 100));

                  if (context.mounted) {
                    context.read<TripBloc>().add(StartTrip(tripId: tripId, clientId: clientId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Trip dispatched. Tracking started.')),
                    );
                  }
                },
                onDelivery: (photoUrl) async {
                  // Call the existing delivery handler
                  final tripId = selectedTrip!['id']?.toString();
                  if (tripId == null) return;

                  final user = context.read<AuthBloc>().state.userProfile;
                  if (user == null) return;

                  final scheduledTripsRepo = context.read<ScheduledTripsRepository>();
                  await scheduledTripsRepo.updateTripStatus(
                    tripId: tripId,
                    tripStatus: 'delivered',
                    deliveryPhotoUrl: photoUrl,
                    deliveredBy: user.id,
                    deliveredByRole: 'driver',
                    source: 'driver',
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Trip marked as delivered.')),
                    );
                  }
                },
                onReturn: (reading) async {
                  final tripId = selectedTrip!['id']?.toString();
                  if (tripId == null) return;

                  final user = context.read<AuthBloc>().state.userProfile;
                  if (user == null) return;

                  double? distance;
                  if (reading != null) {
                    final initialReading = (selectedTrip!['initialReading'] as num?)?.toDouble();
                    if (initialReading != null && reading >= initialReading) {
                      distance = reading - initialReading;
                    }
                  }

                  final locationService = context.read<LocationService>();
                  final computedDistance = locationService.totalDistance;

                  final scheduledTripsRepo = context.read<ScheduledTripsRepository>();
                  await scheduledTripsRepo.updateTripStatus(
                    tripId: tripId,
                    tripStatus: 'returned',
                    finalReading: reading,
                    distanceTravelled: distance,
                    computedTravelledDistance: computedDistance,
                    returnedBy: user.id,
                    returnedByRole: 'driver',
                    source: 'driver',
                  );

                  await Future.delayed(const Duration(milliseconds: 100));

                  if (context.mounted) {
                    context.read<TripBloc>().add(const EndTrip());
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Trip marked as returned.')),
                    );
                  }
                },
              ),
          ],
        ],
      ),
    );
  }
}

class _TripPicker extends StatelessWidget {
  const _TripPicker({
    required this.organization,
    required this.user,
    required this.scheduledTripsRepo,
    required this.selectedTrip,
    required this.onSelectTrip,
  });

  final dynamic organization;
  final dynamic user;
  final ScheduledTripsRepository scheduledTripsRepo;
  final Map<String, dynamic>? selectedTrip;
  final ValueChanged<Map<String, dynamic>> onSelectTrip;

  @override
  Widget build(BuildContext context) {
    if (organization == null) {
      return const Text(
        'Select an organization to view trips.',
        style: TextStyle(
          color: AuthColors.textSub,
          fontSize: 12,
          fontFamily: 'SF Pro Display',
          fontWeight: FontWeight.w600,
        ),
      );
    }
    if (user == null || user.phoneNumber.isEmpty) {
      return const Text(
        'No driver phone number found for this account.',
        style: TextStyle(
          color: AuthColors.textSub,
          fontSize: 12,
          fontFamily: 'SF Pro Display',
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final today = DateTime.now();
    final date = DateTime(today.year, today.month, today.day);

    return StreamBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('trips_${organization.id}_${user.phoneNumber}'),
      stream: scheduledTripsRepo.watchDriverScheduledTripsForDate(
        organizationId: organization.id.toString(),
        driverPhone: user.phoneNumber.toString(),
        scheduledDate: date,
      ),
      builder: (context, snapshot) {
        // Early return if widget is disposed
        if (!context.mounted) {
          return const SizedBox.shrink();
        }
        final trips = snapshot.data ?? const [];

        if (snapshot.connectionState == ConnectionState.waiting && trips.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Text(
            'Failed to load trips: ${snapshot.error}',
            style: const TextStyle(
              color: AuthColors.textSub,
              fontSize: 12,
              fontFamily: 'SF Pro Display',
              fontWeight: FontWeight.w600,
            ),
          );
        }

        if (trips.isEmpty) {
          return const Text(
            'No trips scheduled for today.',
            style: TextStyle(
              color: AuthColors.textSub,
              fontSize: 12,
              fontFamily: 'SF Pro Display',
              fontWeight: FontWeight.w600,
            ),
          );
        }

        // Preserve selected trip across status changes
        // Only auto-select if no trip is currently selected or the selected trip is no longer in the list
        final currentId = selectedTrip?['id']?.toString();
        if (currentId == null) {
          // No trip selected - auto-select first trip only once
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && trips.isNotEmpty) {
              onSelectTrip(trips.first);
            }
          });
        } else {
          // Check if selected trip still exists in the list
          final tripExists = trips.any((t) => t['id']?.toString() == currentId);
          if (!tripExists) {
            // Selected trip no longer exists - select first available trip
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted && trips.isNotEmpty) {
                onSelectTrip(trips.first);
              }
            });
          } else {
            // Selected trip exists - update with latest data but preserve selection
            // Only update if the trip data actually changed (not just reference equality)
            final updatedTrip = trips.firstWhere(
              (t) => t['id']?.toString() == currentId,
            );
            // Compare by ID and status to avoid unnecessary updates
            final currentStatus = getTripStatus(selectedTrip!);
            final updatedStatus = getTripStatus(updatedTrip);
            // Only update if status changed (which means trip data changed)
            if (currentStatus != updatedStatus) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  onSelectTrip(updatedTrip);
                }
              });
            }
          }
        }

        final selectedId = (selectedTrip?['id'] ?? trips.first['id']).toString();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: AuthColors.background.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AuthColors.textMainWithOpacity(0.12), width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedId,
              isExpanded: true,
              dropdownColor: AuthColors.surface,
              iconEnabledColor: AuthColors.textSub,
              items: trips.map((t) {
                final id = t['id']?.toString() ?? '';
                final clientName = (t['clientName'] as String?) ?? 'Client';
                final slotName = (t['slotName'] as String?) ?? '';
                final vehicle = (t['vehicleNumber'] as String?) ?? '';
                final label = [
                  clientName,
                  if (slotName.isNotEmpty) slotName,
                  if (vehicle.isNotEmpty) vehicle,
                ].join(' • ');
                return DropdownMenuItem<String>(
                  value: id,
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AuthColors.textMain,
                      fontSize: 12,
                      fontFamily: 'SF Pro Display',
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (id) {
                if (id == null) return;
                final picked = trips.firstWhere((t) => t['id']?.toString() == id, orElse: () => trips.first);
                onSelectTrip(picked);
              },
            ),
          ),
        );
      },
    );
  }
}

class _TrackingPill extends StatelessWidget {
  const _TrackingPill({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AuthColors.success : AuthColors.error;
    final text = isActive ? '🟢 ONLINE' : '🔴 OFFLINE';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
          fontFamily: 'SF Pro Display',
        ),
      ),
    );
  }
}


