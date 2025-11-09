import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/animated_background.dart';
import '../../../../contexts/organization_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/page_container.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/form_container.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/custom_snackbar.dart';
import '../../../../core/widgets/realtime_list_cache_mixin.dart';
import '../../../../core/repositories/employee_repository.dart';
import '../../../../core/models/employee.dart';
import '../../bloc/vehicle_bloc.dart';
import '../../bloc/vehicle_event.dart';
import '../../bloc/vehicle_state.dart';
import '../../repositories/vehicle_repository.dart';
import '../../models/vehicle.dart';
import '../widgets/vehicle_form_dialog.dart';
import '../../../auth/bloc/auth_bloc.dart';
import 'package:uuid/uuid.dart';

class VehicleManagementPage extends StatelessWidget {
  final VoidCallback? onBack;

  const VehicleManagementPage({
    super.key,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return OrganizationAwareWidget(
      builder: (context, orgContext) {
        final organizationId = orgContext.organizationId;
        
        if (organizationId == null) {
          return Scaffold(
            body: Center(
              child: Text(
                'Organization not found',
                style: TextStyle(color: AppTheme.textPrimaryColor),
              ),
            ),
          );
        }

        return BlocProvider(
          create: (context) => VehicleBloc(
            vehicleRepository: VehicleRepository(),
          )..add(LoadVehicles(organizationId)),
          child: VehicleManagementView(
            organizationId: organizationId,
            userRole: orgContext.userRole ?? 0,
            onBack: onBack,
          ),
        );
      },
    );
  }
}

class VehicleManagementView extends StatefulWidget {
  const VehicleManagementView({
    super.key,
    required this.organizationId,
    required this.userRole,
    this.onBack,
  });

  final String organizationId;
  final int userRole;
  final VoidCallback? onBack;

