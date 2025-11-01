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

class VehicleManagementView extends StatelessWidget {
  final String organizationId;
  final int userRole;
  final VoidCallback? onBack;

  const VehicleManagementView({
    super.key,
    required this.organizationId,
    required this.userRole,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<VehicleBloc, VehicleState>(
      listener: (context, state) {
        if (state is VehicleOperationSuccess) {
          CustomSnackBar.showSuccess(context, state.message);
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
              onBack: onBack,
              role: _getRoleString(userRole),
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
              // Show loading on initial state or loading state
              if (state is VehicleInitial || state is VehicleLoading) {
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
                              LoadVehicles(organizationId),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              if (state is VehicleEmpty) {
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
                          state.searchQuery != null
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
                          state.searchQuery != null
                              ? 'No vehicles match your search criteria'
                              : 'Add your first vehicle to get started',
                          style: const TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppTheme.spacingLg),
                        if (state.searchQuery != null)
                          CustomButton(
                            text: 'Clear Search',
                            variant: CustomButtonVariant.outline,
                            onPressed: () {
                              context.read<VehicleBloc>().add(const ResetSearch());
                              context.read<VehicleBloc>().add(
                                LoadVehicles(organizationId),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                );
              }
              
              if (state is VehicleLoaded) {
                return _buildVehiclesTable(context, state.vehicles);
              }
              
              return const SizedBox.shrink();
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
        // Add Vehicle button on the left (matching PaveBoard layout)
        CustomButton(
          text: '➕ Add Vehicle',
          variant: CustomButtonVariant.primary,
          onPressed: () => _showAddVehicleDialog(context),
        ),
        const Spacer(),
        // Search field on the right (matching PaveBoard layout)
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
                      LoadVehicles(organizationId),
                    );
                  } else {
                    context.read<VehicleBloc>().add(
                      SearchVehicles(
                        organizationId: organizationId,
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
                            LoadVehicles(organizationId),
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

  Widget _buildVehiclesTable(BuildContext context, List<Vehicle> vehicles) {
    // Calculate minimum table width based on columns
    const double minTableWidth = 1400; // Approximate minimum for all columns
    
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
                  (Set<MaterialState> states) {
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
                      'VEHICLE ID',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
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
              rows: vehicles.map((vehicle) {
                return DataRow(
                  cells: [
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        child: Text(
                          vehicle.vehicleID,
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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

  void _submitVehicle(BuildContext context, Vehicle vehicle) {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated
        ? authState.firebaseUser.uid
        : const Uuid().v4();

    context.read<VehicleBloc>().add(
      AddVehicle(
        organizationId: organizationId,
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
        organizationId: organizationId,
        vehicleId: oldVehicle.id!,
        vehicle: newVehicle,
        userId: userId,
      ),
    );
  }

  void _deleteVehicle(BuildContext context, Vehicle vehicle) {
    context.read<VehicleBloc>().add(
      DeleteVehicle(
        organizationId: organizationId,
        vehicleId: vehicle.id!,
      ),
    );
  }
}

