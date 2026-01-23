import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart' as core_models;
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/repositories/geofences_repository.dart';
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
  List<LatLng> _polygonPoints = [];
  bool _isDrawingPolygon = false;
  GoogleMapController? _mapController;
  final _nameController = TextEditingController();
  List<String> _selectedRecipientIds = [];
  List<String> _availableUserIds = [];
  Map<String, String> _userIdToName = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    if (organization == null) return;

    // Load users for recipient selection
    final usersRepo = context.read<UsersRepository>();
    final users = await usersRepo.fetchOrgUsers(organization.id);
    setState(() {
      _availableUserIds = users.map((u) => u.id).toList();
      _userIdToName = {for (var u in users) u.id: u.name};
    });

    // Load existing geofence if editing
    if (widget.geofenceId != null) {
      final geofencesRepo = context.read<GeofencesRepository>();
      final geofence = await geofencesRepo.fetchGeofence(
        orgId: organization.id,
        geofenceId: widget.geofenceId!,
      );
      if (geofence != null) {
        _nameController.text = geofence.name;
        _selectedType = geofence.type;
        _centerPoint = LatLng(geofence.centerLat, geofence.centerLng);
        _radiusMeters = geofence.radiusMeters ?? 100.0;
        if (geofence.polygonPoints != null) {
          _polygonPoints = geofence.polygonPoints!
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList();
        }
        _selectedRecipientIds = geofence.notificationRecipientIds;
      }
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
      return const Scaffold(
        body: Center(child: Text('No organization selected')),
      );
    }

    return PageWorkspaceLayout(
      title: widget.geofenceId != null ? 'Edit Geofence' : 'Create Geofence',
      currentIndex: -1,
      onNavTap: (index) => context.go('/home?section=$index'),
      onBack: () => context.go('/locations-geofences'),
      child: MultiBlocProvider(
        providers: [
          BlocProvider<GeofencesCubit>(
            create: (context) => GeofencesCubit(
              repository: context.read<GeofencesRepository>(),
              organizationId: organization.id,
            ),
          ),
        ],
        child: _GeofenceEditorContent(
          organizationId: organization.id,
          locationId: widget.locationId,
          geofenceId: widget.geofenceId,
          selectedType: _selectedType,
          onTypeChanged: (type) => setState(() {
            _selectedType = type;
            _resetGeofence();
          }),
          radiusMeters: _radiusMeters,
          onRadiusChanged: (radius) => setState(() => _radiusMeters = radius),
          centerPoint: _centerPoint,
          onCenterChanged: (point) => setState(() => _centerPoint = point),
          polygonPoints: _polygonPoints,
          isDrawingPolygon: _isDrawingPolygon,
          onPolygonPointAdded: (point) => setState(() {
            _polygonPoints.add(point);
            _updatePolygon();
          }),
          onStartDrawing: () => setState(() {
            _isDrawingPolygon = true;
            _polygonPoints.clear();
          }),
          onFinishDrawing: () {
            if (_polygonPoints.length < 3) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Polygon needs at least 3 points')),
              );
              return;
            }
            setState(() => _isDrawingPolygon = false);
          },
          onClearPolygon: () => setState(() {
            _polygonPoints.clear();
          }),
          nameController: _nameController,
          selectedRecipientIds: _selectedRecipientIds,
          availableUserIds: _availableUserIds,
          userIdToName: _userIdToName,
          onRecipientsChanged: (ids) => setState(() => _selectedRecipientIds = ids),
          onMapControllerCreated: (controller) => _mapController = controller,
        ),
      ),
    );
  }

  void _resetGeofence() {
    _radiusMeters = 100.0;
    _polygonPoints.clear();
    _isDrawingPolygon = false;
  }

  void _updatePolygon() {
    // Trigger rebuild
    setState(() {});
  }
}

