import 'package:bloc/bloc.dart';
import 'package:dash_mobile/data/repositories/caller_overlay_repository.dart';
import 'package:dash_mobile/data/utils/caller_overlay_utils.dart';
import 'package:dash_mobile/presentation/blocs/call_overlay/call_overlay_event.dart';
import 'package:dash_mobile/presentation/blocs/call_overlay/call_overlay_state.dart';

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
    final phone = normalizePhone(event.phone);
    if (phone.isEmpty) {
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

    try {
      final client = await _repository.fetchClientByPhone(phone);
      if (client == null) {
        emit(state.copyWith(
          isLoadingClient: false,
          clientName: 'Unknown',
          clientNumber: event.phone,
          error: null,
        ));
        return;
      }

      final displayNumber = client.primaryPhone ??
          (client.phoneIndex.isNotEmpty ? client.phoneIndex.first : null) ??
          event.phone;
      emit(state.copyWith(
        isLoadingClient: false,
        clientName: client.name,
        clientNumber: displayNumber,
        error: null,
      ));

      final orgId = client.organizationId;
      if (orgId == null || orgId.isEmpty) return;

      emit(state.copyWith(isLoadingDetails: true));

      final orderResult = await _repository.fetchPendingOrderForClient(
        organizationId: orgId,
        clientId: client.id,
      );
      final lastTx = await _repository.fetchLastTransactionForClient(
        organizationId: orgId,
        clientId: client.id,
      );

      CallerOverlayScheduledTrip? trip;
      if (orderResult != null) {
        trip = await _repository.fetchActiveTripForOrder(orderResult.orderId);
      }

      emit(state.copyWith(
        isLoadingDetails: false,
        pendingOrder: orderResult,
        scheduledTrip: trip,
        lastTransaction: lastTx,
      ));
    } catch (e, _) {
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
