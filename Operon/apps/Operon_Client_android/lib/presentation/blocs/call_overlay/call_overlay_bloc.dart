import 'dart:developer' as developer;

import 'package:bloc/bloc.dart';
import 'package:dash_mobile/data/repositories/caller_overlay_repository.dart';
import 'package:dash_mobile/data/utils/caller_overlay_utils.dart';
import 'package:dash_mobile/presentation/blocs/call_overlay/call_overlay_event.dart';
import 'package:dash_mobile/presentation/blocs/call_overlay/call_overlay_state.dart';

void _log(String msg) {
  developer.log(msg, name: 'CallOverlayBloc');
}

class CallOverlayBloc extends Bloc<CallOverlayEvent, CallOverlayState> {
  CallOverlayBloc({
    required CallerOverlayRepository repository,
  })  : _repository = repository,
        super(const CallOverlayState()) {
    on<PhoneNumberReceived>(_onPhoneNumberReceived);
  }

  final CallerOverlayRepository _repository;

  Future<void> _onPhoneNumberReceived(
    PhoneNumberReceived event,
    Emitter<CallOverlayState> emit,
  ) async {
    _log('📞 PhoneNumberReceived event: ${event.phone}');
    final phone = normalizePhone(event.phone);
    _log('📞 Normalized phone: $phone');
    if (phone.isEmpty) {
      _log('⚠️  Empty phone number. Showing Unknown.');
      // No digits (e.g. restricted call, or data not yet available). Show Unknown, not error.
      emit(state.copyWith(
        isLoadingClient: false,
        isLoadingDetails: false,
        clientName: 'Unknown',
        clientNumber: event.phone.trim().isNotEmpty ? event.phone.trim() : 'No number',
        error: null,
      ));
      return;
    }

      emit(state.copyWith(
        isLoadingClient: true,
        error: null,
        clientName: null,
        clientNumber: null,
        pendingOrder: null,
        scheduledTrip: null,
        lastTransaction: null,
      ));
      _log('🔄 Loading client data...');

    try {
      _log('🔍 Fetching client by phone: $phone');
      final client = await _repository.fetchClientByPhone(phone);
      if (client == null) {
        _log('❌ Client not found for phone: $phone');
        emit(state.copyWith(
          isLoadingClient: false,
          clientName: 'Unknown',
          clientNumber: event.phone,
          error: null,
        ));
        return;
      }
      _log('✅ Client found: ${client.name} (ID: ${client.id})');

      final displayNumber = client.primaryPhone ??
          (client.phoneIndex.isNotEmpty ? client.phoneIndex.first : null) ??
          event.phone;
      _log('📱 Display number: $displayNumber');
      emit(state.copyWith(
        isLoadingClient: false,
        clientName: client.name,
        clientNumber: displayNumber,
        error: null,
      ));

      final orgId = client.organizationId;
      _log('🏢 Org ID: $orgId');
      if (orgId == null || orgId.isEmpty) {
        _log('⚠️  No organization ID found. Skipping details fetch.');
        return;
      }

      emit(state.copyWith(isLoadingDetails: true));
      _log('🔄 Loading order and transaction details...');

      _log('Fetching pending orders for org: $orgId, client: ${client.id}');
      final orderResult = await _repository.fetchPendingOrderForClient(
        organizationId: orgId,
        clientId: client.id,
      );
      _log('Pending order result: ${orderResult != null ? 'Found (ID: ${orderResult.orderId})' : 'None'}');

      _log('Fetching last transaction for org: $orgId, client: ${client.id}');
      final lastTx = await _repository.fetchLastTransactionForClient(
        organizationId: orgId,
        clientId: client.id,
      );
      _log('Last transaction result: ${lastTx != null ? 'Found' : 'None'}');

      CallerOverlayScheduledTrip? trip;
      if (orderResult != null) {
        _log('Fetching active trip for order: ${orderResult.orderId}');
        trip = await _repository.fetchActiveTripForOrder(orderResult.orderId);
        _log('Active trip result: ${trip != null ? 'Found (ID: ${trip.tripId})' : 'None'}');
      }

      _log('✅ Overlay state updated with client details');
      emit(state.copyWith(
        isLoadingDetails: false,
        pendingOrder: orderResult,
        scheduledTrip: trip,
        lastTransaction: lastTx,
      ));
    } catch (e, st) {
      _log('❌ Error fetching client details: $e');
      _log('Stack: $st');
      // Firestore can fail (e.g. FAILED_PRECONDITION) when overlay runs without auth.
      // Show caller number and "Unknown" instead of raw error.
      emit(state.copyWith(
        isLoadingClient: false,
        isLoadingDetails: false,
        clientName: 'Unknown',
        clientNumber: event.phone,
        error: null,
      ));
    }
  }
}
