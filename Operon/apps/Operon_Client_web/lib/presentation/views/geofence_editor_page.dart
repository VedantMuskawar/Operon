import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart' as core_models;
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/repositories/geofences_repository.dart';
import 'package:dash_web/data/repositories/organization_locations_repository.dart';
import 'package:dash_web/data/repositories/users_repository.dart';
import 'package:dash_web/presentation/blocs/geofences/geofences_cubit.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/widgets/page_workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';

class GeofenceEditorPage extends StatefulWidget {
  const GeofenceEditorPage({
    super.key,
    this.geofenceId,
    this.locationId,
  });

  final String? geofenceId;
  final String? locationId;

  @override
  State<GeofenceEditorPage> createState() => _GeofenceEditorPageState();
}

class _GeofenceEditorPageState extends State<GeofenceEditorPage> {
  core_models.GeofenceType _selectedType = core_models.GeofenceType.circle;
  double _radiusMeters = 100.0;
  LatLng _centerPoint = const LatLng(19.0760, 72.8777);
  final List<LatLng> _polygonPoints = [];
  bool _isDrawingPolygon = false;
  GoogleMapController? _mapController;
  final TextEditingController _nameController = TextEditingController();
  final List<String> _selectedRecipientIds = [];
  final List<String> _availableUserIds = [];
  final Map<String, String> _userIdToName = {};

  core_models.OrganizationLocation? _location;

  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    if (organization == null) {
      setState(() {
        _isLoading = false;
        _loadError = 'No organization selected';
      });
      return;
    }

    final usersRepo = context.read<UsersRepository>();
    final geofencesRepo = context.read<GeofencesRepository>();
    final locationsRepo = context.read<OrganizationLocationsRepository>();
    final orgId = organization.id;
    final geofenceId = widget.geofenceId;
    var locationId = widget.locationId;