  @override
  State<VehicleManagementView> createState() => _VehicleManagementViewState();
}

class _VehicleManagementViewState
    extends RealtimeListCacheState<VehicleManagementView, Vehicle> {
  final EmployeeRepository _employeeRepository = EmployeeRepository();

  List<Employee>? _driverCache;
  DateTime? _driverCacheAt;
  Future<List<Employee>>? _driversFuture;
  bool _showUnassignedOnly = false;
  String _driverSearchQuery = '';

  static const _driverCacheTtl = Duration(minutes: 5);

  Future<List<Employee>> _loadDrivers({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _driverCache != null &&
        _driverCacheAt != null &&
        DateTime.now().difference(_driverCacheAt!) < _driverCacheTtl) {
      return _applyDriverSearch(_driverCache!);
    }

    final drivers =
        await _employeeRepository.fetchDriverEmployees(widget.organizationId);
    _driverCache = drivers;
    _driverCacheAt = DateTime.now();
    return _applyDriverSearch(drivers);
  }

  Future<List<Employee>> _getDriversFuture({bool forceRefresh = false}) {
    final cacheExpired = _driverCacheAt == null ||
        DateTime.now().difference(_driverCacheAt!) >= _driverCacheTtl;

    if (forceRefresh) {
      _driverCache = null;
      _driverCacheAt = null;
    }

    if (forceRefresh ||
        _driversFuture == null ||
        _driverCache == null ||
        cacheExpired) {
      _driversFuture = _loadDrivers(forceRefresh: forceRefresh || cacheExpired);
    }

    return _driversFuture!;
  }

  void _refreshDrivers() {
    if (!mounted) return;
    setState(() {
      _driversFuture = _loadDrivers(forceRefresh: true);
    });
  }

  List<Employee> _applyDriverSearch(List<Employee> drivers) {
    final query = _driverSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return List<Employee>.from(drivers);
    return drivers
        .where((driver) =>
            driver.nameLowercase.contains(query) ||
            (driver.contactPhone?.toLowerCase().contains(query) ?? false) ||
            (driver.contactEmail?.toLowerCase().contains(query) ?? false))
        .toList(growable: false);
  }

  void _invalidateDriverCache() {
    _driverCache = null;
    _driverCacheAt = null;
    _driversFuture = null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<VehicleBloc, VehicleState>(
      listener: (context, state) {
        if (state is VehicleLoaded) {
          applyRealtimeItems(state.vehicles, searchQuery: state.searchQuery);
        } else if (state is VehicleEmpty) {
          applyRealtimeEmpty(searchQuery: state.searchQuery);
        } else if (state is VehicleInitial) {
          resetRealtimeSnapshot();
        } else if (state is VehicleOperationSuccess) {
          _invalidateDriverCache();
          CustomSnackBar.showSuccess(context, state.message);
        } else if (state is VehicleAssignmentConflict) {
          _handleAssignmentConflict(context, state);
        } else if (state is VehicleError) {
          CustomSnackBar.showError(context, state.message);
        }
      },
      child: PageContainer(
        fullHeight: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PageHeader(
              title: 'Vehicle Management',
              onBack: widget.onBack,
              role: _getRoleString(widget.userRole),
            ),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.95,
                  minWidth: 800,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: AppTheme.spacingLg),
                    _buildContent(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRoleString(int userRole) {
    switch (userRole) {
      case 0:
        return 'admin';
      case 1:
        return 'admin';
      case 2:
        return 'manager';
      case 3:
        return 'driver';
      default:
        return 'member';
    }
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter Bar - matching PaveBoard styling
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF181C1F),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingLg,
            vertical: AppTheme.spacingLg,
          ),
          child: _buildFilterBar(context),
        ),
        const SizedBox(height: AppTheme.spacingLg),
        
        // Vehicles Table - matching PaveBoard styling
        LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF141618).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
              // Header with emoji and title (matching PaveBoard)
              Row(
                children: [
                  const Text(
                    '🚜',
                    style: TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  const Text(
                    'Vehicles',
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingLg),
              BlocBuilder<VehicleBloc, VehicleState>(
            builder: (context, state) {
              final bool waitingForFirstLoad = !hasRealtimeData &&
                  (state is VehicleInitial || state is VehicleLoading);

              if (waitingForFirstLoad) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppTheme.spacing2xl),
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                );
              }

              if (state is VehicleError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacing2xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppTheme.errorColor,
                        ),
                        const SizedBox(height: AppTheme.spacingMd),
                        Text(
                          state.message,
                          style: const TextStyle(
                            color: AppTheme.errorColor,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppTheme.spacingMd),
                        CustomButton(
                          text: 'Retry',
                          variant: CustomButtonVariant.primary,
                          onPressed: () {
                            context.read<VehicleBloc>().add(
                              LoadVehicles(widget.organizationId),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (state is VehicleEmpty || (hasRealtimeData && realtimeItems.isEmpty)) {
                final String? searchQuery =
                    state is VehicleEmpty ? state.searchQuery : realtimeSearchQuery;
                return _buildEmptyVehiclesView(context, searchQuery);
              }

              final vehicles = state is VehicleLoaded ? state.vehicles : realtimeItems;

              if (vehicles.isEmpty) {
                return _buildEmptyVehiclesView(context, realtimeSearchQuery);
              }

              final table = _buildVehiclesTable(context, vehicles);
              final bool showBusyOverlay = hasRealtimeData &&
                  (state is VehicleLoading || state is VehicleOperating);

              return withRealtimeBusyOverlay(
                child: table,
                showOverlay: showBusyOverlay,
                overlayColor: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(16),
                progressIndicator: const CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                ),
              );
            },
                ),
              ],
            ),
          );
          },
        ),
        const SizedBox(height: AppTheme.spacingLg),
      ],
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return Row(
      children: [
        CustomButton(
          text: '➕ Add Vehicle',
          variant: CustomButtonVariant.primary,
          onPressed: () => _showAddVehicleDialog(context),
        ),
        const SizedBox(width: AppTheme.spacingLg),
        FilterChip(
          label: const Text('Unassigned only'),
          selected: _showUnassignedOnly,
          onSelected: (selected) {
            setState(() => _showUnassignedOnly = selected);
          },
        ),
        const Spacer(),
        SizedBox(
          width: 300,
          child: BlocBuilder<VehicleBloc, VehicleState>(
            builder: (context, state) {
              return CustomTextField(
                hintText: 'Search vehicles...',
                prefixIcon: const Icon(Icons.search, size: 18),
                variant: CustomTextFieldVariant.search,
                onChanged: (query) {
                  if (query.isEmpty) {
                    context.read<VehicleBloc>().add(const ResetSearch());
                    context.read<VehicleBloc>().add(
                      LoadVehicles(widget.organizationId),
                    );
                  } else {
                    context.read<VehicleBloc>().add(
                      SearchVehicles(
                        organizationId: widget.organizationId,
                        query: query,
                      ),
                    );
                  }
                },
                suffixIcon: state is VehicleLoaded &&
                        state.searchQuery != null &&
                        state.searchQuery!.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          context.read<VehicleBloc>().add(const ResetSearch());
                          context.read<VehicleBloc>().add(
                            LoadVehicles(widget.organizationId),
                          );
                        },
                      )
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyVehiclesView(BuildContext context, String? searchQuery) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing2xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🚜',
              style: TextStyle(fontSize: 64),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              searchQuery != null && searchQuery.isNotEmpty
                  ? 'No Vehicles Found'
                  : 'No Vehicles',
              style: const TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              searchQuery != null && searchQuery.isNotEmpty
                  ? 'No vehicles match your search criteria'
                  : 'Add your first vehicle to get started',
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            if (searchQuery != null && searchQuery.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacingLg),
              CustomButton(
                text: 'Clear Search',
                variant: CustomButtonVariant.outline,
                onPressed: () {
                  context.read<VehicleBloc>().add(const ResetSearch());
                  context.read<VehicleBloc>().add(
                        LoadVehicles(widget.organizationId),
                      );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVehiclesTable(BuildContext context, List<Vehicle> vehicles) {
    final filteredVehicles = _showUnassignedOnly
        ? vehicles.where((vehicle) => vehicle.assignedDriverId == null).toList()
        : vehicles;

    if (filteredVehicles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXl),
        child: Center(
          child: Text(
            _showUnassignedOnly
                ? 'All vehicles have drivers assigned.'
                : 'No vehicles to display.',
            style: const TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    const double minTableWidth = 1350;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final tableWidth = availableWidth > minTableWidth
            ? availableWidth
            : minTableWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DataTable(
                headingRowHeight: 52,
                dataRowMinHeight: 60,
                dataRowMaxHeight: 80,
                horizontalMargin: 0,
                columnSpacing: 24,
                headingRowColor: MaterialStateProperty.all(
                  const Color(0xFF1F2937).withValues(alpha: 0.8),
                ),
                dataRowColor: MaterialStateProperty.resolveWith<Color?>(
                  (states) {
                    if (states.contains(MaterialState.selected)) {
                      return const Color(0xFF374151).withValues(alpha: 0.5);
                    }
                    if (states.contains(MaterialState.hovered)) {
                      return const Color(0xFF374151).withValues(alpha: 0.3);
                    }
                    return Colors.transparent;
                  },
                ),
                dividerThickness: 1,
                columns: [
                  DataColumn(
                    label: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'VEHICLE NO',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'TYPE',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'METER TYPE',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'CAPACITY',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'STATUS',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'WEEKLY CAPACITY',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'DRIVER',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'ACTIONS',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
                rows: filteredVehicles.map((vehicle) {
                  return DataRow(
                    cells: [
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        child: Text(
                          vehicle.vehicleNo,
                          style: const TextStyle(
                            color: AppTheme.textPrimaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        child: Text(
                          vehicle.type,
                          style: const TextStyle(
                            color: AppTheme.textPrimaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        child: Text(
                          vehicle.meterType,
                          style: const TextStyle(
                            color: AppTheme.textPrimaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        child: Text(
                          vehicle.vehicleQuantity.toString(),
                          style: const TextStyle(
                            color: AppTheme.textPrimaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        child: _buildStatusBadge(vehicle.status),
                      ),
                    ),
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        child: _buildWeeklyCapacity(vehicle.weeklyCapacity),
                      ),
                    ),
                  DataCell(
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      child: _buildDriverInfo(vehicle),
                    ),
                  ),
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                          IconButton(
                            icon: const Icon(Icons.person_pin_circle_outlined, size: 18),
                            color: AppTheme.primaryColor,
                            onPressed: () => _showAssignDriverDialog(context, vehicle),
                            style: IconButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                              padding: const EdgeInsets.all(8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingXs),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              color: AppTheme.warningColor,
                              onPressed: () => _showEditVehicleDialog(context, vehicle),
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.warningColor.withValues(alpha: 0.1),
                                padding: const EdgeInsets.all(8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingXs),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              color: AppTheme.errorColor,
                              onPressed: () => _showDeleteConfirmation(context, vehicle),
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.errorColor.withValues(alpha: 0.1),
                                padding: const EdgeInsets.all(8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    if (status == 'Active') {
      color = AppTheme.successColor;
    } else if (status == 'Inactive') {
      color = AppTheme.textTertiaryColor;
    } else {
      color = AppTheme.warningColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSm,
        vertical: AppTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildWeeklyCapacity(Map<String, int> capacity) {
    const days = ['Thu', 'Fri', 'Sat', 'Sun', 'Mon', 'Tue', 'Wed'];
    
    return SizedBox(
      width: 320,
      child: Text(
        days.map((day) => '$day: ${capacity[day] ?? 0}').join(', '),
        style: const TextStyle(
          color: AppTheme.textSecondaryColor,
          fontSize: 14,
        ),
        maxLines: 4,
        overflow: TextOverflow.visible,
      ),
    );
  }

  Widget _buildDriverInfo(Vehicle vehicle) {
    final name = vehicle.assignedDriverName;
    final contact = vehicle.assignedDriverContact;

    if (name == null || name.isEmpty) {
      return Tooltip(
        message: 'No driver assigned',
        child: Chip(
          label: const Text('Unassigned'),
          backgroundColor: AppTheme.textSecondaryColor.withValues(alpha: 0.12),
          labelStyle: const TextStyle(color: AppTheme.textSecondaryColor),
        ),
      );
    }

    String assignedInfo = 'Assigned driver';
    final assignedAt = vehicle.assignedDriverAt?.toLocal();
    if (assignedAt != null) {
      final formatted = assignedAt.toString().split('.').first;
      assignedInfo = 'Assigned on $formatted\nby ${vehicle.assignedDriverBy ?? 'unknown'}';
    }

    return Tooltip(
      message: contact != null && contact.isNotEmpty
          ? '$assignedInfo\nContact: $contact'
          : assignedInfo,
      child: Chip(
        label: Text(name),
        avatar: const Icon(Icons.person, size: 16, color: AppTheme.textPrimaryColor),
        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
        labelStyle: const TextStyle(
          color: AppTheme.textPrimaryColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showAddVehicleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => VehicleFormDialog(
        onSubmit: (vehicle) {
          Navigator.of(dialogContext).pop();
          _submitVehicle(context, vehicle);
        },
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  void _showEditVehicleDialog(BuildContext context, Vehicle vehicle) {
    showDialog(
      context: context,
      builder: (dialogContext) => VehicleFormDialog(
        vehicle: vehicle,
        onSubmit: (updatedVehicle) {
          Navigator.of(dialogContext).pop();
          _updateVehicle(context, vehicle, updatedVehicle);
        },
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Vehicle vehicle) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          side: BorderSide(
            color: AppTheme.borderColor,
            width: 1,
          ),
        ),
        title: const Text(
          'Delete Vehicle',
          style: TextStyle(
            color: AppTheme.errorColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to delete vehicle "${vehicle.vehicleNo}"?',
          style: const TextStyle(color: AppTheme.textPrimaryColor),
        ),
        actions: [
          CustomButton(
            text: 'Cancel',
            variant: CustomButtonVariant.outline,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          const SizedBox(width: AppTheme.spacingSm),
          CustomButton(
            text: 'Delete',
            variant: CustomButtonVariant.danger,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _deleteVehicle(context, vehicle);
            },
          ),
        ],
      ),
    );
  }

  void _showAssignDriverDialog(BuildContext context, Vehicle vehicle) {
    final vehicleBloc = context.read<VehicleBloc>();
    final authBloc = context.read<AuthBloc>();

    final blocState = vehicleBloc.state;
    final Map<String, Vehicle> activeAssignments = {};
    if (blocState is VehicleLoaded) {
      for (final v in blocState.vehicles) {
        if (v.assignedDriverId != null) {
          activeAssignments[v.assignedDriverId!] = v;
        }
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return FutureBuilder<List<Employee>>(
          future: _getDriversFuture(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const AlertDialog(
                backgroundColor: AppTheme.surfaceColor,
                content: SizedBox(
                  height: 120,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return AlertDialog(
                backgroundColor: AppTheme.surfaceColor,
                title: const Text(
                  'Unable to load drivers',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
                content: Text(
                  snapshot.error.toString(),
                  style: const TextStyle(color: AppTheme.textPrimaryColor),
                ),
                actions: [
                  CustomButton(
                    text: 'Close',
                    variant: CustomButtonVariant.primary,
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              );
            }

            final initialDrivers = snapshot.data ?? [];
            bool ascending = true;

            return StatefulBuilder(
              builder: (context, setInnerState) {
                List<Employee> visibleDrivers = _applyDriverSearch(initialDrivers);
                visibleDrivers.sort((a, b) => ascending
                    ? a.nameLowercase.compareTo(b.nameLowercase)
                    : b.nameLowercase.compareTo(a.nameLowercase));

                return AlertDialog(
                  backgroundColor: AppTheme.surfaceColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                    side: BorderSide(color: AppTheme.borderColor, width: 1),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Assign Driver',
                              style: TextStyle(
                                color: AppTheme.textPrimaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${visibleDrivers.length} available driver${visibleDrivers.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                color: AppTheme.textSecondaryColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          ascending ? Icons.sort_by_alpha : Icons.sort,
                          size: 18,
                        ),
                        tooltip: ascending
                            ? 'Sort Z-A'
                            : 'Sort A-Z',
                        onPressed: () {
                          setInnerState(() {
                            ascending = !ascending;
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18),
                        tooltip: 'Refresh drivers',
                        onPressed: () {
                          setInnerState(() {
                            _driverSearchQuery = '';
                          });
                          _refreshDrivers();
                        },
                      ),
                    ],
                  ),
                  content: SizedBox(
                    width: 480,
                    height: visibleDrivers.isEmpty ? 160 : 360,
                    child: Column(
                      children: [
                        CustomTextField(
                          hintText: 'Search drivers...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          onChanged: (value) {
                            setInnerState(() {
                              _driverSearchQuery = value;
                            });
                          },
                        ),
                        const SizedBox(height: AppTheme.spacingMd),
                        if (visibleDrivers.isEmpty)
                          const Expanded(
                            child: Center(
                              child: Text(
                                'No active drivers available. Add or activate driver employees first.',
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: ListView.separated(
                              itemCount: visibleDrivers.length,
                              separatorBuilder: (_, __) => const Divider(
                                height: 1,
                                color: Color(0x112E3440),
                              ),
                              itemBuilder: (context, index) {
                                final driver = visibleDrivers[index];
                                final subtitle = driver.contactPhone ?? driver.contactEmail;
                                final assignedVehicle = activeAssignments[driver.id];
                                final bool isAssignedElsewhere = assignedVehicle != null &&
                                    assignedVehicle.id != vehicle.id;

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 2,
                                  ),
                                  title: Text(
                                    driver.name,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (subtitle != null)
                                        Text(
                                          subtitle,
                                          style: const TextStyle(
                                            color: AppTheme.textSecondaryColor,
                                            fontSize: 13,
                                          ),
                                        ),
                                      Text(
                                        'Start: ${driver.startDate.toLocal().toString().split(' ').first}',
                                        style: const TextStyle(
                                          color: AppTheme.textTertiaryColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (isAssignedElsewhere)
                                        Text(
                                          'Currently assigned to ${assignedVehicle!.vehicleNo}',
                                          style: const TextStyle(
                                            color: AppTheme.warningColor,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: vehicle.assignedDriverId == driver.id
                                      ? const Icon(Icons.check_circle, color: AppTheme.successColor)
                                      : isAssignedElsewhere
                                          ? const Icon(Icons.warning_amber_rounded,
                                              color: AppTheme.warningColor)
                                          : null,
                                  onTap: () {
                                    final authState = authBloc.state;
                                    final userId = authState is AuthAuthenticated
                                        ? authState.firebaseUser.uid
                                        : const Uuid().v4();

                                    vehicleBloc.add(
                                      AssignDriverToVehicle(
                                        organizationId: widget.organizationId,
                                        vehicleId: vehicle.id!,
                                        driverId: driver.id,
                                        driverName: driver.name,
                                        driverContact: subtitle,
                                        userId: userId,
                                        force: isAssignedElsewhere,
                                      ),
                                    );

                                    Navigator.of(dialogContext).pop();
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  actions: [
                    if (vehicle.assignedDriverId != null)
                      CustomButton(
                        text: 'Unassign Driver',
                        variant: CustomButtonVariant.outline,
                        onPressed: () {
                          final authState = authBloc.state;
                          final userId = authState is AuthAuthenticated
                              ? authState.firebaseUser.uid
                              : const Uuid().v4();

                          vehicleBloc.add(
                            AssignDriverToVehicle(
                              organizationId: widget.organizationId,
                              vehicleId: vehicle.id!,
                              driverId: null,
                              driverName: null,
                              driverContact: null,
                              userId: userId,
                            ),
                          );

                          Navigator.of(dialogContext).pop();
                        },
                      ),
                    CustomButton(
                      text: 'Close',
                      variant: CustomButtonVariant.ghost,
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _submitVehicle(BuildContext context, Vehicle vehicle) {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated
        ? authState.firebaseUser.uid
        : const Uuid().v4();

    context.read<VehicleBloc>().add(
      AddVehicle(
        organizationId: widget.organizationId,
        vehicle: vehicle,
        userId: userId,
      ),
    );
  }

  void _updateVehicle(BuildContext context, Vehicle oldVehicle, Vehicle newVehicle) {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated
        ? authState.firebaseUser.uid
        : const Uuid().v4();

    context.read<VehicleBloc>().add(
      UpdateVehicle(
        organizationId: widget.organizationId,
        vehicleId: oldVehicle.id!,
        vehicle: newVehicle,
        userId: userId,
      ),
    );
  }

  void _deleteVehicle(BuildContext context, Vehicle vehicle) {
    context.read<VehicleBloc>().add(
      DeleteVehicle(
        organizationId: widget.organizationId,
        vehicleId: vehicle.id!,
      ),
    );
  }

  void _handleAssignmentConflict(
    BuildContext context,
    VehicleAssignmentConflict conflict,
  ) {
    CustomSnackBar.showWarning(
      context,
      'Driver already assigned to vehicle ${conflict.conflictingVehicleNo}.',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          side: BorderSide(color: AppTheme.borderColor, width: 1),
        ),
        title: const Text(
          'Driver Assignment Conflict',
          style: TextStyle(
            color: AppTheme.warningColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Assigning ${conflict.driverName ?? 'this driver'} will unassign them from vehicle ${conflict.conflictingVehicleNo}. Continue?',
          style: const TextStyle(color: AppTheme.textPrimaryColor),
        ),
        actions: [
          CustomButton(
            text: 'Cancel',
            variant: CustomButtonVariant.outline,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          CustomButton(
            text: 'Override',
            variant: CustomButtonVariant.primary,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              final authState = context.read<AuthBloc>().state;
              final userId = authState is AuthAuthenticated
                  ? authState.firebaseUser.uid
                  : const Uuid().v4();

              context.read<VehicleBloc>().add(
                    AssignDriverToVehicle(
                      organizationId: conflict.organizationId,
                      vehicleId: conflict.vehicleId,
                      driverId: conflict.driverId,
                      driverName: conflict.driverName,
                      driverContact: conflict.driverContact,
                      userId: userId,
                      force: true,
                    ),
                  );
            },
          ),
        ],
      ),
    );
  }
}

