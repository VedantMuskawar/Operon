import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_models/core_models.dart' hide LatLng;
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/blocs/organization_locations/organization_locations_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Reusable content for Locations list; used by full page and Settings side sheet.
class OrganizationLocationsPageContent extends StatelessWidget {
  const OrganizationLocationsPageContent({super.key});

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    final appAccessRole = orgState.appAccessRole;
    final isAdmin = appAccessRole?.isAdmin ?? false;

    if (organization == null) {
      return const Center(child: Text('No organization selected'));
    }

    return BlocListener<OrganizationLocationsCubit, OrganizationLocationsState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          DashSnackbar.show(
            context,
            message: state.message!,
            isError: true,
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAdmin)
            SizedBox(
              width: double.infinity,
              child: DashButton(
                label: 'Add Location',
                onPressed: () => _openLocationDialog(context),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0x22FFFFFF),
              ),
              child: const Text(
                'You have read-only access to locations.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          const SizedBox(height: 20),
          BlocBuilder<OrganizationLocationsCubit, OrganizationLocationsState>(
            builder: (context, state) {
              if (state.status == ViewStatus.loading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.locations.isEmpty) {
                return Center(
                  child: Text(
                    'No locations yet. Tap "Add Location" to create one.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return AnimationLimiter(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.locations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final location = state.locations[index];
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 200),
                      child: SlideAnimation(
                        verticalOffset: 50.0,
                        child: FadeInAnimation(
                          curve: Curves.easeOut,
                          child: _LocationTile(
                            location: location,
                            canManage: isAdmin,
                            onEdit: isAdmin
                                ? () => _openLocationDialog(context, location: location)
                                : null,
                            onDelete: isAdmin
                                ? () => context.read<OrganizationLocationsCubit>().deleteLocation(location.id)
                                : null,
                            onSetPrimary: isAdmin
                                ? () => context.read<OrganizationLocationsCubit>().setPrimaryLocation(location.id)
                                : null,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _openLocationDialog(
    BuildContext context, {
    OrganizationLocation? location,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<OrganizationLocationsCubit>(),
        child: _LocationDialog(location: location),
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.location,
    required this.canManage,
    this.onEdit,
    this.onDelete,
    this.onSetPrimary,
  });

  final OrganizationLocation location;
  final bool canManage;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSetPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1F1F2C),
        border: Border.all(
          color: location.isPrimary
              ? const Color(0xFF6F4BFF)
              : Colors.white.withValues(alpha: 0.1),
          width: location.isPrimary ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: location.isPrimary
                  ? const Color(0xFF6F4BFF).withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
            ),
            child: Icon(
              Icons.location_on,
              color: location.isPrimary
                  ? const Color(0xFF6F4BFF)
                  : Colors.white70,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        location.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (location.isPrimary)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: const Color(0xFF6F4BFF).withValues(alpha: 0.2),
                        ),
                        child: const Text(
                          'Primary',
                          style: TextStyle(
                            color: Color(0xFF6F4BFF),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
                if (location.address != null && location.address!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    location.address!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (canManage) ...[
            if (!location.isPrimary && onSetPrimary != null)
              IconButton(
                icon: const Icon(Icons.star_outline, color: Colors.white70),
                onPressed: onSetPrimary,
                tooltip: 'Set as primary',
              ),
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                onPressed: onEdit,
                tooltip: 'Edit',
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF11111B),
                      title: const Text(
                        'Delete Location',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: Text(
                        'Are you sure you want to delete "${location.name}"?',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        DashButton(
                          label: 'Cancel',
                          onPressed: () => Navigator.of(ctx).pop(),
                          variant: DashButtonVariant.text,
                        ),
                        DashButton(
                          label: 'Delete',
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            onDelete?.call();
                          },
                          variant: DashButtonVariant.text,
                          isDestructive: true,
                        ),
                      ],
                    ),
                  );
                },
                tooltip: 'Delete',
              ),
          ],
        ],
      ),
    );
  }
}

class _LocationDialog extends StatefulWidget {
  const _LocationDialog({this.location});

  final OrganizationLocation? location;

  @override
  State<_LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends State<_LocationDialog> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  double? _latitude;
  double? _longitude;
  GoogleMapController? _mapController;
  LatLng? _selectedPosition;

  @override
  void initState() {
    super.initState();
    if (widget.location != null) {
      _nameController.text = widget.location!.name;
      _addressController.text = widget.location!.address ?? '';
      _latitude = widget.location!.latitude;
      _longitude = widget.location!.longitude;
      _selectedPosition = LatLng(_latitude!, _longitude!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.location != null;
    final initialPosition = _selectedPosition ?? const LatLng(19.0760, 72.8777); // Mumbai default

    return AlertDialog(
      backgroundColor: const Color(0xFF11111B),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isEdit ? 'Edit Location' : 'Add Location',
            style: const TextStyle(color: Colors.white),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Location Name',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF6F4BFF)),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a location name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address (Optional)',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF6F4BFF)),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Location on Map',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: initialPosition,
                        zoom: 15,
                      ),
                      onMapCreated: (controller) {
                        _mapController = controller;
                        controller.setMapStyle(darkMapStyle);
                      },
                      onTap: (position) {
                        setState(() {
                          _selectedPosition = position;
                          _latitude = position.latitude;
                          _longitude = position.longitude;
                        });
                      },
                      markers: _selectedPosition != null
                          ? {
                              Marker(
                                markerId: const MarkerId('selected'),
                                position: _selectedPosition!,
                                draggable: true,
                                onDragEnd: (position) {
                                  setState(() {
                                    _selectedPosition = position;
                                    _latitude = position.latitude;
                                    _longitude = position.longitude;
                                  });
                                },
                              ),
                            }
                          : {},
                    ),
                  ),
                ),
                if (_latitude != null && _longitude != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Coordinates: ${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        DashButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
          variant: DashButtonVariant.text,
        ),
        DashButton(
          label: isEdit ? 'Update' : 'Create',
          onPressed: _saveLocation,
        ),
      ],
    );
  }

  void _saveLocation() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_latitude == null || _longitude == null) {
      DashSnackbar.show(context, message: 'Please select a location on the map', isError: true);
      return;
    }

    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    if (organization == null) return;

    final location = OrganizationLocation(
      id: widget.location?.id ?? '',
      organizationId: organization.id,
      name: _nameController.text.trim(),
      latitude: _latitude!,
      longitude: _longitude!,
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      isPrimary: widget.location?.isPrimary ?? false,
    );

    if (widget.location != null) {
      context.read<OrganizationLocationsCubit>().updateLocation(location);
    } else {
      context.read<OrganizationLocationsCubit>().createLocation(location);
    }

    Navigator.of(context).pop();
  }
}