class _GeofenceEditorContent extends StatelessWidget {
  const _GeofenceEditorContent({
    required this.organizationId,
    this.locationId,
    this.geofenceId,
    required this.selectedType,
    required this.onTypeChanged,
    required this.radiusMeters,
    required this.onRadiusChanged,
    required this.centerPoint,
    required this.onCenterChanged,
    required this.polygonPoints,
    required this.isDrawingPolygon,
    required this.onPolygonPointAdded,
    required this.onStartDrawing,
    required this.onFinishDrawing,
    required this.onClearPolygon,
    required this.nameController,
    required this.selectedRecipientIds,
    required this.availableUserIds,
    required this.userIdToName,
    required this.onRecipientsChanged,
    required this.onMapControllerCreated,
  });

  final String organizationId;
  final String? locationId;
  final String? geofenceId;
  final core_models.GeofenceType selectedType;
  final ValueChanged<core_models.GeofenceType> onTypeChanged;
  final double radiusMeters;
  final ValueChanged<double> onRadiusChanged;
  final LatLng centerPoint;
  final ValueChanged<LatLng> onCenterChanged;
  final List<LatLng> polygonPoints;
  final bool isDrawingPolygon;
  final ValueChanged<LatLng> onPolygonPointAdded;
  final VoidCallback onStartDrawing;
  final VoidCallback onFinishDrawing;
  final VoidCallback onClearPolygon;
  final TextEditingController nameController;
  final List<String> selectedRecipientIds;
  final List<String> availableUserIds;
  final Map<String, String> userIdToName;
  final ValueChanged<List<String>> onRecipientsChanged;
  final ValueChanged<GoogleMapController> onMapControllerCreated;

