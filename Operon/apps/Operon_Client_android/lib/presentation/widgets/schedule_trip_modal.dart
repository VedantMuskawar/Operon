import 'package:core_models/core_models.dart';
import 'package:core_ui/components/trip_scheduling/schedule_trip_modal.dart' as shared_modal;
import 'package:dash_mobile/data/repositories/scheduled_trips_repository.dart';
import 'package:dash_mobile/data/repositories/vehicles_repository.dart';
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/utils/network_error_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Android wrapper for the shared ScheduleTripModal
/// 
/// This wrapper provides Android-specific dependencies to the shared widget:
/// - ScheduledTripsRepository (implements ScheduledTripsRepositoryInterface)
/// - VehiclesRepository (implements VehiclesRepositoryInterface)
/// - ClientService for adding phone numbers
/// - NetworkErrorHelper for error formatting
/// - OrganizationContextCubit for organization access
class ScheduleTripModal extends StatelessWidget {
  const ScheduleTripModal({
    super.key,
    required this.order,
    required this.clientId,
    required this.clientName,
    required this.clientPhones,
    required this.onScheduled,
  });

  final Map<String, dynamic> order;
  final String clientId;
  final String clientName;
  final List<Map<String, dynamic>> clientPhones;
  final VoidCallback onScheduled;

  @override
  Widget build(BuildContext context) {
    final scheduledTripsRepo = context.read<ScheduledTripsRepository>();
      final vehiclesRepo = context.read<VehiclesRepository>();
    final clientService = ClientService();
    final orgContextCubit = context.read<OrganizationContextCubit>();

    // Create adapter classes that implement the interfaces
    return shared_modal.ScheduleTripModal(
      order: order,
      clientId: clientId,
      clientName: clientName,
      clientPhones: clientPhones,
      onScheduled: onScheduled,
      scheduledTripsRepository: _ScheduledTripsRepositoryAdapter(scheduledTripsRepo),
      vehiclesRepository: _VehiclesRepositoryAdapter(vehiclesRepo),
      addPhoneNumber: ({
        required String clientId,
        required String contactName,
        required String phoneNumber,
      }) async {
        await clientService.addContactToExistingClient(
          clientId: clientId,
          contactName: contactName,
          phoneNumber: phoneNumber,
        );
      },
      errorFormatter: (error) {
        return NetworkErrorHelper.isNetworkError(error)
            ? NetworkErrorHelper.getNetworkErrorMessage(error)
            : 'Failed to schedule trip: $error';
      },
      organizationContextCubit: orgContextCubit,
    );
  }
}

/// Adapter that makes ScheduledTripsRepository implement ScheduledTripsRepositoryInterface
class _ScheduledTripsRepositoryAdapter implements shared_modal.ScheduledTripsRepositoryInterface {
  final ScheduledTripsRepository _repo;

  _ScheduledTripsRepositoryAdapter(this._repo);

  Future<String> createScheduledTrip({
    required String organizationId,
    required String orderId,
    required String clientId,
    required String clientName,
    required String customerNumber,
    String? clientPhone,
    required String paymentType,
    required DateTime scheduledDate,
    required String scheduledDay,
    required String vehicleId,
    required String vehicleNumber,
    required String? driverId,
    required String? driverName,
    required String? driverPhone,
    required int slot,
    required String slotName,
    required Map<String, dynamic> deliveryZone,
    required List<dynamic> items,
    Map<String, dynamic>? pricing,
    bool? includeGstInTotal,
    required String priority,
    required String createdBy,
    int? itemIndex,
    String? productId,
    String? meterType,
  }) {
    return _repo.createScheduledTrip(
      organizationId: organizationId,
      orderId: orderId,
      clientId: clientId,
      clientName: clientName,
      customerNumber: customerNumber,
      clientPhone: clientPhone,
      paymentType: paymentType,
      scheduledDate: scheduledDate,
      scheduledDay: scheduledDay,
      vehicleId: vehicleId,
      vehicleNumber: vehicleNumber,
      driverId: driverId,
      driverName: driverName,
      driverPhone: driverPhone,
      slot: slot,
      slotName: slotName,
      deliveryZone: deliveryZone,
      items: items,
      pricing: pricing,
      includeGstInTotal: includeGstInTotal,
      priority: priority,
      createdBy: createdBy,
      itemIndex: itemIndex,
      productId: productId,
      meterType: meterType,
    );
  }

  Future<List<Map<String, dynamic>>> getScheduledTripsForDayAndVehicle({
    required String organizationId,
    required String scheduledDay,
    required DateTime scheduledDate,
    required String vehicleId,
  }) {
    return _repo.getScheduledTripsForDayAndVehicle(
      organizationId: organizationId,
      scheduledDay: scheduledDay,
      scheduledDate: scheduledDate,
      vehicleId: vehicleId,
    );
  }
}

/// Adapter that makes VehiclesRepository implement VehiclesRepositoryInterface
class _VehiclesRepositoryAdapter implements shared_modal.VehiclesRepositoryInterface {
  final VehiclesRepository _repo;

  _VehiclesRepositoryAdapter(this._repo);

  Future<List<Vehicle>> fetchVehicles(String organizationId) {
    return _repo.fetchVehicles(organizationId);
  }
}
