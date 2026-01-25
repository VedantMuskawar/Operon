import 'package:dash_mobile/data/repositories/caller_overlay_repository.dart';

class CallOverlayState {
  const CallOverlayState({
    this.clientName,
    this.clientNumber,
    this.pendingOrder,
    this.scheduledTrip,
    this.lastTransaction,
    this.isLoadingClient = false,
    this.isLoadingDetails = false,
    this.error,
  });

  final String? clientName;
  final String? clientNumber;
  final CallerOverlayPendingOrder? pendingOrder;
  final CallerOverlayScheduledTrip? scheduledTrip;
  final CallerOverlayLastTransaction? lastTransaction;
  final bool isLoadingClient;
  final bool isLoadingDetails;
  final String? error;

  CallOverlayState copyWith({
    String? clientName,
    String? clientNumber,
    CallerOverlayPendingOrder? pendingOrder,
    CallerOverlayScheduledTrip? scheduledTrip,
    CallerOverlayLastTransaction? lastTransaction,
    bool? isLoadingClient,
    bool? isLoadingDetails,
    String? error,
  }) {
    return CallOverlayState(
      clientName: clientName ?? this.clientName,
      clientNumber: clientNumber ?? this.clientNumber,
      pendingOrder: pendingOrder ?? this.pendingOrder,
      scheduledTrip: scheduledTrip ?? this.scheduledTrip,
      lastTransaction: lastTransaction ?? this.lastTransaction,
      isLoadingClient: isLoadingClient ?? this.isLoadingClient,
      isLoadingDetails: isLoadingDetails ?? this.isLoadingDetails,
      error: error ?? this.error,
    );
  }
}