  @override
  Widget build(BuildContext context) {
    final circles = <Circle>{};
    final polygons = <Polygon>{};
    final markers = <Marker>{};

    if (selectedType == core_models.GeofenceType.circle) {
      circles.add(
        Circle(
          circleId: const CircleId('geofence'),
          center: centerPoint,
          radius: radiusMeters,
          fillColor: const Color(0xFF6F4BFF).withValues(alpha: 0.3),
          strokeColor: const Color(0xFF6F4BFF),
          strokeWidth: 2,
        ),
      );
      markers.add(
        Marker(
          markerId: const MarkerId('center'),
          position: centerPoint,
          draggable: true,
          onDragEnd: (newPosition) => onCenterChanged(newPosition),
        ),
      );
    } else if (selectedType == core_models.GeofenceType.polygon && polygonPoints.isNotEmpty) {
      polygons.add(
        Polygon(
          polygonId: const PolygonId('geofence'),
          points: polygonPoints,
          fillColor: const Color(0xFF6F4BFF).withValues(alpha: 0.3),
          strokeColor: const Color(0xFF6F4BFF),
          strokeWidth: 2,
        ),
      );
      // Add markers for polygon points
      for (int i = 0; i < polygonPoints.length; i++) {
        markers.add(
          Marker(
            markerId: MarkerId('point_$i'),
            position: polygonPoints[i],
            draggable: true,
            onDragEnd: (newPosition) {
              // Update polygon point
              // This would require state management - simplified for now
            },
          ),
        );
      }
    }

    return Column(
      children: [
        // Type selector
        Container(
          padding: const EdgeInsets.all(16),
          child: SegmentedButton<core_models.GeofenceType>(
            segments: [
              ButtonSegment<core_models.GeofenceType>(
                value: core_models.GeofenceType.circle,
                label: const Text('Circle'),
                icon: const Icon(Icons.radio_button_unchecked),
              ),
              ButtonSegment<core_models.GeofenceType>(
                value: core_models.GeofenceType.polygon,
                label: const Text('Polygon'),
                icon: const Icon(Icons.polyline),
              ),
            ],
            selected: {selectedType},
            onSelectionChanged: (Set<core_models.GeofenceType> newSelection) {
              onTypeChanged(newSelection.first);
            },
          ),
        ),

        // Map
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: centerPoint,
                  zoom: 15,
                ),
                onMapCreated: (controller) {
                  controller.setMapStyle(darkMapStyle);
                  onMapControllerCreated(controller);
                },
                onTap: selectedType == core_models.GeofenceType.polygon && isDrawingPolygon
                    ? onPolygonPointAdded
                    : null,
                circles: circles,
                polygons: polygons,
                markers: markers,
              ),
            ),
          ),
        ),

        // Controls
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F2C),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selectedType == core_models.GeofenceType.circle) _buildCircleControls() else _buildPolygonControls(),
              const SizedBox(height: 16),
              _buildNameField(),
              const SizedBox(height: 16),
              _buildRecipientSelector(context),
              const SizedBox(height: 16),
              _buildSaveButton(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCircleControls() {
    return Column(
      children: [
        Text(
          'Radius: ${radiusMeters.toStringAsFixed(0)} meters',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        Slider(
          value: radiusMeters,
          min: 10,
          max: 5000,
          divisions: 99,
          onChanged: onRadiusChanged,
        ),
      ],
    );
  }

  Widget _buildPolygonControls() {
    return Column(
      children: [
        if (!isDrawingPolygon)
          DashButton(
            label: 'Start Drawing',
            onPressed: onStartDrawing,
          )
        else
          Row(
            children: [
              Expanded(
                child: DashButton(
                  label: 'Finish Drawing',
                  onPressed: onFinishDrawing,
                ),
              ),
              const SizedBox(width: 8),
              if (polygonPoints.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70),
                  onPressed: onClearPolygon,
                  tooltip: 'Clear',
                ),
            ],
          ),
        if (polygonPoints.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${polygonPoints.length} points${polygonPoints.length < 3 ? ' (need at least 3)' : ''}',
              style: TextStyle(
                color: polygonPoints.length < 3 ? Colors.orange : Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextField(
      controller: nameController,
      decoration: const InputDecoration(
        labelText: 'Geofence Name',
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
    );
  }

  Widget _buildRecipientSelector(BuildContext context) {
    return ExpansionTile(
      title: const Text(
        'Notification Recipients',
        style: TextStyle(color: Colors.white, fontSize: 14),
      ),
      subtitle: Text(
        '${selectedRecipientIds.length} selected',
        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
      ),
      children: [
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableUserIds.length,
            itemBuilder: (context, index) {
              final userId = availableUserIds[index];
              final isSelected = selectedRecipientIds.contains(userId);
              return CheckboxListTile(
                title: Text(
                  userIdToName[userId] ?? userId,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                value: isSelected,
                onChanged: (value) {
                  final newList = List<String>.from(selectedRecipientIds);
                  if (value == true) {
                    newList.add(userId);
                  } else {
                    newList.remove(userId);
                  }
                  onRecipientsChanged(newList);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    return BlocListener<GeofencesCubit, GeofencesState>(
      listener: (context, state) {
        if (state.status == ViewStatus.success) {
          context.go('/locations-geofences');
        } else if (state.status == ViewStatus.failure && state.message != null) {
          DashSnackbar.show(
            context,
            message: state.message!,
            isError: true,
          );
        }
      },
      child: SizedBox(
        width: double.infinity,
        child: DashButton(
          label: geofenceId != null ? 'Update Geofence' : 'Create Geofence',
          onPressed: () => _saveGeofence(context),
        ),
      ),
    );
  }

  void _saveGeofence(BuildContext context) {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a geofence name')),
      );
      return;
    }

    if (selectedType == core_models.GeofenceType.polygon && polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Polygon needs at least 3 points')),
      );
      return;
    }

    final geofence = core_models.Geofence(
      id: geofenceId ?? '',
      organizationId: organizationId,
      locationId: locationId ?? '',
      name: nameController.text.trim(),
      type: selectedType,
      centerLat: centerPoint.latitude,
      centerLng: centerPoint.longitude,
      radiusMeters: selectedType == core_models.GeofenceType.circle ? radiusMeters : null,
      polygonPoints: selectedType == core_models.GeofenceType.polygon
          ? polygonPoints.map((p) => core_models.LatLng(p.latitude, p.longitude)).toList()
          : null,
      notificationRecipientIds: selectedRecipientIds,
      isActive: true,
    );

    if (geofenceId != null) {
      context.read<GeofencesCubit>().updateGeofence(geofence);
    } else {
      context.read<GeofencesCubit>().createGeofence(geofence);
    }
  }
}
