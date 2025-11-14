import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_snackbar.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../bloc/depot/depot_bloc.dart';
import '../../bloc/depot/depot_event.dart';
import '../../bloc/depot/depot_state.dart';
import '../../../../core/utils/map_marker_utils.dart';

class DepotLocationSection extends StatefulWidget {
  const DepotLocationSection({
    super.key,
    required this.orgId,
  });

  final String orgId;

  @override
  State<DepotLocationSection> createState() => _DepotLocationSectionState();
}

class _DepotLocationSectionState extends State<DepotLocationSection> {
  static const LatLng _defaultPosition = LatLng(20.5937, 78.9629); // India fallback

  GoogleMapController? _mapController;
  LatLng? _selectedPosition;
  bool _hasPendingChanges = false;
  bool _hasHydratedFromState = false;
  BitmapDescriptor? _depotMarkerIcon;
  String _lastMarkerLabel = '';

  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _labelController.addListener(_handleLabelChanged);
    _refreshDepotMarkerIcon();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _labelController.removeListener(_handleLabelChanged);
    _labelController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DepotBloc, DepotState>(
      listenWhen: (previous, current) =>
          previous.location != current.location ||
          previous.errorMessage != current.errorMessage ||
          previous.saveSuccess != current.saveSuccess,
      listener: (context, state) {
        _syncFromState(state);

        if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          CustomSnackBar.showError(context, state.errorMessage!);
        }

        if (state.saveSuccess) {
          CustomSnackBar.showSuccess(context, 'Depot location saved successfully.');
          if (mounted) {
            setState(() {
              _hasPendingChanges = false;
            });
          }
          context.read<DepotBloc>().add(const ClearDepotStatus());
        }
      },
      child: BlocBuilder<DepotBloc, DepotState>(
        builder: (context, state) {
          final position = _selectedPosition;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pin your depot on the map so the team knows where operations are based. Use your current location or drag the marker to fine-tune.',
                style: const TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              _buildMap(state),
              const SizedBox(height: AppTheme.spacingMd),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _labelController,
                      labelText: 'Depot label (optional)',
                      hintText: 'e.g. Head Office Depot',
                      onChanged: (_) => _markPendingChanges(),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMd),
                  Expanded(
                    child: CustomTextField(
                      controller: _addressController,
                      labelText: 'Address or landmark (optional)',
                      hintText: 'Add an address to share with drivers',
                      maxLines: 2,
                      onChanged: (_) => _markPendingChanges(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMd),
              _buildCoordinateRow(position),
              if (_hasPendingChanges)
                Padding(
                  padding: const EdgeInsets.only(top: AppTheme.spacingSm),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.info_outline,
                        color: AppTheme.warningColor,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You have unsaved depot changes.',
                          style: TextStyle(
                            color: AppTheme.warningColor,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppTheme.spacingMd),
              Row(
                children: [
                  CustomButton(
                    text: 'Use Current Location',
                    onPressed: state.isSaving || state.isLoading
                        ? null
                        : _centerOnCurrentLocation,
                    variant: CustomButtonVariant.secondary,
                    size: CustomButtonSize.medium,
                    icon: const Icon(
                      Icons.my_location_outlined,
                      size: 18,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMd),
                  CustomButton(
                    text: 'Save Depot Location',
                    onPressed: (position == null || state.isSaving)
                        ? null
                        : () => _saveDepot(context),
                    variant: CustomButtonVariant.primary,
                    size: CustomButtonSize.medium,
                    isLoading: state.isSaving,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMap(DepotState state) {
    final markers = <Marker>{
      if (_selectedPosition != null)
        Marker(
          markerId: const MarkerId('depot'),
          position: _selectedPosition!,
          draggable: true,
          icon: _depotMarkerIcon ?? MapMarkerUtils.fallbackDepotMarker,
          onDragEnd: _onPositionChanged,
        ),
    };

    return Container(
      width: double.infinity,
      height: 320,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: const Color(0xFF374151)),
      ),
      clipBehavior: Clip.none,
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedPosition ?? _defaultPosition,
              zoom: _selectedPosition != null ? 15 : 5,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              if (_selectedPosition != null) {
                _animateTo(_selectedPosition!);
              }
            },
            myLocationButtonEnabled: true,
            myLocationEnabled: true,
            compassEnabled: true,
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
            markers: markers,
            onTap: _onPositionChanged,
          ),
          if (state.isLoading || state.isSaving)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCoordinateRow(LatLng? position) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_pin,
            color: position != null
                ? AppTheme.successColor
                : AppTheme.textTertiaryColor,
            size: 20,
          ),
          const SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Text(
              position != null
                  ? 'Lat ${position.latitude.toStringAsFixed(6)}, '
                      'Lng ${position.longitude.toStringAsFixed(6)}'
                  : 'Tap the map or use your current location to drop a depot pin.',
              style: TextStyle(
                color: position != null
                    ? AppTheme.textSecondaryColor
                    : AppTheme.textTertiaryColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onPositionChanged(LatLng position) {
    if (!mounted) return;
    setState(() {
      _selectedPosition = position;
      _hasPendingChanges = true;
      _hasHydratedFromState = true;
    });
    _animateTo(position);
  }

  void _markPendingChanges() {
    if (!mounted) return;
    setState(() {
      _hasPendingChanges = true;
    });
  }

  void _handleLabelChanged() {
    _refreshDepotMarkerIcon();
  }

  Future<void> _refreshDepotMarkerIcon() async {
    final label = _labelController.text.trim();
    if (label == _lastMarkerLabel && _depotMarkerIcon != null) {
      return;
    }
    _lastMarkerLabel = label;
    final icon = await MapMarkerUtils.depotMarkerForLabel(label);
    if (!mounted) return;
    setState(() {
      _depotMarkerIcon = icon;
    });
  }

  Future<void> _centerOnCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        CustomSnackBar.showError(
          context,
          'Location services are disabled. Please enable them to use your current location.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        CustomSnackBar.showError(
          context,
          'Location permission denied. Please allow access from your browser settings.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _onPositionChanged(LatLng(position.latitude, position.longitude));
    } catch (error) {
      CustomSnackBar.showError(
        context,
        'Unable to fetch current location: ${error.toString()}',
      );
    }
  }

  void _saveDepot(BuildContext context) {
    final position = _selectedPosition;
    if (position == null) {
      CustomSnackBar.showError(
        context,
        'Select a depot location before saving.',
      );
      return;
    }

    context.read<DepotBloc>().add(
          SaveDepotLocation(
            orgId: widget.orgId,
            latitude: position.latitude,
            longitude: position.longitude,
            label: _labelController.text.trim().isEmpty
                ? null
                : _labelController.text.trim(),
            address: _addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim(),
          ),
        );
  }

  void _animateTo(LatLng position) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: 15),
      ),
    );
  }

  void _syncFromState(DepotState state) {
    final location = state.location;
    if (location == null) {
      if (!_hasHydratedFromState) {
        if (!mounted) return;
        setState(() {
          _selectedPosition = null;
          _labelController.text = '';
          _addressController.text = '';
          _hasPendingChanges = false;
          _hasHydratedFromState = true;
        });
      }
      return;
    }

    final newPosition = LatLng(location.latitude, location.longitude);
    final hasLatLngChanged = _selectedPosition == null ||
        (_selectedPosition!.latitude - newPosition.latitude).abs() > 1e-7 ||
        (_selectedPosition!.longitude - newPosition.longitude).abs() > 1e-7;

    final newLabel = location.label ?? '';
    final newAddress = location.address ?? '';

    if (!mounted) return;
    if (hasLatLngChanged ||
        _labelController.text != newLabel ||
        _addressController.text != newAddress ||
        !_hasHydratedFromState) {
      setState(() {
        _selectedPosition = newPosition;
        _labelController.text = newLabel;
        _addressController.text = newAddress;
        _hasPendingChanges = false;
        _hasHydratedFromState = true;
      });
      _animateTo(newPosition);
      _refreshDepotMarkerIcon();
    }
  }
}