    try {
      // Load users and locations
      final users = await usersRepo.fetchOrgUsers(orgId);
      if (!mounted) return;
      final locations = await locationsRepo.fetchLocations(orgId);
      if (!mounted) return;

      // If locationId is not provided but geofenceId is, get locationId from geofence
      if (locationId == null && geofenceId != null) {
        final geofence = await geofencesRepo.fetchGeofence(
          orgId: orgId,
          geofenceId: geofenceId,
        );
        if (!mounted) return;
        if (geofence != null) {
          locationId = geofence.locationId;
        }
      }

      if (locationId == null) {
        setState(() {
          _isLoading = false;
          _loadError = 'Location ID is required';
        });
        return;
      }

      final location = locations.firstWhere(
        (l) => l.id == locationId,
        orElse: () => throw Exception('Location not found'),
      );

      setState(() {
        _availableUserIds
          ..clear()
          ..addAll(users.map((u) => u.id));
        _userIdToName
          ..clear()
          ..addAll({for (var u in users) u.id: u.name});
        _location = location;
      });

      if (geofenceId != null) {
        final geofence = await geofencesRepo.fetchGeofence(
          orgId: orgId,
          geofenceId: geofenceId,
        );
        if (!mounted) return;
        if (geofence != null) {
          // Verify geofence belongs to the specified location
          if (geofence.locationId != locationId) {
            setState(() {
              _isLoading = false;
              _loadError = 'Geofence does not belong to this location';
            });
            return;
          }
          setState(() {
            _nameController.text = geofence.name;
            _selectedType = geofence.type;
            _centerPoint = LatLng(geofence.centerLat, geofence.centerLng);
            _radiusMeters = geofence.radiusMeters ?? 100.0;
            _polygonPoints.clear();
            if (geofence.polygonPoints != null) {
              _polygonPoints.addAll(
                geofence.polygonPoints!
                    .map((p) => LatLng(p.latitude, p.longitude)),
              );
            }
            _selectedRecipientIds
              ..clear()
              ..addAll(geofence.notificationRecipientIds);
          });
        }
      } else {
        // For new geofences, center on the location
        setState(() {
          _centerPoint = LatLng(location.latitude, location.longitude);
        });
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = null;
      });
    } catch (e, st) {
      debugPrint('GeofenceEditorPage _loadData error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e is Exception ? e.toString() : 'Failed to load';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;

    if (organization == null) {
      return Scaffold(
        backgroundColor: AuthColors.background,
        body: const Center(child: Text('No organization selected')),
      );
    }

    final isCreate = widget.geofenceId == null;
    final title = isCreate ? 'Create Geofence' : 'Edit Geofence';

    Widget body;
    if (_isLoading) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AuthColors.primary),
        ),
      );
    } else if (_loadError != null) {
      body = _buildErrorBody();
    } else if (_location == null) {
      body = _buildNoLocationBody();
    } else {
      body = _buildEditorBody(organization.id);
    }

    return PageWorkspaceLayout(
      title: title,
      currentIndex: -1,
      onBack: () => context.go('/locations-geofences'),
      onNavTap: (value) => context.go('/home?section=$value'),
      child: body,
    );
  }

  Widget _buildErrorBody() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _loadError!,
            style: const TextStyle(color: AuthColors.textMain),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          DashButton(
            label: 'Retry',
            onPressed: () {
              setState(() {
                _isLoading = true;
                _loadError = null;
              });
              _loadData();
            },
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go('/locations-geofences'),
            style: TextButton.styleFrom(foregroundColor: AuthColors.primary),
            child: const Text('Back to Locations & Geofences'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoLocationBody() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.location_off_outlined,
            size: 48,
            color: AuthColors.textSub,
          ),
          const SizedBox(height: 16),
          Text(
            'Location not found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AuthColors.textMain,
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'The specified location could not be found. Please go back and try again.',
            style: const TextStyle(color: AuthColors.textSub, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          DashButton(
            label: 'Back to Locations & Geofences',
            onPressed: () => context.go('/locations-geofences'),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorBody(String organizationId) {
    return BlocProvider<GeofencesCubit>(
      create: (context) => GeofencesCubit(
        repository: context.read<GeofencesRepository>(),
        organizationId: organizationId,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLocationInfo(),
            const SizedBox(height: 20),
            _buildTypeSelector(),
            const SizedBox(height: 16),
            _buildMapSection(organizationId),
            const SizedBox(height: 24),
            _buildControlsCard(organizationId),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInfo() {
    if (_location == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1F1F2C),
        border: Border.all(
          color: _location!.isPrimary
              ? const Color(0xFF6F4BFF)
              : Colors.white.withValues(alpha: 0.1),
          width: _location!.isPrimary ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _location!.isPrimary
                  ? const Color(0xFF6F4BFF).withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
            ),
            child: Icon(
              Icons.location_on,
              color: _location!.isPrimary
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
                        _location!.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_location!.isPrimary)
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
                  '${_location!.latitude.toStringAsFixed(6)}, ${_location!.longitude.toStringAsFixed(6)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
                if (_location!.address != null && _location!.address!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _location!.address!,
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
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return SegmentedButton<core_models.GeofenceType>(
      segments: const [
        ButtonSegment<core_models.GeofenceType>(
          value: core_models.GeofenceType.circle,
          label: Text('Circle'),
          icon: Icon(Icons.radio_button_unchecked, size: 20),
        ),
        ButtonSegment<core_models.GeofenceType>(
          value: core_models.GeofenceType.polygon,
          label: Text('Polygon'),
          icon: Icon(Icons.polyline, size: 20),
        ),
      ],
      selected: {_selectedType},
      onSelectionChanged: (Set<core_models.GeofenceType> s) {
        setState(() {
          _selectedType = s.first;
          _radiusMeters = 100.0;
          _polygonPoints.clear();
          _isDrawingPolygon = false;
        });
      },
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AuthColors.primary
              : AuthColors.surface;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? Colors.white
              : AuthColors.textSub;
        }),
      ),
    );
  }

  Widget _buildMapSection(String organizationId) {
    final circles = <Circle>{};
    final polygons = <Polygon>{};
    final markers = <Marker>{};
    const accent = AuthColors.primary;

    if (_selectedType == core_models.GeofenceType.circle) {
      circles.add(
        Circle(
          circleId: const CircleId('geofence'),
          center: _centerPoint,
          radius: _radiusMeters,
          fillColor: accent.withValues(alpha: 0.3),
          strokeColor: accent,
          strokeWidth: 2,
        ),
      );
      markers.add(
        Marker(
          markerId: const MarkerId('center'),
          position: _centerPoint,
          draggable: true,
          onDragEnd: (p) => setState(() => _centerPoint = p),
        ),
      );
    } else if (_selectedType == core_models.GeofenceType.polygon &&
        _polygonPoints.isNotEmpty) {
      polygons.add(
        Polygon(
          polygonId: const PolygonId('geofence'),
          points: _polygonPoints,
          fillColor: accent.withValues(alpha: 0.3),
          strokeColor: accent,
          strokeWidth: 2,
        ),
      );
    }

    return SizedBox(
      height: 320,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AuthColors.textMainWithOpacity(0.15)),
        ),
        clipBehavior: Clip.antiAlias,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _centerPoint,
            zoom: 15,
          ),
          onMapCreated: (c) {
            c.setMapStyle(darkMapStyle);
            _mapController = c;
          },
          onTap: _selectedType == core_models.GeofenceType.polygon &&
                  _isDrawingPolygon
              ? (p) => setState(() => _polygonPoints.add(p))
              : null,
          circles: circles,
          polygons: polygons,
          markers: markers,
        ),
      ),
    );
  }

  Widget _buildControlsCard(String organizationId) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_selectedType == core_models.GeofenceType.circle)
            _buildCircleControls()
          else
            _buildPolygonControls(),
          const SizedBox(height: 20),
          _buildNameField(),
          const SizedBox(height: 20),
          _buildRecipientSelector(),
          const SizedBox(height: 24),
          _buildSaveButton(organizationId),
        ],
      ),
    );
  }

  Widget _buildCircleControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Radius: ${_radiusMeters.toStringAsFixed(0)} m',
          style: const TextStyle(
            color: AuthColors.textMain,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AuthColors.primary,
            inactiveTrackColor: AuthColors.textMainWithOpacity(0.2),
            thumbColor: AuthColors.primary,
            overlayColor: AuthColors.primary.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: _radiusMeters,
            min: 10,
            max: 5000,
            divisions: 99,
            onChanged: (v) => setState(() => _radiusMeters = v),
          ),
        ),
      ],
    );
  }

  Widget _buildPolygonControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_isDrawingPolygon)
          DashButton(
            label: 'Start Drawing',
            onPressed: () => setState(() {
              _isDrawingPolygon = true;
              _polygonPoints.clear();
            }),
          )
        else
          Row(
            children: [
              Expanded(
                child: DashButton(
                  label: 'Finish Drawing',
                  onPressed: () {
                    if (_polygonPoints.length < 3) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Polygon needs at least 3 points')),
                      );
                      return;
                    }
                    setState(() => _isDrawingPolygon = false);
                  },
                ),
              ),
              if (_polygonPoints.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, color: AuthColors.textSub),
                  onPressed: () => setState(() => _polygonPoints.clear()),
                  tooltip: 'Clear',
                ),
            ],
          ),
        if (_polygonPoints.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${_polygonPoints.length} points${_polygonPoints.length < 3 ? ' (need at least 3)' : ''}',
              style: TextStyle(
                color: _polygonPoints.length < 3
                    ? AuthColors.warning
                    : AuthColors.textSub,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: 'Geofence Name',
        labelStyle: const TextStyle(color: AuthColors.textSub),
        filled: true,
        fillColor: AuthColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AuthColors.textMainWithOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AuthColors.primary, width: 1.5),
        ),
      ),
      style: const TextStyle(color: AuthColors.textMain),
    );
  }

  Widget _buildRecipientSelector() {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: AuthColors.primary.withValues(alpha: 0.2),
        highlightColor: AuthColors.primary.withValues(alpha: 0.1),
      ),
      child: ExpansionTile(
        iconColor: AuthColors.textSub,
        collapsedIconColor: AuthColors.textSub,
        title: const Text(
          'Notification Recipients',
          style: TextStyle(
            color: AuthColors.textMain,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          '${_selectedRecipientIds.length} selected',
          style: const TextStyle(color: AuthColors.textSub, fontSize: 13),
        ),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _availableUserIds.length,
              itemBuilder: (context, index) {
                final uid = _availableUserIds[index];
                final sel = _selectedRecipientIds.contains(uid);
                return CheckboxListTile(
                  title: Text(
                    _userIdToName[uid] ?? uid,
                    style: const TextStyle(
                      color: AuthColors.textMain,
                      fontSize: 14,
                    ),
                  ),
                  value: sel,
                  activeColor: AuthColors.primary,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedRecipientIds.add(uid);
                      } else {
                        _selectedRecipientIds.remove(uid);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(String organizationId) {
    return BlocConsumer<GeofencesCubit, GeofencesState>(
      listener: (context, state) {
        if (state.status == ViewStatus.success) {
          context.go('/locations-geofences');
        }
        if (state.status == ViewStatus.failure && state.message != null) {
          DashSnackbar.show(context, message: state.message!, isError: true);
        }
      },
      builder: (context, state) {
        final busy = state.status == ViewStatus.loading;
        return SizedBox(
          width: double.infinity,
          child: DashButton(
            label: widget.geofenceId != null ? 'Update Geofence' : 'Create Geofence',
            onPressed: busy ? null : () => _save(organizationId),
          ),
        );
      },
    );
  }

  void _save(String organizationId) {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a geofence name')),
      );
      return;
    }
    if (_location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not found')),
      );
      return;
    }
    if (_selectedType == core_models.GeofenceType.polygon &&
        _polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Polygon needs at least 3 points')),
      );
      return;
    }

    final g = core_models.Geofence(
      id: widget.geofenceId ?? '',
      organizationId: organizationId,
      locationId: _location!.id,
      name: name,
      type: _selectedType,
      centerLat: _centerPoint.latitude,
      centerLng: _centerPoint.longitude,
      radiusMeters:
          _selectedType == core_models.GeofenceType.circle ? _radiusMeters : null,
      polygonPoints: _selectedType == core_models.GeofenceType.polygon
          ? _polygonPoints
              .map((p) => core_models.LatLng(p.latitude, p.longitude))
              .toList()
          : null,
      notificationRecipientIds: List.from(_selectedRecipientIds),
      isActive: true,
    );

    if (widget.geofenceId != null) {
      context.read<GeofencesCubit>().updateGeofence(g);
    } else {
      context.read<GeofencesCubit>().createGeofence(g);
    }
  }
}
