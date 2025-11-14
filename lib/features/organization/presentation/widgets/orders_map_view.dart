import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/models/depot_location.dart';
import '../../../../core/navigation/organization_navigation_scope.dart';
import '../../../../core/repositories/depot_repository.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_snackbar.dart';
import '../../../../core/utils/map_marker_utils.dart';
import '../../bloc/depot/depot_bloc.dart';
import '../../bloc/depot/depot_event.dart';
import '../../bloc/depot/depot_state.dart';

class OrdersMapView extends StatelessWidget {
  const OrdersMapView({
    super.key,
    required this.organizationId,
    this.organizationName,
  });

  final String organizationId;
  final String? organizationName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DepotBloc(depotRepository: DepotRepository())
        ..add(LoadDepotLocation(organizationId)),
      child: _OrdersMapViewBody(
        organizationName: organizationName,
      ),
    );
  }
}

class _OrdersMapViewBody extends StatefulWidget {
  const _OrdersMapViewBody({this.organizationName});

  final String? organizationName;

  @override
  State<_OrdersMapViewBody> createState() => _OrdersMapViewBodyState();
}

class _OrdersMapViewBodyState extends State<_OrdersMapViewBody> {
  GoogleMapController? _mapController;
  LatLng? _lastCameraTarget;
  BitmapDescriptor? _depotMarkerIcon;
  String _lastMarkerLabel = '';

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navigation = OrganizationNavigationScope.of(context);
    final orgLabel = widget.organizationName ?? 'organization';

    return BlocConsumer<DepotBloc, DepotState>(
      listener: (context, state) {
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          CustomSnackBar.showError(context, state.errorMessage!);
        }
        if (state.location != null && _lastCameraTarget == null) {
          final target = LatLng(
            state.location!.latitude,
            state.location!.longitude,
          );
          _lastCameraTarget = target;
          _animateTo(target);
        }
      },
      builder: (context, state) {
        if (state.location != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _ensureDepotMarkerIcon(state.location!.label);
          });
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Orders Map',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.textPrimaryColor,
                  ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'Visualize the depot location for $orgLabel. Drivers and dispatch teams can reference this when planning orders.',
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            _buildMapContent(state),
            const SizedBox(height: AppTheme.spacingLg),
            if (state.location != null)
              _buildLocationDetails(state.location!)
            else if (!state.isLoading)
              _buildEmptyState(navigation),
          ],
        );
      },
    );
  }

  Widget _buildMapContent(DepotState state) {
    if (state.isLoading && state.location == null) {
      return SizedBox(
        height: 360,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: AppTheme.spacingSm),
              Text(
                'Loading depot location...',
                style: TextStyle(color: AppTheme.textSecondaryColor),
              ),
            ],
          ),
        ),
      );
    }

    if (state.location == null) {
      return Container(
        width: double.infinity,
        height: 360,
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          border: Border.all(color: const Color(0xFF374151)),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        child: const Center(
          child: Text(
            'No depot location saved yet.',
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    final depotLatLng = LatLng(
      state.location!.latitude,
      state.location!.longitude,
    );

    return Container(
      width: double.infinity,
      height: 360,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: depotLatLng,
          zoom: 15,
        ),
        markers: {
          Marker(
            markerId: const MarkerId('depot'),
            position: depotLatLng,
            icon: _depotMarkerIcon ?? MapMarkerUtils.fallbackDepotMarker,
            infoWindow: InfoWindow(
              title: state.location!.label ?? 'Depot',
              snippet: state.location!.address,
            ),
          ),
        },
        onMapCreated: (controller) {
          _mapController = controller;
          _animateTo(depotLatLng);
        },
        compassEnabled: true,
        mapToolbarEnabled: false,
        myLocationButtonEnabled: false,
        myLocationEnabled: false,
        zoomControlsEnabled: true,
        liteModeEnabled: false,
      ),
    );
  }

  Widget _buildLocationDetails(DepotLocation location) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            location.label ?? 'Primary Depot',
            style: const TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          if (location.address != null && location.address!.isNotEmpty) ...[
            Text(
              location.address!,
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
          ],
          Text(
            'Latitude: ${location.latitude.toStringAsFixed(6)}',
            style: const TextStyle(
              color: AppTheme.textTertiaryColor,
              fontSize: 13,
            ),
          ),
          Text(
            'Longitude: ${location.longitude.toStringAsFixed(6)}',
            style: const TextStyle(
              color: AppTheme.textTertiaryColor,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(OrganizationNavigationScope? navigation) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Set up your depot location to unlock the orders map.',
            style: TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          const Text(
            'Save a depot pin inside Organization Settings → Depot Location. Once saved, it will appear here on the orders map.',
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          CustomButton(
            text: 'Manage Depot Location',
            onPressed: navigation == null
                ? null
                : () => navigation.goToView('organization-settings'),
            variant: CustomButtonVariant.secondary,
            size: CustomButtonSize.medium,
            icon: const Icon(
              Icons.edit_location_alt_outlined,
              size: 18,
              color: Color(0xFF8E8E93),
            ),
          ),
        ],
      ),
    );
  }

  void _animateTo(LatLng target) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: target,
          zoom: 15,
        ),
      ),
    );
  }

  Future<void> _ensureDepotMarkerIcon(String? rawLabel) async {
    final label = (rawLabel ?? 'Depot').trim();
    if (_depotMarkerIcon != null && label == _lastMarkerLabel) {
      return;
    }
    _lastMarkerLabel = label;
    final icon = await MapMarkerUtils.depotMarkerForLabel(label);
    if (!mounted) return;
    setState(() {
      _depotMarkerIcon = icon;
    });
  }
}

