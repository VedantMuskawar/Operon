import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/app_theme.dart';
import '../../bloc/android_vehicle_bloc.dart';
import '../../repositories/android_vehicle_repository.dart';
import '../../models/vehicle.dart';
import '../widgets/android_vehicle_form_dialog.dart';

class AndroidVehicleManagementPage extends StatelessWidget {
  final String organizationId;
  final String userId;

  const AndroidVehicleManagementPage({
    super.key,
    required this.organizationId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AndroidVehicleBloc(
        vehicleRepository: AndroidVehicleRepository(),
      )..add(AndroidLoadVehicles(organizationId)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vehicle Management'),
          backgroundColor: AppTheme.surfaceColor,
        ),
        backgroundColor: AppTheme.backgroundColor,
        body: BlocListener<AndroidVehicleBloc, AndroidVehicleState>(
          listener: (context, state) {
            if (state is AndroidVehicleOperationSuccess) {
              // Reload vehicles after successful operation
              context.read<AndroidVehicleBloc>().add(
                AndroidLoadVehicles(organizationId),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppTheme.successColor,
                  duration: const Duration(seconds: 2),
                ),
              );
            } else if (state is AndroidVehicleError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            }
          },
          child: BlocBuilder<AndroidVehicleBloc, AndroidVehicleState>(
            builder: (context, state) {
              if (state is AndroidVehicleLoading || state is AndroidVehicleInitial) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                  ),
                );
              }

              if (state is AndroidVehicleError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppTheme.errorColor,
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          state.message,
                          style: const TextStyle(color: AppTheme.textPrimaryColor),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          context.read<AndroidVehicleBloc>().add(
                            AndroidLoadVehicles(organizationId),
                          );
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (state is AndroidVehicleEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.two_wheeler,
                        size: 64,
                        color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No vehicles found',
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (state is AndroidVehicleLoaded) {
                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: state.vehicles.length,
                        itemBuilder: (context, index) {
                          final vehicle = state.vehicles[index];
                          return _buildVehicleCard(context, vehicle);
                        },
                      ),
                    ),
                    // Purple "+ NEW VEHICLE" button at bottom
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddVehicleDialog(context),
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text(
                            'NEW VEHICLE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }

              return const Center(
                child: Text(
                  'Unknown state',
                  style: TextStyle(color: AppTheme.textPrimaryColor),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleCard(BuildContext context, Vehicle vehicle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppTheme.borderColor,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showVehicleMenu(context, vehicle),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              // Motorcycle icon on left
              Icon(
                Icons.two_wheeler,
                color: AppTheme.textPrimaryColor,
                size: 32,
              ),
              const SizedBox(width: 16),
              // Vehicle number in center
              Expanded(
                child: Text(
                  vehicle.vehicleNo,
                  style: const TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Vertical ellipsis menu on right
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: AppTheme.textPrimaryColor,
                ),
                color: AppTheme.surfaceColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditVehicleDialog(context, vehicle);
                  } else if (value == 'delete') {
                    _showDeleteConfirmDialog(context, vehicle);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: AppTheme.textPrimaryColor, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Edit',
                          style: TextStyle(color: AppTheme.textPrimaryColor),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: AppTheme.errorColor, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Delete',
                          style: TextStyle(color: AppTheme.errorColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVehicleMenu(BuildContext context, Vehicle vehicle) {
    // Optionally show details or edit on tap
    _showEditVehicleDialog(context, vehicle);
  }

  void _showAddVehicleDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AndroidVehicleFormDialog(
        onSubmit: (vehicle) {
          context.read<AndroidVehicleBloc>().add(
            AndroidAddVehicle(
              organizationId: organizationId,
              vehicle: vehicle,
              userId: userId,
            ),
          );
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showEditVehicleDialog(BuildContext context, Vehicle vehicle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AndroidVehicleFormDialog(
        vehicle: vehicle,
        onSubmit: (vehicle) {
          context.read<AndroidVehicleBloc>().add(
            AndroidUpdateVehicle(
              organizationId: organizationId,
              vehicleId: vehicle.id!,
              vehicle: vehicle,
              userId: userId,
            ),
          );
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, Vehicle vehicle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text(
          'Delete Vehicle',
          style: TextStyle(color: AppTheme.textPrimaryColor),
        ),
        content: Text(
          'Are you sure you want to delete ${vehicle.vehicleNo}?',
          style: const TextStyle(color: AppTheme.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<AndroidVehicleBloc>().add(
                AndroidDeleteVehicle(
                  organizationId: organizationId,
                  vehicleId: vehicle.id!,
                ),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
